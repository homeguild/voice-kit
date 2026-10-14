import 'agent_frames.dart';
import 'directive.dart';
import 'message.dart';
import 'shell.dart';

/// Folding an agent's SSE stream into shell state — the SHARED reducer both ports
/// run (the 1:1 Dart mirror of TS `agent-turn.ts`) so a cassette
/// (voice-kit/fixtures/agent-cassettes.json) produces the SAME stream + panel on
/// web and Flutter (docs/journey-testing.md). Pure: same frames in, same shell out.

/// The in-progress turn: the shell + the growing agent message id + an id seq.
class AgentTurn {
  const AgentTurn({required this.shell, this.agentId, this.seq = 0});

  final ShellState shell;
  final String? agentId;
  final int seq;

  AgentTurn _with({ShellState? shell, String? agentId, bool clearAgentId = false, int? seq}) =>
      AgentTurn(
        shell: shell ?? this.shell,
        agentId: clearAgentId ? null : (agentId ?? this.agentId),
        seq: seq ?? this.seq,
      );
}

const AgentTurn initialTurn = AgentTurn(shell: ShellState.empty);

/// Seed a turn with the assistant's opening line (e.g. today's brief) so the shell
/// isn't empty before the operator says anything.
AgentTurn openingTurn(String text) => AgentTurn(
      shell: appendMessage(ShellState.empty, _agentMessage('a-opening', text)),
      seq: 1,
    );

/// Append the operator's own message and start a fresh agent turn.
AgentTurn appendUser(AgentTurn turn, String text) {
  final msg = Message(
    id: 'u-${turn.seq}',
    author: MessageAuthor.operator,
    state: MessageState.sent,
    channel: MessageChannel.chat,
    text: text,
  );
  return AgentTurn(shell: appendMessage(turn.shell, msg), seq: turn.seq + 1);
}

/// Apply one SSE frame. Terminal/unknown frames (progress, done, error) pass through.
AgentTurn applyFrame(AgentTurn turn, AgentFrame frame) {
  switch (frame.type) {
    case 'narrative_start':
      return _startAgentMessage(turn, '');

    case 'narrative':
      final text = frame.text ?? '';
      if (turn.agentId == null) return _startAgentMessage(turn, text);
      final grown = _currentText(turn.shell, turn.agentId!) + text;
      return turn._with(
          shell: _replaceMessage(turn.shell, _agentMessage(turn.agentId!, grown)));

    case 'narrative_end':
      return turn._with(clearAgentId: true);

    case 'directive':
      // Retract a pinned panel view when its task is done (however it was finished).
      if (frame.directive == 'dismiss_view') {
        return turn._with(shell: dismissPanel(turn.shell, frame.windowId ?? ''));
      }
      if (frame.directive != 'show_view') return turn; // notify → host toast, not the shell
      final windowId = frame.windowId;
      final d = Directive(
        view: MessageView(
          viewId: frame.viewId ?? '',
          // Carry window_id into the view's data so an interactive view (a form) can
          // echo it back in its view_event and resume the right agent turn.
          data: <String, Object?>{...?frame.data, '__windowId': windowId},
        ),
        target: frame.target == 'panel' ? DirectiveTarget.panel : DirectiveTarget.inline,
        windowId: windowId,
      );
      return turn._with(shell: applyDirective(turn.shell, d));

    default:
      return turn;
  }
}

AgentTurn _startAgentMessage(AgentTurn turn, String text) {
  final agentId = 'a-${turn.seq}';
  return AgentTurn(
    shell: appendMessage(turn.shell, _agentMessage(agentId, text)),
    agentId: agentId,
    seq: turn.seq + 1,
  );
}

/// The agent's chat voice — a left agent line. Directive views render by their view.
Message _agentMessage(String id, String text) => Message(
      id: id,
      author: MessageAuthor.agentPublic,
      state: MessageState.sent,
      channel: MessageChannel.chat,
      text: text,
    );

String _currentText(ShellState shell, String id) {
  for (final m in shell.messages) {
    if (m.id == id) return m.text ?? '';
  }
  return '';
}

ShellState _replaceMessage(ShellState shell, Message msg) => shell.copyWith(
      messages: [for (final m in shell.messages) if (m.id == msg.id) msg else m],
    );
