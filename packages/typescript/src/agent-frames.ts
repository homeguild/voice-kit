/**
 * The agent SSE envelope — the frame contract every agent turn streams, and the
 * shared spine of journey testing (docs/journey-testing.md, axis 3). Sophia emits
 * these frames (services/sophia/sophia/streaming.py); the client folds them into
 * shell state. Both ports speak this EXACT envelope (this type + its Flutter
 * mirror), so one recorded cassette drives both — a mock replay and the real
 * transport are indistinguishable at this boundary.
 *
 * This module is the CONTRACT (types + the frame-type set + a validator). The
 * fold (frames → ShellState) is the reducer; the recorded cassettes are the
 * shared fixture (voice-kit/fixtures/agent-cassettes.json).
 */

export type DirectiveTargetName = "inline" | "panel";

/** A frame of Sophia's SSE stream. Discriminated by `type` (and `directive`). */
export type AgentFrame =
  | { type: "progress"; message?: string }
  | { type: "narrative_start" }
  | { type: "narrative"; text: string }
  | { type: "narrative_end" }
  | {
      type: "directive";
      directive: "show_view";
      view_id: string;
      window_id?: string;
      target?: DirectiveTargetName;
      data?: Record<string, unknown>;
      options?: Record<string, unknown>;
    }
  | { type: "directive"; directive: "notify"; message: string; severity?: string }
  // Retract a view the agent earlier pinned to the PANEL (by windowId) — when the task it was
  // for is done, however the operator finished it (filled the form, or just answered in chat).
  // No-op on inline views (conversation history). The reusable spine of multi-step panel flows.
  | { type: "directive"; directive: "dismiss_view"; window_id: string }
  | { type: "done"; data?: Record<string, unknown> }
  | { type: "error"; message?: string };

export const AGENT_FRAME_TYPES = [
  "progress",
  "narrative_start",
  "narrative",
  "narrative_end",
  "directive",
  "done",
  "error",
] as const;

export type AgentFrameType = (typeof AGENT_FRAME_TYPES)[number];

/**
 * A recorded, frozen agent turn — one canonical example per RETURN STATE
 * (narrative, notify, form, confirmation, selection_list, error, composite).
 * `branches` maps a view_event's event_type → the id of the cassette that
 * resumes the conversation, so a scripted flow stays deterministic.
 */
export interface AgentCassette {
  id: string;
  title: string;
  returnState: string;
  opening?: string;
  userMessage: string;
  frames: AgentFrame[];
  branches?: Record<string, string>;
}

/**
 * Validate a frame against the envelope contract — the check the record/replay
 * "contract test" runs on shapes (not content) so the harness can't drift from
 * the live agent. Returns an error string, or null when the shape is valid.
 */
export function validateAgentFrame(frame: AgentFrame): string | null {
  if (!frame || typeof frame !== "object") return "frame is not an object";
  const type = (frame as { type?: unknown }).type;
  if (typeof type !== "string" || !(AGENT_FRAME_TYPES as readonly string[]).includes(type)) {
    return `unknown frame type: ${String(type)}`;
  }
  if (type === "narrative" && typeof (frame as { text?: unknown }).text !== "string") {
    return "narrative frame missing text";
  }
  if (type === "directive") {
    const d = (frame as { directive?: unknown }).directive;
    if (d === "show_view") {
      if (typeof (frame as { view_id?: unknown }).view_id !== "string") {
        return "show_view directive missing view_id";
      }
      const target = (frame as { target?: unknown }).target;
      if (target !== undefined && target !== "inline" && target !== "panel") {
        return `show_view directive has invalid target: ${String(target)}`;
      }
    } else if (d === "notify") {
      if (typeof (frame as { message?: unknown }).message !== "string") {
        return "notify directive missing message";
      }
    } else if (d === "dismiss_view") {
      if (typeof (frame as { window_id?: unknown }).window_id !== "string") {
        return "dismiss_view directive missing window_id";
      }
    } else {
      return `unknown directive: ${String(d)}`;
    }
  }
  return null;
}
