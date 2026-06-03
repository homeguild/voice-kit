/// Abstract interface for text-to-speech providers.
///
/// Implement this to integrate any TTS service (OpenAI, Google, ElevenLabs, etc.)
/// with [VoiceConversationManager].
abstract class TTSProvider {
  /// Stream of speaking state changes.
  Stream<bool> get isSpeakingStream;

  /// Whether the TTS queue has sentences waiting to be spoken.
  bool get hasPendingSentences;

  /// Queue a sentence for sequential playback.
  ///
  /// Sentences are played in order. If nothing is currently playing,
  /// playback starts immediately. Otherwise the sentence is queued.
  Future<void> speakStreamingSentence(String sentence);

  /// Stop all current and queued speech immediately.
  Future<void> stopAndClear();

  /// Release all resources held by this provider.
  void dispose();
}
