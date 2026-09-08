import { describe, expect, it } from "vitest";

import type { Directive } from "../src/directive";
import { Message } from "../src/message";
import {
  appendMessage,
  applyDirective,
  dismissPanel,
  emptyShell,
} from "../src/shell";

/**
 * The stream+panel routing (docs/agent-shell.md) — the foundational shell pattern
 * shared by both ports. A directive lands on exactly one surface based on target;
 * panel windows update-in-place; inline directives are history and never retract.
 */

const chart = (viewId = "chart"): Directive["view"] => ({ viewId, data: {} });

describe("applyDirective — surface routing", () => {
  it("routes an inline directive to the stream as a non-transmitting message", () => {
    const s = applyDirective(emptyShell, { view: chart(), target: "inline" });
    expect(s.messages).toHaveLength(1);
    expect(s.panel).toHaveLength(0);
    const m = s.messages[0]!;
    expect(m.view?.viewId).toBe("chart");
    expect(m.isInternal).toBe(true); // agent-surfaced view, private to the operator
    expect(m.canTransmit).toBe(false); // never leaves the surface
  });

  it("routes a panel directive to the panel, not the stream", () => {
    const s = applyDirective(emptyShell, {
      view: chart("checklist"),
      target: "panel",
      windowId: "w1",
    });
    expect(s.messages).toHaveLength(0);
    expect(s.panel).toHaveLength(1);
    expect(s.panel[0]!.view.viewId).toBe("checklist");
    expect(s.panel[0]!.windowId).toBe("w1");
  });

  it("updates a panel window in place (same windowId replaces, does not stack)", () => {
    let s = applyDirective(emptyShell, {
      view: { viewId: "checklist", data: { done: 0 } },
      target: "panel",
      windowId: "w1",
    });
    s = applyDirective(s, {
      view: { viewId: "checklist", data: { done: 1 } },
      target: "panel",
      windowId: "w1",
    });
    expect(s.panel).toHaveLength(1);
    expect(s.panel[0]!.view.data.done).toBe(1);
  });

  it("stacks distinct panel windows", () => {
    let s = applyDirective(emptyShell, { view: chart("checklist"), target: "panel", windowId: "w1" });
    s = applyDirective(s, { view: chart("dashboard"), target: "panel", windowId: "w2" });
    expect(s.panel.map((p) => p.windowId)).toEqual(["w1", "w2"]);
  });

  it("dismisses a panel window, leaving the stream untouched", () => {
    let s = applyDirective(emptyShell, { view: chart(), target: "inline" });
    s = applyDirective(s, { view: chart("checklist"), target: "panel", windowId: "w1" });
    s = dismissPanel(s, "w1");
    expect(s.panel).toHaveLength(0);
    expect(s.messages).toHaveLength(1); // inline history does not retract
  });

  it("is pure — does not mutate the prior state", () => {
    const before = applyDirective(emptyShell, { view: chart(), target: "panel", windowId: "w1" });
    const after = applyDirective(before, { view: chart("x"), target: "inline" });
    expect(before.messages).toHaveLength(0);
    expect(after.messages).toHaveLength(1);
    expect(before).not.toBe(after);
  });
});

describe("appendMessage", () => {
  it("appends an ordinary message to the stream", () => {
    const s = appendMessage(emptyShell, new Message({ id: "u1", author: "operator", state: "sent", channel: "chat", text: "hi" }));
    expect(s.messages).toHaveLength(1);
    expect(s.messages[0]!.author).toBe("operator");
  });
});
