/// The message model — the core of the conversation surface
/// (docs/conversation-surface.md §3–§5). Pure Dart, zero dependencies. Every
/// item in the stream is a [Message]; its [author] (provenance) and [state]
/// carry the trust rules that keep a private note from ever reaching a contact.

/// Who authored a message — the provenance. Set at creation and **never
/// changed** ([Message.copyWith] cannot alter it): "the agent said X to the
/// customer" and "the agent told me X" are different messages, forever (§4).
enum MessageAuthor {
  /// The other human in the thread (inbound).
  contact,

  /// The host's user (outbound, human-authored).
  operator,

  /// The agent speaking AS THE BUSINESS, to the contact.
  agentPublic,

  /// The agent speaking PRIVATELY, to the operator.
  agentAdvisor,

  /// The surface itself (status, lifecycle).
  system;

  /// Agent-authored (public reply or private advisor).
  bool get isAgent => this == agentPublic || this == agentAdvisor;

  /// Private to the operator — has **no transport path** to a contact.
  bool get isPrivate => this == agentAdvisor || this == system;
}

/// The delivery lifecycle of a message.
enum MessageState {
  /// Composed, not sent.
  draft,

  /// A public-agent reply awaiting the operator's yes.
  pendingApproval,

  /// Handed to transport.
  sent,

  /// Confirmed delivered.
  delivered,

  /// Read by the recipient.
  read,

  /// Delivery failed.
  failed,

  /// Never leaves the surface (advisor notes, system events).
  internal,
}

/// The channel a message belongs to. `voice` carries a transcript; `none` is
/// surface-only. Channel-specific fields (email subject/cc, social reactions)
/// ride in [Message.channelMeta], never the core.
enum MessageChannel { sms, email, chat, voice, none }

/// Inline affordances a renderer may offer on a message (§5). `refine` = the
/// agent rewrites; `review` = the agent annotates the operator's own draft;
/// `openWith` = hand off to the native client (interoperability, §8).
enum MessageAction {
  approve,
  refine,
  review,
  edit,
  reword,
  shorten,
  rephrase,
  send,
  speak,
  dismiss,
  openWith,

  /// Navigate the app to a surface — "take you there" (§9). The message's
  /// deeplink path (in [Message.channelMeta] `'route'`) is resolved by the host.
  takeMeThere,
}

/// A directive view carried inline by a message — dynamic UI resolved by the
/// renderer's view registry (§7). The core keeps it minimal on purpose.
class MessageView {
  const MessageView({required this.viewId, this.data = const {}});

  final String viewId;
  final Map<String, Object?> data;
}

/// One item in the conversation stream. Immutable. The provenance/approval
/// guarantees (§4) are enforced here, in the model and its transitions — not in
/// styling — so a rendering bug can never become a disclosure bug.
class Message {
  Message({
    required this.id,
    required this.author,
    required this.state,
    required this.channel,
    this.text,
    this.view,
    this.audioUrl,
    this.actions = const [],
    this.replyToId,
    this.channelMeta = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final MessageAuthor author;
  final MessageState state;
  final MessageChannel channel;
  final String? text;
  final MessageView? view;

  /// Optional audio for the voice modality (§9).
  final String? audioUrl;
  final List<MessageAction> actions;
  final String? replyToId;

  /// Channel-specific extras (email subject/cc, etc.) — kept out of the core.
  final Map<String, Object?> channelMeta;
  final DateTime createdAt;

  /// Private notes + system events never leave the surface.
  bool get isInternal => author.isPrivate || state == MessageState.internal;

  /// A public-agent reply awaiting the operator's yes.
  bool get requiresApproval =>
      author == MessageAuthor.agentPublic &&
      state == MessageState.pendingApproval;

  /// Whether a transport layer is permitted to send this message to the contact.
  /// **The final safety gate:** only a `sent` message from a non-private author
  /// (contact / operator / public agent) may transmit. Advisor and system
  /// messages never can; drafts and pending replies never can.
  bool get canTransmit =>
      !author.isPrivate && state == MessageState.sent;

  /// The one blessed path from `pendingApproval` → `sent` for a public-agent
  /// reply. Built directly (not via [copyWith]) so approval is the only route to
  /// a sent agent message. Misuse is a programming error, not a silent no-op.
  Message approve() {
    if (!requiresApproval) {
      throw StateError(
          'approve() only applies to a pending public-agent reply');
    }
    return Message(
      id: id,
      author: author,
      state: MessageState.sent,
      channel: channel,
      text: text,
      view: view,
      audioUrl: audioUrl,
      actions: actions,
      replyToId: replyToId,
      channelMeta: channelMeta,
      createdAt: createdAt,
    );
  }

  /// State/content transitions. `author` is intentionally **not** a parameter —
  /// provenance is immutable (§4). A public-agent reply may not be moved to
  /// `sent` here; it must go through [approve] (enforced in release, not just an
  /// assert), so the approval step can never be bypassed.
  Message copyWith({
    MessageState? state,
    String? text,
    MessageView? view,
    List<MessageAction>? actions,
  }) {
    final next = state ?? this.state;
    if (author == MessageAuthor.agentPublic &&
        next == MessageState.sent &&
        this.state != MessageState.sent) {
      throw StateError('A public-agent reply must reach "sent" via approve()');
    }
    return Message(
      id: id,
      author: author,
      state: next,
      channel: channel,
      text: text ?? this.text,
      view: view ?? this.view,
      audioUrl: audioUrl,
      actions: actions ?? this.actions,
      replyToId: replyToId,
      channelMeta: channelMeta,
      createdAt: createdAt,
    );
  }
}
