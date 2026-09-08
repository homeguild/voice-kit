import 'message.dart';

/// The agent shell's two-surface routing (docs/agent-shell.md). A directive from
/// the agent carries a view AND where it renders:
///
///  - [DirectiveTarget.inline] — appended to the STREAM as a message (part of the
///    conversation; scrolls with history). Charts, one-off forms, confirmations.
///  - [DirectiveTarget.panel]  — pinned to the PANEL surface (the persistent
///    "current focus": onboarding tasks, a dashboard, a settings form). Stays
///    until the agent or the user changes it.
///
/// The one protocol addition over agent-ui-arch.md; everything else (the view
/// registry, the two-channel emit, view-event feedback) is unchanged.
enum DirectiveTarget { inline, panel }

/// A view the agent asked to show, and where. [windowId] identifies it so a later
/// directive can update/dismiss it; [options] carries host hints (placement/size).
class Directive {
  const Directive({
    required this.view,
    required this.target,
    this.windowId,
    this.options = const {},
  });

  final MessageView view;
  final DirectiveTarget target;
  final String? windowId;
  final Map<String, Object?> options;
}
