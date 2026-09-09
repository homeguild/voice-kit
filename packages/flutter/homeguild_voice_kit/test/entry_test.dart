import 'package:flutter_test/flutter_test.dart';
import 'package:homeguild_voice_kit/homeguild_voice_kit.dart';

/// The Flutter half of the entry-gate contract (docs/app-state.md). Mirrors the TS
/// `entry.test.ts`: both ports resolve auth × intent the SAME way, so the sign-in
/// vs app decision — and the deeplink continue — can never diverge across ports.
void main() {
  group('resolveEntry', () {
    test('resolving → splash regardless of intent', () {
      expect(resolveEntry(AuthPhase.resolving, const Destination('inbox/voice/1')).kind,
          EntrySurfaceKind.splash);
    });

    test('authenticated → the app at the intended destination', () {
      expect(
        resolveEntry(AuthPhase.authenticated, const Destination('settings/agent')),
        const EntrySurface(EntrySurfaceKind.app, Destination('settings/agent')),
      );
    });

    test('authenticated + no intent → home (today)', () {
      expect(resolveEntry(AuthPhase.authenticated, null),
          const EntrySurface(EntrySurfaceKind.app, Destination('today')));
    });

    test('unauthenticated + protected → sign-in, remembering the intent', () {
      expect(
        resolveEntry(AuthPhase.unauthenticated, const Destination('inbox/voice/123')),
        const EntrySurface(
            EntrySurfaceKind.public, Destination('signin', {'next': 'inbox/voice/123'})),
      );
    });

    test('unauthenticated + home → sign-in, no continue', () {
      expect(resolveEntry(AuthPhase.unauthenticated, const Destination('today')),
          const EntrySurface(EntrySurfaceKind.public, Destination('signin')));
    });

    test('unauthenticated + a PUBLIC deeplink → that surface, no gate', () {
      expect(
        resolveEntry(AuthPhase.unauthenticated, const Destination('invite/abc123')),
        const EntrySurface(EntrySurfaceKind.public, Destination('invite/abc123')),
      );
    });
  });
}
