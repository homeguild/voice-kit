import type { AgentCassette, AgentFrame } from "./agent-frames";
import { CASSETTES } from "./cassettes";

/**
 * The MOCK AGENT transport (docs/journey-testing.md, step 4) — replay a cassette
 * as the real SSE stream so a journey drives agent turns with no Sophia/LLM. Pure
 * + shared: the same resolution runs in the Playwright route interceptor AND the
 * `MOCK_AGENT` relay mode, so both produce frames the client can't distinguish
 * from the live transport. Branching stays deterministic — an event resolves the
 * next cassette from the submitted window's `branches`.
 */

/** Frames → the SSE wire format the client's readSse consumes (`data: {json}\n\n`). */
export function framesToSse(frames: AgentFrame[]): string {
  return frames.map((f) => `data: ${JSON.stringify(f)}\n\n`).join("");
}

export function cassetteToSse(cassette: AgentCassette): string {
  return framesToSse(cassette.frames);
}

/**
 * The cassette a `/chat` message plays: exact `userMessage` match first, then a
 * loose contains-match. Returns undefined when nothing matches (caller picks a
 * fallback — e.g. a plain narrative).
 */
export function chatCassette(
  message: string,
  cassettes: AgentCassette[] = CASSETTES,
): AgentCassette | undefined {
  const m = message.trim();
  if (!m) return undefined;
  return (
    cassettes.find((c) => c.userMessage && c.userMessage === m) ??
    cassettes.find((c) => c.userMessage && m.toLowerCase().includes(c.userMessage.toLowerCase()))
  );
}

/**
 * The cassette a view_event resumes: find the cassette whose show_view opened
 * `windowId`, then follow its `branches[eventType]` (submitted | cancelled) to the
 * next cassette. Undefined when the window/branch isn't scripted.
 */
export function eventCassette(
  windowId: string,
  eventType: string,
  cassettes: AgentCassette[] = CASSETTES,
): AgentCassette | undefined {
  const source = cassettes.find((c) =>
    c.frames.some(
      (f) => f.type === "directive" && f.directive === "show_view" && f.window_id === windowId,
    ),
  );
  const nextId = source?.branches?.[eventType];
  return nextId ? cassettes.find((c) => c.id === nextId) : undefined;
}
