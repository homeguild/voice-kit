import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

import 'fixtures/device_personas.dart';

/// The Flutter half of the shared device-persona contract (docs/journey-testing.md,
/// axis 2). Mirrors the TS `device.test.ts`: both ports load the SAME file and
/// resolve personas the SAME way against a frozen clock — a persona can never mean
/// one device on web and another on mobile.
void main() {
  final frozen = DateTime.utc(2026, 9, 9, 12);
  final clock = Clock(() => frozen);

  group('device personas (shared fixture)', () {
    test('fresh_install resolves to the new-install default', () {
      final s = resolvePersona(DevicePersonas.byId('fresh_install'), clock);
      expect(s.appOpenCount, 0);
      expect(s.firstOpenAt, isNull);
      expect(isFreshInstall(s), isTrue);
    });

    test('resolves relative times against the clock', () {
      final s = resolvePersona(DevicePersonas.byId('returning_unauth'), clock);
      expect(s.appOpenCount, 3);
      expect(s.firstOpenAt, '2026-09-04T12:00:00.000Z');
      expect(daysSinceInstall(s, clock), 5);
      expect(isFreshInstall(s), isFalse);
    });

    test('covers the canonical personas', () {
      final ids = DevicePersonas.all.map((p) => p.id).toSet();
      for (final required in const [
        'fresh_install',
        'returning_unauth',
        'waitlisted',
        'onboarding_midway',
        'lapsed',
      ]) {
        expect(ids.contains(required), isTrue, reason: 'missing persona: $required');
      }
    });
  });
}
