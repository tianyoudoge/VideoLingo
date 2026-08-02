# Third-Party Notices

CaptionFlow source code is licensed under the MIT License. See [LICENSE](./LICENSE).

This project also uses or can interoperate with third-party components that keep their own licenses.

## Bundled in Release Builds

### whisper.cpp

CaptionFlow release builds bundle the whisper.cpp command-line runtime and dynamic libraries.

- Project: https://github.com/ggml-org/whisper.cpp
- License: MIT
- Bundled license path inside the app: `CaptionFlow.app/Contents/Resources/licenses/whisper.cpp-LICENSE`

### AMSMB2 and libsmb2

CaptionFlow bundles AMSMB2 as a replaceable dynamic library for direct SMB2/SMB3 directory browsing. The wrapper source is MIT-licensed, but because AMSMB2 includes libsmb2, the distributed dynamic library is treated as LGPL-2.1-or-later. CaptionFlow dynamically links this library so it can be replaced independently.

- AMSMB2 4.0.3: https://github.com/amosavian/AMSMB2/tree/4.0.3
- libsmb2 source: https://github.com/sahlberg/libsmb2 (LGPL-2.1-or-later)
- Bundled notices: `CaptionFlow.app/Contents/Resources/licenses/AMSMB2-LICENSE` and `libsmb2-COPYING`
- Corresponding source archives: `AMSMB2-4.0.3-source.tar.gz` and `libsmb2-source.tar.gz` in the same directory

## Not Bundled in Release Builds

### FFmpeg / FFprobe

CaptionFlow does not bundle FFmpeg or FFprobe in the GitHub release archive.

The app can download FFmpeg/FFprobe into the user's Application Support directory at runtime, or use an existing system installation. FFmpeg/FFprobe are not part of CaptionFlow's MIT license.

FFmpeg is generally licensed under LGPLv2.1-or-later, but builds that enable GPL components are GPL for FFmpeg itself. Builds that enable nonfree components may not be redistributable. Distributors should verify the exact FFmpeg build configuration and provide the required license notices and corresponding source when redistributing FFmpeg binaries.

- Project: https://ffmpeg.org/
- Legal notes: https://ffmpeg.org/legal.html

### Whisper Model Weights

CaptionFlow does not bundle Whisper model weights. Models are downloaded separately at runtime and are subject to their upstream terms.

- whisper.cpp model repository: https://huggingface.co/ggerganov/whisper.cpp

### Silero VAD Model Weights

CaptionFlow does not bundle Silero VAD model weights. The VAD model is downloaded separately at runtime and remains subject to its upstream terms.

- whisper.cpp VAD model repository: https://huggingface.co/ggml-org/whisper-vad

## LLM Providers

CaptionFlow talks to user-configured OpenAI-compatible LLM endpoints. API access, generated output, and billing are governed by the selected provider's own terms.
