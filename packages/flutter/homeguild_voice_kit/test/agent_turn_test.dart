import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// The shared fold (frames → shell state) — the Dart mirror of the TS
/// `agent-turn.test.ts`. Narrative grows the agent message; directives route to the
/// stream or the panel by target; dismiss_view retracts a panel window.
AgentTurn _run(List<Map<String, dynamic>> frames, {AgentTurn? from}) =>
    frames.fold(from ?? initialTurn, (t, f) => applyFrame(t, AgentFrame(f)));

void main() {
  test('appends the operator message and resets the agent turn', () {
    final t = appendUser(initialTurn, 'hi');
    expect(t.shell.messages, hasLength(1));
    expect(t.shell.messages.first.author, MessageAuthor.operator);
    expect(t.agentId, isNull);
  });

  test('grows the agent message across narrative tokens', () {
    final t = _run([
      {'type': 'narrative_start'},
      {'type': 'narrative', 'text': 'Hel'},
      {'type': 'narrative', 'text': 'lo'},
      {'type': 'narrative_end'},
    ]);
    expect(t.shell.messages, hasLength(1));
    expect(t.shell.messages.first.text, 'Hello');
    expect(t.shell.messages.first.author, MessageAuthor.agentPublic);
    expect(t.agentId, isNull); // narrative_end closed the message
  });

  test('routes a panel directive to the panel and an inline one to the stream', () {
    final panel = _run([
      {'type': 'directive', 'directive': 'show_view', 'view_id': 'form', 'window_id': 'teach', 'target': 'panel', 'data': <String, dynamic>{'title': 'Teach'}},
    ]);
    expect(panel.shell.panel, hasLength(1));
    expect(panel.shell.messages, isEmpty);
    expect(panel.shell.panel.first.view.data['__windowId'], 'teach'); // echo-back id carried

    final inline = _run([
      {'type': 'directive', 'directive': 'show_view', 'view_id': 'chart', 'window_id': 'c1', 'target': 'inline', 'data': <String, dynamic>{}},
    ]);
    expect(inline.shell.panel, isEmpty);
    expect(inline.shell.messages, hasLength(1));
  });

  test('dismiss_view retracts the matching panel slot; a notify is ignored', () {
    var t = _run([
      {'type': 'directive', 'directive': 'show_view', 'view_id': 'form', 'window_id': 'teach', 'target': 'panel', 'data': <String, dynamic>{}},
      {'type': 'directive', 'directive': 'notify', 'message': 'saved'},
    ]);
    expect(t.shell.panel, hasLength(1)); // notify didn't touch the shell
    t = _run([
      {'type': 'directive', 'directive': 'dismiss_view', 'window_id': 'teach'},
    ], from: t);
    expect(t.shell.panel, isEmpty);
  });
}
