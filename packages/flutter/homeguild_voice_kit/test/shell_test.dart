import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// The stream+panel routing (docs/agent-shell.md) — the foundational shell pattern,
/// mirrored 1:1 from the TS port. A directive lands on exactly one surface by
/// target; panel windows update in place; inline directives never retract.
void main() {
  MessageView chart([String id = 'chart']) => MessageView(viewId: id);

  group('applyDirective — surface routing', () {
    test('routes an inline directive to the stream as a non-transmitting message',
        () {
      final s = applyDirective(
          ShellState.empty, Directive(view: chart(), target: DirectiveTarget.inline));
      expect(s.messages, hasLength(1));
      expect(s.panel, isEmpty);
      final m = s.messages.first;
      expect(m.view?.viewId, 'chart');
      expect(m.isInternal, isTrue);
      expect(m.canTransmit, isFalse);
    });

    test('routes a panel directive to the panel, not the stream', () {
      final s = applyDirective(
          ShellState.empty,
          Directive(
              view: chart('checklist'),
              target: DirectiveTarget.panel,
              windowId: 'w1'));
      expect(s.messages, isEmpty);
      expect(s.panel, hasLength(1));
      expect(s.panel.first.view.viewId, 'checklist');
      expect(s.panel.first.windowId, 'w1');
    });

    test('updates a panel window in place (same windowId replaces)', () {
      var s = applyDirective(
          ShellState.empty,
          Directive(
              view: MessageView(viewId: 'checklist', data: {'done': 0}),
              target: DirectiveTarget.panel,
              windowId: 'w1'));
      s = applyDirective(
          s,
          Directive(
              view: MessageView(viewId: 'checklist', data: {'done': 1}),
              target: DirectiveTarget.panel,
              windowId: 'w1'));
      expect(s.panel, hasLength(1));
      expect(s.panel.first.view.data['done'], 1);
    });

    test('stacks distinct panel windows', () {
      var s = applyDirective(ShellState.empty,
          Directive(view: chart('checklist'), target: DirectiveTarget.panel, windowId: 'w1'));
      s = applyDirective(s,
          Directive(view: chart('dashboard'), target: DirectiveTarget.panel, windowId: 'w2'));
      expect(s.panel.map((p) => p.windowId), ['w1', 'w2']);
    });

    test('dismisses a panel window, leaving the stream untouched', () {
      var s = applyDirective(
          ShellState.empty, Directive(view: chart(), target: DirectiveTarget.inline));
      s = applyDirective(s,
          Directive(view: chart('checklist'), target: DirectiveTarget.panel, windowId: 'w1'));
      s = dismissPanel(s, 'w1');
      expect(s.panel, isEmpty);
      expect(s.messages, hasLength(1)); // inline history does not retract
    });

    test('is pure — does not mutate the prior state', () {
      final before = applyDirective(ShellState.empty,
          Directive(view: chart(), target: DirectiveTarget.panel, windowId: 'w1'));
      final after =
          applyDirective(before, Directive(view: chart('x'), target: DirectiveTarget.inline));
      expect(before.messages, isEmpty);
      expect(after.messages, hasLength(1));
    });
  });

  test('appendMessage appends an ordinary message to the stream', () {
    final s = appendMessage(
      ShellState.empty,
      Message(
          id: 'u1',
          author: MessageAuthor.operator,
          state: MessageState.sent,
          channel: MessageChannel.chat,
          text: 'hi'),
    );
    expect(s.messages, hasLength(1));
    expect(s.messages.first.author, MessageAuthor.operator);
  });
}
