// Generate src/cassettes.generated.ts from the canonical, language-neutral
// voice-kit/fixtures/agent-cassettes.json so the kit can SHIP the cassettes to
// consumers (Triclinium) — the repo-root fixtures dir isn't inside the package's
// published `src`. The JSON stays the single source of truth; this embeds a typed
// copy. A drift test (test/cassettes-shipped.test.ts) fails if they diverge.
// Run: npm run gen:cassettes (also runs in prepublishOnly).
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const canonical = resolve(here, "../../../fixtures/agent-cassettes.json");
const out = resolve(here, "../src/cassettes.generated.ts");

const { cassettes } = JSON.parse(readFileSync(canonical, "utf8"));

const banner =
  "// GENERATED from voice-kit/fixtures/agent-cassettes.json by scripts/gen-cassettes.mjs.\n" +
  "// Do NOT edit — run `npm run gen:cassettes`. The JSON is the source of truth.\n" +
  'import type { AgentCassette } from "./agent-frames";\n\n';
const body = `export const CASSETTES: AgentCassette[] = ${JSON.stringify(cassettes, null, 2)};\n`;

writeFileSync(out, banner + body);
console.log(`wrote ${cassettes.length} cassettes → src/cassettes.generated.ts`);
