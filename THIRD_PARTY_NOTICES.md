# Third-Party Notices

VideoLingo source code is licensed under the MIT License. See [LICENSE](./LICENSE).

This project also uses or can interoperate with third-party components that keep their own licenses.

## Bundled in Release Builds

### whisper.cpp

VideoLingo release builds bundle the whisper.cpp command-line runtime and dynamic libraries.

- Project: https://github.com/ggml-org/whisper.cpp
- License: MIT
- Bundled license path inside the app: `VideoLingo.app/Contents/Resources/licenses/whisper.cpp-LICENSE`

## Not Bundled in Release Builds

### FFmpeg / FFprobe

VideoLingo does not bundle FFmpeg or FFprobe in the GitHub release archive.

The app can download FFmpeg/FFprobe into the user's Application Support directory at runtime, or use an existing system installation. FFmpeg/FFprobe are not part of VideoLingo's MIT license.

FFmpeg is generally licensed under LGPLv2.1-or-later, but builds that enable GPL components are GPL for FFmpeg itself. Builds that enable nonfree components may not be redistributable. Distributors should verify the exact FFmpeg build configuration and provide the required license notices and corresponding source when redistributing FFmpeg binaries.

- Project: https://ffmpeg.org/
- Legal notes: https://ffmpeg.org/legal.html

### Whisper Model Weights

VideoLingo does not bundle Whisper model weights. Models are downloaded separately at runtime and are subject to their upstream terms.

- whisper.cpp model repository: https://huggingface.co/ggerganov/whisper.cpp

## LLM Providers

VideoLingo talks to user-configured OpenAI-compatible LLM endpoints. API access, generated output, and billing are governed by the selected provider's own terms.
