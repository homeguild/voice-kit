import 'dart:async';
import 'package:logging/logging.dart';

import 'stt_provider.dart';
import 'tts_provider.dart';
import 'voice_stream_adapter.dart';
import 'models/stt_result.dart';
import 'models/voice_stream_chunk.dart';
import 'models/voice_conversation_state.dart';

/// Default filler words removed from transcripts before sending to backend.
const List<String> kDefaultFillerWords = ['um', 'uh', 'like', 'you know'];

/// Default tool-call announcements spoken via TTS while waiting for results.
const Map<String, List<String>> kDefaultToolAnnouncements = {
  'default': ['Let me check on that...', 'One moment...'],
};

/// Orchestrates a complete voice conversation flow:
/// STT → Backend streaming → TTS.
///
/// Manages state transitions, transcript cleaning, sentence buffering for TTS,
/// tool-call announcements, and interruption handling.
///
/// ```dart
/// final manager = VoiceConversationManager(
///   sttProvider: mySTT,
///   ttsProvider: myTTS,
///   streamAdapter: myBackend,
/// );
///
/// await manager.startConversation(context: {'agent': 'support'});
/// ```
class VoiceConversationManager {
  static final Logger _logger = Logger('VoiceConversationManager');

  // Providers
  final STTProvider _sttProvider;
  final TTSProvider _ttsProvider;
  final VoiceStreamAdapter _streamAdapter;

  // Configuration
  final Map<String, List<String>> _toolAnnouncements;
  final int _sentenceLengthThreshold;
  final RegExp _fillerRegex;

  // State
  VoiceConversationState _currentState = VoiceConversationState.idle;

  // Streams
  final StreamController<VoiceConversationState> _stateController =
      StreamController<VoiceConversationState>.broadcast();
  final StreamController<String> _interimTranscriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _finalTranscriptController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<String> _narrativeController =
      StreamController<String>.broadcast();

  // Accumulates full response text for UI display
  final StringBuffer _fullNarrativeBuffer = StringBuffer();

  // Subscriptions
  StreamSubscription<STTResult>? _sttSubscription;
  StreamSubscription<String>? _sttErrorSubscription;
  StreamSubscription<bool>? _ttsStateSubscription;

  // Current conversation context
  Map<String, dynamic>? _context;

  // Sentence buffering
  final StringBuffer _narrativeBuffer = StringBuffer();

  /// Create a new voice conversation manager.
  ///
  /// [sttProvider] handles speech-to-text.
  /// [ttsProvider] handles text-to-speech.
  /// [streamAdapter] connects to the backend.
  /// [fillerWords] are stripped from transcripts before sending to backend.
  /// [toolAnnouncements] map tool names to spoken announcements.
  /// [sentenceLengthThreshold] triggers TTS when a buffer exceeds this length
  ///   without sentence-ending punctuation.
  VoiceConversationManager({
    required STTProvider sttProvider,
    required TTSProvider ttsProvider,
    required VoiceStreamAdapter streamAdapter,
    List<String>? fillerWords,
    Map<String, List<String>>? toolAnnouncements,
    int sentenceLengthThreshold = 100,
  })  : _sttProvider = sttProvider,
        _ttsProvider = ttsProvider,
        _streamAdapter = streamAdapter,
        _toolAnnouncements = toolAnnouncements ?? kDefaultToolAnnouncements,
        _sentenceLengthThreshold = sentenceLengthThreshold,
        _fillerRegex = RegExp(
          '\\b(${(fillerWords ?? kDefaultFillerWords).join('|')})\\b',
          caseSensitive: false,
        );

  // ── Public API ──────────────────────────────────────────────────────

  /// Stream of conversation state transitions.
  Stream<VoiceConversationState> get stateStream => _stateController.stream;

  /// Stream of interim (partial) transcripts for real-time UI feedback.
  Stream<String> get interimTranscriptStream =>
      _interimTranscriptController.stream;

  /// Stream of final (confirmed) transcripts.
  Stream<String> get finalTranscriptStream =>
      _finalTranscriptController.stream;

  /// Stream of error messages.
  Stream<String> get errorStream => _errorController.stream;

  /// Stream of accumulated narrative text (for UI display).
  Stream<String> get narrativeStream => _narrativeController.stream;

  /// The current conversation state.
  VoiceConversationState get currentState => _currentState;

  /// Whether a conversation is currently active.
  bool get isActive => _currentState != VoiceConversationState.idle;

  /// Start a voice conversation.
  ///
  /// [context] is forwarded to [VoiceStreamAdapter.streamResponse] and can
  /// carry session tokens, agent types, or any backend-specific data.
  Future<void> startConversation({
    Map<String, dynamic>? context,
  }) async {
    if (isActive) {
      _logger.warning('Conversation already active, stopping previous first');
      await stopConversation();
    }

    _logger.info('Starting voice conversation');
    _context = context;

    try {
      // Subscribe to STT events
      _sttSubscription = _sttProvider.transcriptStream.listen(
        _handleSttResult,
        onError: (error) {
          _logger.severe('STT stream error: $error');
          _errorController.add('Speech recognition error: $error');
        },
      );

      _sttErrorSubscription = _sttProvider.errorStream.listen((error) {
        _logger.warning('STT error: $error');
        _errorController.add(error);
      });

      // Subscribe to TTS state changes
      _ttsStateSubscription =
          _ttsProvider.isSpeakingStream.listen((isSpeaking) {
        if (isSpeaking &&
            _currentState != VoiceConversationState.speaking) {
          _setState(VoiceConversationState.speaking);
        } else if (!isSpeaking &&
            _currentState == VoiceConversationState.speaking) {
          _setState(VoiceConversationState.idle);
        }
      });

      // Start listening
      await _sttProvider.startListening();
      _setState(VoiceConversationState.listening);
    } catch (e, stackTrace) {
      _logger.severe('Failed to start conversation: $e', e, stackTrace);
      _errorController.add('Failed to start voice conversation: $e');
      await stopConversation();
    }
  }

  /// Stop the current conversation and release resources.
  Future<void> stopConversation() async {
    _logger.info('Stopping voice conversation');

    await _sttProvider.stopListening();
    await _ttsProvider.stopAndClear();

    await _sttSubscription?.cancel();
    await _sttErrorSubscription?.cancel();
    await _ttsStateSubscription?.cancel();

    _sttSubscription = null;
    _sttErrorSubscription = null;
    _ttsStateSubscription = null;

    _setState(VoiceConversationState.idle);
    _context = null;
    _narrativeBuffer.clear();
  }

  /// Interrupt TTS playback (e.g. when the user speaks while the agent talks).
  Future<void> interruptSpeaking() async {
    if (_currentState == VoiceConversationState.speaking) {
      _logger.info('Interrupting TTS playback');
      await _ttsProvider.stopAndClear();
      _setState(VoiceConversationState.listening);
    }
  }

  /// Release all resources. Call this when the manager is no longer needed.
  Future<void> dispose() async {
    _logger.info('Disposing VoiceConversationManager');
    await stopConversation();
    _stateController.close();
    _interimTranscriptController.close();
    _finalTranscriptController.close();
    _errorController.close();
    _narrativeController.close();
  }

  // ── Private ─────────────────────────────────────────────────────────

  void _handleSttResult(STTResult result) {
    if (result.isSpeechFinal) {
      _logger.fine('VAD: Speech ended');
      return;
    }

    if (result.isFinal) {
      final cleanedText = _cleanTranscript(result.text);
      if (cleanedText.isNotEmpty) {
        _logger.info('Final transcript: "$cleanedText"');
        _finalTranscriptController.add(cleanedText);
        _sendToBackend(cleanedText);
      }
    } else {
      _interimTranscriptController.add(result.text);
    }
  }

  String _cleanTranscript(String raw) {
    return raw
        .replaceAll(_fillerRegex, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _sendToBackend(String message) async {
    // Stop STT to prevent feedback loop during TTS playback
    _logger.fine('Stopping STT to prevent feedback loop during response');
    await _sttProvider.stopListening();

    _setState(VoiceConversationState.processing);
    _narrativeBuffer.clear();
    _fullNarrativeBuffer.clear();

    try {
      _logger.info('Sending to backend: "$message"');

      final stream = _streamAdapter.streamResponse(
        message: message,
        context: _context ?? {},
      );

      await for (final chunk in stream) {
        _handleBackendChunk(chunk);
      }

      if (!_ttsProvider.hasPendingSentences) {
        _setState(VoiceConversationState.idle);
      }
    } catch (e, stackTrace) {
      _logger.severe('Backend streaming error: $e', e, stackTrace);
      _errorController.add('Failed to get response: $e');
      _setState(VoiceConversationState.idle);
    }
  }

  void _handleBackendChunk(VoiceStreamChunk chunk) {
    switch (chunk.type) {
      case VoiceStreamChunkType.progress:
        if (chunk.message != null) {
          _logger.fine('Progress: ${chunk.message}');
          _maybeAnnounceToolCall(chunk.message!);
        }

      case VoiceStreamChunkType.toolCall:
        if (chunk.message != null) {
          _logger.fine('Tool call: ${chunk.message}');
          _maybeAnnounceToolCall(chunk.message!);
        }

      case VoiceStreamChunkType.narrativeStart:
        _logger.fine('Narrative started');
        _narrativeBuffer.clear();
        _fullNarrativeBuffer.clear();

      case VoiceStreamChunkType.narrative:
        if (chunk.text != null) {
          _narrativeBuffer.write(chunk.text);
          _fullNarrativeBuffer.write(chunk.text);
          _narrativeController.add(_fullNarrativeBuffer.toString());

          final currentText = _narrativeBuffer.toString();
          if (_isCompleteSentence(currentText)) {
            final sentence = currentText.trim();
            _logger.fine('Complete sentence buffered: "$sentence"');
            _ttsProvider.speakStreamingSentence(sentence);
            _narrativeBuffer.clear();
          }
        }

      case VoiceStreamChunkType.narrativeEnd:
        _logger.fine('Narrative ended');
        if (_narrativeBuffer.isNotEmpty) {
          final remaining = _narrativeBuffer.toString().trim();
          if (remaining.isNotEmpty) {
            _logger.fine('Speaking remaining text: "$remaining"');
            _ttsProvider.speakStreamingSentence(remaining);
          }
          _narrativeBuffer.clear();
        }
        if (_fullNarrativeBuffer.isNotEmpty) {
          _narrativeController.add(_fullNarrativeBuffer.toString());
        }

      case VoiceStreamChunkType.done:
        _logger.info('Backend stream completed');

      case VoiceStreamChunkType.error:
        _logger.warning('Backend error: ${chunk.message}');
        if (chunk.message != null) {
          _errorController.add(chunk.message!);
          _ttsProvider.speakStreamingSentence(
            'Sorry, I encountered an error: ${chunk.message}',
          );
        }
    }
  }

  void _maybeAnnounceToolCall(String message) {
    final lower = message.toLowerCase();
    for (final entry in _toolAnnouncements.entries) {
      final toolKey = entry.key.replaceAll('_', ' ');
      if (lower.contains(toolKey)) {
        final announcements = entry.value;
        if (announcements.isNotEmpty) {
          _ttsProvider.speakStreamingSentence(announcements.first);
        }
        return;
      }
    }
    // Fallback to default announcements
    final defaults = _toolAnnouncements['default'];
    if (defaults != null && defaults.isNotEmpty) {
      _ttsProvider.speakStreamingSentence(defaults.first);
    }
  }

  bool _isCompleteSentence(String text) {
    final trimmed = text.trim();
    return trimmed.endsWith('.') ||
        trimmed.endsWith('?') ||
        trimmed.endsWith('!') ||
        trimmed.length > _sentenceLengthThreshold;
  }

  void _setState(VoiceConversationState newState) {
    if (_currentState != newState) {
      _logger.fine('State transition: $_currentState → $newState');
      _currentState = newState;
      _stateController.add(newState);
    }
  }
}
