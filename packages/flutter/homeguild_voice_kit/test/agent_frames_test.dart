import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// The frame envelope contract — the shapes `validate()` accepts/rejects. Mirrors the TS
/// kit's `agent-frames` validation so the two ports stay 1:1 (docs/journey-testing.md).
void main() {
  group('AgentFrame.validate — directives', () {
    test('accepts a show_view directive', () {
      final f = AgentFrame({
        'type': 'directive',
        'directive': 'show_view',
        'view_id': 'form',
        'target': 'panel',
      });
      expect(f.validate(), isNull);
    });

    test('accepts a dismiss_view directive with a window_id', () {
      final f = AgentFrame({
        'type': 'directive',
        'directive': 'dismiss_view',
        'window_id': 'teach',
      });
      expect(f.validate(), isNull);
    });

    test('rejects a dismiss_view directive without a window_id', () {
      final f = AgentFrame({'type': 'directive', 'directive': 'dismiss_view'});
      expect(f.validate(), 'dismiss_view directive missing window_id');
    });

    test('still rejects an unknown directive', () {
      final f = AgentFrame({'type': 'directive', 'directive': 'teleport'});
      expect(f.validate(), 'unknown directive: teleport');
    });
  });

  test('dismiss_view folds to dismissPanel (reducer parity)', () {
    var s = applyDirective(
      ShellState.empty,
      Directive(
          view: const MessageView(viewId: 'form'),
          windowId: 'teach',
          target: DirectiveTarget.panel),
    );
    expect(s.panel, hasLength(1));
    s = dismissPanel(s, 'teach'); // the dismiss_view frame's effect
    expect(s.panel, isEmpty);
    expect(s.messages, isEmpty); // inline history untouched
  });
}
