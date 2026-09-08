import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { expect, test } from "@playwright/test";

/**
 * L2 component visual goldens. The scenario pages are pre-rendered by
 * `visual/generate.ts` (see `test:visual`); this spec only loads + screenshots
 * them, so it never imports the kit's JSX (which Playwright's transform would
 * mangle). Same scenarios as the Flutter golden suite — separate pixel baselines
 * per engine, one shared source of stories.
 */

const here = dirname(fileURLToPath(import.meta.url));
const { scenarios } = JSON.parse(
  readFileSync(resolve(here, "../../../fixtures/scenarios.json"), "utf8"),
) as { scenarios: { id: string; title: string }[] };

for (const s of scenarios) {
  test(`conversation surface — ${s.title}`, async ({ page }) => {
    await page.goto(pathToFileURL(resolve(here, "gen", `${s.id}.html`)).href, {
      waitUntil: "load",
    });
    await expect(page).toHaveScreenshot(`${s.id}.png`, { fullPage: true });
  });
}
