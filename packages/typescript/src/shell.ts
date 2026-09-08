import type { Directive } from "./directive";
import { Message, type MessageView } from "./message";

/**
 * The conversation shell — the stream + the panel — as a single piece of state,
 * and the pure routing that applies agent directives to it (docs/agent-shell.md).
 * Host-agnostic and pure, so the two ports route identically (proven by the
 * shared fixtures). The host owns transport (SSE) and rendering (ConversationStream
 * + PanelSurface); this owns "which surface does a directive land on."
 */

/** One thing pinned to the panel, keyed by its directive's windowId. */
export interface PanelSlot {
  readonly view: MessageView;
  readonly windowId?: string;
}

/** The two surfaces as one state: the conversation stream + the panel's slots. */
export interface ShellState {
  readonly messages: readonly Message[];
  readonly panel: readonly PanelSlot[];
}

export const emptyShell: ShellState = { messages: [], panel: [] };

/**
 * Route a directive to its surface. `inline` → a message carrying the view is
 * appended to the stream (authored by the agent's private voice, so it never
 * transmits). `panel` → the view is pinned to the panel, replacing a slot with
 * the same windowId (an update) or appended (a new pin). Pure: same inputs →
 * same state.
 */
export function applyDirective(state: ShellState, d: Directive): ShellState {
  if (d.target === "inline") {
    const message = new Message({
      id: d.windowId ?? `dir-${state.messages.length}`,
      author: "agentAdvisor",
      state: "internal",
      channel: "none",
      view: d.view,
    });
    return { ...state, messages: [...state.messages, message] };
  }

  const slot: PanelSlot = { view: d.view, windowId: d.windowId };
  const existing =
    d.windowId != null &&
    state.panel.some((s) => s.windowId === d.windowId);
  const panel = existing
    ? state.panel.map((s) => (s.windowId === d.windowId ? slot : s))
    : [...state.panel, slot];
  return { ...state, panel };
}

/** Remove a pinned panel slot (a `dismiss_view` on a panel window). No-op on the
 *  stream — inline directives are conversation history and don't retract. */
export function dismissPanel(state: ShellState, windowId: string): ShellState {
  return { ...state, panel: state.panel.filter((s) => s.windowId !== windowId) };
}

/** Append an ordinary conversation message (operator or agent) to the stream. */
export function appendMessage(state: ShellState, message: Message): ShellState {
  return { ...state, messages: [...state.messages, message] };
}
