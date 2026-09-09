import type { DevicePersona } from "./device";
import { DEVICE_PERSONAS } from "./personas.generated";

/**
 * The shared device personas, shipped so consumers (Triclinium's seedDevice /
 * Playwright) seed the SAME pre-account state definitions both ports test against.
 * Generated from the canonical voice-kit/fixtures/device-personas.json (see
 * gen-personas.mjs); a drift test keeps the shipped copy honest.
 */

export { DEVICE_PERSONAS };

/** A persona by id — throws on a typo so a bad seed reference fails loudly. */
export function personaById(id: string): DevicePersona {
  const found = DEVICE_PERSONAS.find((p) => p.id === id);
  if (!found) throw new Error(`no persona with id "${id}"`);
  return found;
}
