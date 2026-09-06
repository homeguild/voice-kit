import type { ReactNode } from "react";
import {
  isPrivateAuthor,
  type Message,
  type MessageAction,
  type MessageView,
} from "./message.js";

/**
 * The conversation surface — a stream of {@link Message}s rendered by the
 * taxonomy (party / agent reply / advisor aside / directive view / system) with
 * inline actions. The React port of `conversation_stream.dart`; the two render
 * the same states the same way (proven by the shared scenario fixtures).
 *
 * Host-agnostic: styling comes from {@link ConversationTheme}, dynamic content
 * from {@link ConversationStreamProps.viewRegistry}, and every action is
 * dispatched back through {@link ConversationStreamProps.onAction}. The composer
 * is intentionally NOT here — the host wraps the stream with its own.
 */

/** Whose side the surface renders from — decides which side the public agent
 *  lands on (operator's inbox → agent is outbound/right; talking-to-the-agent
 *  → the agent is the other party/left). */
export type ConversationViewpoint = "contact" | "operator";

/** The host's view registry: `viewId` → a native component (§7). */
export type MessageViewBuilder = (view: MessageView) => ReactNode;

/** An optional caption under a message (timestamp, delivery state, …), aligned
 *  to the message's side. Return null to render none. */
export type MessageCaptionBuilder = (message: Message) => ReactNode | null;

/** Injectable colours so the stream wears the host's design system. */
export interface ConversationTheme {
  contactBubble: string;
  contactText: string;
  operatorBubble: string;
  operatorText: string;
  /** The bubble behind an agent-sent reply when it renders OUTBOUND (operator
   *  viewpoint) — accented to mark it agent-authored. */
  agentBubble: string;
  /** The agent's text colour (left-aligned line + the outbound bubble). */
  agentText: string;
  /** The private advisor voice — visually unmistakable from anything sendable. */
  advisorText: string;
  systemText: string;
  /** The border on a draft reply awaiting approval. */
  draftBorder: string;
  surface: string;
}

/** A neutral default; a host overrides any field. */
export const defaultTheme: ConversationTheme = {
  contactBubble: "#eaeaea",
  contactText: "#111827",
  operatorBubble: "#1e3a8a",
  operatorText: "#ffffff",
  agentBubble: "rgba(180,140,40,0.16)",
  agentText: "#7a5c12",
  advisorText: "#7a5c12",
  systemText: "#6b7280",
  draftBorder: "#c9a94a",
  surface: "#faf7f0",
};

const ACTION_LABELS: Record<MessageAction, string> = {
  approve: "Approve",
  refine: "Refine",
  review: "Review",
  edit: "Edit",
  reword: "Reword",
  shorten: "Shorten",
  rephrase: "Rephrase",
  send: "Send",
  speak: "Say it",
  dismiss: "Dismiss",
  openWith: "Open with…",
  takeMeThere: "Take me there",
};

export interface ConversationStreamProps {
  messages: readonly Message[];
  onAction?: (message: Message, action: MessageAction) => void;
  viewRegistry?: Record<string, MessageViewBuilder>;
  captionBuilder?: MessageCaptionBuilder;
  theme?: ConversationTheme;
  viewpoint?: ConversationViewpoint;
}

export function ConversationStream({
  messages,
  onAction,
  viewRegistry = {},
  captionBuilder,
  theme = defaultTheme,
  viewpoint = "contact",
}: ConversationStreamProps) {
  return (
    <div style={{ display: "flex", flexDirection: "column", padding: "16px" }}>
      {messages.map((m, i) => {
        const caption = captionBuilder?.(m) ?? null;
        // Caption aligns to the message's side (outbound right, else left); from
        // the operator's viewpoint the public agent is outbound too.
        const right =
          m.author === "operator" ||
          (m.author === "agentPublic" && viewpoint === "operator");
        return (
          <div key={m.id || i}>
            <MessageTile
              message={m}
              theme={theme}
              viewpoint={viewpoint}
              onAction={onAction}
              viewRegistry={viewRegistry}
            />
            {caption && (
              <div
                style={{
                  display: "flex",
                  justifyContent: right ? "flex-end" : "flex-start",
                  color: theme.systemText,
                  fontSize: 11,
                  marginBottom: 8,
                }}
              >
                {caption}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function MessageTile({
  message: m,
  theme,
  viewpoint,
  onAction,
  viewRegistry,
}: {
  message: Message;
  theme: ConversationTheme;
  viewpoint: ConversationViewpoint;
  onAction?: (message: Message, action: MessageAction) => void;
  viewRegistry: Record<string, MessageViewBuilder>;
}) {
  // A directive view renders as its own inline component (§7).
  if (m.view) {
    const builder = viewRegistry[m.view.viewId];
    return (
      <div style={{ marginBottom: 10 }}>
        {builder ? builder(m.view) : <FallbackView theme={theme} view={m.view} />}
      </div>
    );
  }

  const agentOutbound = viewpoint === "operator";

  switch (m.author) {
    case "contact":
      return <Bubble alignEnd={false} bg={theme.contactBubble} fg={theme.contactText} text={m.text} />;
    case "operator":
      return <Bubble alignEnd bg={theme.operatorBubble} fg={theme.operatorText} text={m.text} />;
    case "agentPublic":
      if (m.state === "pendingApproval") {
        return <DraftReply message={m} theme={theme} agentOutbound={agentOutbound} onAction={onAction} />;
      }
      // A sent public reply: outbound bubble (operator inbox) or the agent line.
      return agentOutbound ? (
        <AgentBubble text={m.text} theme={theme} />
      ) : (
        <AgentLine text={m.text} color={theme.agentText} />
      );
    case "agentAdvisor":
      return <AdvisorAside message={m} theme={theme} onAction={onAction} />;
    case "system":
      return <SystemLine text={m.text} color={theme.systemText} />;
  }
}

function Bubble({
  alignEnd,
  bg,
  fg,
  text,
}: {
  alignEnd: boolean;
  bg: string;
  fg: string;
  text?: string;
}) {
  if (!text) return null;
  return (
    <div style={{ display: "flex", justifyContent: alignEnd ? "flex-end" : "flex-start" }}>
      <div
        style={{
          maxWidth: "78%",
          margin: "0 0 10px 0",
          padding: "10px 14px",
          background: bg,
          color: fg,
          borderRadius: 14,
        }}
      >
        {text}
      </div>
    </div>
  );
}

/** Agent speaking as the business, OUTBOUND (operator viewpoint): a right bubble
 *  on the agent accent, tagged so it's unmistakably the agent's voice. */
function AgentBubble({ text, theme }: { text?: string; theme: ConversationTheme }) {
  if (!text) return null;
  return (
    <div style={{ display: "flex", justifyContent: "flex-end" }}>
      <div
        style={{
          maxWidth: "78%",
          margin: "0 0 10px 0",
          padding: "8px 14px 10px",
          background: theme.agentBubble,
          color: theme.agentText,
          borderRadius: 14,
        }}
      >
        <div style={{ fontSize: 9, letterSpacing: 1, fontWeight: 600, opacity: 0.6 }}>
          AGENT
        </div>
        <div style={{ marginTop: 2 }}>{text}</div>
      </div>
    </div>
  );
}

function AgentLine({ text, color }: { text?: string; color: string }) {
  if (!text) return null;
  return (
    <div style={{ margin: "0 32px 10px 0", color, lineHeight: 1.45 }}>{text}</div>
  );
}

/** The private advisor voice — unmistakably aside, never sendable. */
function AdvisorAside({
  message: m,
  theme,
  onAction,
}: {
  message: Message;
  theme: ConversationTheme;
  onAction?: (message: Message, action: MessageAction) => void;
}) {
  return (
    <div
      style={{
        margin: "0 24px 10px 0",
        padding: "8px 12px",
        borderLeft: `2px solid ${theme.advisorText}80`,
      }}
    >
      <div style={{ color: theme.advisorText, fontSize: 10, letterSpacing: 1, fontWeight: 600 }}>
        ONLY YOU SEE THIS
      </div>
      {m.text && (
        <div style={{ color: theme.advisorText, fontStyle: "italic", lineHeight: 1.4, marginTop: 2 }}>
          {m.text}
        </div>
      )}
      <Actions message={m} onAction={onAction} />
    </div>
  );
}

/** A public-agent reply awaiting the operator's yes (inline approval). Aligned
 *  to the side the sent reply would land on. */
function DraftReply({
  message: m,
  theme,
  agentOutbound,
  onAction,
}: {
  message: Message;
  theme: ConversationTheme;
  agentOutbound: boolean;
  onAction?: (message: Message, action: MessageAction) => void;
}) {
  return (
    <div style={{ display: "flex", justifyContent: agentOutbound ? "flex-end" : "flex-start" }}>
      <div
        style={{
          maxWidth: "82%",
          margin: "0 0 10px 0",
          padding: "10px 14px 8px",
          background: theme.surface,
          border: `1px solid ${theme.draftBorder}`,
          borderRadius: 14,
        }}
      >
        <div style={{ color: theme.systemText, fontSize: 10, letterSpacing: 1, fontWeight: 600 }}>
          DRAFT REPLY · NEEDS YOUR YES
        </div>
        <div style={{ color: theme.agentText, marginTop: 4 }}>{m.text}</div>
        <Actions
          message={m}
          onAction={onAction}
          fallback={["approve", "refine", "edit"]}
        />
      </div>
    </div>
  );
}

function SystemLine({ text, color }: { text?: string; color: string }) {
  if (!text) return null;
  return (
    <div style={{ display: "flex", justifyContent: "center", padding: "8px 0" }}>
      <span style={{ color, fontSize: 12 }}>{text}</span>
    </div>
  );
}

function Actions({
  message: m,
  onAction,
  fallback = [],
}: {
  message: Message;
  onAction?: (message: Message, action: MessageAction) => void;
  fallback?: readonly MessageAction[];
}) {
  const actions = m.actions.length > 0 ? m.actions : fallback;
  if (actions.length === 0 || !onAction) return null;
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 4, marginTop: 2 }}>
      {actions.map((a) => (
        <button
          key={a}
          type="button"
          onClick={() => onAction(m, a)}
          style={{
            border: "none",
            background: "transparent",
            color: "inherit",
            font: "inherit",
            cursor: "pointer",
            padding: "2px 10px",
          }}
        >
          {ACTION_LABELS[a]}
        </button>
      ))}
    </div>
  );
}

function FallbackView({ theme, view }: { theme: ConversationTheme; view: MessageView }) {
  return (
    <div style={{ padding: 12, border: `1px solid ${theme.draftBorder}`, borderRadius: 12, color: theme.systemText }}>
      [{view.viewId}]
    </div>
  );
}
