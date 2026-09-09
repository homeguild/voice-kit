import type { AgentCassette } from "./agent-frames";
import { CASSETTES } from "./cassettes.generated";

/**
 * The shared agent cassette library, shipped so consumers (Triclinium) can fold a
 * cassette through {@link applyFrame} in their L2 goldens / L3 replay without
 * reaching into the repo-root fixtures dir. The data is generated from the
 * canonical voice-kit/fixtures/agent-cassettes.json (see gen-cassettes.mjs); a
 * drift test keeps the shipped copy honest.
 */

export { CASSETTES };

/** A cassette by id — throws on a typo so a bad branch reference fails loudly. */
export function cassetteById(id: string): AgentCassette {
  const found = CASSETTES.find((c) => c.id === id);
  if (!found) throw new Error(`no cassette with id "${id}"`);
  return found;
}
