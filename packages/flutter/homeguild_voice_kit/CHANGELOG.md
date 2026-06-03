## 0.1.0

- Initial release
- `VoiceConversationManager` — full state machine with sentence buffering, filler word cleanup, and tool announcements
- `STTProvider` / `TTSProvider` / `VoiceStreamAdapter` — pluggable abstract interfaces
- `VoiceConversationState` enum — idle, listening, processing, speaking
- `VoiceStreamChunk` / `VoiceStreamChunkType` — typed backend response model
- `STTResult` — transcript result with confidence and language detection
- `VoiceInputButton`, `VoiceStatusIndicator`, `VoiceTranscriptDisplay` widgets
