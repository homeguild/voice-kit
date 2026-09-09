import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

import 'fixtures/cassettes.dart';

/// The Flutter half of the shared cassette contract (docs/journey-testing.md,
/// axis 3). Mirrors the TS `cassettes.test.ts`: both ports load the SAME file and
/// assert the SAME envelope contract, so a malformed cassette fails on both — the
/// fixture can never mean one thing on web and another on mobile.
void main() {
  group('agent cassettes (shared fixture)', () {
    test('loads the library', () {
      expect(Cassettes.all, isNotEmpty);
    });

    test('every frame conforms to the envelope contract', () {
      for (final c in Cassettes.all) {
        expect(c.frames, isNotEmpty, reason: '${c.id} has frames');
        for (final frame in c.frames) {
          expect(frame.validate(), isNull,
              reason: '${c.id}: ${frame.raw}');
        }
      }
    });

    test('every branch target references an existing cassette', () {
      final ids = Cassettes.all.map((c) => c.id).toSet();
      for (final c in Cassettes.all) {
        c.branches.forEach((event, next) {
          expect(ids.contains(next), isTrue,
              reason: '${c.id}.branches.$event → $next');
        });
      }
    });

    test('ids are unique', () {
      final ids = Cassettes.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('covers the canonical return states', () {
      final states = Cassettes.all.map((c) => c.returnState).toSet();
      for (final required in const [
        'narrative',
        'notify',
        'form',
        'confirmation',
        'selection_list',
        'error',
        'composite',
      ]) {
        expect(states.contains(required), isTrue,
            reason: 'missing return state: $required');
      }
    });
  });
}
