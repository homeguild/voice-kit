import 'package:flutter/material.dart';

import '../src/conversation/message.dart';

/// Renders a directive view ([MessageView]) inline — the host's view registry
/// maps `viewId` → a native widget (docs/conversation-surface.md §7).
typedef MessageViewBuilder = Widget Function(BuildContext context, MessageView view);

/// Injectable styling so the stream wears the host's design system. Defaults are
/// derived from the ambient [ThemeData]; a host overrides any field.
class ConversationTheme {
  const ConversationTheme({
    required this.contactBubble,
    required this.contactText,
    required this.operatorBubble,
    required this.operatorText,
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

  /// Agent speaking as the business (a sent public reply).
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
    this.theme,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  final List<Message> messages;
  final void Function(Message message, MessageAction action)? onAction;
  final Map<String, MessageViewBuilder> viewRegistry;
  final ConversationTheme? theme;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ConversationTheme.of(context);
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: messages.length,
      itemBuilder: (context, i) => _MessageTile(
        message: messages[i],
        theme: t,
        onAction: onAction,
        viewRegistry: viewRegistry,
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.theme,
    required this.onAction,
    required this.viewRegistry,
  });

  final Message message;
  final ConversationTheme theme;
  final void Function(Message, MessageAction)? onAction;
  final Map<String, MessageViewBuilder> viewRegistry;

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
        return message.state == MessageState.pendingApproval
            ? _draftReply(context)
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
  Widget _draftReply(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 16),
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
      };
}
