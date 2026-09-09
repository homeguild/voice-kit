import 'dart:convert';
import 'dart:io';

import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// Loads the language-neutral agent cassettes (voice-kit/fixtures/agent-cassettes.json)
/// — the SAME file the TypeScript port reads. One frozen cassette per agentic
/// return state; both ports replay these exact frames, so a divergence is a
/// failing test, not a review catch. See docs/journey-testing.md (axis 3).
class Cassettes {
  Cassettes._();

  static final List<AgentCassette> all = _load();

  /// The shared fixture lives at the repo root; `flutter test` runs with the
  /// package directory as its working directory.
  static String get _fixturePath =>
      '${Directory.current.path}/../../../fixtures/agent-cassettes.json';

  static List<AgentCassette> _load() {
    final json = jsonDecode(File(_fixturePath).readAsStringSync())
        as Map<String, dynamic>;
    return (json['cassettes'] as List)
        .cast<Map<String, dynamic>>()
        .map(_cassette)
        .toList();
  }

  /// A cassette by id — throws on a typo so a bad branch reference fails loudly.
  static AgentCassette byId(String id) =>
      all.firstWhere((c) => c.id == id,
          orElse: () => throw ArgumentError('no cassette with id "$id"'));

  static AgentCassette _cassette(Map<String, dynamic> j) => AgentCassette(
        id: j['id'] as String,
        title: j['title'] as String,
        returnState: j['returnState'] as String,
        userMessage: j['userMessage'] as String,
        opening: j['opening'] as String?,
        frames: (j['frames'] as List)
            .cast<Map<String, dynamic>>()
            .map(AgentFrame.new)
            .toList(),
        branches: ((j['branches'] as Map?)?.cast<String, String>()) ?? const {},
      );
}
