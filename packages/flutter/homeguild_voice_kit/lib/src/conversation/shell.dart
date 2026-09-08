import 'directive.dart';
import 'message.dart';

/// The conversation shell — the stream + the panel — as one piece of state, and
/// the pure routing that applies agent directives (docs/agent-shell.md).
/// Host-agnostic and pure, so the two ports route identically (proven by the
/// shared fixtures). The host owns transport (SSE) and rendering (ConversationStream
/// + PanelSurface); this owns "which surface does a directive land on."

/// One thing pinned to the panel, keyed by its directive's windowId.
class PanelSlot {
  const PanelSlot({required this.view, this.windowId});
  final MessageView view;
  final String? windowId;
}

/// The two surfaces as one state: the conversation stream + the panel's slots.
class ShellState {
  const ShellState({this.messages = const [], this.panel = const []});

  final List<Message> messages;
  final List<PanelSlot> panel;

  static const ShellState empty = ShellState();

  ShellState copyWith({List<Message>? messages, List<PanelSlot>? panel}) =>
      ShellState(messages: messages ?? this.messages, panel: panel ?? this.panel);
}

/// Route a directive to its surface. [DirectiveTarget.inline] → a message carrying
/// the view is appended to the stream (authored by the agent's private voice, so
/// it never transmits). [DirectiveTarget.panel] → the view is pinned to the panel,
/// replacing a slot with the same windowId (an update) or appended (a new pin).
/// Pure: same inputs → same state.
ShellState applyDirective(ShellState state, Directive d) {
  if (d.target == DirectiveTarget.inline) {
    final message = Message(
      id: d.windowId ?? 'dir-${state.messages.length}',
      author: MessageAuthor.agentAdvisor,
      state: MessageState.internal,
      channel: MessageChannel.none,
      view: d.view,
    );
    return state.copyWith(messages: [...state.messages, message]);
  }

  final slot = PanelSlot(view: d.view, windowId: d.windowId);
  final exists =
      d.windowId != null && state.panel.any((s) => s.windowId == d.windowId);
  final panel = exists
      ? [for (final s in state.panel) if (s.windowId == d.windowId) slot else s]
      : [...state.panel, slot];
  return state.copyWith(panel: panel);
}

/// Remove a pinned panel slot (a `dismiss_view` on a panel window). No-op on the
/// stream — inline directives are conversation history and don't retract.
ShellState dismissPanel(ShellState state, String windowId) => state.copyWith(
      panel: [for (final s in state.panel) if (s.windowId != windowId) s],
    );

/// Append an ordinary conversation message (operator or agent) to the stream.
ShellState appendMessage(ShellState state, Message message) =>
    state.copyWith(messages: [...state.messages, message]);
