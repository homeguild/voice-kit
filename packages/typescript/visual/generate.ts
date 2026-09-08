import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

import { ConversationStream } from "../src/index";
import { scenarios } from "../test/fixtures/scenarios";

/**
 * Renders each shared scenario to a self-contained HTML page (real React, via
 * tsx). Run BEFORE Playwright — the spec then only loads + screenshots these
 * files, so no kit JSX is ever imported into a Playwright-transformed module
 * (Playwright rewrites JSX to its own component objects, which breaks SSR).
 */

const here = dirname(fileURLToPath(import.meta.url));
const outDir = resolve(here, "gen");
mkdirSync(outDir, { recursive: true });

const wrap = (body: string) =>
  `<!doctype html><html><head><meta charset="utf-8"><style>
     *{box-sizing:border-box}
     html,body{margin:0}
     body{font-family:-apple-system,system-ui,"Segoe UI",Roboto,sans-serif;background:#faf7f0}
   </style></head><body>${body}</body></html>`;

for (const s of scenarios) {
  const html = renderToStaticMarkup(
    createElement(ConversationStream, {
      messages: s.messages,
      viewpoint: "operator",
    }),
  );
  writeFileSync(resolve(outDir, `${s.id}.html`), wrap(html), "utf8");
}

console.log(`generated ${scenarios.length} scenario page(s) → visual/gen/`);
