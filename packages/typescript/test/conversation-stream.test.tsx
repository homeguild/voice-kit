import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { ConversationStream } from "../src/conversation-stream.js";
import { Message } from "../src/message.js";

/**
 * Render conformance: the React stream must surface the same taxonomy signals as
 * the Flutter widget (the AGENT tag, the draft-approval card, the advisor aside,
 * a centered system line) for the same Messages. Rendered to static markup so no
 * DOM is needed.
 */
describe("ConversationStream — taxonomy render (operator viewpoint)", () => {
  const html = renderToStaticMarkup(
    <ConversationStream
      viewpoint="operator"
      onAction={() => {}}
      messages={[
        new Message({ id: "1", author: "contact", state: "sent", channel: "sms", text: "Do you work weekends?" }),
        new Message({ id: "2", author: "operator", state: "sent", channel: "sms", text: "We do — emergencies only." }),
        new Message({ id: "3", author: "agentPublic", state: "sent", channel: "sms", text: "Booked you for 3pm." }),
        new Message({ id: "4", author: "agentPublic", state: "pendingApproval", channel: "sms", text: "Want me to book Monday?" }),
        new Message({ id: "5", author: "agentAdvisor", state: "internal", channel: "none", text: "This caller reached out 3 times." }),
        new Message({ id: "6", author: "system", state: "internal", channel: "none", text: "Missed call · 2:14 PM" }),
      ]}
    />,
  );

  it("marks a sent public-agent reply as AGENT (outbound)", () => {
    expect(html).toContain("AGENT");
    expect(html).toContain("Booked you for 3pm.");
  });

  it("renders the draft-approval card with its actions", () => {
    expect(html).toContain("DRAFT REPLY · NEEDS YOUR YES");
    expect(html).toContain("Approve");
    expect(html).toContain("Edit");
  });

  it("renders the advisor aside, unmistakably private", () => {
    expect(html).toContain("ONLY YOU SEE THIS");
    expect(html).not.toContain("Send"); // an advisor note is never sendable
  });

  it("renders a system event as a quiet line", () => {
    expect(html).toContain("Missed call · 2:14 PM");
  });

  it("resolves a directive view through the registry", () => {
    const out = renderToStaticMarkup(
      <ConversationStream
        messages={[
          new Message({
            id: "v",
            author: "agentAdvisor",
            state: "internal",
            channel: "email",
            view: { viewId: "summary", data: { gist: "wants a quote" } },
          }),
        ]}
        viewRegistry={{ summary: (v) => <div>SUMMARY: {String(v.data.gist)}</div> }}
      />,
    );
    expect(out).toContain("SUMMARY: wants a quote");
  });
});
