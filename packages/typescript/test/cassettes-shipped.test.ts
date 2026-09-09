import { describe, expect, it } from "vitest";

import { CASSETTES } from "../src/index";
import { cassettes } from "./fixtures/cassettes";

/**
 * The SHIPPED cassettes (src/cassettes.generated.ts, embedded so consumers get
 * them from the package) must equal the canonical JSON both ports load. If the
 * JSON changed without re-running `npm run gen:cassettes`, this fails — the shipped
 * copy can't silently drift from the source of truth.
 */
describe("shipped cassettes", () => {
  it("match the canonical fixtures/agent-cassettes.json", () => {
    expect(CASSETTES).toEqual(cassettes);
  });
});
