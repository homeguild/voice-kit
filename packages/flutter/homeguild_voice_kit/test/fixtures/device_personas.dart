import 'dart:convert';
import 'dart:io';

import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// Loads the language-neutral device personas (voice-kit/fixtures/device-personas.json)
/// — the SAME file the TypeScript port reads. Journey-testing axis 2: both ports
/// seed these exact personas, so a divergence is a failing test, not a review catch.
class DevicePersonas {
  DevicePersonas._();

  static final List<DevicePersona> all = _load();

  static String get _fixturePath =>
      '${Directory.current.path}/../../../fixtures/device-personas.json';

  static List<DevicePersona> _load() {
    final json = jsonDecode(File(_fixturePath).readAsStringSync())
        as Map<String, dynamic>;
    return (json['personas'] as List)
        .cast<Map<String, dynamic>>()
        .map((p) => DevicePersona(
              id: p['id'] as String,
              title: p['title'] as String,
              state: (p['state'] as Map).cast<String, dynamic>(),
            ))
        .toList();
  }

  static DevicePersona byId(String id) => all.firstWhere((p) => p.id == id,
      orElse: () => throw ArgumentError('no persona with id "$id"'));
}
