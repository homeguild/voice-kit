# @homeguild/conversation-kit

**The conversation surface — React port.** The agentic layer over any threaded
conversation (SMS · voice · email · social · agent chat): one stream of typed
`Message`s rendered by a trust-aware taxonomy — party bubbles, agent replies,
private advisor asides, directive views, and system events — with inline actions
like approve / edit / dismiss.

> **Proprietary and confidential.** © 2026 HomeGuild Labs. All rights reserved.
> Not open source; do not distribute. See [LICENSE](../../LICENSE).

One protocol, **two ports** (Flutter + React), kept behaviourally identical and
proven equal by shared fixtures. This is the React port; the Flutter port lives
in `packages/flutter/homeguild_voice_kit`.

## The trust model (why this isn't just a chat UI)

Provenance and approval are enforced in the model, not the styling — so a
rendering bug can never become a disclosure bug:

- **Provenance is immutable.** A message's author (`contact` · `operator` ·
  `agentPublic` · `agentAdvisor` · `system`) is set at creation and never changes.
- **Private authors never transmit.** `agentAdvisor` and `system` messages have
  no transport path to a contact, in any state.
- **A public-agent reply reaches `sent` only via `approve()`.** The agent can
  draft as the business, but nothing goes out until the operator says yes.

## Install

Private package on GitHub Packages. In the consuming repo, map the scope (token
via `${NODE_AUTH_TOKEN}`, never committed):

```
# .npmrc
@homeguild:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}
```

```bash
npm install @homeguild/conversation-kit
```

The package ships TypeScript source — consumers transpile it (e.g. Next.js
`transpilePackages: ['@homeguild/conversation-kit']`).

## Usage

```tsx
import { ConversationStream, Message } from "@homeguild/conversation-kit";

const messages = [
  new Message({ id: "1", author: "contact", state: "sent", channel: "sms",
    text: "Do you do weekend callouts?" }),
  new Message({ id: "2", author: "agentPublic", state: "pendingApproval",
    channel: "sms", text: "I can book you 3–5pm today. Want me to?",
    actions: ["approve", "edit", "dismiss"] }),
];

<ConversationStream
  messages={messages}
  viewpoint="operator"                 // operator's inbox: agent replies land outbound
  onAction={(m, action) => { /* approve/edit/dismiss a draft, etc. */ }}
/>;
```

Dynamic content (call cards, email summaries, review cards) is host-provided via
a `viewRegistry` keyed by `view.viewId`; colours come from an injectable
`ConversationTheme`. The composer is intentionally not included — the host wraps
the stream with its own.

## Development

```bash
npm test              # vitest: model invariants + render conformance
npm run typecheck     # tsc --noEmit
npm run test:visual   # Playwright visual goldens (shared scenario fixtures)
```

Scenarios live in `fixtures/scenarios.json` (repo root) and drive both ports'
tests — see `PUBLISHING.md` for the release flow and the north-star design doc
`docs/conversation-surface.md`.
