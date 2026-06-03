import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// Deepgram speech-to-text provider.
///
/// Streams microphone audio to Deepgram via WebSocket and emits
/// [STTResult]s (both interim and final).
///
/// ```dart
/// final stt = DeepgramSTTProvider(apiKey: 'YOUR_DEEPGRAM_KEY');
/// stt.transcriptStream.listen((result) => print(result));
/// await stt.startListening();
/// ```
class DeepgramSTTProvider implements STTProvider {
  static final Logger _logger = Logger('DeepgramSTTProvider');

  final String _apiKey;
  final String _model;
  final String _language;
  final String _encoding;
  final int _sampleRate;

  /// Optional callback invoked when a listening session ends,
  /// with the duration in seconds. Useful for usage metering.
  final void Function(double durationSeconds)? onUsageTracked;

  // WebSocket
  WebSocketChannel? _channel;

  // Audio recording
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordingSubscription;

  // State
  bool _isListening = false;
  bool _isConnected = false;

  // Streams
  final StreamController<STTResult> _transcriptController =
      StreamController<STTResult>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Keep-alive
  Timer? _keepAliveTimer;

  // Usage tracking
  DateTime? _recordingStartTime;

  /// Create a Deepgram STT provider.
  ///
  /// [apiKey] is your Deepgram API key.
  /// [model] defaults to `nova-2` (Deepgram's latest model).
  /// [language] defaults to `multi` for auto-detection.
  /// [encoding] audio encoding sent to Deepgram.
  /// [sampleRate] in Hz — must match the recording config.
  DeepgramSTTProvider({
    required String apiKey,
    String model = 'nova-2',
    String language = 'multi',
    String encoding = 'linear16',
    int sampleRate = 16000,
    this.onUsageTracked,
  })  : _apiKey = apiKey,
        _model = model,
        _language = language,
        _encoding = encoding,
        _sampleRate = sampleRate;

  @override
  Stream<STTResult> get transcriptStream => _transcriptController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  bool get isListening => _isListening;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _isConnected;

  @override
  Future<void> startListening() async {
    if (_isListening) {
      _logger.warning('Already listening, ignoring startListening call');
      return;
    }

    if (_apiKey.isEmpty) {
      const error = 'Deepgram API key not configured';
      _logger.severe(error);
      _errorController.add(error);
      return;
    }

    try {
      _logger.info('Starting Deepgram STT session...');
      await _connectWebSocket();
      await _startRecording();
      _isListening = true;
      _recordingStartTime = DateTime.now();
      _logger.info('Deepgram STT session started successfully');
    } catch (e, stackTrace) {
      _logger.severe('Failed to start listening: $e', e, stackTrace);
      _errorController.add('Failed to start listening: $e');
      await stopListening();
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;

    _logger.info('Stopping Deepgram STT session...');

    // Track usage
    if (_recordingStartTime != null) {
      final duration = DateTime.now().difference(_recordingStartTime!);
      final durationSeconds = duration.inSeconds.toDouble();
      _logger.info('Deepgram session duration: ${durationSeconds}s');
      onUsageTracked?.call(durationSeconds);
      _recordingStartTime = null;
    }

    await _stopRecording();

    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    await _disconnectWebSocket();
    _isListening = false;
    _logger.info('Deepgram STT session stopped');
  }

  @override
  void dispose() {
    _logger.info('Disposing DeepgramSTTProvider');
    stopListening();
    _transcriptController.close();
    _errorController.close();
    _recorder.dispose();
  }

  // ── WebSocket ───────────────────────────────────────────────────────

  Future<void> _connectWebSocket() async {
    final uri = Uri.parse(
      'wss://api.deepgram.com/v1/listen'
      '?encoding=$_encoding'
      '&sample_rate=$_sampleRate'
      '&channels=1'
      '&language=$_language'
      '&model=$_model'
      '&punctuate=true'
      '&interim_results=true'
      '&vad_events=true'
      '&smart_format=true',
    );

    _logger.fine('Connecting to Deepgram WebSocket');

    _channel = WebSocketChannel.connect(
      uri,
      protocols: ['token', _apiKey],
    );

    _channel!.stream.listen(
      _handleWebSocketMessage,
      onError: _handleWebSocketError,
      onDone: _handleWebSocketClosed,
      cancelOnError: false,
    );

    _isConnected = true;
    _logger.info('Connected to Deepgram WebSocket');
    _startKeepAlive();
  }

  Future<void> _disconnectWebSocket() async {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'CloseStream'}));
        await _channel!.sink.close();
      } catch (e) {
        _logger.warning('Error closing WebSocket: $e');
      }
      _channel = null;
    }
    _isConnected = false;
  }

  void _startKeepAlive() {
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'KeepAlive'}));
        } catch (e) {
          _logger.warning('Failed to send KeepAlive: $e');
        }
      }
    });
  }

  // ── Recording ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    );

    final stream = await _recorder.startStream(config);

    _recordingSubscription = stream.listen(
      (audioBytes) {
        if (_isConnected && _channel != null) {
          try {
            _channel!.sink.add(audioBytes);
          } catch (e) {
            _logger.warning('Failed to send audio to Deepgram: $e');
          }
        }
      },
      onError: (error) {
        _logger.severe('Recording stream error: $error');
        _errorController.add('Recording error: $error');
      },
      cancelOnError: false,
    );

    _logger.info(
        'Started audio recording (${_sampleRate}Hz, PCM16, mono)');
  }

  Future<void> _stopRecording() async {
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    try {
      await _recorder.stop();
    } catch (e) {
      _logger.warning('Error stopping recorder: $e');
    }
  }

  // ── Message handling ────────────────────────────────────────────────

  void _handleWebSocketMessage(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'Results') {
        _handleTranscriptResult(json);
      } else if (type == 'SpeechStarted') {
        _logger.fine('VAD: Speech started');
      } else if (type == 'UtteranceEnd') {
        _logger.fine('VAD: Utterance ended');
        _transcriptController.add(const STTResult(
          text: '',
          isFinal: false,
          confidence: 0,
          isSpeechFinal: true,
        ));
      } else {
        _logger.fine('Received WebSocket message type: $type');
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to parse WebSocket message: $e', e, stackTrace);
    }
  }

  void _handleTranscriptResult(Map<String, dynamic> json) {
    try {
      final channel = json['channel'] as Map<String, dynamic>?;
      if (channel == null) return;

      final alternatives = channel['alternatives'] as List<dynamic>?;
      if (alternatives == null || alternatives.isEmpty) return;

      final alt = alternatives[0] as Map<String, dynamic>;
      final transcript = alt['transcript'] as String? ?? '';
      final confidence = (alt['confidence'] as num?)?.toDouble() ?? 0.0;
      final isFinal = json['is_final'] as bool? ?? false;
      final detectedLanguage = alt['languages']?[0] as String?;

      if (transcript.isNotEmpty) {
        _transcriptController.add(STTResult(
          text: transcript,
          isFinal: isFinal,
          confidence: confidence,
          detectedLanguage: detectedLanguage,
        ));
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to parse transcript result: $e', e, stackTrace);
    }
  }

  void _handleWebSocketError(error) {
    _logger.severe('WebSocket error: $error');
    _errorController.add('Connection error: $error');
    _isConnected = false;
  }

  void _handleWebSocketClosed() {
    _logger.info('WebSocket connection closed');
    _isConnected = false;
    if (_isListening) {
      _logger.warning('WebSocket closed unexpectedly while listening');
      _errorController.add('Connection lost');
    }
  }
}
