# homeguild_voice_kit

Voice conversation orchestration for Flutter. Plug in any STT and TTS provider, connect your backend, and get a complete voice AI experience with a battle-tested state machine, streaming sentence buffering, and ready-made widgets.

Part of [Voice Kit](https://github.com/homeguild/voice-kit) by [HomeGuild Labs](https://www.homeguild.ai/labs).

## Features

- **VoiceConversationManager** — orchestrates the full voice loop: listen, transcribe, send to backend, speak response
- **Pluggable providers** — `STTProvider`, `TTSProvider`, and `VoiceStreamAdapter` abstract interfaces
- **State machine** — idle, listening, processing, speaking with automatic transitions and interrupt handling
- **Sentence buffering** — streams partial sentences to TTS as they arrive (on `.` `?` `!` or length threshold)
- **Filler word cleanup** — strips "um", "uh", "like", "you know" (configurable)
- **Tool announcements** — speaks status messages during tool calls
- **Ready-made widgets** — `VoiceInputButton`, `VoiceStatusIndicator`, `VoiceTranscriptDisplay`

## Quick Start

```dart
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';
import 'package:homeguild_voice_deepgram/homeguild_voice_deepgram.dart';
import 'package:homeguild_voice_openai_tts/homeguild_voice_openai_tts.dart';

final manager = VoiceConversationManager(
  sttProvider: DeepgramSTTProvider(apiKey: 'YOUR_DEEPGRAM_KEY'),
  ttsProvider: OpenAITTSProvider(apiKey: 'YOUR_OPENAI_KEY'),
  streamAdapter: MyBackendAdapter(),
);

await manager.startConversation(context: {'agent': 'support'});
```

## Writing Your Own Provider

Implement `STTProvider`, `TTSProvider`, or `VoiceStreamAdapter` to integrate any service. See the [full documentation](https://github.com/homeguild/voice-kit#writing-your-own-provider) for examples.

## License

MIT — see [LICENSE](https://github.com/homeguild/voice-kit/blob/main/LICENSE).

---

Built by [HomeGuild Labs](https://www.homeguild.ai/labs) — powering AI voice assistants for service professionals.
