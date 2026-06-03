import 'models/voice_stream_chunk.dart';

/// Abstract interface for streaming responses from a backend.
///
/// Implement this to connect [VoiceConversationManager] to your backend.
/// The adapter receives transcribed user messages and returns a stream
/// of response chunks (narrative text, tool calls, progress updates, etc.).
abstract class VoiceStreamAdapter {
  /// Stream a user message to the backend and yield response chunks.
  ///
  /// [message] is the cleaned transcript text from STT.
  /// [context] carries session-specific data (agent type, auth tokens, etc.).
  Stream<VoiceStreamChunk> streamResponse({
    required String message,
    required Map<String, dynamic> context,
  });
}
