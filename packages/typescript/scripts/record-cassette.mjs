// Record a REAL Sophia turn into a frozen cassette (docs/journey-testing.md — the
// record half of record/replay). Build a flow live against the agent, then capture
// what it actually streamed so the deterministic test conforms to reality instead
// of a hand-authored guess.
//
//   node scripts/record-cassette.mjs --id onboarding --message "help me get set up" \
//       [--title "..."] [--returnState form] [--window form_onboarding] [--write]
//
// Logs into local Sacrum for a token, streams Sophia's /chat SSE, collects the
// frames. Prints the cassette JSON; with --write, upserts it into
// fixtures/agent-cassettes.json (by id) and regenerates the shipped copy.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const flag = (name) => process.argv.includes(`--${name}`);

const id = arg("id");
const message = arg("message");
if (!id || !message) {
  console.error('Required: --id <id> --message "<what the operator types>"');
  process.exit(1);
}
const SACRUM = arg("sacrum", "http://localhost:8095");
const SOPHIA = arg("sophia", "http://localhost:8092");
const EMAIL = arg("email", "1@1.com");
const PASSWORD = arg("password", "12345678");
const forceWindow = arg("window"); // optional: rewrite show_view window_id → stable

async function login() {
  const res = await fetch(`${SACRUM}/graphql`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query: "mutation($i: LoginInput!){ login(input:$i){ accessToken } }",
      variables: { i: { email: EMAIL, password: PASSWORD } },
    }),
  });
  const json = await res.json();
  const token = json?.data?.login?.accessToken;
  if (!token) throw new Error(`login failed: ${JSON.stringify(json.errors ?? json)}`);
  return token;
}

async function streamFrames(token) {
  const res = await fetch(`${SOPHIA}/api/v1/agent/internal/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ message }),
  });
  if (!res.ok) throw new Error(`Sophia ${res.status}`);
  const text = await res.text();
  return text
    .split("\n\n")
    .map((c) => c.replace(/^data:\s?/, "").trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

const token = await login();
const frames = await streamFrames(token);

// Stabilize: real Sophia stamps a random window_id (form_<hex>). Rewrite it to a
// fixed value so goldens + branch references are deterministic.
if (forceWindow) {
  for (const f of frames) {
    if (f.type === "directive" && f.directive === "show_view" && f.window_id) {
      f.window_id = forceWindow;
    }
  }
}

const view = frames.find((f) => f.type === "directive" && f.directive === "show_view");
const cassette = {
  id,
  title: arg("title", id),
  returnState: arg("returnState", view ? view.view_id : "narrative"),
  userMessage: message,
  frames,
};

if (!flag("write")) {
  console.log(JSON.stringify(cassette, null, 2));
  console.error(`\n(dry run — re-run with --write to save into agent-cassettes.json)`);
  process.exit(0);
}

const fixturePath = resolve(here, "../../../fixtures/agent-cassettes.json");
const doc = JSON.parse(readFileSync(fixturePath, "utf8"));
const idx = doc.cassettes.findIndex((c) => c.id === id);
if (idx >= 0) doc.cassettes[idx] = cassette;
else doc.cassettes.push(cassette);
writeFileSync(fixturePath, JSON.stringify(doc, null, 2) + "\n");
execFileSync("node", [resolve(here, "gen-cassettes.mjs")], { stdio: "inherit" });
console.error(`\n✅ ${idx >= 0 ? "updated" : "added"} cassette "${id}" (${cassette.frames.length} frames) + regenerated.`);
