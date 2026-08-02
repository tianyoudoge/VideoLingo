package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode/utf8"
)

type Config struct {
	Input                 string
	OutputDir             string
	FFmpeg                string
	FFprobe               string
	WhisperBin            string
	ModelPath             string
	VADModelPath          string
	Language              string
	TargetLanguage        string
	Provider              string
	APIKey                string
	BaseURL               string
	Model                 string
	VADThreshold          float64
	VADMinSpeechMS        int
	VADMinSilenceMS       int
	VADMaxSpeech          float64
	VADSpeechPadMS        int
	VADOverlap            float64
	BatchSize             int
	MaxLineChars          int
	TranslationAttempts   int
	KeepTemp              bool
	TotalPromptTokens     int
	TotalCachedPrompt     int
	TotalCompletionTokens int
	TotalTokens           int
}

type Cue struct {
	Index int
	Start float64
	End   float64
	Text  string
}

type RepeatedRange struct {
	Start float64
	End   float64
	Text  string
	Count int
}

type Event struct {
	Event                string  `json:"event"`
	Stage                string  `json:"stage,omitempty"`
	Message              string  `json:"message,omitempty"`
	Percent              float64 `json:"percent,omitempty"`
	Path                 string  `json:"path,omitempty"`
	Index                int     `json:"index,omitempty"`
	Start                float64 `json:"start,omitempty"`
	End                  float64 `json:"end,omitempty"`
	Source               string  `json:"source,omitempty"`
	Target               string  `json:"target,omitempty"`
	DurationSeconds      float64 `json:"durationSeconds,omitempty"`
	SegmentCount         int     `json:"segmentCount,omitempty"`
	SegmentIndex         int     `json:"segmentIndex,omitempty"`
	Provider             string  `json:"provider,omitempty"`
	Model                string  `json:"model,omitempty"`
	PromptTokens         int     `json:"promptTokens,omitempty"`
	CachedPromptTokens   int     `json:"cachedPromptTokens,omitempty"`
	UncachedPromptTokens int     `json:"uncachedPromptTokens,omitempty"`
	CompletionTokens     int     `json:"completionTokens,omitempty"`
	TotalTokens          int     `json:"totalTokens,omitempty"`
}

func main() {
	if len(os.Args) < 2 {
		fatalf("usage: captionflow-backend transcribe --input video.mp4 --api-key $DEEPSEEK_API_KEY --model models/ggml-large-v3-q5_0.bin --vad-model models/ggml-silero-v6.2.0.bin")
	}

	switch os.Args[1] {
	case "transcribe":
		cfg, err := parseTranscribe(os.Args[2:])
		if err != nil {
			fatalf("%v", err)
		}
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		if err := runTranscribe(ctx, cfg); err != nil {
			fatalf("%v", err)
		}
	default:
		fatalf("unknown command: %s", os.Args[1])
	}
}

func parseTranscribe(args []string) (Config, error) {
	fs := flag.NewFlagSet("transcribe", flag.ContinueOnError)
	fs.SetOutput(io.Discard)

	cfg := Config{
		FFmpeg:              "ffmpeg",
		FFprobe:             "ffprobe",
		WhisperBin:          "whisper-cli",
		ModelPath:           "models/ggml-large-v3-q5_0.bin",
		VADModelPath:        "models/ggml-silero-v6.2.0.bin",
		Language:            "ja",
		TargetLanguage:      "zh-Hans",
		Provider:            "deepseek",
		APIKey:              os.Getenv("DEEPSEEK_API_KEY"),
		BaseURL:             "https://api.deepseek.com/chat/completions",
		Model:               "deepseek-v4-flash",
		VADThreshold:        0.45,
		VADMinSpeechMS:      120,
		VADMinSilenceMS:     500,
		VADMaxSpeech:        30,
		VADSpeechPadMS:      350,
		VADOverlap:          0.80,
		BatchSize:           50,
		MaxLineChars:        18,
		TranslationAttempts: 5,
	}

	fs.StringVar(&cfg.Input, "input", cfg.Input, "input video path")
	fs.StringVar(&cfg.OutputDir, "output-dir", cfg.OutputDir, "output directory")
	fs.StringVar(&cfg.FFmpeg, "ffmpeg", cfg.FFmpeg, "ffmpeg executable")
	fs.StringVar(&cfg.FFprobe, "ffprobe", cfg.FFprobe, "ffprobe executable")
	fs.StringVar(&cfg.WhisperBin, "whisper-bin", cfg.WhisperBin, "whisper.cpp whisper-cli executable")
	fs.StringVar(&cfg.ModelPath, "model", cfg.ModelPath, "whisper.cpp ggml model path")
	fs.StringVar(&cfg.VADModelPath, "vad-model", cfg.VADModelPath, "whisper.cpp Silero VAD model path")
	fs.StringVar(&cfg.Language, "language", cfg.Language, "source language")
	fs.StringVar(&cfg.TargetLanguage, "target-language", cfg.TargetLanguage, "target subtitle language")
	fs.StringVar(&cfg.Provider, "provider", cfg.Provider, "translation provider name")
	fs.StringVar(&cfg.APIKey, "api-key", cfg.APIKey, "translation API key")
	fs.StringVar(&cfg.BaseURL, "base-url", cfg.BaseURL, "OpenAI-compatible chat completions endpoint")
	fs.StringVar(&cfg.Model, "llm-model", cfg.Model, "translation model")
	fs.StringVar(&cfg.BaseURL, "deepseek-url", cfg.BaseURL, "deprecated alias for --base-url")
	fs.StringVar(&cfg.Model, "deepseek-model", cfg.Model, "deprecated alias for --llm-model")
	fs.Float64Var(&cfg.VADThreshold, "vad-threshold", cfg.VADThreshold, "Silero speech probability threshold")
	fs.IntVar(&cfg.VADMinSpeechMS, "vad-min-speech-ms", cfg.VADMinSpeechMS, "minimum speech duration in milliseconds")
	fs.IntVar(&cfg.VADMinSilenceMS, "vad-min-silence-ms", cfg.VADMinSilenceMS, "minimum silence duration in milliseconds")
	fs.Float64Var(&cfg.VADMaxSpeech, "vad-max-speech", cfg.VADMaxSpeech, "maximum VAD speech chunk seconds")
	fs.IntVar(&cfg.VADSpeechPadMS, "vad-speech-pad-ms", cfg.VADSpeechPadMS, "speech padding in milliseconds")
	fs.Float64Var(&cfg.VADOverlap, "vad-overlap", cfg.VADOverlap, "overlap between VAD chunks in seconds")
	fs.IntVar(&cfg.BatchSize, "batch-size", cfg.BatchSize, "translation cue batch size")
	fs.IntVar(&cfg.MaxLineChars, "max-line-chars", cfg.MaxLineChars, "Chinese subtitle wrap length")
	fs.IntVar(&cfg.TranslationAttempts, "translation-attempts", cfg.TranslationAttempts, "maximum retries for missing subtitle translations")
	fs.BoolVar(&cfg.KeepTemp, "keep-temp", cfg.KeepTemp, "keep temp files")

	if err := fs.Parse(args); err != nil {
		return cfg, err
	}
	if cfg.Input == "" {
		return cfg, errors.New("--input is required")
	}
	if cfg.APIKey == "" {
		return cfg, errors.New("--api-key is required")
	}
	if cfg.OutputDir == "" {
		cfg.OutputDir = filepath.Dir(cfg.Input)
	}
	return cfg, nil
}

func runTranscribe(ctx context.Context, cfg Config) error {
	started := time.Now()
	if err := requireFile(cfg.Input, "input video"); err != nil {
		return err
	}
	if err := requireFile(cfg.ModelPath, "whisper model"); err != nil {
		return err
	}
	if err := requireFile(cfg.VADModelPath, "Silero VAD model"); err != nil {
		return err
	}
	if _, err := exec.LookPath(cfg.FFmpeg); err != nil && !filepath.IsAbs(cfg.FFmpeg) {
		return fmt.Errorf("ffmpeg not found: %w", err)
	}
	if _, err := exec.LookPath(cfg.FFprobe); err != nil && !filepath.IsAbs(cfg.FFprobe) {
		return fmt.Errorf("ffprobe not found: %w", err)
	}
	if _, err := exec.LookPath(cfg.WhisperBin); err != nil && !filepath.IsAbs(cfg.WhisperBin) {
		return fmt.Errorf("whisper executable not found: %w", err)
	}

	if err := os.MkdirAll(cfg.OutputDir, 0o755); err != nil {
		return err
	}

	base := trimExt(filepath.Base(cfg.Input))
	sourceSRT := filepath.Join(cfg.OutputDir, base+".source.srt")
	targetSRT := filepath.Join(cfg.OutputDir, base+"."+targetSubtitleSuffix(cfg.TargetLanguage)+".srt")
	tmp, err := os.MkdirTemp("", "captionflow-*")
	if err != nil {
		return err
	}
	if !cfg.KeepTemp {
		defer os.RemoveAll(tmp)
	}
	inputPath, err := stageSMBInput(ctx, cfg.Input, tmp)
	if err != nil {
		return err
	}

	emit("progress", "extract", "extracting 16 kHz mono audio", 0.03, "")
	audio := filepath.Join(tmp, "audio.wav")
	if err := runCmd(ctx, cfg.FFmpeg, "-y", "-i", inputPath, "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", audio); err != nil {
		return err
	}

	emit("progress", "vad", "使用 Silero VAD 检测语音并保留短句", 0.10, "")
	duration, err := probeDuration(ctx, cfg, audio)
	if err != nil {
		return err
	}
	emitProgress("progress", "extract", fmt.Sprintf("已提取 %.1f 分钟音频", duration/60), 0.08, "", duration, 0, 0)
	emitProgress("progress", "vad", "Silero VAD 最长语音块 30 秒，重叠 0.8 秒", 0.16, "", duration, 0, 0)

	cues, err := transcribeWithSilero(ctx, cfg, tmp, audio, "primary", 0, false)
	if err != nil {
		return err
	}
	if len(cues) == 0 {
		return errors.New("whisper produced no subtitle cues")
	}
	normalizeCues(cues)
	cues = filterCues(cues)
	cues, err = repairRepeatedRanges(ctx, cfg, tmp, audio, duration, cues)
	if err != nil {
		return err
	}
	normalizeCues(cues)
	if len(cues) == 0 {
		return errors.New("all subtitle cues were filtered as non-speech")
	}
	for _, cue := range cues {
		emitSubtitle(cue.Index, cue.Start, cue.End, cue.Text, "")
	}
	if err := writeSRT(sourceSRT, cues, false, cfg.MaxLineChars); err != nil {
		return err
	}
	emit("artifact", "transcribe", "源语言字幕已写入", 0.72, sourceSRT)

	emit("progress", "translate", fmt.Sprintf("开始翻译为 %s", targetLanguageName(cfg.TargetLanguage)), 0.74, "")
	translated, err := translateCues(ctx, &cfg, cues)
	if err != nil {
		return err
	}
	if err := writeSRT(targetSRT, translated, true, cfg.MaxLineChars); err != nil {
		return err
	}
	emitTokenUsage(cfg.Provider, cfg.Model, cfg.TotalPromptTokens, cfg.TotalCachedPrompt, cfg.TotalCompletionTokens, cfg.TotalTokens)
	emit("done", "complete", fmt.Sprintf("finished in %s", time.Since(started).Round(time.Second)), 1, targetSRT)
	return nil
}

func stageSMBInput(ctx context.Context, inputPath, tmp string) (string, error) {
	if !isSMBFileSystem(inputPath) {
		return inputPath, nil
	}

	info, err := os.Stat(inputPath)
	if err != nil {
		return "", fmt.Errorf("inspect SMB input: %w", err)
	}
	if info.Size() <= 0 {
		return "", errors.New("SMB input video is empty")
	}
	if available, err := availableBytes(tmp); err == nil && uint64(info.Size()) > available {
		return "", fmt.Errorf("not enough local temporary disk space to stage SMB video: need %s, available %s", byteSize(info.Size()), byteSize(int64(available)))
	}

	emitProgress("progress", "copy", fmt.Sprintf("正在从 SMB 复制视频到本机临时目录（%s）", byteSize(info.Size())), 0.01, "", 0, 0, 0)
	source, err := os.Open(inputPath)
	if err != nil {
		return "", fmt.Errorf("open SMB input: %w", err)
	}
	defer source.Close()

	stagedPath := filepath.Join(tmp, "source"+filepath.Ext(inputPath))
	target, err := os.OpenFile(stagedPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return "", fmt.Errorf("create local staged video: %w", err)
	}
	defer target.Close()

	buffer := make([]byte, 4*1024*1024)
	var copied int64
	lastUpdate := time.Now()
	for {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		read, readErr := source.Read(buffer)
		if read > 0 {
			written, writeErr := target.Write(buffer[:read])
			copied += int64(written)
			if writeErr != nil {
				return "", fmt.Errorf("write local staged video: %w", writeErr)
			}
			if written != read {
				return "", io.ErrShortWrite
			}
		}
		if time.Since(lastUpdate) >= 2*time.Second {
			percent := 0.01 + 0.02*float64(copied)/float64(info.Size())
			emitProgress("progress", "copy", fmt.Sprintf("正在复制 SMB 视频：%s / %s", byteSize(copied), byteSize(info.Size())), percent, "", 0, 0, 0)
			lastUpdate = time.Now()
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return "", fmt.Errorf("read SMB input: %w", readErr)
		}
	}
	if err := target.Sync(); err != nil {
		return "", fmt.Errorf("sync local staged video: %w", err)
	}
	if copied != info.Size() {
		return "", fmt.Errorf("SMB video copy incomplete: copied %s of %s", byteSize(copied), byteSize(info.Size()))
	}
	emitProgress("progress", "copy", "SMB 视频已完整复制到本机，开始提取音频", 0.03, "", 0, 0, 0)
	return stagedPath, nil
}

func isSMBFileSystem(path string) bool {
	var fs syscall.Statfs_t
	if err := syscall.Statfs(path, &fs); err != nil {
		return false
	}
	name := make([]byte, 0, len(fs.Fstypename))
	for _, char := range fs.Fstypename {
		if char == 0 {
			break
		}
		name = append(name, byte(char))
	}
	return string(name) == "smbfs"
}

func availableBytes(path string) (uint64, error) {
	var fs syscall.Statfs_t
	if err := syscall.Statfs(path, &fs); err != nil {
		return 0, err
	}
	return fs.Bavail * uint64(fs.Bsize), nil
}

func byteSize(value int64) string {
	const unit = 1024
	if value < unit {
		return fmt.Sprintf("%d B", value)
	}
	div, exp := int64(unit), 0
	for n := value / unit; n >= unit && exp < 5; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(value)/float64(div), "KMGTPE"[exp])
}

func transcribeWithSilero(ctx context.Context, cfg Config, tmp string, audio string, name string, offset float64, noContext bool) ([]Cue, error) {
	outBase := filepath.Join(tmp, name)
	language := strings.TrimSpace(cfg.Language)
	if language == "" || strings.EqualFold(language, "auto") {
		language = "ja"
	}
	args := []string{
		"-m", cfg.ModelPath,
		"-f", audio,
		"-l", language,
		"-osrt",
		"-of", outBase,
		"--no-prints",
		"--vad",
		"--vad-model", cfg.VADModelPath,
		"--vad-threshold", fmt.Sprintf("%.2f", cfg.VADThreshold),
		"--vad-min-speech-duration-ms", strconv.Itoa(cfg.VADMinSpeechMS),
		"--vad-min-silence-duration-ms", strconv.Itoa(cfg.VADMinSilenceMS),
		"--vad-max-speech-duration-s", fmt.Sprintf("%.1f", cfg.VADMaxSpeech),
		"--vad-speech-pad-ms", strconv.Itoa(cfg.VADSpeechPadMS),
		"--vad-samples-overlap", fmt.Sprintf("%.2f", cfg.VADOverlap),
	}
	if noContext {
		args = append(args, "--max-context", "0")
	}
	if err := runCmd(ctx, cfg.WhisperBin, args...); err != nil {
		return nil, err
	}
	part, err := parseSRT(outBase + ".srt")
	if err != nil {
		if noContext && os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	for i := range part {
		part[i].Start += offset
		part[i].End += offset
	}
	return part, nil
}

func repairRepeatedRanges(ctx context.Context, cfg Config, tmp string, audio string, duration float64, cues []Cue) ([]Cue, error) {
	ranges := detectRepeatedRanges(cues, 3)
	if len(ranges) == 0 {
		return cues, nil
	}
	emit("progress", "whisper", fmt.Sprintf("检测到 %d 个重复幻觉区间，开始局部重跑", len(ranges)), 0.66, "")
	out := cues
	for i, suspect := range ranges {
		clipStart := math.Max(0, suspect.Start-1.5)
		clipEnd := math.Min(duration, suspect.End+1.5)
		clipPath := filepath.Join(tmp, fmt.Sprintf("repair_%04d.wav", i+1))
		if err := runCmd(ctx, cfg.FFmpeg, "-y", "-ss", fmt.Sprintf("%.3f", clipStart), "-t", fmt.Sprintf("%.3f", clipEnd-clipStart), "-i", audio, "-c:a", "pcm_s16le", clipPath); err != nil {
			return nil, err
		}
		candidate, err := transcribeWithSilero(ctx, cfg, tmp, clipPath, fmt.Sprintf("repair_%04d", i+1), clipStart, true)
		if err != nil {
			return nil, err
		}
		candidate = cuesWithin(candidate, suspect.Start, suspect.End)
		if longestRepeatedRun(candidate) >= suspect.Count {
			emit("progress", "whisper", fmt.Sprintf("异常区间 %.1f-%.1f 秒重跑后未改善，保留原结果", suspect.Start, suspect.End), 0, "")
			continue
		}
		out = replaceCueRange(out, candidate, suspect.Start, suspect.End)
		emit("progress", "whisper", fmt.Sprintf("已修复重复区间 %.1f-%.1f 秒（连续 %d 条）", suspect.Start, suspect.End, suspect.Count), 0, "")
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].Start < out[j].Start })
	return out, nil
}

func detectRepeatedRanges(cues []Cue, minimum int) []RepeatedRange {
	var out []RepeatedRange
	for start := 0; start < len(cues); {
		key := comparableCueText(cues[start].Text)
		end := start + 1
		for end < len(cues) && key != "" && comparableCueText(cues[end].Text) == key && cues[end].Start-cues[end-1].End <= 3 {
			end++
		}
		if key != "" && end-start >= minimum {
			out = append(out, RepeatedRange{Start: cues[start].Start, End: cues[end-1].End, Text: cues[start].Text, Count: end - start})
		}
		start = end
	}
	return out
}

func comparableCueText(text string) string {
	text = strings.ToLower(strings.Join(strings.Fields(text), ""))
	return strings.Trim(text, "、。，．,.!?！？…・~〜ー-—()（）[]【】『』「」 ")
}

func longestRepeatedRun(cues []Cue) int {
	longest := 0
	for start := 0; start < len(cues); {
		key := comparableCueText(cues[start].Text)
		end := start + 1
		for end < len(cues) && key != "" && comparableCueText(cues[end].Text) == key && cues[end].Start-cues[end-1].End <= 3 {
			end++
		}
		longest = max(longest, end-start)
		start = end
	}
	return longest
}

func cuesWithin(cues []Cue, start float64, end float64) []Cue {
	out := make([]Cue, 0, len(cues))
	for _, cue := range cues {
		midpoint := (cue.Start + cue.End) / 2
		if midpoint >= start && midpoint <= end {
			out = append(out, cue)
		}
	}
	return out
}

func replaceCueRange(cues []Cue, replacement []Cue, start float64, end float64) []Cue {
	out := make([]Cue, 0, len(cues)+len(replacement))
	inserted := false
	for _, cue := range cues {
		if cue.End > start && cue.Start < end {
			if !inserted {
				out = append(out, replacement...)
				inserted = true
			}
			continue
		}
		out = append(out, cue)
	}
	if !inserted {
		out = append(out, replacement...)
	}
	return out
}

func translateCues(ctx context.Context, cfg *Config, cues []Cue) ([]Cue, error) {
	out := make([]Cue, len(cues))
	copy(out, cues)
	for start := 0; start < len(cues); start += cfg.BatchSize {
		end := min(start+cfg.BatchSize, len(cues))
		percent := 0.76 + 0.20*(float64(start)/math.Max(1, float64(len(cues))))
		emit("progress", "translate", fmt.Sprintf("正在翻译第 %d-%d/%d 句", start+1, end, len(cues)), percent, "")

		translations, err := translateBatchWithRetry(ctx, cfg, cues[start:end], cfg.TranslationAttempts)
		if err != nil {
			return nil, err
		}
		for i, text := range translations {
			if strings.TrimSpace(text) != "" {
				out[start+i].Text = strings.TrimSpace(text)
			}
			out[start+i].Index = start + i + 1
			emitSubtitle(out[start+i].Index, out[start+i].Start, out[start+i].End, cues[start+i].Text, out[start+i].Text)
		}
	}
	return out, nil
}

func translateBatchWithRetry(ctx context.Context, cfg *Config, cues []Cue, attempts int) ([]string, error) {
	if attempts < 1 {
		attempts = 1
	}
	translations := make([]string, len(cues))
	pending := make([]int, len(cues))
	for i := range cues {
		pending[i] = i
	}
	var lastErr error
	for attempt := 1; attempt <= attempts; attempt++ {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		batch := make([]Cue, len(pending))
		for i, index := range pending {
			batch[i] = cues[index]
		}
		partial, err := translateBatch(ctx, cfg, batch)
		if err == nil {
			nextPending := make([]int, 0, len(pending))
			for i, index := range pending {
				if i < len(partial) && isUsableTranslation(partial[i]) {
					translations[index] = strings.TrimSpace(partial[i])
				} else {
					nextPending = append(nextPending, index)
				}
			}
			pending = nextPending
			if len(pending) == 0 {
				return translations, nil
			}
			lastErr = fmt.Errorf("%d subtitle lines were missing or refused", len(pending))
		} else {
			lastErr = err
		}
		if attempt == attempts {
			break
		}
		emit("progress", "translate", fmt.Sprintf("有 %d 句未获得可用译文，正在重试 %d/%d", len(pending), attempt+1, attempts), 0, "")
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(time.Duration(attempt) * time.Second):
		}
	}
	for _, index := range pending {
		translations[index] = cues[index].Text
	}
	emit("progress", "translate", fmt.Sprintf("仍有 %d 句未能翻译，已保留原日文：%v", len(pending), lastErr), 0, "")
	return translations, nil
}

func isUsableTranslation(text string) bool {
	text = strings.TrimSpace(text)
	if text == "" {
		return false
	}
	lower := strings.ToLower(text)
	refusalMarkers := []string{
		"i can't", "i cannot", "i'm sorry", "unable to", "cannot assist",
		"抱歉", "无法", "不能协助", "不便", "申し訳", "できません",
	}
	for _, marker := range refusalMarkers {
		if strings.Contains(lower, marker) {
			return false
		}
	}
	return true
}

func translateBatch(ctx context.Context, cfg *Config, cues []Cue) ([]string, error) {
	var b strings.Builder
	targetName := targetLanguageName(cfg.TargetLanguage)
	b.WriteString("Translate these source-language subtitles into " + targetName + ".\n")
	b.WriteString("Rules: keep the exact numbering, translate every supplied line, one subtitle per line, no timestamps, no notes, concise natural wording suitable for SRT subtitles.\n")
	b.WriteString("This is a literal transformation task. Do not add, embellish, summarize, judge, or omit dialogue; preserve the meaning of the supplied text only.\n")
	b.WriteString("If the source and target languages are the same, polish the subtitles lightly without changing meaning.\n\n")
	for i, cue := range cues {
		fmt.Fprintf(&b, "%d. %s\n", i+1, cleanOneLine(cue.Text))
	}

	body := map[string]any{
		"model":       cfg.Model,
		"temperature": 0.2,
		"stream":      false,
		"messages": []map[string]string{
			{
				"role":    "system",
				"content": "You are a professional subtitle translator. Translate source-language subtitles into " + targetName + ". Preserve meaning, speaker tone, names, terminology, and subtitle brevity. Output only numbered translations.",
			},
			{"role": "user", "content": b.String()},
		},
	}
	payload, _ := json.Marshal(body)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, cfg.BaseURL, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+cfg.APIKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("translation api error %s: %s", resp.Status, strings.TrimSpace(string(raw)))
	}

	var decoded struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
		Usage struct {
			PromptTokens        int `json:"prompt_tokens"`
			CompletionTokens    int `json:"completion_tokens"`
			TotalTokens         int `json:"total_tokens"`
			PromptTokensDetails struct {
				CachedTokens int `json:"cached_tokens"`
			} `json:"prompt_tokens_details"`
		} `json:"usage"`
	}
	if err := json.Unmarshal(raw, &decoded); err != nil {
		return nil, err
	}
	if len(decoded.Choices) == 0 {
		return nil, errors.New("translation provider returned no choices")
	}
	cfg.TotalPromptTokens += decoded.Usage.PromptTokens
	cfg.TotalCachedPrompt += decoded.Usage.PromptTokensDetails.CachedTokens
	cfg.TotalCompletionTokens += decoded.Usage.CompletionTokens
	cfg.TotalTokens += decoded.Usage.TotalTokens
	emitTokenUsage(cfg.Provider, cfg.Model, cfg.TotalPromptTokens, cfg.TotalCachedPrompt, cfg.TotalCompletionTokens, cfg.TotalTokens)
	return parseNumberedTranslations(decoded.Choices[0].Message.Content, len(cues)), nil
}

func parseNumberedTranslations(content string, want int) []string {
	out := make([]string, want)
	re := regexp.MustCompile(`^\s*(\d+)[\.\)、:：-]\s*(.+?)\s*$`)
	for _, line := range strings.Split(content, "\n") {
		m := re.FindStringSubmatch(line)
		if len(m) != 3 {
			continue
		}
		n, _ := strconv.Atoi(m[1])
		if n >= 1 && n <= want {
			out[n-1] = strings.TrimSpace(m[2])
		}
	}
	return out
}

func probeDuration(ctx context.Context, cfg Config, path string) (float64, error) {
	cmd := exec.CommandContext(ctx, cfg.FFprobe, "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path)
	out, err := cmd.Output()
	if err != nil {
		return 0, err
	}
	duration, err := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
	if err != nil {
		return 0, err
	}
	return duration, nil
}

func parseSRT(path string) ([]Cue, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	normalized := strings.ReplaceAll(string(raw), "\r\n", "\n")
	blocks := regexp.MustCompile(`\n{2,}`).Split(strings.TrimSpace(normalized), -1)
	timeRe := regexp.MustCompile(`(\d\d:\d\d:\d\d[,.]\d\d\d)\s*-->\s*(\d\d:\d\d:\d\d[,.]\d\d\d)`)
	var cues []Cue
	for _, block := range blocks {
		lines := strings.Split(strings.TrimSpace(block), "\n")
		if len(lines) < 2 {
			continue
		}
		timeLine := 0
		if !strings.Contains(lines[0], "-->") && len(lines) > 1 {
			timeLine = 1
		}
		m := timeRe.FindStringSubmatch(lines[timeLine])
		if len(m) != 3 {
			continue
		}
		start, err1 := parseSRTTime(m[1])
		end, err2 := parseSRTTime(m[2])
		if err1 != nil || err2 != nil {
			continue
		}
		text := strings.TrimSpace(strings.Join(lines[timeLine+1:], " "))
		cues = append(cues, Cue{Start: start, End: end, Text: text})
	}
	return cues, nil
}

func writeSRT(path string, cues []Cue, wrap bool, maxChars int) error {
	var b strings.Builder
	for i, cue := range cues {
		text := strings.TrimSpace(cue.Text)
		if wrap {
			text = wrapChinese(text, maxChars)
		}
		fmt.Fprintf(&b, "%d\n%s --> %s\n%s\n\n", i+1, formatSRTTime(cue.Start), formatSRTTime(cue.End), text)
	}
	return os.WriteFile(path, []byte(b.String()), 0o644)
}

func normalizeCues(cues []Cue) {
	for i := range cues {
		cues[i].Index = i + 1
		cues[i].Text = strings.Join(strings.Fields(cues[i].Text), " ")
		if cues[i].End <= cues[i].Start {
			cues[i].End = cues[i].Start + 1.2
		}
	}
}

func filterCues(cues []Cue) []Cue {
	out := make([]Cue, 0, len(cues))
	for _, cue := range cues {
		text := strings.TrimSpace(cue.Text)
		if text == "" || isNonSpeechCue(text) {
			continue
		}
		out = append(out, cue)
	}
	for i := range out {
		out[i].Index = i + 1
	}
	return out
}

func isNonSpeechCue(text string) bool {
	normalized := strings.TrimSpace(text)
	if strings.ContainsAny(normalized, "♪♫") {
		return true
	}
	if strings.Contains(strings.ToUpper(normalized), "BGM") {
		return true
	}

	trimmed := strings.Trim(normalized, "()（）[]【】 ")
	isBracketed := trimmed != normalized
	if isBracketed {
		noiseWords := []string{"音", "声", "息", "泣", "笑", "拍手", "歓声", "スプ", "コーラ"}
		for _, word := range noiseWords {
			if strings.Contains(trimmed, word) {
				return true
			}
		}
	}
	return false
}

func parseSRTTime(s string) (float64, error) {
	s = strings.ReplaceAll(s, ",", ".")
	parts := strings.Split(s, ":")
	if len(parts) != 3 {
		return 0, fmt.Errorf("bad srt time: %s", s)
	}
	h, _ := strconv.Atoi(parts[0])
	m, _ := strconv.Atoi(parts[1])
	sec, err := strconv.ParseFloat(parts[2], 64)
	if err != nil {
		return 0, err
	}
	return float64(h*3600+m*60) + sec, nil
}

func formatSRTTime(seconds float64) string {
	if seconds < 0 {
		seconds = 0
	}
	msTotal := int64(math.Round(seconds * 1000))
	h := msTotal / 3_600_000
	msTotal %= 3_600_000
	m := msTotal / 60_000
	msTotal %= 60_000
	s := msTotal / 1000
	ms := msTotal % 1000
	return fmt.Sprintf("%02d:%02d:%02d,%03d", h, m, s, ms)
}

func wrapChinese(text string, maxChars int) string {
	if maxChars <= 0 || utf8.RuneCountInString(text) <= maxChars {
		return text
	}
	var lines []string
	var current []rune
	for _, r := range []rune(text) {
		current = append(current, r)
		if len(current) >= maxChars {
			lines = append(lines, strings.TrimSpace(string(current)))
			current = current[:0]
		}
	}
	if len(current) > 0 {
		lines = append(lines, strings.TrimSpace(string(current)))
	}
	if len(lines) > 2 {
		return strings.Join([]string{lines[0], strings.Join(lines[1:], "")}, "\n")
	}
	return strings.Join(lines, "\n")
}

func cleanOneLine(s string) string {
	return strings.Join(strings.Fields(strings.ReplaceAll(s, "\n", " ")), " ")
}

func targetLanguageName(code string) string {
	switch strings.ToLower(strings.TrimSpace(code)) {
	case "en":
		return "English"
	case "ja":
		return "Japanese"
	case "zh-hant", "zh_tw", "zh-tw", "traditional-chinese":
		return "Traditional Chinese"
	case "fr", "francis", "french":
		return "French"
	case "es", "spanish":
		return "Spanish"
	case "zh-hans", "zh_cn", "zh-cn", "zh", "simplified-chinese", "":
		return "Simplified Chinese"
	default:
		return code
	}
}

func targetSubtitleSuffix(code string) string {
	switch strings.ToLower(strings.TrimSpace(code)) {
	case "en":
		return "en"
	case "ja":
		return "ja"
	case "zh-hant", "zh_tw", "zh-tw", "traditional-chinese":
		return "zh-Hant"
	case "fr", "francis", "french":
		return "fr"
	case "es", "spanish":
		return "es"
	case "zh-hans", "zh_cn", "zh-cn", "zh", "simplified-chinese", "":
		return "zh-Hans"
	default:
		safe := regexp.MustCompile(`[^A-Za-z0-9_-]+`).ReplaceAllString(code, "-")
		return strings.Trim(safe, "-")
	}
}

func trimExt(name string) string {
	return strings.TrimSuffix(name, filepath.Ext(name))
}

func requireFile(path string, label string) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("%s not found at %s", label, path)
	}
	if info.IsDir() {
		return fmt.Errorf("%s is a directory: %s", label, path)
	}
	return nil
}

func runCmd(ctx context.Context, name string, args ...string) error {
	cmd := exec.CommandContext(ctx, name, args...)
	var stderr bytes.Buffer
	cmd.Stdout = io.Discard
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = err.Error()
		}
		return fmt.Errorf("%s failed: %s", filepath.Base(name), msg)
	}
	return nil
}

func emit(event, stage, message string, percent float64, path string) {
	encoded, _ := json.Marshal(Event{Event: event, Stage: stage, Message: message, Percent: percent, Path: path})
	fmt.Println(string(encoded))
}

func emitProgress(event, stage, message string, percent float64, path string, durationSeconds float64, segmentCount int, segmentIndex int) {
	encoded, _ := json.Marshal(Event{
		Event:           event,
		Stage:           stage,
		Message:         message,
		Percent:         percent,
		Path:            path,
		DurationSeconds: durationSeconds,
		SegmentCount:    segmentCount,
		SegmentIndex:    segmentIndex,
	})
	fmt.Println(string(encoded))
}

func emitSubtitle(index int, start float64, end float64, source string, target string) {
	encoded, _ := json.Marshal(Event{
		Event:  "subtitle",
		Stage:  "subtitle",
		Index:  index,
		Start:  start,
		End:    end,
		Source: strings.TrimSpace(source),
		Target: strings.TrimSpace(target),
	})
	fmt.Println(string(encoded))
}

func emitTokenUsage(provider string, model string, promptTokens int, cachedPromptTokens int, completionTokens int, totalTokens int) {
	uncachedPromptTokens := promptTokens - cachedPromptTokens
	if uncachedPromptTokens < 0 {
		uncachedPromptTokens = 0
	}
	encoded, _ := json.Marshal(Event{
		Event:                "usage",
		Stage:                "translate",
		Provider:             provider,
		Model:                model,
		PromptTokens:         promptTokens,
		CachedPromptTokens:   cachedPromptTokens,
		UncachedPromptTokens: uncachedPromptTokens,
		CompletionTokens:     completionTokens,
		TotalTokens:          totalTokens,
	})
	fmt.Println(string(encoded))
}

func fatalf(format string, args ...any) {
	emit("error", "error", fmt.Sprintf(format, args...), 0, "")
	os.Exit(1)
}
