# VideoLingo

[English](./README.md)

VideoLingo 是一个 macOS 桌面 App，用于把视频识别成字幕，并翻译成目标语言外挂字幕。它本地提取音频、做 VAD 语音分段、用 whisper.cpp 识别字幕，再通过 OpenAI-compatible 大模型接口翻译。

为了方便开源分发，App 包不会内置模型权重和 FFmpeg。用户安装后再按需下载运行组件。

## 特性

- 支持拖入视频。
- 源语言支持自动识别，也可以手动选择。
- 目标字幕语言支持 English、Japanese、简体中文、繁体中文、French、Spanish。
- 本地 whisper.cpp 识别运行时。
- 可配置 OpenAI-compatible 大模型供应商：DeepSeek、豆包、百炼/Qwen、Kimi、智谱、MiniMax 和自定义接口。
- 每个供应商独立保存 API Key。
- 按模型累计 token 消耗，包括输入、缓存命中输入、非缓存输入、输出和总 token。
- 输出外挂字幕：`.source.srt` 和目标语言 `.srt`。

## 处理链路

```text
视频
  -> FFmpeg 提取音频
  -> VAD 语音分段
  -> whisper.cpp 识别字幕
  -> OpenAI-compatible 大模型翻译
  -> .source.srt 和目标语言 .srt
```

## 运行时资源

VideoLingo 会把下载的运行组件放在：

```text
~/Library/Application Support/VideoLingo/
  models/
  tools/
```

App 包不包含 Whisper 模型权重。

## 本地开发

依赖：

- Apple Silicon macOS
- Swift Command Line Tools
- Go
- Homebrew
- CMake

本地构建：

```bash
./scripts/install_deps_macos.sh
./scripts/build_backend.sh
./scripts/build_app_bundle.sh
open ./VideoLingo.app
```

## Release 构建

本地生成 macOS release zip：

```bash
./scripts/build_release.sh
```

产物：

```text
dist/VideoLingo-macOS-arm64.zip
```

## GitHub Release

仓库内置 GitHub Actions workflow，打 tag 后自动构建并上传 release 产物：

```bash
git tag v0.1.0
git push origin v0.1.0
```

成功后，`VideoLingo-macOS-arm64.zip` 会上传到对应 tag 的 GitHub Release。

## 后端 CLI

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

## 许可证

VideoLingo 使用 MIT License。见 [LICENSE](./LICENSE)。

Copyright (c) 2026 dogggyu。

第三方组件和运行时依赖见 [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)。

第三方组件遵循各自许可证：

- release app 内置 whisper.cpp，遵循 MIT。
- release app 不内置 FFmpeg/FFprobe，也不内置 Whisper 模型权重。
- 运行时下载的 FFmpeg/FFprobe 取决于具体构建，可能是 LGPL/GPL/nonfree，不属于 VideoLingo 的 MIT 授权范围。
