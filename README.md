# Voice Kit

Voice conversation orchestration for Flutter. Plug in any STT and TTS provider, connect your backend, and get a complete voice AI experience with a battle-tested state machine, streaming sentence buffering, and ready-made widgets.

**Built by [HomeGuild Labs](https://www.homeguild.ai/labs)** — powering AI voice assistants for service professionals.

## Packages

| Package | Description | pub.dev |
|---------|-------------|---------|
| `homeguild_voice_kit` | Core orchestration, interfaces, models, and widgets | _coming soon_ |
| `homeguild_voice_deepgram` | Deepgram STT provider (WebSocket, multi-language, VAD) | _coming soon_ |
| `homeguild_voice_openai_tts` | OpenAI TTS provider (sentence queue, voice selection) | _coming soon_ |

## Why Voice Kit?

Building voice into a Flutter app means wiring together speech-to-text, a backend, and text-to-speech — then managing state transitions, microphone feedback loops, sentence buffering, interruptions, and filler word cleanup. Every team rebuilds this from scratch.

Voice Kit extracts all of that into a single, tested orchestration layer with pluggable providers. Swap Deepgram for Google STT, or OpenAI TTS for ElevenLabs, without touching your conversation logic.

## Quick Start

```dart
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';
import 'package:homeguild_voice_deepgram/homeguild_voice_deepgram.dart';
import 'package:homeguild_voice_openai_tts/homeguild_voice_openai_tts.dart';

// 1. Create providers
final stt = DeepgramSTTProvider(apiKey: 'YOUR_DEEPGRAM_KEY');
final tts = OpenAITTSProvider(apiKey: 'YOUR_OPENAI_KEY');

// 2. Implement your backend adapter
class MyBackendAdapter implements VoiceStreamAdapter {
  @override
  Stream<VoiceStreamChunk> streamResponse({
    required String message,
    required Map<String, dynamic> context,
  }) async* {
    // Stream response chunks from your backend
    yield VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart);
    yield VoiceStreamChunk(type: VoiceStreamChunkType.narrative, text: 'Hello!');
    yield VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd);
    yield VoiceStreamChunk(type: VoiceStreamChunkType.done);
  }
}

// 3. Wire it up
final manager = VoiceConversationManager(
  sttProvider: stt,
  ttsProvider: tts,
  streamAdapter: MyBackendAdapter(),
);

// 4. Start a conversation
await manager.startConversation(context: {'agent': 'support'});
```

## Architecture

```
                    ┌─────────────────────────────┐
                    │  VoiceConversationManager    │
                    │                             │
  User speaks ──►   │  STT ──► Clean ──► Backend  │
                    │                    │        │
                    │  TTS ◄── Buffer ◄──┘        │
                    │                             │
                    └─────────────────────────────┘
                         │         │         │
                    ┌────┘    ┌────┘    ┌────┘
                    ▼         ▼         ▼
               STTProvider  TTSProvider  VoiceStreamAdapter
               (abstract)   (abstract)   (abstract)
                    │         │
                    ▼         ▼
              Deepgram    OpenAI TTS
              (included)  (included)
```

### State Machine

```
idle ──► listening ──► processing ──► speaking ──► idle
                                         │
                                    (interrupt)
                                         │
                                         ▼
                                      listening
```

The manager handles all transitions automatically:
- **idle** — ready, microphone off
- **listening** — microphone streaming to STT
- **processing** — STT stopped, waiting for backend response
- **speaking** — TTS playing response audio
- Interruptions (user speaks while TTS plays) immediately stop TTS and resume listening

### What the Manager Does For You

- **Filler word removal** — strips "um", "uh", "like", "you know" (configurable)
- **Feedback loop prevention** — stops microphone before TTS plays
- **Sentence buffering** — streams partial sentences to TTS as they complete (on `.` `?` `!` or length threshold)
- **Tool announcements** — speaks status messages during tool calls ("Let me check on that...")
- **Error recovery** — speaks errors aloud and transitions back to idle

## Widgets

Three ready-made widgets that react to `VoiceConversationState`:

```dart
// Push-to-talk button with pulse animation
VoiceInputButton(
  state: currentState,
  onStart: () => manager.startConversation(),
  onStop: () => manager.stopConversation(),
  onCancel: () => manager.interruptSpeaking(),
)

// Color-coded status badge with wave indicators
VoiceStatusIndicator(state: currentState)

// Real-time transcript with auto-scroll
VoiceTranscriptDisplay(
  interimTranscript: interim,
  finalTranscript: final,
)
```

Also includes compact variants (`VoiceInputButtonCompact`, `VoiceTranscriptDisplayCompact`, `VoiceTranscriptBubble`) and a full-width `VoiceStatusBanner`.

## Writing Your Own Provider

Implement one of the abstract interfaces to integrate any service:

### STT Provider

```dart
class MySTTProvider implements STTProvider {
  @override
  Stream<STTResult> get transcriptStream => /* your stream */;

  @override
  Stream<String> get errorStream => /* your error stream */;

  @override
  bool get isListening => /* current state */;

  @override
  Future<void> startListening() async { /* open mic, connect */ }

  @override
  Future<void> stopListening() async { /* close mic, disconnect */ }

  @override
  void dispose() { /* cleanup */ }
}
```

### TTS Provider

```dart
class MyTTSProvider implements TTSProvider {
  @override
  Stream<bool> get isSpeakingStream => /* speaking state stream */;

  @override
  bool get hasPendingSentences => /* queue check */;

  @override
  Future<void> speakStreamingSentence(String sentence) async { /* queue + play */ }

  @override
  Future<void> stopAndClear() async { /* stop playback, clear queue */ }

  @override
  void dispose() { /* cleanup */ }
}
```

### Backend Adapter

```dart
class MyBackendAdapter implements VoiceStreamAdapter {
  @override
  Stream<VoiceStreamChunk> streamResponse({
    required String message,
    required Map<String, dynamic> context,
  }) async* {
    // Connect to your API, yield chunks as they arrive
    yield VoiceStreamChunk(type: VoiceStreamChunkType.narrative, text: '...');
  }
}
```

## Configuration

```dart
final manager = VoiceConversationManager(
  sttProvider: stt,
  ttsProvider: tts,
  streamAdapter: backend,

  // Custom filler words to strip from transcripts
  fillerWords: ['um', 'uh', 'like', 'you know', 'basically'],

  // Tool-call announcements (spoken while waiting for tool results)
  toolAnnouncements: {
    'search_database': ['Searching for that...'],
    'create_estimate': ['Preparing that estimate...'],
    'default': ['One moment...'],
  },

  // Flush sentence buffer when text exceeds this length without punctuation
  sentenceLengthThreshold: 100,
);
```

## Included Providers

### Deepgram STT

```dart
final stt = DeepgramSTTProvider(
  apiKey: 'YOUR_KEY',
  model: 'nova-2',          // Deepgram's latest model
  language: 'multi',         // Auto-detect (English/Spanish)
  sampleRate: 16000,
  onUsageTracked: (seconds) => print('Used ${seconds}s of STT'),
);
```

### OpenAI TTS

```dart
final tts = OpenAITTSProvider(
  apiKey: 'YOUR_KEY',
  voice: 'alloy',           // alloy, echo, fable, onyx, nova, shimmer
  speed: 1.25,              // 0.25 to 4.0
  model: 'tts-1',           // or 'tts-1-hd' for higher quality
  onUsageTracked: (seconds) => print('Used ${seconds}s of TTS'),
  textSanitizer: (text) => text.replaceAll('**', ''),  // strip markdown
);
```

## Roadmap

- [ ] TypeScript/npm packages (`@homeguild/voice-kit`)
- [ ] Google Cloud STT provider
- [ ] ElevenLabs TTS provider
- [ ] Native `flutter_tts` fallback provider
- [ ] Riverpod integration helpers
- [ ] CI/CD with GitHub Actions

## License

MIT — see [LICENSE](LICENSE).

---

Built with care by [HomeGuild Labs](https://www.homeguild.ai/labs). We build AI-powered tools for home service professionals. Voice Kit is extracted from our production voice assistant platform.
