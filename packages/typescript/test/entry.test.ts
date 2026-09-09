import { describe, expect, it } from "vitest";

import { resolveEntry, type Destination } from "../src/index";

/**
 * The entry gate (docs/app-state.md) — auth × intent → surface, the shared
 * contract both ports conform to. These lock the coherence: an unauthenticated
 * visitor never resolves to a view they can't see (the `#/today`-on-signin bug).
 */
const dest = (path: string, params?: Record<string, string>): Destination => ({ path, params });

describe("resolveEntry", () => {
  it("resolving → splash regardless of intent", () => {
    expect(resolveEntry("resolving", dest("inbox/voice/1")).kind).toBe("splash");
  });

  it("authenticated → the app at the intended destination", () => {
    const s = resolveEntry("authenticated", dest("settings/agent"));
    expect(s).toEqual({ kind: "app", dest: dest("settings/agent") });
  });

  it("authenticated + no intent → the app at home (today)", () => {
    expect(resolveEntry("authenticated", null)).toEqual({ kind: "app", dest: { path: "today" } });
  });

  it("unauthenticated + protected intent → sign-in, remembering where they were headed", () => {
    const s = resolveEntry("unauthenticated", dest("inbox/voice/123"));
    expect(s).toEqual({ kind: "public", dest: { path: "signin", params: { next: "inbox/voice/123" } } });
  });

  it("unauthenticated + home → sign-in with no continue (home is the default)", () => {
    expect(resolveEntry("unauthenticated", dest("today"))).toEqual({
      kind: "public",
      dest: { path: "signin", params: undefined },
    });
  });

  it("unauthenticated + a PUBLIC deeplink → that surface, no gate", () => {
    expect(resolveEntry("unauthenticated", dest("invite/abc123"))).toEqual({
      kind: "public",
      dest: dest("invite/abc123"),
    });
    const reset = resolveEntry("unauthenticated", dest("reset"));
    expect(reset.kind === "public" && reset.dest.path).toBe("reset");
  });
});
