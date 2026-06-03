# homeguild_voice_openai_tts

OpenAI TTS provider for [homeguild_voice_kit](https://pub.dev/packages/homeguild_voice_kit). Natural-sounding text-to-speech with a streaming sentence queue, voice selection, and speed control.

Part of [Voice Kit](https://github.com/homeguild/voice-kit) by [HomeGuild Labs](https://www.homeguild.ai/labs).

## Usage

```dart
import 'package:homeguild_voice_openai_tts/homeguild_voice_openai_tts.dart';

final tts = OpenAITTSProvider(
  apiKey: 'YOUR_OPENAI_KEY',
  voice: 'alloy',        // alloy, echo, fable, onyx, nova, shimmer
  speed: 1.25,            // 0.25 to 4.0
  model: 'tts-1',         // or 'tts-1-hd' for higher quality
  textSanitizer: (text) => text.replaceAll('**', ''),  // strip markdown
  onUsageTracked: (seconds) => print('Used ${seconds}s of TTS'),
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

- Streaming sentence queue with sequential playback
- Six voice options: alloy, echo, fable, onyx, nova, shimmer
- Runtime speed adjustment (0.25x to 4.0x)
- Optional text sanitizer callback (strip markdown, clean formatting)
- Optional usage tracking callback
- Graceful queue clearing for interruptions

## Requirements

- An [OpenAI](https://platform.openai.com) API key with TTS access

## License

MIT — see [LICENSE](https://github.com/homeguild/voice-kit/blob/main/LICENSE).
