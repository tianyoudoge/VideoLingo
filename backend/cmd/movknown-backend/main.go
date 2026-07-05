package main

import (
	"bufio"
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
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
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
	Language              string
	TargetLanguage        string
	Provider              string
	APIKey                string
	BaseURL               string
	Model                 string
	VADNoise              string
	VADSilence            float64
	VADPadding            float64
	MinSegment            float64
	MaxSegment            float64
	MaxPackGap            float64
	BatchSize             int
	MaxLineChars          int
	KeepTemp              bool
	TotalPromptTokens     int
	TotalCachedPrompt     int
	TotalCompletionTokens int
	TotalTokens           int
}

type Segment struct {
	Start float64
	End   float64
}

type Cue struct {
	Index int
	Start float64
	End   float64
	Text  string
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
		fatalf("usage: videolingo-backend transcribe --input video.mp4 --api-key $DEEPSEEK_API_KEY --model models/ggml-small-q5_1.bin")
	}

	switch os.Args[1] {
	case "transcribe":
		cfg, err := parseTranscribe(os.Args[2:])
		if err != nil {
			fatalf("%v", err)
		}
		if err := runTranscribe(context.Background(), cfg); err != nil {
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
		FFmpeg:         "ffmpeg",
		FFprobe:        "ffprobe",
		WhisperBin:     "whisper-cli",
		ModelPath:      "models/ggml-medium.bin",
		Language:       "auto",
		TargetLanguage: "zh-Hans",
		Provider:       "deepseek",
		APIKey:         os.Getenv("DEEPSEEK_API_KEY"),
		BaseURL:        "https://api.deepseek.com/chat/completions",
		Model:          "deepseek-v4-flash",
		VADNoise:       "-35dB",
		VADSilence:     0.80,
		VADPadding:     0.30,
		MinSegment:     2.00,
		MaxSegment:     240,
		MaxPackGap:     8,
		BatchSize:      50,
		MaxLineChars:   18,
	}

	fs.StringVar(&cfg.Input, "input", cfg.Input, "input video path")
	fs.StringVar(&cfg.OutputDir, "output-dir", cfg.OutputDir, "output directory")
	fs.StringVar(&cfg.FFmpeg, "ffmpeg", cfg.FFmpeg, "ffmpeg executable")
	fs.StringVar(&cfg.FFprobe, "ffprobe", cfg.FFprobe, "ffprobe executable")
	fs.StringVar(&cfg.WhisperBin, "whisper-bin", cfg.WhisperBin, "whisper.cpp whisper-cli executable")
	fs.StringVar(&cfg.ModelPath, "model", cfg.ModelPath, "whisper.cpp ggml model path")
	fs.StringVar(&cfg.Language, "language", cfg.Language, "source language")
	fs.StringVar(&cfg.TargetLanguage, "target-language", cfg.TargetLanguage, "target subtitle language")
	fs.StringVar(&cfg.Provider, "provider", cfg.Provider, "translation provider name")
	fs.StringVar(&cfg.APIKey, "api-key", cfg.APIKey, "translation API key")
	fs.StringVar(&cfg.BaseURL, "base-url", cfg.BaseURL, "OpenAI-compatible chat completions endpoint")
	fs.StringVar(&cfg.Model, "llm-model", cfg.Model, "translation model")
	fs.StringVar(&cfg.BaseURL, "deepseek-url", cfg.BaseURL, "deprecated alias for --base-url")
	fs.StringVar(&cfg.Model, "deepseek-model", cfg.Model, "deprecated alias for --llm-model")
	fs.StringVar(&cfg.VADNoise, "vad-noise", cfg.VADNoise, "ffmpeg silencedetect noise threshold")
	fs.Float64Var(&cfg.VADSilence, "vad-silence", cfg.VADSilence, "minimum silence duration")
	fs.Float64Var(&cfg.VADPadding, "vad-padding", cfg.VADPadding, "seconds of padding around VAD segments")
	fs.Float64Var(&cfg.MinSegment, "min-segment", cfg.MinSegment, "minimum speech segment seconds")
	fs.Float64Var(&cfg.MaxSegment, "max-segment", cfg.MaxSegment, "maximum segment seconds before splitting")
	fs.Float64Var(&cfg.MaxPackGap, "max-pack-gap", cfg.MaxPackGap, "maximum silence gap seconds allowed when packing speech segments")
	fs.IntVar(&cfg.BatchSize, "batch-size", cfg.BatchSize, "translation cue batch size")
	fs.IntVar(&cfg.MaxLineChars, "max-line-chars", cfg.MaxLineChars, "Chinese subtitle wrap length")
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
	tmp, err := os.MkdirTemp("", "videolingo-*")
	if err != nil {
		return err
	}
	if !cfg.KeepTemp {
		defer os.RemoveAll(tmp)
	}

	emit("progress", "extract", "extracting 16 kHz mono audio", 0.03, "")
	audio := filepath.Join(tmp, "audio.wav")
	if err := runCmd(ctx, cfg.FFmpeg, "-y", "-i", cfg.Input, "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", audio); err != nil {
		return err
	}

	emit("progress", "vad", "detecting speech segments", 0.10, "")
	duration, err := probeDuration(ctx, cfg, audio)
	if err != nil {
		return err
	}
	emitProgress("progress", "extract", fmt.Sprintf("已提取 %.1f 分钟音频", duration/60), 0.08, "", duration, 0, 0)
	segments, err := detectSegments(ctx, cfg, audio, duration)
	if err != nil {
		return err
	}
	if len(segments) == 0 {
		segments = []Segment{{Start: 0, End: duration}}
	}
	emitProgress("progress", "vad", fmt.Sprintf("切成 %d 个识别块", len(segments)), 0.16, "", duration, len(segments), 0)

	cues, err := transcribeSegments(ctx, cfg, tmp, audio, segments)
	if err != nil {
		return err
	}
	if len(cues) == 0 {
		return errors.New("whisper produced no subtitle cues")
	}
	normalizeCues(cues)
	cues = filterCues(cues)
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

func transcribeSegments(ctx context.Context, cfg Config, tmp string, audio string, segments []Segment) ([]Cue, error) {
	var all []Cue
	for i, seg := range segments {
		percent := 0.18 + 0.52*(float64(i)/math.Max(1, float64(len(segments))))
		emitProgress("progress", "whisper", fmt.Sprintf("正在识别第 %d/%d 块，%.1f-%.1f 分钟", i+1, len(segments), seg.Start/60, seg.End/60), percent, "", seg.End, len(segments), i+1)

		segPath := filepath.Join(tmp, fmt.Sprintf("segment_%04d.wav", i+1))
		if err := runCmd(ctx, cfg.FFmpeg, "-y", "-ss", fmt.Sprintf("%.3f", seg.Start), "-to", fmt.Sprintf("%.3f", seg.End), "-i", audio, "-c", "copy", segPath); err != nil {
			return nil, err
		}

		outBase := filepath.Join(tmp, fmt.Sprintf("segment_%04d", i+1))
		whisperArgs := []string{
			"-m", cfg.ModelPath,
			"-f", segPath,
			"-l", cfg.Language,
			"-osrt",
			"-of", outBase,
			"--no-prints",
			"--suppress-nst",
			"--no-speech-thold", "0.35",
			"--logprob-thold", "-0.60",
			"--entropy-thold", "2.20",
		}
		err := runCmd(ctx, cfg.WhisperBin, whisperArgs...)
		if err != nil {
			// Older whisper.cpp builds may not support --no-prints.
			err = runCmd(ctx, cfg.WhisperBin, "-m", cfg.ModelPath, "-f", segPath, "-l", cfg.Language, "-osrt", "-of", outBase)
		}
		if err != nil {
			return nil, err
		}

		part, err := parseSRT(outBase + ".srt")
		if err != nil {
			return nil, err
		}
		for _, cue := range part {
			cue.Start += seg.Start
			cue.End += seg.Start
			if strings.TrimSpace(cue.Text) != "" {
				all = append(all, cue)
			}
		}
	}
	sort.SliceStable(all, func(i, j int) bool { return all[i].Start < all[j].Start })
	return all, nil
}

func detectSegments(ctx context.Context, cfg Config, audio string, duration float64) ([]Segment, error) {
	cmd := exec.CommandContext(ctx, cfg.FFmpeg, "-hide_banner", "-nostats", "-i", audio, "-af", fmt.Sprintf("silencedetect=noise=%s:d=%.2f", cfg.VADNoise, cfg.VADSilence), "-f", "null", "-")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	cmd.Stdout = io.Discard
	_ = cmd.Run()

	reStart := regexp.MustCompile(`silence_start:\s*([0-9.]+)`)
	reEnd := regexp.MustCompile(`silence_end:\s*([0-9.]+)`)
	scanner := bufio.NewScanner(strings.NewReader(stderr.String()))

	var segments []Segment
	speechStart := 0.0
	inSilence := false
	for scanner.Scan() {
		line := scanner.Text()
		if m := reStart.FindStringSubmatch(line); len(m) == 2 {
			silenceStart, _ := strconv.ParseFloat(m[1], 64)
			if silenceStart-speechStart >= cfg.MinSegment {
				segments = append(segments, Segment{
					Start: math.Max(0, speechStart-cfg.VADPadding),
					End:   math.Min(duration, silenceStart+cfg.VADPadding),
				})
			}
			inSilence = true
			continue
		}
		if m := reEnd.FindStringSubmatch(line); len(m) == 2 {
			silenceEnd, _ := strconv.ParseFloat(m[1], 64)
			speechStart = silenceEnd
			inSilence = false
		}
	}
	if !inSilence && duration-speechStart >= cfg.MinSegment {
		segments = append(segments, Segment{Start: math.Max(0, speechStart-cfg.VADPadding), End: duration})
	}
	segments = mergeCloseSegments(segments, 1.50)
	segments = packSegments(segments, cfg.MaxSegment, cfg.MaxPackGap)
	return splitLongSegments(segments, cfg.MaxSegment), nil
}

func mergeCloseSegments(in []Segment, gap float64) []Segment {
	if len(in) == 0 {
		return in
	}
	out := []Segment{in[0]}
	for _, seg := range in[1:] {
		last := &out[len(out)-1]
		if seg.Start-last.End <= gap {
			last.End = math.Max(last.End, seg.End)
		} else {
			out = append(out, seg)
		}
	}
	return out
}

func splitLongSegments(in []Segment, maxLen float64) []Segment {
	if maxLen <= 0 {
		return in
	}
	var out []Segment
	for _, seg := range in {
		if seg.End-seg.Start <= maxLen {
			out = append(out, seg)
			continue
		}
		for start := seg.Start; start < seg.End; start += maxLen {
			out = append(out, Segment{Start: start, End: math.Min(seg.End, start+maxLen)})
		}
	}
	return out
}

func packSegments(in []Segment, maxLen float64, maxGap float64) []Segment {
	if len(in) == 0 || maxLen <= 0 {
		return in
	}

	out := make([]Segment, 0, len(in))
	current := in[0]
	for _, seg := range in[1:] {
		gap := seg.Start - current.End
		if gap <= maxGap && seg.End-current.Start <= maxLen {
			current.End = math.Max(current.End, seg.End)
			continue
		}
		out = append(out, current)
		current = seg
	}
	out = append(out, current)
	return out
}

func translateCues(ctx context.Context, cfg *Config, cues []Cue) ([]Cue, error) {
	out := make([]Cue, len(cues))
	copy(out, cues)
	for start := 0; start < len(cues); start += cfg.BatchSize {
		end := min(start+cfg.BatchSize, len(cues))
		percent := 0.76 + 0.20*(float64(start)/math.Max(1, float64(len(cues))))
		emit("progress", "translate", fmt.Sprintf("正在翻译第 %d-%d/%d 句", start+1, end, len(cues)), percent, "")

		translations := translateBatchWithRetry(ctx, cfg, cues[start:end], 3)
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

func translateBatchWithRetry(ctx context.Context, cfg *Config, cues []Cue, attempts int) []string {
	var lastErr error
	for attempt := 1; attempt <= attempts; attempt++ {
		translations, err := translateBatch(ctx, cfg, cues)
		if err == nil && hasAnyTranslation(translations) {
			return fillMissingTranslations(translations, cues)
		}
		if err != nil {
			lastErr = err
		} else {
			lastErr = errors.New("empty translation")
		}
		emit("progress", "translate", fmt.Sprintf("翻译失败，正在重试 %d/%d", attempt, attempts), 0, "")
		time.Sleep(time.Duration(attempt) * 2 * time.Second)
	}
	emit("progress", "translate", fmt.Sprintf("翻译仍失败，已回退为源语言：%v", lastErr), 0, "")
	fallback := make([]string, len(cues))
	for i, cue := range cues {
		fallback[i] = cue.Text
	}
	return fallback
}

func hasAnyTranslation(translations []string) bool {
	for _, text := range translations {
		if strings.TrimSpace(text) != "" {
			return true
		}
	}
	return false
}

func fillMissingTranslations(translations []string, cues []Cue) []string {
	out := make([]string, len(cues))
	for i := range cues {
		if i < len(translations) && strings.TrimSpace(translations[i]) != "" {
			out[i] = strings.TrimSpace(translations[i])
		} else {
			out[i] = cues[i].Text
		}
	}
	return out
}

func translateBatch(ctx context.Context, cfg *Config, cues []Cue) ([]string, error) {
	var b strings.Builder
	targetName := targetLanguageName(cfg.TargetLanguage)
	b.WriteString("Translate these source-language subtitles into " + targetName + ".\n")
	b.WriteString("Rules: keep the exact numbering, one subtitle per line, no timestamps, no notes, concise natural wording suitable for SRT subtitles.\n")
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
