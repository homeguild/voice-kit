import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import type { DevicePersona } from "../../src/index";

/**
 * Loads the language-neutral device personas (voice-kit/fixtures/device-personas.json)
 * — the SAME file the Flutter port reads. Journey-testing axis 2: both ports seed
 * these exact personas, so a divergence is a failing test, not a review catch.
 */

// test/fixtures/ → ../../../../ = the voice-kit repo root.
const FIXTURE = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../../../fixtures/device-personas.json",
);

export function loadPersonas(): DevicePersona[] {
  const { personas } = JSON.parse(readFileSync(FIXTURE, "utf8")) as {
    personas: DevicePersona[];
  };
  return personas;
}

export const personas: DevicePersona[] = loadPersonas();

export function persona(id: string): DevicePersona {
  const found = personas.find((p) => p.id === id);
  if (!found) throw new Error(`no persona with id "${id}"`);
  return found;
}
