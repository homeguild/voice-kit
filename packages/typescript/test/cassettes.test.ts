import { describe, expect, it } from "vitest";

import { validateAgentFrame } from "../src/index";
import { cassettes } from "./fixtures/cassettes";

/**
 * The shared cassette library is the spine of journey testing (axis 3). These
 * checks are the envelope contract: every frame is a valid shape, every branch
 * resolves, and the canonical return states are all present — so both ports load
 * one truth and a malformed cassette fails here, not in a flaky UI run.
 */
describe("agent cassettes (shared fixture)", () => {
  it("loads the library", () => {
    expect(cassettes.length).toBeGreaterThan(0);
  });

  it("every frame conforms to the envelope contract", () => {
    for (const c of cassettes) {
      expect(c.frames.length, `${c.id} has frames`).toBeGreaterThan(0);
      for (const frame of c.frames) {
        expect(validateAgentFrame(frame), `${c.id}: ${JSON.stringify(frame)}`).toBeNull();
      }
    }
  });

  it("every branch target references an existing cassette", () => {
    const ids = new Set(cassettes.map((c) => c.id));
    for (const c of cassettes) {
      for (const [event, next] of Object.entries(c.branches ?? {})) {
        expect(ids.has(next), `${c.id}.branches.${event} → ${next}`).toBe(true);
      }
    }
  });

  it("ids are unique", () => {
    const ids = cassettes.map((c) => c.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("covers the canonical return states", () => {
    const states = new Set(cassettes.map((c) => c.returnState));
    for (const required of ["narrative", "notify", "form", "confirmation", "selection_list", "error", "composite"]) {
      expect(states.has(required), `missing return state: ${required}`).toBe(true);
    }
  });

  it("interactive views (branches) carry a window_id to echo back", () => {
    for (const c of cassettes) {
      if (!c.branches) continue;
      const hasWindowedView = c.frames.some(
        (f) => f.type === "directive" && f.directive === "show_view" && typeof f.window_id === "string",
      );
      expect(hasWindowedView, `${c.id} branches but has no windowed show_view`).toBe(true);
    }
  });
});
