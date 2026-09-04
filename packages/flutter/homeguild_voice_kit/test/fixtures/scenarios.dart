import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// A described, deterministic conversation scenario — the reusable core of the
/// test/doc pipeline. One [Scenario] is simultaneously:
///   • test data (a fixed `List<Message>`),
///   • a golden screenshot (keyed by [id]),
///   • a user-doc entry (its [narrative] + screenshot),
///   • an agentic-support knowledge unit ([narrative] + [shows] + screenshot).
/// Add personas × states here as the app grows; every consumer picks them up.
class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.feature,
    required this.narrative,
    required this.shows,
    required this.route,
    required this.breadcrumb,
    required this.messages,
  });

  /// Matches the golden file name (`$id.png`).
  final String id;

  /// Short human title.
  final String title;

  /// Where in the product this lives (surface · interaction).
  final String feature;

  /// The canonical **deeplink path** of the surface this lives on — scheme/host-
  /// agnostic (`/inbox`, `/inbox/thread/{id}`, `/settings/agent`). Each platform
  /// prepends its own (web URL, iOS/Android universal link, Electron scheme), so
  /// "take you there" is just "open this link" — and the agent can hand it over
  /// from anywhere (in-app, push, email). Coarse paths (sections) cover most
  /// support asks; entity paths with params are added selectively.
  final String route;

  /// The human path to it — shown in docs ("you'll find this under …") and as
  /// the agent's spoken directions.
  final String breadcrumb;

  /// Human-readable description of the feature/interaction this captures.
  final String narrative;

  /// The notable, verified things a reader (or a support agent) learns here.
  final List<String> shows;

  final List<Message> messages;

  String get golden => '$id.png';
}

class Scenarios {
  Scenarios._();

  static final DateTime _t = DateTime.utc(2026, 9, 4, 14, 0);
  static DateTime _at(int min) => _t.add(Duration(minutes: min));

  /// A repeat customer chasing a weekend callout — the classic case: an inbound
  /// question, an agent reply awaiting the operator's yes, and a private advisor
  /// nudge. Exercises every trust boundary at once.
  static final Scenario weekendCallout = Scenario(
    id: 'weekend_callout',
    title: 'Weekend emergency callout',
    feature: 'Inbox · approving an agent draft',
    narrative:
        "A repeat customer texts asking about a weekend emergency callout. The "
        "conversation stays in one thread across text and a missed call. When "
        "things turn urgent, Nuntilo drafts a reply on your behalf and holds it "
        "for your approval — nothing goes to the customer until you say yes. "
        "Alongside it, privately, the advisor points out this person has reached "
        "out three times this week and suggests a personal call to close it.",
    shows: const [
      'A single thread carries text and calls together (one conversation).',
      'The agent can draft a customer reply, but it waits for your approval '
          '(the "Draft reply · needs your yes" card) — it is never sent on its own.',
      'The advisor speaks privately in-thread ("Only you see this") and can '
          'never be sent to the customer.',
    ],
    route: '/inbox',
    breadcrumb: 'Inbox › a customer thread',
    messages: [
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
    ],
  );

  /// Every scenario — the source every consumer iterates (goldens, docs, KB).
  static final List<Scenario> all = [weekendCallout];
}
