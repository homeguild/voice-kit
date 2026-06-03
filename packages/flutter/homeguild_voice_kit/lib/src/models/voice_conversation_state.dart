/// States of a voice conversation.
enum VoiceConversationState {
  /// Ready to listen — no active session.
  idle,

  /// Recording user speech via STT.
  listening,

  /// Waiting for or receiving a backend response.
  processing,

  /// Playing TTS audio.
  speaking,
}
