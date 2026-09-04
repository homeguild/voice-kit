import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

Widget _host(List<Message> messages,
        {void Function(Message, MessageAction)? onAction,
        Map<String, MessageViewBuilder> views = const {},
        ConversationViewpoint viewpoint = ConversationViewpoint.contact}) =>
    MaterialApp(
      home: Scaffold(
        body: ConversationStream(
            messages: messages,
            onAction: onAction,
            viewRegistry: views,
            viewpoint: viewpoint),
      ),
    );

void main() {
  testWidgets('a pending public-agent reply shows Approve and fires the action',
      (tester) async {
    Message? acted;
    MessageAction? action;
    await tester.pumpWidget(_host([
      Message(
          id: '1',
          author: MessageAuthor.agentPublic,
          state: MessageState.pendingApproval,
          channel: MessageChannel.sms,
          text: "Weekends are emergencies only — want me to book you Monday?"),
    ], onAction: (m, a) {
      acted = m;
      action = a;
    }));

    expect(find.text('DRAFT REPLY · NEEDS YOUR YES'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    expect(action, MessageAction.approve);
    expect(acted!.requiresApproval, isTrue);
  });

  testWidgets('an advisor aside is labelled private and offers no Send',
      (tester) async {
    await tester.pumpWidget(_host([
      Message(
          id: '2',
          author: MessageAuthor.agentAdvisor,
          state: MessageState.internal,
          channel: MessageChannel.none,
          text: 'That caller has reached out 3 times this week.',
          actions: const [MessageAction.dismiss]),
    ], onAction: (_, __) {}));

    expect(find.text('ONLY YOU SEE THIS'), findsOneWidget);
    expect(find.text('Send'), findsNothing);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets(
      'operator viewpoint: a sent agent reply is outbound (right, tagged AGENT)',
      (tester) async {
    final sent = Message(
        id: '4',
        author: MessageAuthor.agentPublic,
        state: MessageState.sent,
        channel: MessageChannel.sms,
        text: 'Booked you for 3pm — see you then.');

    // Operator's inbox: the agent spoke as the business → outbound, right side.
    await tester
        .pumpWidget(_host([sent], viewpoint: ConversationViewpoint.operator));
    expect(find.text('AGENT'), findsOneWidget);
    final center = tester.getCenter(find.text('Booked you for 3pm — see you then.'));
    final width = tester.getSize(find.byType(ConversationStream)).width;
    expect(center.dx, greaterThan(width / 2), reason: 'agent reply hugs the right');

    // Contact viewpoint (talking to the agent): the agent is the other party →
    // a left-aligned line, no outbound tag.
    await tester
        .pumpWidget(_host([sent], viewpoint: ConversationViewpoint.contact));
    expect(find.text('AGENT'), findsNothing);
    final leftCenter =
        tester.getCenter(find.text('Booked you for 3pm — see you then.'));
    expect(leftCenter.dx, lessThan(width / 2), reason: 'agent line hugs the left');
  });

  testWidgets('a directive view renders through the registry', (tester) async {
    await tester.pumpWidget(_host([
      Message(
          id: '3',
          author: MessageAuthor.agentAdvisor,
          state: MessageState.internal,
          channel: MessageChannel.email,
          view: const MessageView(viewId: 'summary', data: {'gist': 'wants a quote'})),
    ], views: {
      'summary': (context, v) => Text('SUMMARY: ${v.data['gist']}'),
    }));

    expect(find.text('SUMMARY: wants a quote'), findsOneWidget);
  });
}
