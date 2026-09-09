import { describe, expect, it } from "vitest";

import {
  daysSinceInstall,
  isFreshInstall,
  NEW_INSTALL,
  resolvePersona,
  type Clock,
} from "../src/index";
import { persona, personas } from "./fixtures/device-personas";

// A frozen clock so relative persona times resolve to fixed instants.
const FROZEN = new Date("2026-09-09T12:00:00.000Z");
const clock: Clock = { now: () => FROZEN };

describe("device state + personas (axis 2)", () => {
  it("fresh_install resolves to the new-install default", () => {
    const state = resolvePersona(persona("fresh_install"), clock);
    expect(state).toEqual(NEW_INSTALL);
    expect(isFreshInstall(state)).toBe(true);
  });

  it("resolves relative times against the clock", () => {
    const state = resolvePersona(persona("returning_unauth"), clock);
    expect(state.appOpenCount).toBe(3);
    expect(state.firstOpenAt).toBe("2026-09-04T12:00:00.000Z"); // 5 days before FROZEN
    expect(state.lastSeenAt).toBe("2026-09-09T12:00:00.000Z"); // 0 days ago
    expect(daysSinceInstall(state, clock)).toBe(5);
    expect(isFreshInstall(state)).toBe(false);
  });

  it("carries onboarding + waitlist state through", () => {
    expect(resolvePersona(persona("onboarding_midway"), clock).onboardingStep).toBe(2);
    expect(resolvePersona(persona("waitlisted"), clock).waitlistState).toBe("joined");
  });

  it("every persona resolves to a well-formed DeviceState", () => {
    for (const p of personas) {
      const s = resolvePersona(p, clock);
      expect(typeof s.appOpenCount).toBe("number");
      expect(Array.isArray(s.dismissedPrompts)).toBe(true);
      expect(["none", "joined"]).toContain(s.waitlistState);
    }
  });

  it("covers the canonical personas", () => {
    const ids = new Set(personas.map((p) => p.id));
    for (const required of ["fresh_install", "returning_unauth", "waitlisted", "onboarding_midway", "lapsed"]) {
      expect(ids.has(required), `missing persona: ${required}`).toBe(true);
    }
  });
});
