## 0.1.2

- `applyFrame` / `AgentTurn` — the shared SSE-stream → `ShellState` fold (mirror of the TS `agent-turn.ts`), so a cassette produces the same stream + panel on both ports.

## 0.1.1

- `dismiss_view` frame — retract a pinned panel view by windowId (folds to `dismissPanel`); contract parity with the TS kit.

## 0.1.0

- Initial release
- `VoiceConversationManager` — full state machine with sentence buffering, filler word cleanup, and tool announcements
- `STTProvider` / `TTSProvider` / `VoiceStreamAdapter` — pluggable abstract interfaces
- `VoiceConversationState` enum — idle, listening, processing, speaking
- `VoiceStreamChunk` / `VoiceStreamChunkType` — typed backend response model
- `STTResult` — transcript result with confidence and language detection
- `VoiceInputButton`, `VoiceStatusIndicator`, `VoiceTranscriptDisplay` widgets
