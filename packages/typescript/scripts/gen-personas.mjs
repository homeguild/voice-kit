// Generate src/personas.generated.ts from the canonical
// voice-kit/fixtures/device-personas.json so the kit can SHIP the personas to
// consumers (Triclinium seedDevice / Playwright). Mirror of gen-cassettes.mjs;
// the JSON stays the source of truth, a drift test keeps the copy honest.
// Run: npm run gen:personas (also in prepublishOnly).
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const canonical = resolve(here, "../../../fixtures/device-personas.json");
const out = resolve(here, "../src/personas.generated.ts");

const { personas } = JSON.parse(readFileSync(canonical, "utf8"));

const banner =
  "// GENERATED from voice-kit/fixtures/device-personas.json by scripts/gen-personas.mjs.\n" +
  "// Do NOT edit — run `npm run gen:personas`. The JSON is the source of truth.\n" +
  'import type { DevicePersona } from "./device";\n\n';
const body = `export const DEVICE_PERSONAS: DevicePersona[] = ${JSON.stringify(personas, null, 2)};\n`;

writeFileSync(out, banner + body);
console.log(`wrote ${personas.length} personas → src/personas.generated.ts`);
