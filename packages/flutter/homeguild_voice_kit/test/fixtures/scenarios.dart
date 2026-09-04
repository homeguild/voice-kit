import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// Reusable, deterministic conversation scenarios — the "realistic test data"
/// layer. One scenario feeds a golden test, a view-map catalog entry, a design
/// reference, and (later) real dev/demo seeding. Everything here is fixed: no
/// clocks, no randomness, no live agent output — so a screenshot of it is stable
/// enough to gate on.
///
/// A scenario is just a `List<Message>`; the surface renders it the same way it
/// renders a live thread. Add personas × states here as the app grows.
class Scenarios {
  Scenarios._();

  static final DateTime _t = DateTime.utc(2026, 9, 4, 14, 0);
  static DateTime _at(int min) => _t.add(Duration(minutes: min));

  /// A repeat customer chasing a weekend callout — the classic case: an inbound
  /// question, an agent reply *awaiting the operator's yes*, and a private
  /// advisor nudge. Exercises every trust boundary at once.
  static List<Message> get weekendCallout => [
        Message(
          id: 's1',
          author: MessageAuthor.contact,
          state: MessageState.sent,
          channel: MessageChannel.sms,
          text: 'Hi — do you do emergency callouts on weekends? My kitchen sink '
              'is backing up badly.',
          createdAt: _at(0),
        ),
        Message(
          id: 's2',
          author: MessageAuthor.operator,
          state: MessageState.sent,
          channel: MessageChannel.sms,
          text: 'Hey! Yes we do — is this an emergency or can it wait to Monday?',
          createdAt: _at(2),
        ),
        Message(
          id: 's3',
          author: MessageAuthor.contact,
          state: MessageState.sent,
          channel: MessageChannel.sms,
          text: "It's getting worse, water's near the top now.",
          createdAt: _at(9),
        ),
        Message(
          id: 's4',
          author: MessageAuthor.system,
          state: MessageState.internal,
          channel: MessageChannel.voice,
          text: 'Missed call · 21s · 2:14 PM',
          createdAt: _at(14),
        ),
        // The agent drafted a reply on the business's behalf — it needs a yes.
        Message(
          id: 's5',
          author: MessageAuthor.agentPublic,
          state: MessageState.pendingApproval,
          channel: MessageChannel.sms,
          text: "That sounds urgent — I can get someone out this afternoon "
              "between 3 and 5. Our weekend emergency rate is \$180 callout. "
              "Want me to book it?",
          createdAt: _at(15),
        ),
        // The advisor, privately, to the operator.
        Message(
          id: 's6',
          author: MessageAuthor.agentAdvisor,
          state: MessageState.internal,
          channel: MessageChannel.none,
          text: "This is the third time this customer's reached out this week — "
              "they've been patient. Worth a quick personal call to close it.",
          actions: const [MessageAction.dismiss],
          createdAt: _at(15),
        ),
      ];
}
