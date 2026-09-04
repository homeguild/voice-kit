# Voice Kit → the Conversation Surface

**Status:** North-star architecture + roadmap. Captures where Voice Kit is
going: from *voice conversation orchestration* to **the agent conversation
surface** — one coherent stream in which human messages, agent messages,
approval-gated drafts, inline assists, and dynamic views all coexist.

Voice Kit is a **standalone project**. It has consumers (production apps that
embed it), but it is not owned by any one of them: the roadmap here is the
library's, and every design choice is made to keep it host-agnostic, backend-
agnostic, and reusable. What follows is the contract those consumers build to.

---

## 1. The charter, expanded

Voice Kit began as a Flutter orchestration layer for voice conversations —
pluggable STT/TTS providers, a state machine, sentence buffering, widgets. That
core stays. The charter grows:

> **Once an agent is a first-class participant, a text thread and an "agent
> conversation" are the same object.** A customer's SMS, the business's reply,
> the agent drafting that reply for approval, the advisor whispering a private
> note, a form the agent renders inline — these are all *messages in one
> stream*. Voice Kit owns that stream: its model, its trust rules, its
> interaction protocol, and its rendering.

Call it the **stream of consciousness of an agent**: a single surface that
carries the conversation, the agent's thinking about it, and the controls to
act on it — rendered natively per platform, driven by any backend.

Voice is not the whole of it anymore; **voice is one modality** of the stream
(speak an utterance in, hear an aside out). The stream is the primary object.

---

## 2. Design principles (non-negotiable)

1. **Host-agnostic.** No consumer app's concepts leak into the core. The kit
   knows *messages, streams, providers, adapters, theme* — never a specific
   product's domain.
2. **Backend-agnostic via adapters.** The kit never speaks HTTP to a named
   service. A `StreamAdapter` (already proven for voice) is the only seam to a
   backend; consumers implement it.
3. **Provider-pluggable.** STT and TTS are interfaces with swappable
   implementations. So are, now, the pieces that turn a stream into audio or
   text.
4. **Theme-injectable.** The kit ships behavior and structure; the host injects
   tokens/styling so the surface wears the host's design system.
5. **Two ports, one protocol, one version.** A Flutter port and a TypeScript/
   React port live in this monorepo, implement one versioned protocol, and
   release in lockstep. Platform-idiomatic inside; contract-identical outside.
   Behavioral equivalence is *proven by shared conformance fixtures*, not
   assumed.
6. **Provenance-safe by construction.** Who authored a message and what state
   it is in are first-class model fields — never inferred from styling. This is
   the property that keeps an agent's private note from ever reaching a
   customer. It is load-bearing (§4).

---

## 3. The message model (the core)

Every item in the stream is a `Message` carrying, at minimum:

- **`author`** — the provenance. One of:
  - `contact` — the other human (inbound).
  - `operator` — the host's user (outbound, human-authored).
  - `agent_public` — the agent speaking **as the business, to the contact**.
  - `agent_advisor` — the agent speaking **privately, to the operator**.
  - `system` — the surface itself (status, lifecycle).
- **`state`** — the lifecycle:
  - `draft` — composed, not sent.
  - `pending_approval` — awaits the operator's yes before it can leave.
  - `sent` / `delivered` / `read` / `failed` — normal delivery states.
  - `internal` — never leaves the surface (advisor notes, system).
- **`channel`** — `sms | email | chat | voice | none` (voice carries a
  transcript; `none` = surface-only).
- **`body`** — text and/or a **view** (§7) and/or an **audio** ref.
- **`actions`** — the inline affordances available on this message (§5).
- ids, timestamps, threading/reply refs.

### The taxonomy that falls out

| Kind | author · state | Meaning |
|------|----------------|---------|
| **Party** | contact/operator · sent | the actual conversation |
| **Agent reply** | agent_public · pending_approval \| sent | the agent answering the contact *on the business's behalf* — gated or auto per host policy |
| **Advisor aside** | agent_advisor · internal | a private note to the operator, in-thread; cannot be sent without an explicit escalation |
| **Assist** | agent_advisor · draft | a transform of the operator's in-progress draft (reword, shorten, refine) |
| **Directive view** | agent_* · any | inline interactive UI (form, confirmation, choice, dynamic card) |
| **System** | system · internal | call started/ended, status, lifecycle |

Everything a host wants — the agent whispering mid-conversation with
approve/refine, "rework what I'm about to send," an approval gate living *inline
in the thread* instead of a separate queue, a rendered form — is a combination
of an `author`, a `state`, and a set of `actions`. No new surface per feature.

The enum is **extensible**: hosts may register additional kinds + renderers
(§7). The core defines the safe baseline.

---

## 4. Provenance & approval — the trust boundary

This is the property that makes "SMS and agent messaging are the same thing"
*safe* rather than dangerous. The rules the kit enforces (not merely styles):

1. **An `agent_public` message can only leave the surface from `sent`, and can
   only reach `sent` through the host's approval policy** — either an explicit
   operator action on a `pending_approval` message, or an auto-send the host has
   opted into. The kit refuses to transmit an unapproved agent message.
2. **`agent_advisor` and `system` messages are `internal` and have no transport
   path.** There is no code path by which an advisor aside is delivered to a
   `contact`. Turning an aside into an outbound message is an *explicit new
   message* the operator authors/approves — never an implicit reclassification.
3. **Provenance is immutable.** A message's `author` is set at creation and
   never mutated. "The agent said X to the customer" and "the agent told me X"
   are different rows, forever.

The renderers make these visually unmistakable (agent-as-business vs. private
advisor vs. your own words), but the *guarantee* lives in the model and the
send path, so a styling bug can never become a disclosure bug.

---

## 5. Inline actions — the interaction protocol

Actions are declared on a message and dispatched back through the adapter. The
baseline set:

- **`approve`** — move a `pending_approval` agent reply to `sent`.
- **`refine`** — ask the agent to *revise* a draft/reply in place (agent
  rewrites; returns a new version of the same message; provenance unchanged).
- **`review`** — ask the agent to *annotate/suggest* on the operator's own draft
  without rewriting it; the operator decides. The defining long-form action
  (§8). Distinct from `refine`.
- **`edit`** — the operator edits the text directly (author becomes `operator`
  if they take it over).
- **`reword` / `shorten` / `rephrase`** — assist transforms on the operator's
  own draft.
- **`send`** — transmit an `operator`/approved message.
- **`speak`** — voice this message aloud (the voice modality, §10).
- **`dismiss`** — drop an aside/suggestion.
- **`takeMeThere`** — navigate the app to a surface (§9). The message's
  deeplink path is resolved by the host — "take you there."

Hosts may add actions; the kit renders declared actions and routes their results
through the same streaming envelope (§6). Refinement is a loop: *refine → new
draft → approve/edit → send.*

---

## 6. The streaming envelope

The backend adapter yields a stream of typed chunks — a superset of today's
`VoiceStreamChunk`:

- `message.start` / `message.delta` / `message.end` — a streaming message
  (carries author + state so the renderer places it correctly *as it streams*).
- `aside` — a completed advisor note.
- `draft` — an agent reply proposed for approval (author `agent_public`, state
  `pending_approval`).
- `directive` — render/patch/dismiss a view (§7).
- `action.result` — the outcome of an inline action.
- `status` — progress / tool activity (spinner-level feedback).
- `done` / `error`.

The envelope is **versioned with the protocol**. Adding a chunk type is a
protocol bump → both ports bump → lockstep release.

---

## 7. Directive views — dynamic content in the stream

Rich, interactive content (forms, confirmations, choices, and open-ended
"dynamic content") renders **inline as messages** via a small, bounded view
schema and a **two-channel** convention: the agent's tool returns a terse status
to the model *and* emits a `directive` chunk carrying the full view to the
surface. Each port keeps a **view registry** mapping `view_id → native
component`; view events post back through the adapter and become the agent's
next input.

This is the home for the agent-driven-UI protocol. It is deliberately a *small
bounded schema with native renderers per port*, not a cross-platform UI runtime
— the same discipline as the rest of the kit. `form`, `confirmation`, and
**`summary`** (a collapse/expand view for long-form bodies — §8) are the
baseline vocabulary; hosts register more.

---

## 8. Channels & the ownership boundary

Back all the way out and the surface isn't "agent messaging" — it's **the
agentic layer over any threaded conversation.** SMS, voice, email, social DMs
are the same object (a thread of authored messages) in different *shapes*. A
**channel** is therefore a thin composition over the core, never a new build:

> **channel = transport adapter + views + actions + an ownership contract.**

The load-bearing part is the **ownership contract** — what the kit handles
inline vs. what it hands off. This is the discipline that keeps "add a channel"
from becoming "build a client":

- **The kit owns the agentic layer** — the high-value work the agent does:
  summarize, draft, revise, **review**, triage (advisor asides), approve, send.
- **The kit delegates commodity depth** — via a first-class **`open_with`
  action**: rich formatting, attachments, folders, search, the full native
  experience open in the user's own client with the draft pre-populated where
  possible. **Interoperability, not reimplementation.**

This is the same philosophy the surrounding product makes elsewhere — *own the
high level, link out for depth.* An email client (or a social client) is a
commodity with flavors; the kit does not compete there. It adds the agentic
layer on top and hands off the rest.

### Worked example — email (long-form)

Email is a channel profile, not a special case:

- **Summary-first.** A long email renders as a `summary` view (§7) by default —
  expand for the full body. Summaries are a baseline view type because they
  recur across every long-form channel (email, long call transcripts, long
  threads), not just email.
- **The composer is an editor.** The composer scales from quick-reply (SMS) to
  **assisted long-form draft** (email), with the agent loop constant. Long-form
  is where the editor earns its keep.
- **`review` vs. `refine`.** *Refine* = the agent rewrites the draft. *Review* =
  the agent annotates/suggests on **the operator's** draft and the operator
  decides. "Review this before I send" is the defining long-form action; both
  ride the same approval/provenance model.
- **Denser advisor.** Email leans harder on `agent_advisor` + drafts than SMS
  does — more agent participation, same structure. A *density* difference, not a
  structural one.
- **Delegate the rest.** `open_with` hands formatting/attachments/etc. to the
  native mail app.

### The discipline that keeps it from becoming a god-object

Abstraction has a failure mode — the core bloating as each channel pushes its
quirks in. Two rules prevent it:

1. **Minimal core; channels extend via registry.** The core `Message` stays
   `{author, state, channel, body, actions}`. Channel specifics — email's
   `subject`/`cc`, social's reactions/public-vs-DM, voice's real-time — live in
   a **`channelMeta` bag + per-channel renderers/actions registered** exactly
   like directive views. The core never learns "email."
2. **The ownership contract is declared per channel and enforced.** `open_with`
   is a first-class action, not a hack; the boundary is documented per channel
   so it can be defended against scope creep.

With these, a new channel is: an adapter + a view/action set + an ownership
policy. Everything else — provenance, approval, advisor, refine/review,
directive views, voice — is reused untouched. *It builds on itself.*

---

## 9. Navigation & deeplinks

Where a message points the user is an **address**, and the address is a
canonical **deeplink path** — scheme/host-agnostic (`/inbox/thread/{id}`), each
port prepending its own (web URL, iOS/Android universal link, Electron scheme).
This is the one primitive behind "take you there": a `takeMeThere` action (or a
`navigate` directive, a sibling of `open_with`) carries the path; the host
resolves it through the router it already has. Because the address is a plain
link, the agent can hand it over **from anywhere** — in-app, a push, an email,
an SMS — not only when embedded.

The kit owns the action/directive + the path convention. **The host owns
resolution:** reconstructing state from params (fine routes), and the gate
(not-logged-in → continue; not-on-plan → *upsell*; unauthorized). The deeplink
table is the host's surface registry — not a separate thing. Same practice
across the product: see `docs/scenario-driven-development.md` (§4).

---

## 10. Voice as a modality

The existing pieces — `STTProvider`, `TTSProvider`, `VoiceConversationManager`,
the voice widgets — are re-seated as **one input/output modality of the stream**:

- **In:** an STT provider turns an utterance into a `contact`/`operator` message
  entering the stream (transcript as `body`, `channel: voice`).
- **Out:** the `speak` action / a TTS provider voices any message — most
  powerfully an **advisor aside spoken mid-thread** (the private whisper), which
  is exactly the call-time "counsel" experience generalized to every channel.

Voice keeps its own providers and manager; it simply becomes a mode the stream
can be driven by and rendered to, rather than a separate product.

---

## 11. Repo shape & the versioning discipline

```
voice-kit/
├── docs/                     # protocol spec + this vision (the contract)
├── fixtures/                 # shared conformance fixtures (streams → expected behavior)
├── packages/
│   ├── flutter/              # the Flutter port
│   └── typescript/           # the React/TS port
└── example/                  # runnable demos per port
```

- **One protocol, defined once** (in `docs/` + machine-readable fixtures),
  implemented by both ports.
- **Shared conformance fixtures** — a golden corpus of input streams and
  expected surface behavior that *both* ports run as tests. This is what makes
  "versioned together" mean *behaviorally equivalent*, not just co-released.
- **Version = protocol version.** A protocol change bumps both ports; ports
  release in lockstep at the same version.
- **Adapters + theme are the only host seams.** A host provides a
  `StreamAdapter` (backend), provider implementations (STT/TTS or others), a
  view registry (custom views), and a theme. Nothing else.

Keep the **core small** (model + stream + protocol + baseline widgets). Product
specifics live in adapters, providers, custom views, and theme — never the core.

---

## 12. Roadmap (supersedes the README stub)

**Now — foundation**
- [ ] Extract the message model + provenance/state + approval rules into the
      core (Flutter port first; it has production users).
- [ ] Extend the streaming envelope to the full chunk set (§6).
- [ ] Stand up the `fixtures/` corpus + a conformance runner in the Flutter
      port.

**Next — the surface**
- [ ] The stream widget: renders party / agent-reply / aside / assist / system,
      with inline actions and streaming placement by author+state.
- [ ] Directive views in the stream (view registry + `form`/`confirmation`).
- [ ] Voice re-seated as a modality (speak-an-aside; utterance-in).

**Then — the second port**
- [ ] The TypeScript/React port implementing the same protocol against the same
      fixtures.
- [ ] Publish both (`homeguild_voice_kit`, `@homeguild/voice-kit`) at a shared
      version.

**Providers & adapters (parallel, ongoing)**
- [ ] Additional STT/TTS providers (Google, ElevenLabs, native fallback).
- [ ] Reference `StreamAdapter`s (SSE, WebSocket) hosts can start from.

---

## 13. Open decisions

- **Naming.** The scope now exceeds "voice." Does the project stay **Voice
  Kit** (voice as its origin + a headline modality) or become **Conversation
  Kit** (voice a modality within it)? The package ids (`homeguild_voice_kit`,
  `@homeguild/voice-kit`) and the existing users argue for keeping the name and
  expanding the charter; revisit before the first non-Flutter release.
- **Fixture format.** JSON stream transcripts + declarative expectations is the
  likely shape; pin it when the conformance runner lands.
- **Approval policy surface.** How much of "auto-send vs. gate" is host policy
  passed in vs. modeled in the kit. Lean: host policy in, kit enforces the
  guarantee.

---

Built by [HomeGuild Labs](https://www.homeguild.ai/labs). Voice Kit is extracted
from a production voice + messaging platform and developed in the open as a
standalone library.
