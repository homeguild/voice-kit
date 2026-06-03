# homeguild_voice_deepgram

Deepgram STT provider for [homeguild_voice_kit](https://pub.dev/packages/homeguild_voice_kit). Real-time speech-to-text via WebSocket with multi-language support, Voice Activity Detection, and keep-alive.

Part of [Voice Kit](https://github.com/homeguild/voice-kit) by [HomeGuild Labs](https://www.homeguild.ai/labs).

## Usage

```dart
import 'package:homeguild_voice_deepgram/homeguild_voice_deepgram.dart';

final stt = DeepgramSTTProvider(
  apiKey: 'YOUR_DEEPGRAM_KEY',
  model: 'nova-2',       // Deepgram's latest model
  language: 'multi',      // Auto-detect English/Spanish
  sampleRate: 16000,
  onUsageTracked: (seconds) => print('Used ${seconds}s of STT'),
);
```

Pass it to `VoiceConversationManager` from `homeguild_voice_kit`:

```dart
final manager = VoiceConversationManager(
  sttProvider: stt,
  ttsProvider: tts,
  streamAdapter: myBackend,
);
```

## Features

- Real-time transcription with interim and final results
- Multi-language auto-detection (English/Spanish via `language: 'multi'`)
- Voice Activity Detection (VAD) events for natural pause detection
- Configurable model, language, encoding, and sample rate
- Keep-alive mechanism (5s intervals) for stable WebSocket connections
- Optional usage tracking callback

## Requirements

- A [Deepgram](https://deepgram.com) API key
- Microphone permission on the target platform

## License

MIT — see [LICENSE](https://github.com/homeguild/voice-kit/blob/main/LICENSE).
