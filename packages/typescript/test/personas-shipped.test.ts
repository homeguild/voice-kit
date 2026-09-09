import { describe, expect, it } from "vitest";

import { DEVICE_PERSONAS } from "../src/index";
import { personas } from "./fixtures/device-personas";

/**
 * The SHIPPED personas (src/personas.generated.ts) must equal the canonical JSON
 * both ports load. If the JSON changed without `npm run gen:personas`, this fails —
 * the shipped copy can't silently drift from the source of truth.
 */
describe("shipped personas", () => {
  it("match the canonical fixtures/device-personas.json", () => {
    expect(DEVICE_PERSONAS).toEqual(personas);
  });
});
