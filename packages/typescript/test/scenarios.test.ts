import { describe, expect, it } from "vitest";

import { isPrivateAuthor } from "../src/index";
import { scenarios } from "./fixtures/scenarios";

/**
 * The shared-fixture spine, TS side: the scenarios load from the language-neutral
 * JSON and satisfy the same taxonomy the Flutter port asserts on the same file.
 * If the fixture changes shape, both ports' suites move together.
 */
describe("shared scenario fixtures", () => {
  const weekend = scenarios.find((s) => s.id === "weekend_callout");

  it("hydrates the scenario from the shared JSON", () => {
    expect(weekend).toBeTruthy();
    expect(weekend!.messages).toHaveLength(6);
    expect(weekend!.shows.length).toBeGreaterThan(0);
  });

  it("has exactly one message awaiting approval — the public-agent draft", () => {
    const pending = weekend!.messages.filter((m) => m.requiresApproval);
    expect(pending).toHaveLength(1);
    expect(pending[0]!.author).toBe("agentPublic");
  });

  it("never lets a private (advisor/system) message transmit", () => {
    const priv = weekend!.messages.filter((m) => isPrivateAuthor(m.author));
    expect(priv.length).toBeGreaterThan(0);
    for (const m of priv) expect(m.canTransmit).toBe(false);
  });

  it("only lets settled contact/operator messages transmit", () => {
    const transmit = weekend!.messages.filter((m) => m.canTransmit);
    expect(transmit.length).toBeGreaterThan(0);
    expect(
      transmit.every((m) => m.author === "contact" || m.author === "operator"),
    ).toBe(true);
  });
});
