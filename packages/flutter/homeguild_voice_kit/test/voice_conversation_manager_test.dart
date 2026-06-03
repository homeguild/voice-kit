import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

// ── Mock STT Provider ───────────────────────────────────────────────────

class MockSTTProvider implements STTProvider {
  final _transcripts = StreamController<STTResult>.broadcast();
  final _errors = StreamController<String>.broadcast();
  bool _isListening = false;
  int startCount = 0;
  int stopCount = 0;

  @override
  Stream<STTResult> get transcriptStream => _transcripts.stream;
  @override
  Stream<String> get errorStream => _errors.stream;
  @override
  bool get isListening => _isListening;

  @override
  Future<void> startListening() async {
    _isListening = true;
    startCount++;
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    stopCount++;
  }

  @override
  void dispose() {
    _transcripts.close();
    _errors.close();
  }

  /// Simulate an interim transcript arriving from the microphone.
  void emitInterim(String text) {
    _transcripts.add(STTResult(text: text, isFinal: false, confidence: 0.8));
  }

  /// Simulate a final transcript arriving from the microphone.
  void emitFinal(String text) {
    _transcripts.add(STTResult(text: text, isFinal: true, confidence: 0.95));
  }

  /// Simulate a VAD speech-final event.
  void emitSpeechFinal() {
    _transcripts.add(
        const STTResult(text: '', isFinal: false, confidence: 0, isSpeechFinal: true));
  }

  /// Simulate an STT error.
  void emitError(String msg) {
    _errors.add(msg);
  }
}

// ── Mock TTS Provider ───────────────────────────────────────────────────

class MockTTSProvider implements TTSProvider {
  final _isSpeaking = StreamController<bool>.broadcast();
  final List<String> spokenSentences = [];
  bool _hasPending = false;
  int stopCount = 0;

  @override
  Stream<bool> get isSpeakingStream => _isSpeaking.stream;
  @override
  bool get hasPendingSentences => _hasPending;

  @override
  Future<void> speakStreamingSentence(String sentence) async {
    spokenSentences.add(sentence);
  }

  @override
  Future<void> stopAndClear() async {
    stopCount++;
    _hasPending = false;
    _isSpeaking.add(false);
  }

  @override
  void dispose() {
    _isSpeaking.close();
  }

  void simulateSpeaking() => _isSpeaking.add(true);
  void simulateDoneSpeaking() => _isSpeaking.add(false);
  void setHasPending(bool v) => _hasPending = v;
}

// ── Mock Stream Adapter ─────────────────────────────────────────────────

class MockStreamAdapter implements VoiceStreamAdapter {
  List<VoiceStreamChunk> chunks = [];
  String? lastMessage;
  Map<String, dynamic>? lastContext;

  @override
  Stream<VoiceStreamChunk> streamResponse({
    required String message,
    required Map<String, dynamic> context,
  }) async* {
    lastMessage = message;
    lastContext = context;
    for (final chunk in chunks) {
      yield chunk;
    }
  }
}

// ── Tests ────────────────────────────────────────────────────────────────

void main() {
  late MockSTTProvider stt;
  late MockTTSProvider tts;
  late MockStreamAdapter adapter;
  late VoiceConversationManager manager;

  setUp(() {
    stt = MockSTTProvider();
    tts = MockTTSProvider();
    adapter = MockStreamAdapter();
    manager = VoiceConversationManager(
      sttProvider: stt,
      ttsProvider: tts,
      streamAdapter: adapter,
    );
  });

  tearDown(() async {
    await manager.dispose();
  });

  group('startConversation', () {
    test('transitions to listening state', () async {
      final states = <VoiceConversationState>[];
      manager.stateStream.listen(states.add);

      await manager.startConversation();

      expect(manager.currentState, VoiceConversationState.listening);
      expect(manager.isActive, isTrue);
      expect(stt.startCount, 1);
      await Future.delayed(Duration.zero); // let stream deliver
      expect(states, contains(VoiceConversationState.listening));
    });

    test('stops previous conversation if already active', () async {
      await manager.startConversation();
      expect(stt.startCount, 1);

      await manager.startConversation();
      expect(stt.startCount, 2);
      expect(stt.stopCount, greaterThanOrEqualTo(1));
    });

    test('passes context through to stream adapter', () async {
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'Hi.'),
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation(context: {'agent': 'test'});
      stt.emitFinal('hello');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(adapter.lastContext, {'agent': 'test'});
    });
  });

  group('stopConversation', () {
    test('transitions to idle and stops providers', () async {
      await manager.startConversation();
      await manager.stopConversation();

      expect(manager.currentState, VoiceConversationState.idle);
      expect(manager.isActive, isFalse);
      expect(stt.stopCount, greaterThanOrEqualTo(1));
      expect(tts.stopCount, greaterThanOrEqualTo(1));
    });
  });

  group('transcript handling', () {
    test('emits interim transcripts', () async {
      final interims = <String>[];
      manager.interimTranscriptStream.listen(interims.add);

      await manager.startConversation();
      stt.emitInterim('hello wor');
      await Future.delayed(Duration.zero);

      expect(interims, ['hello wor']);
    });

    test('cleans filler words from final transcripts', () async {
      final finals = <String>[];
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];
      manager.finalTranscriptStream.listen(finals.add);

      await manager.startConversation();
      stt.emitFinal('um I need like a new estimate you know');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(finals.length, 1);
      expect(finals.first, 'I need a new estimate');
    });

    test('ignores VAD speech-final events', () async {
      final finals = <String>[];
      manager.finalTranscriptStream.listen(finals.add);

      await manager.startConversation();
      stt.emitSpeechFinal();
      await Future.delayed(Duration.zero);

      expect(finals, isEmpty);
    });

    test('ignores empty transcripts after cleaning', () async {
      final finals = <String>[];
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];
      manager.finalTranscriptStream.listen(finals.add);

      await manager.startConversation();
      stt.emitFinal('um uh like');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(finals, isEmpty);
    });

    test('supports custom filler words', () async {
      manager.dispose();
      manager = VoiceConversationManager(
        sttProvider: stt,
        ttsProvider: tts,
        streamAdapter: adapter,
        fillerWords: ['hmm', 'well'],
      );

      final finals = <String>[];
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];
      manager.finalTranscriptStream.listen(finals.add);

      await manager.startConversation();
      stt.emitFinal('hmm well I think so');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(finals.first, 'I think so');
    });
  });

  group('backend streaming', () {
    test('stops STT before sending to backend', () async {
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      final stopBefore = stt.stopCount;
      stt.emitFinal('schedule a job');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(stt.stopCount, greaterThan(stopBefore));
    });

    test('transitions to processing then idle', () async {
      final states = <VoiceConversationState>[];
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      manager.stateStream.listen(states.add);

      stt.emitFinal('hello');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states, contains(VoiceConversationState.processing));
      expect(states.last, VoiceConversationState.idle);
    });

    test('sends cleaned message to adapter', () async {
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('um schedule a job');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(adapter.lastMessage, 'schedule a job');
    });
  });

  group('sentence buffering', () {
    test('sends complete sentences to TTS', () async {
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'Hello there.'),
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('hi');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(tts.spokenSentences, contains('Hello there.'));
    });

    test('buffers partial text until sentence boundary', () async {
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'Hello '),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'there. '),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'How are'),
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('hi');
      await Future.delayed(const Duration(milliseconds: 50));

      // "Hello there." sent on period, "How are" sent on narrativeEnd
      expect(tts.spokenSentences, hasLength(2));
      expect(tts.spokenSentences[0], 'Hello there.');
      expect(tts.spokenSentences[1], 'How are');
    });

    test('flushes long text without punctuation', () async {
      final longText = 'a' * 110; // exceeds 100-char default threshold
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart),
        VoiceStreamChunk(type: VoiceStreamChunkType.narrative, text: longText),
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('hi');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(tts.spokenSentences, contains(longText));
    });

    test('respects custom sentence length threshold', () async {
      manager.dispose();
      manager = VoiceConversationManager(
        sttProvider: stt,
        ttsProvider: tts,
        streamAdapter: adapter,
        sentenceLengthThreshold: 20,
      );

      final text25 = 'a' * 25; // exceeds custom 20-char threshold
      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart),
        VoiceStreamChunk(type: VoiceStreamChunkType.narrative, text: text25),
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('hi');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(tts.spokenSentences.first, text25);
    });
  });

  group('narrative stream', () {
    test('accumulates and emits full narrative for UI', () async {
      final narratives = <String>[];
      manager.narrativeStream.listen(narratives.add);

      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'Hello '),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'world.'),
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('hi');
      await Future.delayed(const Duration(milliseconds: 50));

      // Each narrative chunk emits the accumulated text
      expect(narratives, contains('Hello '));
      expect(narratives, contains('Hello world.'));
    });
  });

  group('tool announcements', () {
    test('announces matching tool calls', () async {
      manager.dispose();
      manager = VoiceConversationManager(
        sttProvider: stt,
        ttsProvider: tts,
        streamAdapter: adapter,
        toolAnnouncements: {
          'search_database': ['Searching for that...'],
          'default': ['Working on it...'],
        },
      );

      adapter.chunks = [
        const VoiceStreamChunk(
          type: VoiceStreamChunkType.progress,
          message: 'Running search database query',
        ),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('find jobs');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(tts.spokenSentences, contains('Searching for that...'));
    });

    test('falls back to default announcement for unknown tools', () async {
      adapter.chunks = [
        const VoiceStreamChunk(
          type: VoiceStreamChunkType.progress,
          message: 'Running some_unknown_tool',
        ),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      await manager.startConversation();
      stt.emitFinal('do something');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(tts.spokenSentences, contains('Let me check on that...'));
    });
  });

  group('error handling', () {
    test('emits backend errors and speaks them', () async {
      final errors = <String>[];
      manager.errorStream.listen(errors.add);

      adapter.chunks = [
        const VoiceStreamChunk(
          type: VoiceStreamChunkType.error,
          message: 'Server unavailable',
        ),
      ];

      await manager.startConversation();
      stt.emitFinal('hello');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(errors, contains('Server unavailable'));
      expect(tts.spokenSentences.any((s) => s.contains('Server unavailable')),
          isTrue);
    });

    test('forwards STT errors to error stream', () async {
      final errors = <String>[];
      manager.errorStream.listen(errors.add);

      await manager.startConversation();
      stt.emitError('Microphone disconnected');
      await Future.delayed(Duration.zero);

      expect(errors, contains('Microphone disconnected'));
    });
  });

  group('TTS state integration', () {
    test('transitions to speaking when TTS starts', () async {
      await manager.startConversation();

      adapter.chunks = [
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart),
        const VoiceStreamChunk(
            type: VoiceStreamChunkType.narrative, text: 'Hi.'),
        const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd),
        const VoiceStreamChunk(type: VoiceStreamChunkType.done),
      ];

      stt.emitFinal('hello');
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate TTS starting playback
      tts.simulateSpeaking();
      await Future.delayed(Duration.zero);
      expect(manager.currentState, VoiceConversationState.speaking);

      // Simulate TTS finishing
      tts.simulateDoneSpeaking();
      await Future.delayed(Duration.zero);
      expect(manager.currentState, VoiceConversationState.idle);
    });
  });

  group('interruptSpeaking', () {
    test('stops TTS and transitions to listening', () async {
      await manager.startConversation();

      // Force into speaking state
      tts.simulateSpeaking();
      await Future.delayed(Duration.zero);
      expect(manager.currentState, VoiceConversationState.speaking);

      await manager.interruptSpeaking();

      expect(tts.stopCount, greaterThanOrEqualTo(1));
      expect(manager.currentState, VoiceConversationState.listening);
    });

    test('does nothing if not speaking', () async {
      await manager.startConversation();
      final stopBefore = tts.stopCount;

      await manager.interruptSpeaking();

      expect(tts.stopCount, stopBefore);
    });
  });
}
