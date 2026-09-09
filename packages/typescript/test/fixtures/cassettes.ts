import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import type { AgentCassette } from "../../src/index";

/**
 * Loads the language-neutral agent cassettes (voice-kit/fixtures/agent-cassettes.json)
 * — the SAME file the Flutter port reads. One frozen cassette per agentic return
 * state; both ports replay these exact frames, so a divergence is a failing test,
 * not a review catch. See docs/journey-testing.md (axis 3).
 */

// test/fixtures/ → ../../../../ = the voice-kit repo root.
const FIXTURE = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../../../fixtures/agent-cassettes.json",
);

export function loadCassettes(): AgentCassette[] {
  const { cassettes } = JSON.parse(readFileSync(FIXTURE, "utf8")) as {
    cassettes: AgentCassette[];
  };
  return cassettes;
}

export const cassettes: AgentCassette[] = loadCassettes();

/** A cassette by id — throws on a typo so a bad branch reference fails loudly. */
export function cassette(id: string): AgentCassette {
  const found = cassettes.find((c) => c.id === id);
  if (!found) throw new Error(`no cassette with id "${id}"`);
  return found;
}
