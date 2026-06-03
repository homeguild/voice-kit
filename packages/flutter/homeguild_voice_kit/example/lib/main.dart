import 'dart:async';
import 'package:flutter/material.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

// ─── Example backend adapter ────────────────────────────────────────────
// Replace this with your own backend integration.

class EchoStreamAdapter implements VoiceStreamAdapter {
  @override
  Stream<VoiceStreamChunk> streamResponse({
    required String message,
    required Map<String, dynamic> context,
  }) async* {
    yield const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeStart);

    // Simulate a streaming response
    final words = 'You said: $message. That is very interesting!'.split(' ');
    for (final word in words) {
      await Future.delayed(const Duration(milliseconds: 80));
      yield VoiceStreamChunk(
        type: VoiceStreamChunkType.narrative,
        text: '$word ',
      );
    }

    yield const VoiceStreamChunk(type: VoiceStreamChunkType.narrativeEnd);
    yield const VoiceStreamChunk(type: VoiceStreamChunkType.done);
  }
}

// ─── App ─────────────────────────────────────────────────────────────────

void main() => runApp(const VoiceKitExampleApp());

class VoiceKitExampleApp extends StatelessWidget {
  const VoiceKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Kit Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const VoiceKitExamplePage(),
    );
  }
}

class VoiceKitExamplePage extends StatefulWidget {
  const VoiceKitExamplePage({super.key});

  @override
  State<VoiceKitExamplePage> createState() => _VoiceKitExamplePageState();
}

class _VoiceKitExamplePageState extends State<VoiceKitExamplePage> {
  // In a real app, inject actual STT/TTS providers here:
  //   sttProvider: DeepgramSTTProvider(apiKey: '...')
  //   ttsProvider: OpenAITTSProvider(apiKey: '...')
  //
  // This example uses the echo adapter which just mirrors your input.

  late final VoiceConversationManager _manager;
  VoiceConversationState _state = VoiceConversationState.idle;
  String _interimTranscript = '';
  String _finalTranscript = '';
  String _narrative = '';
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();

    // NOTE: Replace _DummySTT / _DummyTTS with real providers.
    _manager = VoiceConversationManager(
      sttProvider: _DummySTT(),
      ttsProvider: _DummyTTS(),
      streamAdapter: EchoStreamAdapter(),
    );

    _subs.add(_manager.stateStream.listen((s) {
      setState(() => _state = s);
    }));
    _subs.add(_manager.interimTranscriptStream.listen((t) {
      setState(() => _interimTranscript = t);
    }));
    _subs.add(_manager.finalTranscriptStream.listen((t) {
      setState(() => _finalTranscript = t);
    }));
    _subs.add(_manager.narrativeStream.listen((n) {
      setState(() => _narrative = n);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Kit Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            VoiceStatusIndicator(state: _state),
            const SizedBox(height: 16),
            VoiceTranscriptDisplay(
              interimTranscript:
                  _interimTranscript.isEmpty ? null : _interimTranscript,
              finalTranscript:
                  _finalTranscript.isEmpty ? null : _finalTranscript,
            ),
            const SizedBox(height: 16),
            if (_narrative.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_narrative),
              ),
            const Spacer(),
            VoiceInputButton(
              state: _state,
              onStart: () =>
                  _manager.startConversation(context: {'agent': 'demo'}),
              onStop: () => _manager.stopConversation(),
              onCancel: () => _manager.interruptSpeaking(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder providers (replace with real ones) ─────────────────────

class _DummySTT implements STTProvider {
  final StreamController<STTResult> _transcripts =
      StreamController<STTResult>.broadcast();
  final StreamController<String> _errors =
      StreamController<String>.broadcast();

  @override
  Stream<STTResult> get transcriptStream => _transcripts.stream;
  @override
  Stream<String> get errorStream => _errors.stream;
  @override
  bool get isListening => false;

  @override
  Future<void> startListening() async {
    // Simulate a final transcript after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _transcripts.add(const STTResult(
        text: 'Hello voice kit!',
        isFinal: true,
        confidence: 0.95,
      ));
    });
  }

  @override
  Future<void> stopListening() async {}
  @override
  void dispose() {
    _transcripts.close();
    _errors.close();
  }
}

class _DummyTTS implements TTSProvider {
  final StreamController<bool> _speaking =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get isSpeakingStream => _speaking.stream;
  @override
  bool get hasPendingSentences => false;

  @override
  Future<void> speakStreamingSentence(String sentence) async {
    _speaking.add(true);
    // Simulate speaking duration
    await Future.delayed(const Duration(seconds: 1));
    _speaking.add(false);
  }

  @override
  Future<void> stopAndClear() async {
    _speaking.add(false);
  }

  @override
  void dispose() {
    _speaking.close();
  }
}
