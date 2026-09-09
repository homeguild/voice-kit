import { describe, expect, it } from "vitest";

import {
  applyFrame,
  cassetteById,
  cassetteToSse,
  chatCassette,
  eventCassette,
  initialTurn,
  type AgentFrame,
} from "../src/index";

/** Parse an SSE body the way the client's readSse does, back into frames. */
function parseSse(sse: string): AgentFrame[] {
  return sse
    .split("\n\n")
    .map((chunk) => chunk.replace(/^data:\s?/, "").trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line) as AgentFrame);
}

describe("mock agent transport", () => {
  it("serializes a cassette to SSE that folds to the SAME shell as the raw frames", () => {
    const c = cassetteById("form");
    const fromWire = parseSse(cassetteToSse(c)).reduce(applyFrame, initialTurn);
    const direct = c.frames.reduce(applyFrame, initialTurn);
    // The client can't tell the mock replay from the real transport.
    expect(fromWire.shell.panel.map((s) => s.view.viewId)).toEqual(
      direct.shell.panel.map((s) => s.view.viewId),
    );
    expect(fromWire.shell.messages.map((m) => m.text)).toEqual(
      direct.shell.messages.map((m) => m.text),
    );
  });

  it("resolves a /chat message to its cassette (exact, then loose)", () => {
    expect(chatCassette("help me get set up")?.id).toBe("form");
    expect(chatCassette("hey, help me get set up please")?.id).toBe("form");
    expect(chatCassette("")).toBeUndefined();
  });

  it("resolves a view_event to the branch cassette by window + event", () => {
    // form's show_view opens window "form_golden"; submitted → form_ack.
    expect(eventCassette("form_golden", "submitted")?.id).toBe("form_ack");
    // confirmation opens "confirm_del"; cancelled → confirmation_declined.
    expect(eventCassette("confirm_del", "cancelled")?.id).toBe("confirmation_declined");
    // an unscripted window/branch is undefined.
    expect(eventCassette("nope", "submitted")).toBeUndefined();
  });
});
