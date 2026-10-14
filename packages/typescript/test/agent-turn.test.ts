import { describe, expect, it } from "vitest";

import { appendUser, applyFrame, initialTurn, type AgentFrame, type AgentTurn } from "../src/index";

/**
 * Folding an agent's SSE frames into shell state — the SHARED reducer both ports
 * run. Narrative grows the agent's message; directives route to the stream or the
 * panel by target; ordering (text → view → text) is preserved. (Moved here from
 * Triclinium so web + Flutter fold a cassette identically.)
 */
const run = (frames: AgentFrame[], start: AgentTurn = initialTurn) =>
  frames.reduce((t, f) => applyFrame(t, f), start);

describe("agent-turn reducer", () => {
  it("appends the operator's message and resets the agent turn", () => {
    const t = appendUser(initialTurn, "hi");
    expect(t.shell.messages).toHaveLength(1);
    expect(t.shell.messages[0]!.author).toBe("operator");
    expect(t.agentId).toBeNull();
  });

  it("grows the agent's message across narrative tokens", () => {
    const t = run([
      { type: "narrative_start" },
      { type: "narrative", text: "Let's " },
      { type: "narrative", text: "get set up." },
      { type: "narrative_end" },
    ]);
    expect(t.shell.messages).toHaveLength(1);
    expect(t.shell.messages[0]!.author).toBe("agentPublic");
    expect(t.shell.messages[0]!.text).toBe("Let's get set up.");
    expect(t.agentId).toBeNull();
  });

  it("routes a panel directive to the panel, not the stream", () => {
    const t = run([
      { type: "directive", directive: "show_view", view_id: "checklist", window_id: "w1", target: "panel", data: { title: "Set up" } },
    ]);
    expect(t.shell.messages).toHaveLength(0);
    expect(t.shell.panel).toHaveLength(1);
    expect(t.shell.panel[0]!.view.viewId).toBe("checklist");
    expect(t.shell.panel[0]!.windowId).toBe("w1");
  });

  it("carries window_id into the view data so an interactive view can echo it back", () => {
    const t = run([
      { type: "directive", directive: "show_view", view_id: "form", window_id: "form_abc", target: "panel", data: { title: "Onboarding", fields: [] } },
    ]);
    const view = t.shell.panel[0]!.view;
    expect(view.viewId).toBe("form");
    expect(view.data.__windowId).toBe("form_abc");
    expect(view.data.title).toBe("Onboarding"); // agent's own data preserved
  });

  it("routes an inline directive into the stream as a view message", () => {
    const t = run([
      { type: "directive", directive: "show_view", view_id: "chart", window_id: "c1", target: "inline", data: { bars: [] } },
    ]);
    expect(t.shell.panel).toHaveLength(0);
    expect(t.shell.messages).toHaveLength(1);
    expect(t.shell.messages[0]!.view?.viewId).toBe("chart");
  });

  it("preserves order: agent text, then an inline view, then more text", () => {
    const t = run([
      { type: "narrative_start" },
      { type: "narrative", text: "Here's this month:" },
      { type: "narrative_end" },
      { type: "directive", directive: "show_view", view_id: "chart", window_id: "c1", target: "inline", data: {} },
      { type: "narrative_start" },
      { type: "narrative", text: "Trending up." },
      { type: "narrative_end" },
    ]);
    expect(t.shell.messages.map((m) => m.view?.viewId ?? m.text)).toEqual([
      "Here's this month:",
      "chart",
      "Trending up.",
    ]);
  });

  it("ignores a notify directive (it's a host toast, not a shell surface)", () => {
    const t = run([{ type: "directive", directive: "notify", message: "saved", severity: "success" }]);
    expect(t.shell.messages).toHaveLength(0);
    expect(t.shell.panel).toHaveLength(0);
  });

  it("dismiss_view retracts the matching panel slot (the multi-step completion signal)", () => {
    const t = run([
      { type: "directive", directive: "show_view", view_id: "form", window_id: "voice", target: "panel", data: { title: "Voice" } },
      { type: "directive", directive: "show_view", view_id: "checklist", window_id: "focus", target: "panel", data: { title: "Start here" } },
      // The voice step completes (e.g. answered in chat) → the agent retracts just that form.
      { type: "directive", directive: "dismiss_view", window_id: "voice" },
    ]);
    expect(t.shell.panel).toHaveLength(1);
    expect(t.shell.panel[0]!.windowId).toBe("focus"); // the checklist stays pinned
  });

  it("dismiss_view leaves the stream untouched (inline views are history)", () => {
    const t = run([
      { type: "directive", directive: "show_view", view_id: "chart", window_id: "c1", target: "inline", data: {} },
      { type: "directive", directive: "dismiss_view", window_id: "c1" },
    ]);
    expect(t.shell.messages).toHaveLength(1); // inline view not retracted
    expect(t.shell.panel).toHaveLength(0);
  });

  it("defaults an unknown target to inline", () => {
    // An out-of-contract target (not inline|panel) — cast past the typed union.
    const frame = { type: "directive", directive: "show_view", view_id: "x", window_id: "w", target: "sidebar", data: {} } as unknown as AgentFrame;
    const t = run([frame]);
    expect(t.shell.messages).toHaveLength(1);
    expect(t.shell.panel).toHaveLength(0);
  });
});
