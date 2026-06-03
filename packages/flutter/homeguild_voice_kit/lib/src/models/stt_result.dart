/// Result from a speech-to-text provider.
class STTResult {
  /// The transcribed text.
  final String text;

  /// Whether this is a final (confirmed) result or an interim (partial) one.
  final bool isFinal;

  /// Confidence score from the provider (0.0 – 1.0).
  final double confidence;

  /// Detected language code, if the provider supports language detection.
  final String? detectedLanguage;

  /// Whether the provider's VAD detected end-of-speech.
  final bool isSpeechFinal;

  const STTResult({
    required this.text,
    required this.isFinal,
    required this.confidence,
    this.detectedLanguage,
    this.isSpeechFinal = false,
  });

  @override
  String toString() {
    return 'STTResult(text: "$text", isFinal: $isFinal, '
        'confidence: $confidence, language: $detectedLanguage, '
        'speechFinal: $isSpeechFinal)';
  }
}
