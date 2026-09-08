import 'package:flutter/material.dart';

import '../src/conversation/message.dart';
import '../src/conversation/shell.dart';
import 'conversation_stream.dart';

/// The PANEL surface — the persistent "current focus" beside the stream
/// (docs/agent-shell.md). Renders the panel's pinned slots through the SAME view
/// registry the stream uses, so a view can be shown inline or in the panel with no
/// change to the view itself. The host decides WHERE the panel physically sits
/// (right rail on desktop, a sheet/tab on phone); this just renders its contents.
class PanelSurface extends StatelessWidget {
  const PanelSurface({
    super.key,
    required this.slots,
    this.viewRegistry = const {},
    this.theme,
    this.empty,
  });

  /// The pinned slots (from [ShellState.panel]), most-recent last.
  final List<PanelSlot> slots;

  /// `viewId` → a native widget builder — the same registry the stream uses.
  final Map<String, MessageViewBuilder> viewRegistry;

  final ConversationTheme? theme;

  /// Shown when nothing is pinned (onboarding not started / all caught up).
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return empty ?? const SizedBox.shrink();
    final t = theme ?? ConversationTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: viewRegistry[slot.view.viewId]?.call(context, slot.view) ??
                _fallback(t, slot.view),
          ),
      ],
    );
  }

  Widget _fallback(ConversationTheme t, MessageView view) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: t.draftBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('[${view.viewId}]', style: TextStyle(color: t.systemText)),
      );
}
