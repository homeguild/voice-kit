import type { AgentFrame } from "./agent-frames";
import type { Directive } from "./directive";
import { Message } from "./message";
import { appendMessage, applyDirective, emptyShell, type ShellState } from "./shell";

/**
 * Folding an agent's SSE stream into shell state — the SHARED reducer both ports
 * run so a cassette (voice-kit/fixtures/agent-cassettes.json) produces the same
 * stream + panel on web and Flutter (docs/journey-testing.md). Lives beside the
 * envelope (agent-frames.ts) on purpose: the frame contract and the fold that
 * consumes it are one thing. Pure — same frames in, same shell out.
 */

/** The in-progress turn: the shell + the growing agent message id + an id seq. */
export interface AgentTurn {
  shell: ShellState;
  agentId: string | null;
  seq: number;
}

export const initialTurn: AgentTurn = { shell: emptyShell, agentId: null, seq: 0 };

/** Seed a turn with the assistant's opening line (e.g. today's brief) so the
 *  shell isn't empty before the operator says anything. */
export function openingTurn(text: string): AgentTurn {
  return {
    shell: appendMessage(emptyShell, agentMessage("a-opening", text)),
    agentId: null,
    seq: 1,
  };
}

/** Append the operator's own message and start a fresh agent turn. */
export function appendUser(turn: AgentTurn, text: string): AgentTurn {
  const msg = new Message({
    id: `u-${turn.seq}`,
    author: "operator",
    state: "sent",
    channel: "chat",
    text,
  });
  return { shell: appendMessage(turn.shell, msg), agentId: null, seq: turn.seq + 1 };
}

/** Apply one SSE frame. Terminal/unknown frames (progress, done, error) pass through. */
export function applyFrame(turn: AgentTurn, frame: AgentFrame): AgentTurn {
  switch (frame.type) {
    case "narrative_start":
      return startAgentMessage(turn, "");

    case "narrative": {
      const text = frame.text ?? "";
      if (!turn.agentId) return startAgentMessage(turn, text);
      const grown = currentText(turn.shell, turn.agentId) + text;
      return { ...turn, shell: replaceMessage(turn.shell, agentMessage(turn.agentId, grown)) };
    }

    case "narrative_end":
      return { ...turn, agentId: null };

    case "directive": {
      if (frame.directive !== "show_view") return turn; // notify → host toast, not the shell
      const windowId = frame.window_id;
      const directive: Directive = {
        view: {
          viewId: frame.view_id,
          // Carry window_id into the view's data: a MessageView only exposes
          // {viewId, data} to its renderer, but an interactive view (a form) must
          // echo it back in its view_event to resume the right agent turn.
          data: { ...(frame.data ?? {}), __windowId: windowId },
        },
        target: frame.target === "panel" ? "panel" : "inline",
        windowId,
        options: frame.options,
      };
      return { ...turn, shell: applyDirective(turn.shell, directive) };
    }

    default:
      return turn;
  }
}

function startAgentMessage(turn: AgentTurn, text: string): AgentTurn {
  const agentId = `a-${turn.seq}`;
  return {
    shell: appendMessage(turn.shell, agentMessage(agentId, text)),
    agentId,
    seq: turn.seq + 1,
  };
}

/** The agent's chat voice — a left agent line (contact viewpoint). Directive views
 *  render by their view, not the author. */
function agentMessage(id: string, text: string): Message {
  return new Message({ id, author: "agentPublic", state: "sent", channel: "chat", text });
}

function currentText(shell: ShellState, id: string): string {
  return shell.messages.find((m) => m.id === id)?.text ?? "";
}

function replaceMessage(shell: ShellState, msg: Message): ShellState {
  return { ...shell, messages: shell.messages.map((m) => (m.id === msg.id ? msg : m)) };
}
