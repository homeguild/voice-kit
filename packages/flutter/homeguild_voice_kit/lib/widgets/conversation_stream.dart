import 'package:flutter/material.dart';

import '../src/conversation/message.dart';

/// Renders a directive view ([MessageView]) inline — the host's view registry
/// maps `viewId` → a native widget (docs/conversation-surface.md §7).
typedef MessageViewBuilder = Widget Function(BuildContext context, MessageView view);

/// An optional caption rendered under a message (timestamp, delivery state, …),
/// aligned to the message's side. Return null to render none. Kept general: the
/// kit doesn't know about "timestamps"; the host reads what it needs from the
/// [Message] (e.g. `channelMeta['timeLabel']`).
typedef MessageCaptionBuilder = Widget? Function(BuildContext context, Message message);

/// Whose side the surface is rendered from — because it decides which side the
/// **public agent** lands on. In an operator's inbox thread the agent's messages
/// are OUTBOUND (the business replying to the contact → right). In a "talking to
/// the agent" surface (the agent is the *other* party, e.g. the marketing chat)
/// they render as the agent → left. Advisor asides and system lines are
/// unaffected (always private/centered).
enum ConversationViewpoint { contact, operator }

/// Injectable styling so the stream wears the host's design system. Defaults are
/// derived from the ambient [ThemeData]; a host overrides any field.
class ConversationTheme {
  const ConversationTheme({
    required this.contactBubble,
    required this.contactText,
    required this.operatorBubble,
    required this.operatorText,
    required this.agentBubble,
    required this.agentText,
    required this.advisorText,
    required this.systemText,
    required this.draftBorder,
    required this.surface,
    this.baseTextStyle,
  });

  final Color contactBubble;
  final Color contactText;
  final Color operatorBubble;
  final Color operatorText;

  /// The bubble behind an agent-sent reply when it renders OUTBOUND (operator
  /// viewpoint) — accented to mark it agent-authored, distinct from the
  /// operator's own [operatorBubble].
  final Color agentBubble;

  /// Agent speaking as the business (a sent public reply) — text color, used for
  /// the left-aligned agent line (contact viewpoint) and the outbound bubble.
  final Color agentText;

  /// The private advisor voice (asides) — visually unmistakable from anything
  /// that could reach a contact.
  final Color advisorText;
  final Color systemText;

  /// The border on a draft reply awaiting approval.
  final Color draftBorder;
  final Color surface;
  final TextStyle? baseTextStyle;

  factory ConversationTheme.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConversationTheme(
      contactBubble: cs.surfaceContainerHighest,
      contactText: cs.onSurface,
      operatorBubble: cs.primary,
      operatorText: cs.onPrimary,
      agentBubble: cs.tertiaryContainer,
      agentText: cs.onSurface,
      advisorText: cs.tertiary,
      systemText: cs.onSurfaceVariant,
      draftBorder: cs.outline,
      surface: cs.surface,
      baseTextStyle: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

/// The conversation surface — a stream of [Message]s rendered by the taxonomy
/// (party / agent reply / advisor aside / directive view / system) with inline
/// actions. Host-agnostic: styling comes from [ConversationTheme], dynamic
/// content from [viewRegistry], and every action is dispatched back through
/// [onAction] (the host decides what an action does).
///
/// The composer/editor is intentionally NOT here — the host wraps the stream
/// with its own composer, so a quick-reply and a long-form editor are the same
/// surface with a different bottom.
class ConversationStream extends StatelessWidget {
  const ConversationStream({
    super.key,
    required this.messages,
    this.onAction,
    this.viewRegistry = const {},
    this.captionBuilder,
    this.theme,
    this.controller,
    this.viewpoint = ConversationViewpoint.contact,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  final List<Message> messages;
  final void Function(Message message, MessageAction action)? onAction;
  final Map<String, MessageViewBuilder> viewRegistry;
  final MessageCaptionBuilder? captionBuilder;
  final ConversationTheme? theme;
  final ScrollController? controller;

  /// Whose side the surface renders from — decides which side the public agent
  /// lands on (operator's inbox → agent is outbound/right; talking-to-the-agent
  /// → agent is the other party/left). Defaults to [ConversationViewpoint.contact]
  /// so existing hosts (marketing chat) are unaffected.
  final ConversationViewpoint viewpoint;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ConversationTheme.of(context);
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final tile = _MessageTile(
          message: m,
          theme: t,
          onAction: onAction,
          viewRegistry: viewRegistry,
          viewpoint: viewpoint);
        final caption = captionBuilder?.call(context, m);
        if (caption == null) return tile;
        // Caption aligns to the message's side (outbound right, else left). From
        // the operator's viewpoint the public agent is outbound too.
        final right = m.author == MessageAuthor.operator ||
            (m.author == MessageAuthor.agentPublic &&
                viewpoint == ConversationViewpoint.operator);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile,
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: right ? Alignment.centerRight : Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: TextStyle(color: t.systemText, fontSize: 11),
                  child: caption,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.theme,
    required this.onAction,
    required this.viewRegistry,
    required this.viewpoint,
  });

  final Message message;
  final ConversationTheme theme;
  final void Function(Message, MessageAction)? onAction;
  final Map<String, MessageViewBuilder> viewRegistry;
  final ConversationViewpoint viewpoint;

  /// From the operator's inbox, a public-agent message is the business replying
  /// to the contact — outbound, on the right. In a talking-to-the-agent surface
  /// the agent is the other party — on the left.
  bool get _agentIsOutbound => viewpoint == ConversationViewpoint.operator;

  @override
  Widget build(BuildContext context) {
    // A directive view renders as its own inline component (§7).
    if (message.view != null) {
      final builder = viewRegistry[message.view!.viewId];
      final child = builder?.call(context, message.view!) ??
          _fallbackView(context, message.view!);
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: child);
    }

    switch (message.author) {
      case MessageAuthor.contact:
        return _bubble(alignEnd: false, bg: theme.contactBubble, fg: theme.contactText);
      case MessageAuthor.operator:
        return _bubble(alignEnd: true, bg: theme.operatorBubble, fg: theme.operatorText);
      case MessageAuthor.agentPublic:
        if (message.state == MessageState.pendingApproval) {
          return _draftReply(context);
        }
        // A sent public reply. In the operator's inbox it's outbound (a bubble
        // on the right, gold-accented to mark it agent-authored); in the
        // talking-to-the-agent surface it's the agent's line on the left.
        return _agentIsOutbound
            ? _agentBubble()
            : _agentLine(theme.agentText, asBusiness: true);
      case MessageAuthor.agentAdvisor:
        return _advisorAside(context);
      case MessageAuthor.system:
        return _systemLine();
    }
  }

  // ── party bubbles ──
  Widget _bubble({required bool alignEnd, required Color bg, required Color fg}) {
    if ((message.text ?? '').isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10, left: alignEnd ? 48 : 0, right: alignEnd ? 0 : 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(message.text!, style: (theme.baseTextStyle ?? const TextStyle()).copyWith(color: fg)),
      ),
    );
  }

  // ── agent speaking as the business, OUTBOUND (operator viewpoint) ──
  // A right-aligned bubble like the operator's, but on the agent accent and
  // tagged so it's unmistakably the agent's voice, not the operator's own.
  Widget _agentBubble() {
    if ((message.text ?? '').isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 48),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
            color: theme.agentBubble, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AGENT',
                style: TextStyle(
                    color: theme.agentText.withValues(alpha: 0.6),
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(message.text!,
                style: (theme.baseTextStyle ?? const TextStyle())
                    .copyWith(color: theme.agentText)),
          ],
        ),
      ),
    );
  }

  // ── agent speaking as the business (sent) ──
  Widget _agentLine(Color color, {bool asBusiness = false}) {
    if ((message.text ?? '').isEmpty) return _typing(color);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 32),
        child: Text(message.text!,
            style: (theme.baseTextStyle ?? const TextStyle())
                .copyWith(color: color, height: 1.45)),
      ),
    );
  }

  // ── the private advisor voice — unmistakably aside, never sendable ──
  Widget _advisorAside(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 24),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: theme.advisorText.withValues(alpha: 0.5), width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ONLY YOU SEE THIS',
                style: TextStyle(
                    color: theme.advisorText, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            if ((message.text ?? '').isNotEmpty)
              Text(message.text!,
                  style: (theme.baseTextStyle ?? const TextStyle())
                      .copyWith(color: theme.advisorText, fontStyle: FontStyle.italic, height: 1.4))
            else
              _typing(theme.advisorText),
            _actions(context),
          ],
        ),
      ),
    );
  }

  // ── a public-agent reply awaiting the operator's yes (inline approval) ──
  // Aligned to the side the agent's *sent* reply would land on, so approving it
  // in place reads as "this becomes that outbound message".
  Widget _draftReply(BuildContext context) {
    return Align(
      alignment: _agentIsOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            bottom: 10, right: _agentIsOutbound ? 0 : 16, left: _agentIsOutbound ? 16 : 0),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.draftBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DRAFT REPLY · NEEDS YOUR YES',
                style: TextStyle(
                    color: theme.systemText, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(message.text ?? '',
                style: (theme.baseTextStyle ?? const TextStyle()).copyWith(color: theme.agentText)),
            _actions(context, fallback: const [MessageAction.approve, MessageAction.refine, MessageAction.edit]),
          ],
        ),
      ),
    );
  }

  Widget _systemLine() {
    if ((message.text ?? '').isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(message.text!,
            style: TextStyle(color: theme.systemText, fontSize: 12)),
      ),
    );
  }

  Widget _typing(Color color) => Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
      );

  Widget _actions(BuildContext context, {List<MessageAction> fallback = const []}) {
    final actions = message.actions.isNotEmpty ? message.actions : fallback;
    if (actions.isEmpty || onAction == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      children: [
        for (final a in actions)
          TextButton(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: () => onAction!(message, a),
            child: Text(_label(a)),
          ),
      ],
    );
  }

  Widget _fallbackView(BuildContext context, MessageView view) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(color: theme.draftBorder), borderRadius: BorderRadius.circular(12)),
        child: Text('[${view.viewId}]', style: TextStyle(color: theme.systemText)),
      );

  static String _label(MessageAction a) => switch (a) {
        MessageAction.approve => 'Approve',
        MessageAction.refine => 'Refine',
        MessageAction.review => 'Review',
        MessageAction.edit => 'Edit',
        MessageAction.reword => 'Reword',
        MessageAction.shorten => 'Shorten',
        MessageAction.rephrase => 'Rephrase',
        MessageAction.send => 'Send',
        MessageAction.speak => 'Say it',
        MessageAction.dismiss => 'Dismiss',
        MessageAction.openWith => 'Open with…',
        MessageAction.takeMeThere => 'Take me there',
      };
}
