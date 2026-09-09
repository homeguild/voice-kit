/// The agent SSE envelope — the frame contract every agent turn streams, and the
/// shared spine of journey testing (docs/journey-testing.md, axis 3). The 1:1
/// Dart mirror of the TS `agent-frames.ts`. Sophia emits these frames
/// (services/sophia/sophia/streaming.py); the client folds them into shell state.
/// Both ports speak this EXACT envelope, so one recorded cassette
/// (voice-kit/fixtures/agent-cassettes.json) drives both — a mock replay and the
/// real transport are indistinguishable at this boundary.

/// The frame `type` set. A frame outside this set fails the envelope contract.
const List<String> kAgentFrameTypes = [
  'progress',
  'narrative_start',
  'narrative',
  'narrative_end',
  'directive',
  'done',
  'error',
];

/// One frame of Sophia's SSE stream — a thin typed view over the raw JSON map,
/// discriminated by [type] (and, for directives, [directive]). Kept map-backed
/// (not a sealed hierarchy) so a recorded cassette round-trips byte-for-byte.
class AgentFrame {
  const AgentFrame(this.raw);

  final Map<String, dynamic> raw;

  String get type => raw['type'] as String;
  String? get directive => raw['directive'] as String?;
  String? get viewId => raw['view_id'] as String?;
  String? get windowId => raw['window_id'] as String?;
  String? get target => raw['target'] as String?;
  String? get text => raw['text'] as String?;
  String? get message => raw['message'] as String?;
  Map<String, dynamic>? get data => raw['data'] as Map<String, dynamic>?;

  /// Validate this frame against the envelope contract — the same shape check the
  /// contract test runs (shapes, not content), so the harness can't drift from the
  /// live agent. Returns an error string, or null when the shape is valid.
  String? validate() {
    if (!kAgentFrameTypes.contains(type)) return 'unknown frame type: $type';
    if (type == 'narrative' && text is! String) return 'narrative frame missing text';
    if (type == 'directive') {
      if (directive == 'show_view') {
        if (viewId is! String) return 'show_view directive missing view_id';
        if (target != null && target != 'inline' && target != 'panel') {
          return 'show_view directive has invalid target: $target';
        }
      } else if (directive == 'notify') {
        if (message is! String) return 'notify directive missing message';
      } else {
        return 'unknown directive: $directive';
      }
    }
    return null;
  }
}

/// A recorded, frozen agent turn — one canonical example per RETURN STATE.
/// [branches] maps a view_event's event_type to the id of the cassette that
/// resumes the conversation, keeping a scripted flow deterministic.
class AgentCassette {
  const AgentCassette({
    required this.id,
    required this.title,
    required this.returnState,
    required this.userMessage,
    required this.frames,
    this.opening,
    this.branches = const {},
  });

  final String id;
  final String title;
  final String returnState;
  final String userMessage;
  final String? opening;
  final List<AgentFrame> frames;
  final Map<String, String> branches;
}
