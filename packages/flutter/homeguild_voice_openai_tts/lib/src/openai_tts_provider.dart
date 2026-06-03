import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// OpenAI TTS provider for natural-sounding speech.
///
/// Uses OpenAI's `/v1/audio/speech` API with sentence queuing for
/// streaming playback.
///
/// ```dart
/// final tts = OpenAITTSProvider(apiKey: 'YOUR_OPENAI_KEY');
/// await tts.speakStreamingSentence('Hello, how can I help?');
/// ```
class OpenAITTSProvider implements TTSProvider {
  static final Logger _logger = Logger('OpenAITTSProvider');

  final String _apiKey;
  final String _voice;
  final String _model;
  double _speed;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _speechQueue = [];

  bool _isSpeaking = false;
  bool _shouldStopQueue = false;

  final StreamController<bool> _isSpeakingController =
      StreamController<bool>.broadcast();

  /// Optional callback invoked after each sentence is spoken,
  /// with the estimated duration in seconds. Useful for usage metering.
  final void Function(double durationSeconds)? onUsageTracked;

  /// Optional text sanitizer applied before sending to the API.
  /// Useful for stripping markdown or other formatting.
  final String Function(String)? textSanitizer;

  /// Create an OpenAI TTS provider.
  ///
  /// [apiKey] is your OpenAI API key.
  /// [voice] one of: alloy, echo, fable, onyx, nova, shimmer.
  /// [speed] playback speed (0.25–4.0).
  /// [model] TTS model (`tts-1` or `tts-1-hd`).
  OpenAITTSProvider({
    required String apiKey,
    String voice = 'alloy',
    double speed = 1.0,
    String model = 'tts-1',
    this.onUsageTracked,
    this.textSanitizer,
  })  : _apiKey = apiKey,
        _voice = voice,
        _speed = speed,
        _model = model {
    _setupPlayerHandlers();
  }

  @override
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;

  @override
  bool get hasPendingSentences => _speechQueue.isNotEmpty;

  /// Whether currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// Update playback speed for subsequent sentences.
  set speed(double value) => _speed = value;

  @override
  Future<void> speakStreamingSentence(String sentence) async {
    if (sentence.trim().isEmpty) return;

    final cleanText = textSanitizer?.call(sentence) ?? sentence;
    if (cleanText.trim().isEmpty) return;

    _logger.info('Queueing sentence for TTS '
        '(${cleanText.length} chars)');

    if (!_isSpeaking) {
      await _speak(cleanText);
    } else {
      _speechQueue.add(cleanText);
    }
  }

  @override
  Future<void> stopAndClear() async {
    _logger.info(
        'Stopping TTS and clearing queue (${_speechQueue.length} sentences)');
    _shouldStopQueue = true;
    _speechQueue.clear();
    await _audioPlayer.stop();
    _isSpeaking = false;
    _isSpeakingController.add(false);
    _shouldStopQueue = false;
  }

  @override
  void dispose() {
    _logger.info('Disposing OpenAITTSProvider');
    stopAndClear();
    _audioPlayer.dispose();
    _isSpeakingController.close();
  }

  // ── Private ─────────────────────────────────────────────────────────

  void _setupPlayerHandlers() {
    _audioPlayer.onPlayerComplete.listen((_) {
      if (_speechQueue.isNotEmpty && !_shouldStopQueue) {
        final next = _speechQueue.removeAt(0);
        _speak(next);
      } else {
        _isSpeaking = false;
        _isSpeakingController.add(false);
      }
    });
  }

  Future<void> _speak(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.openai.com/v1/audio/speech'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'input': text,
              'voice': _voice,
              'speed': _speed,
              'response_format': 'mp3',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;

        // Estimate duration from MP3 bytes (tts-1 uses ~64kbps)
        final durationSeconds = audioBytes.length / 8000.0;
        onUsageTracked?.call(durationSeconds);

        await _audioPlayer.play(BytesSource(audioBytes));
        _isSpeaking = true;
        _isSpeakingController.add(true);
      } else {
        _logger.severe('OpenAI TTS API error: ${response.statusCode}');
        _isSpeaking = false;
        _isSpeakingController.add(false);
      }
    } catch (e, stackTrace) {
      _logger.severe('TTS error: $e', e, stackTrace);
      _isSpeaking = false;
      _isSpeakingController.add(false);
    }
  }
}
