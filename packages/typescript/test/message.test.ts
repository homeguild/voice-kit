import { describe, expect, it } from "vitest";
import { Message } from "../src/message.js";

/**
 * The trust invariants, ported 1:1 from the Flutter `message_test.dart` — the
 * two ports must agree on provenance + approval. If a rule changes here it must
 * change there (and in docs/conversation-surface.md §4).
 */
describe("Message — provenance & approval invariants", () => {
  const draft = new Message({
    id: "1",
    author: "agentPublic",
    state: "pendingApproval",
    channel: "sms",
    text: "Want me to book you Monday?",
  });

  it("only a sent, non-private message may transmit", () => {
    expect(draft.canTransmit).toBe(false); // pending
    expect(
      new Message({ id: "a", author: "agentAdvisor", state: "sent", channel: "none" })
        .canTransmit,
    ).toBe(false); // private author, even if 'sent'
    expect(
      new Message({ id: "s", author: "system", state: "sent", channel: "none" })
        .canTransmit,
    ).toBe(false);
    expect(
      new Message({ id: "o", author: "operator", state: "sent", channel: "sms" })
        .canTransmit,
    ).toBe(true);
  });

  it("requiresApproval only for a pending public-agent reply", () => {
    expect(draft.requiresApproval).toBe(true);
    expect(
      new Message({ id: "x", author: "operator", state: "pendingApproval", channel: "sms" })
        .requiresApproval,
    ).toBe(false);
  });

  it("approve() moves pendingApproval → sent, keeping provenance", () => {
    const sent = draft.approve();
    expect(sent.state).toBe("sent");
    expect(sent.author).toBe("agentPublic");
    expect(sent.canTransmit).toBe(true);
    expect(sent.id).toBe(draft.id);
  });

  it("approve() throws when it isn't a pending public-agent reply", () => {
    const sent = draft.approve();
    expect(() => sent.approve()).toThrow(); // already sent
    expect(() =>
      new Message({ id: "o", author: "operator", state: "draft", channel: "sms" }).approve(),
    ).toThrow();
  });

  it("copyWith cannot shortcut a public-agent reply to sent", () => {
    expect(() => draft.copyWith({ state: "sent" })).toThrow();
  });

  it("copyWith cannot change author — provenance is immutable", () => {
    const edited = draft.copyWith({ text: "edited" });
    expect(edited.author).toBe("agentPublic");
    // No `author` parameter exists on copyWith (compile-time), and the value is
    // preserved across a content edit.
    expect(edited.text).toBe("edited");
    expect(edited.state).toBe("pendingApproval");
  });

  it("advisor and system messages are internal", () => {
    expect(
      new Message({ id: "a", author: "agentAdvisor", state: "internal", channel: "none" })
        .isInternal,
    ).toBe(true);
    expect(
      new Message({ id: "s", author: "system", state: "sent", channel: "none" }).isInternal,
    ).toBe(true);
    expect(
      new Message({ id: "c", author: "contact", state: "sent", channel: "sms" }).isInternal,
    ).toBe(false);
  });

  it("copyWith allows non-agentPublic state transitions", () => {
    const op = new Message({ id: "o", author: "operator", state: "draft", channel: "sms" });
    expect(op.copyWith({ state: "sent" }).state).toBe("sent"); // operator may send directly
  });
});
