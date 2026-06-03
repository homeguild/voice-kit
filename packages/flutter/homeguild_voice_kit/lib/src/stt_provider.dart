import 'models/stt_result.dart';

/// Abstract interface for speech-to-text providers.
///
/// Implement this to integrate any STT service (Deepgram, Google, Azure, etc.)
/// with [VoiceConversationManager].
abstract class STTProvider {
  /// Stream of transcript results (both interim and final).
  Stream<STTResult> get transcriptStream;

  /// Stream of error messages from the provider.
  Stream<String> get errorStream;

  /// Whether the provider is currently listening for speech.
  bool get isListening;

  /// Start listening for speech input.
  ///
  /// Opens the microphone and begins streaming audio to the STT service.
  Future<void> startListening();

  /// Stop listening for speech input.
  ///
  /// Closes the microphone and disconnects from the STT service.
  Future<void> stopListening();

  /// Release all resources held by this provider.
  void dispose();
}
