/**
 * The message model — the core of the conversation surface
 * (docs/conversation-surface.md §3–§5). The React port of `message.dart`; the
 * two are kept behaviourally identical. Every item in the stream is a
 * {@link Message}; its {@link MessageAuthor} (provenance) and {@link MessageState}
 * carry the trust rules that keep a private note from ever reaching a contact.
 */

/**
 * Who authored a message — the provenance. Set at creation and **never changed**
 * ({@link Message.copyWith} cannot alter it): "the agent said X to the customer"
 * and "the agent told me X" are different messages, forever (§4).
 *
 * - `contact` — the other human in the thread (inbound).
 * - `operator` — the host's user (outbound, human-authored).
 * - `agentPublic` — the agent speaking AS THE BUSINESS, to the contact.
 * - `agentAdvisor` — the agent speaking PRIVATELY, to the operator.
 * - `system` — the surface itself (status, lifecycle).
 */
export type MessageAuthor =
  | "contact"
  | "operator"
  | "agentPublic"
  | "agentAdvisor"
  | "system";

/** Agent-authored (public reply or private advisor). */
export const isAgentAuthor = (a: MessageAuthor): boolean =>
  a === "agentPublic" || a === "agentAdvisor";

/** Private to the operator — has **no transport path** to a contact. */
export const isPrivateAuthor = (a: MessageAuthor): boolean =>
  a === "agentAdvisor" || a === "system";

/** The delivery lifecycle of a message. */
export type MessageState =
  | "draft"
  | "pendingApproval"
  | "sent"
  | "delivered"
  | "read"
  | "failed"
  | "internal";

/**
 * The channel a message belongs to. `voice` carries a transcript; `none` is
 * surface-only. Channel-specific fields (email subject/cc, social reactions)
 * ride in {@link Message.channelMeta}, never the core.
 */
export type MessageChannel = "sms" | "email" | "chat" | "voice" | "none";

/**
 * Inline affordances a renderer may offer on a message (§5). `refine` = the
 * agent rewrites; `review` = the agent annotates the operator's own draft;
 * `openWith` = hand off to the native client (interoperability, §8);
 * `takeMeThere` = navigate the app to a surface (§9).
 */
export type MessageAction =
  | "approve"
  | "refine"
  | "review"
  | "edit"
  | "reword"
  | "shorten"
  | "rephrase"
  | "send"
  | "speak"
  | "dismiss"
  | "openWith"
  | "takeMeThere";

/**
 * A directive view carried inline by a message — dynamic UI resolved by the
 * renderer's view registry (§7). The core keeps it minimal on purpose.
 */
export interface MessageView {
  readonly viewId: string;
  readonly data: Readonly<Record<string, unknown>>;
}

export interface MessageProps {
  id: string;
  author: MessageAuthor;
  state: MessageState;
  channel: MessageChannel;
  text?: string;
  view?: MessageView;
  audioUrl?: string;
  actions?: readonly MessageAction[];
  replyToId?: string;
  channelMeta?: Readonly<Record<string, unknown>>;
  createdAt?: Date;
}

/**
 * One item in the conversation stream. Immutable. The provenance/approval
 * guarantees (§4) are enforced here, in the model and its transitions — not in
 * styling — so a rendering bug can never become a disclosure bug.
 */
export class Message {
  readonly id: string;
  readonly author: MessageAuthor;
  readonly state: MessageState;
  readonly channel: MessageChannel;
  readonly text?: string;
  readonly view?: MessageView;
  /** Optional audio for the voice modality (§10). */
  readonly audioUrl?: string;
  readonly actions: readonly MessageAction[];
  readonly replyToId?: string;
  /** Channel-specific extras (email subject/cc, etc.) — kept out of the core. */
  readonly channelMeta: Readonly<Record<string, unknown>>;
  readonly createdAt: Date;

  constructor(p: MessageProps) {
    this.id = p.id;
    this.author = p.author;
    this.state = p.state;
    this.channel = p.channel;
    this.text = p.text;
    this.view = p.view;
    this.audioUrl = p.audioUrl;
    this.actions = p.actions ?? [];
    this.replyToId = p.replyToId;
    this.channelMeta = p.channelMeta ?? {};
    this.createdAt = p.createdAt ?? new Date();
  }

  /** Private notes + system events never leave the surface. */
  get isInternal(): boolean {
    return isPrivateAuthor(this.author) || this.state === "internal";
  }

  /** A public-agent reply awaiting the operator's yes. */
  get requiresApproval(): boolean {
    return this.author === "agentPublic" && this.state === "pendingApproval";
  }

  /**
   * Whether a transport layer is permitted to send this message to the contact.
   * **The final safety gate:** only a `sent` message from a non-private author
   * (contact / operator / public agent) may transmit. Advisor and system
   * messages never can; drafts and pending replies never can.
   */
  get canTransmit(): boolean {
    return !isPrivateAuthor(this.author) && this.state === "sent";
  }

  /**
   * The one blessed path from `pendingApproval` → `sent` for a public-agent
   * reply. Built directly (not via {@link copyWith}) so approval is the only
   * route to a sent agent message. Misuse is a programming error, not a
   * silent no-op.
   */
  approve(): Message {
    if (!this.requiresApproval) {
      throw new Error("approve() only applies to a pending public-agent reply");
    }
    return new Message({
      id: this.id,
      author: this.author,
      state: "sent",
      channel: this.channel,
      text: this.text,
      view: this.view,
      audioUrl: this.audioUrl,
      actions: this.actions,
      replyToId: this.replyToId,
      channelMeta: this.channelMeta,
      createdAt: this.createdAt,
    });
  }

  /**
   * State/content transitions. `author` is intentionally **not** a parameter —
   * provenance is immutable (§4). A public-agent reply may not be moved to
   * `sent` here; it must go through {@link approve} (enforced, not just a
   * lint), so the approval step can never be bypassed.
   */
  copyWith(changes: {
    state?: MessageState;
    text?: string;
    view?: MessageView;
    actions?: readonly MessageAction[];
  }): Message {
    const next = changes.state ?? this.state;
    if (
      this.author === "agentPublic" &&
      next === "sent" &&
      this.state !== "sent"
    ) {
      throw new Error('A public-agent reply must reach "sent" via approve()');
    }
    return new Message({
      id: this.id,
      author: this.author,
      state: next,
      channel: this.channel,
      text: changes.text ?? this.text,
      view: changes.view ?? this.view,
      audioUrl: this.audioUrl,
      actions: changes.actions ?? this.actions,
      replyToId: this.replyToId,
      channelMeta: this.channelMeta,
      createdAt: this.createdAt,
    });
  }
}
