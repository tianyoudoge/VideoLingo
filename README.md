# VideoLingo

[简体中文](./README.zh-CN.md)

VideoLingo is a macOS desktop app for turning videos into bilingual subtitle files. It extracts audio locally, detects speech segments, transcribes subtitles with whisper.cpp, and translates them with an OpenAI-compatible LLM provider.

The app is designed for lightweight distribution: model weights and FFmpeg are downloaded after installation instead of being bundled in the app archive.

## Features

- Drag-and-drop video import.
- Source language auto-detection or manual selection.
- Target subtitle language selection: English, Japanese, Simplified Chinese, Traditional Chinese, French, and Spanish.
- Local whisper.cpp transcription runtime.
- Configurable OpenAI-compatible LLM providers: DeepSeek, Doubao, Bailian/Qwen, Kimi, Zhipu, MiniMax, and custom endpoints.
- Per-provider API key storage.
- Per-model token accounting, including prompt, cached prompt, uncached prompt, completion, and total tokens.
- External subtitle output: `.source.srt` plus a target-language `.srt`.

## Pipeline

```text
video
  -> FFmpeg audio extraction
  -> VAD speech segmentation
  -> whisper.cpp transcription
  -> OpenAI-compatible LLM translation
  -> .source.srt and target-language .srt
```

## Runtime Assets

VideoLingo stores downloaded runtime assets under:

```text
~/Library/Application Support/VideoLingo/
  models/
  tools/
```

The app bundle does not include Whisper model weights.

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
open ./VideoLingo.app
```

## Release Build

Create a local macOS release archive:

```bash
./scripts/build_release.sh
```

Output:

```text
dist/VideoLingo-macOS-arm64.zip
```

## GitHub Releases

The repository includes a GitHub Actions workflow that builds the macOS archive on tags.

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow uploads `VideoLingo-macOS-arm64.zip` to the GitHub Release for that tag.

## Backend CLI

```bash
./bin/videolingo-backend transcribe \
  --input /path/to/video.mp4 \
  --output-dir /path/to/out \
  --api-key sk-xxx \
  --provider DeepSeek \
  --base-url https://api.deepseek.com/chat/completions \
  --llm-model deepseek-v4-flash \
  --language auto \
  --target-language zh-Hans \
  --model ~/Library/Application\ Support/VideoLingo/models/ggml-small-q5_1.bin \
  --whisper-bin ./bin/whisper-cli \
  --ffmpeg /opt/homebrew/bin/ffmpeg \
  --ffprobe /opt/homebrew/bin/ffprobe
```

## License

VideoLingo is released under the MIT License. See [LICENSE](./LICENSE).

Copyright (c) 2026 dogggyu.

See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for bundled and runtime third-party components.

Third-party components keep their own licenses:

- The release app bundles whisper.cpp under MIT.
- The release app does not bundle FFmpeg/FFprobe or Whisper model weights.
- Runtime FFmpeg/FFprobe downloads are governed by the downloaded build's own LGPL/GPL/nonfree status.
