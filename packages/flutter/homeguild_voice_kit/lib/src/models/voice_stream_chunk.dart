/// Types of chunks that can arrive from a backend stream.
enum VoiceStreamChunkType {
  /// A progress/status update (e.g. "Searching database...").
  progress,

  /// The start of LLM narrative output.
  narrativeStart,

  /// A fragment of LLM narrative text (streamed token-by-token).
  narrative,

  /// The end of LLM narrative output.
  narrativeEnd,

  /// A tool/function call event (for announcing tool execution).
  toolCall,

  /// The stream completed successfully.
  done,

  /// An error occurred.
  error,
}

/// A single chunk from a backend response stream.
class VoiceStreamChunk {
  /// The type of this chunk.
  final VoiceStreamChunkType type;

  /// Human-readable message (for progress/error types).
  final String? message;

  /// Narrative text fragment (for narrative type).
  final String? text;

  /// Arbitrary data payload (for tool calls, results, etc.).
  final Map<String, dynamic>? data;

  const VoiceStreamChunk({
    required this.type,
    this.message,
    this.text,
    this.data,
  });

  @override
  String toString() {
    return 'VoiceStreamChunk(type: $type, message: $message, '
        'text: $text, hasData: ${data != null})';
  }
}
