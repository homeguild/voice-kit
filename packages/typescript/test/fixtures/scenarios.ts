import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  Message,
  type MessageAction,
  type MessageAuthor,
  type MessageChannel,
  type MessageState,
} from "../../src/index";

/**
 * Loads the language-neutral scenario fixtures (voice-kit/fixtures/scenarios.json)
 * — the SAME file the Flutter port reads — and hydrates each scenario's Messages.
 * This is the shared spine: both ports render these exact stories, so a divergence
 * shows up as a failing test (vitest / Playwright here; golden_toolkit there),
 * not a code-review catch.
 */

export interface Scenario {
  id: string;
  title: string;
  feature: string;
  route: string;
  breadcrumb: string;
  narrative: string;
  shows: string[];
  messages: Message[];
}

interface RawMessage {
  id: string;
  author: MessageAuthor;
  state: MessageState;
  channel: MessageChannel;
  text?: string;
  actions?: MessageAction[];
  createdAt?: string;
}

interface RawScenario {
  id: string;
  title: string;
  feature: string;
  route: string;
  breadcrumb: string;
  narrative: string;
  shows: string[];
  messages: RawMessage[];
}

// test/fixtures/ → ../../../../ = the voice-kit repo root.
const FIXTURE = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../../../fixtures/scenarios.json",
);

export function loadScenarios(): Scenario[] {
  const { scenarios } = JSON.parse(readFileSync(FIXTURE, "utf8")) as {
    scenarios: RawScenario[];
  };
  return scenarios.map((s) => ({
    ...s,
    messages: s.messages.map(
      (m) =>
        new Message({
          id: m.id,
          author: m.author,
          state: m.state,
          channel: m.channel,
          text: m.text,
          actions: m.actions ?? [],
          createdAt: m.createdAt ? new Date(m.createdAt) : undefined,
        }),
    ),
  }));
}

export const scenarios: Scenario[] = loadScenarios();
