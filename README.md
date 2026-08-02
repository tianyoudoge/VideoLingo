# CaptionFlow

[简体中文](./README.zh-CN.md)

CaptionFlow is a macOS desktop app for turning videos into bilingual subtitle files. It extracts audio locally, segments speech with Silero VAD, transcribes subtitles with whisper.cpp, repairs repeated hallucination ranges, and translates them with an OpenAI-compatible LLM provider.

The app is designed for lightweight distribution: model weights and FFmpeg are downloaded after installation instead of being bundled in the app archive.

## Features

- Drag-and-drop video import.
- Built-in SMB2/SMB3 video browser with Bonjour discovery, bulk directory listing, server modification-time sorting, local search, Keychain-only password storage, and on-demand mounting for FFmpeg.
- Source language auto-detection or manual selection.
- Target subtitle language selection: English, Japanese, Simplified Chinese, Traditional Chinese, French, and Spanish.
- Local whisper.cpp transcription runtime.
- Custom Whisper/Silero weight directory with migration support for external drives.
- Configurable OpenAI-compatible LLM providers: DeepSeek, Doubao, Bailian/Qwen, Kimi, Zhipu, MiniMax, and custom endpoints.
- Per-provider API key storage.
- Per-model token accounting, including prompt, cached prompt, uncached prompt, completion, and total tokens.
- External subtitle output: `.source.srt` plus a target-language `.srt`.

## Pipeline

```text
video
  -> FFmpeg audio extraction
  -> Silero VAD speech segmentation (120 ms minimum speech, 30 s maximum, 0.8 s overlap)
  -> whisper.cpp large-v3 Q5 transcription
  -> repeated-hallucination detection and local retry
  -> OpenAI-compatible LLM translation
  -> .source.srt and target-language .srt
```

## Runtime Assets

CaptionFlow stores downloaded runtime assets under:

```text
~/Library/Application Support/CaptionFlow/
  models/
    ggml-large-v3-q5_0.bin
    ggml-silero-v6.2.0.bin
  tools/
```

The app bundle does not include Whisper model weights.

Choose a custom location under **Model Management → Whisper Weight Storage**. If an external drive is unavailable, CaptionFlow stops downloads and transcription until the drive is reconnected or a new folder is selected. FFmpeg and app runtime tools remain in the default Application Support directory.

## Local Development

Requirements:

- macOS on Apple Silicon
- Swift Command Line Tools
- Go
- Homebrew
- CMake

Build locally:

```bash
./scripts/install_deps_macos.sh
./scripts/build_backend.sh
./scripts/build_app_bundle.sh
open ./CaptionFlow.app
```

## Release Build

Create a local macOS release archive:

```bash
./scripts/build_release.sh
```

Output:

```text
dist/CaptionFlow-macOS-arm64.zip
```

## GitHub Releases

The repository includes a GitHub Actions workflow that builds the macOS archive on tags.

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow uploads `CaptionFlow-macOS-arm64.zip` to the GitHub Release for that tag.

## Backend CLI

```bash
./bin/captionflow-backend transcribe \
  --input /path/to/video.mp4 \
  --output-dir /path/to/out \
  --api-key sk-xxx \
  --provider DeepSeek \
  --base-url https://api.deepseek.com/chat/completions \
  --llm-model deepseek-v4-flash \
  --language ja \
  --target-language zh-Hans \
  --model ~/Library/Application\ Support/CaptionFlow/models/ggml-large-v3-q5_0.bin \
  --vad-model ~/Library/Application\ Support/CaptionFlow/models/ggml-silero-v6.2.0.bin \
  --whisper-bin ./bin/whisper-cli \
  --ffmpeg /opt/homebrew/bin/ffmpeg \
  --ffprobe /opt/homebrew/bin/ffprobe
```

## License

CaptionFlow is released under the MIT License. See [LICENSE](./LICENSE).

Copyright (c) 2026 dogggyu.

See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for bundled and runtime third-party components.

Third-party components keep their own licenses:

- The release app bundles whisper.cpp under MIT.
- The release app does not bundle FFmpeg/FFprobe or Whisper model weights.
- Runtime FFmpeg/FFprobe downloads are governed by the downloaded build's own LGPL/GPL/nonfree status.
