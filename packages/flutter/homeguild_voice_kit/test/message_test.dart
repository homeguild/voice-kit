import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

Message _msg(MessageAuthor author, MessageState state,
        {MessageChannel channel = MessageChannel.sms}) =>
    Message(id: 'm', author: author, state: state, channel: channel);

void main() {
  group('provenance & approval (the trust boundary)', () {
    test('private authors never transmit, in any state', () {
      for (final state in MessageState.values) {
        expect(_msg(MessageAuthor.agentAdvisor, state).canTransmit, isFalse,
            reason: 'advisor must never transmit ($state)');
        expect(_msg(MessageAuthor.system, state).canTransmit, isFalse,
            reason: 'system must never transmit ($state)');
      }
      expect(_msg(MessageAuthor.agentAdvisor, MessageState.internal).isInternal,
          isTrue);
    });

    test('a public-agent reply transmits only once sent', () {
      final pending = _msg(MessageAuthor.agentPublic, MessageState.pendingApproval);
      expect(pending.canTransmit, isFalse);
      expect(pending.requiresApproval, isTrue);

      final approved = pending.approve();
      expect(approved.state, MessageState.sent);
      expect(approved.canTransmit, isTrue);
    });

    test('sent is reachable for a public-agent reply ONLY via approve()', () {
      final pending = _msg(MessageAuthor.agentPublic, MessageState.pendingApproval);
      // copyWith cannot sneak it to sent — must go through approval.
      expect(() => pending.copyWith(state: MessageState.sent),
          throwsStateError);
      // approve() is the blessed path.
      expect(pending.approve().state, MessageState.sent);
    });

    test('approve() rejects anything but a pending public-agent reply', () {
      expect(() => _msg(MessageAuthor.agentPublic, MessageState.draft).approve(),
          throwsStateError);
      expect(() => _msg(MessageAuthor.operator, MessageState.pendingApproval).approve(),
          throwsStateError);
      expect(() => _msg(MessageAuthor.contact, MessageState.sent).approve(),
          throwsStateError);
    });

    test('provenance is immutable — copyWith cannot change the author', () {
      final m = _msg(MessageAuthor.agentAdvisor, MessageState.internal);
      final n = m.copyWith(text: 'edited');
      expect(n.author, MessageAuthor.agentAdvisor);
      // No `author` parameter exists on copyWith — enforced at compile time.
    });
  });

  group('party & operator messages', () {
    test('a contact message is sent and transmittable', () {
      final m = _msg(MessageAuthor.contact, MessageState.sent);
      expect(m.canTransmit, isTrue);
      expect(m.isInternal, isFalse);
    });

    test('an operator draft becomes transmittable when sent (no approval)', () {
      final draft = _msg(MessageAuthor.operator, MessageState.draft);
      expect(draft.canTransmit, isFalse);
      final sent = draft.copyWith(state: MessageState.sent);
      expect(sent.canTransmit, isTrue);
    });
  });

  group('carriers', () {
    test('channelMeta and view ride without touching the core fields', () {
      final m = Message(
        id: 'e1',
        author: MessageAuthor.contact,
        state: MessageState.sent,
        channel: MessageChannel.email,
        text: 'long email…',
        channelMeta: const {'subject': 'Invoice', 'cc': ['a@x.com']},
        view: const MessageView(viewId: 'summary', data: {'gist': 'wants a quote'}),
        actions: const [MessageAction.review, MessageAction.openWith],
      );
      expect(m.channel, MessageChannel.email);
      expect(m.channelMeta['subject'], 'Invoice');
      expect(m.view?.viewId, 'summary');
      expect(m.actions, contains(MessageAction.openWith));
    });
  });
}
