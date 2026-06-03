/// Voice conversation orchestration for Flutter.
///
/// Provides a complete state machine for voice conversations with pluggable
/// STT and TTS providers, sentence buffering, and ready-made widgets.
///
/// Built by [HomeGuild Labs](https://labs.homeguild.ai).
library homeguild_voice_kit;

// Core interfaces
export 'src/stt_provider.dart';
export 'src/tts_provider.dart';
export 'src/voice_stream_adapter.dart';

// Models
export 'src/models/stt_result.dart';
export 'src/models/voice_stream_chunk.dart';
export 'src/models/voice_conversation_state.dart';

// Orchestration
export 'src/voice_conversation_manager.dart';

// Widgets
export 'widgets/voice_input_button.dart';
export 'widgets/voice_status_indicator.dart';
export 'widgets/voice_transcript_display.dart';
