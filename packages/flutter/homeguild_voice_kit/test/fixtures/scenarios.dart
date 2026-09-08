import 'dart:convert';
import 'dart:io';

import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// A described, deterministic conversation scenario — the reusable core of the
/// test/doc pipeline. One [Scenario] is simultaneously:
///   • test data (a fixed `List<Message>`),
///   • a golden screenshot (keyed by [id]),
///   • a user-doc entry (its [narrative] + screenshot),
///   • an agentic-support knowledge unit ([narrative] + [shows] + screenshot).
///
/// The scenarios are NOT written here — they're loaded from the language-neutral
/// `voice-kit/fixtures/scenarios.json`, the SAME file the TypeScript port reads,
/// so both ports render the same stories and a divergence is a failing test, not
/// a review catch. Add personas × states in the JSON; every consumer picks them up.
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

  /// Every scenario — the source every consumer iterates (goldens, docs, KB) —
  /// loaded from the shared JSON fixture (see class doc).
  static final List<Scenario> all = _load();

  /// The shared fixture lives at the repo root; `flutter test` runs with the
  /// package directory as its working directory.
  static String get _fixturePath =>
      '${Directory.current.path}/../../../fixtures/scenarios.json';

  static List<Scenario> _load() {
    final json = jsonDecode(File(_fixturePath).readAsStringSync())
        as Map<String, dynamic>;
    return (json['scenarios'] as List)
        .cast<Map<String, dynamic>>()
        .map(_scenario)
        .toList();
  }

  static Scenario _scenario(Map<String, dynamic> j) => Scenario(
        id: j['id'] as String,
        title: j['title'] as String,
        feature: j['feature'] as String,
        narrative: j['narrative'] as String,
        route: j['route'] as String,
        breadcrumb: j['breadcrumb'] as String,
        shows: (j['shows'] as List).cast<String>(),
        messages: (j['messages'] as List)
            .cast<Map<String, dynamic>>()
            .map(_message)
            .toList(),
      );

  static Message _message(Map<String, dynamic> m) => Message(
        id: m['id'] as String,
        author: MessageAuthor.values.byName(m['author'] as String),
        state: MessageState.values.byName(m['state'] as String),
        channel: MessageChannel.values.byName(m['channel'] as String),
        text: m['text'] as String?,
        actions: ((m['actions'] as List?) ?? const [])
            .cast<String>()
            .map(MessageAction.values.byName)
            .toList(),
        createdAt:
            m['createdAt'] != null ? DateTime.parse(m['createdAt'] as String) : null,
      );
}
