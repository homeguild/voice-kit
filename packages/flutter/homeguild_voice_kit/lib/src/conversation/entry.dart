/// The entry gate — `AppState = { auth, intent }` → the surface to show
/// (docs/app-state.md). The 1:1 Dart mirror of the TS `entry.ts`. Auth is the
/// OUTER switch; view/nav lives only inside the authenticated branch. Shared +
/// pure so both ports gate identically — an unauthenticated visitor's intent
/// resolves to sign-in, never a view they can't see.

enum AuthPhase { resolving, unauthenticated, authenticated }

/// A canonical destination — the deeplink target. [path] is the logical route
/// incl. ids ("today", "inbox/voice/123", "settings/agent", "invite/{token}").
class Destination {
  const Destination(this.path, [this.params]);

  final String path;
  final Map<String, String>? params;

  @override
  bool operator ==(Object other) =>
      other is Destination &&
      other.path == path &&
      _mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(path, params?.length);
}

bool _mapEquals(Map<String, String>? a, Map<String, String>? b) {
  if (a == null || a.isEmpty) return b == null || b.isEmpty;
  if (b == null || a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

const Destination kHome = Destination('today');
const Destination kSignIn = Destination('signin');

const List<String> _publicHeads = [
  'signin',
  'create',
  'reset',
  'invite',
  'launch',
  'welcome',
];

/// True when a destination is reachable unauthenticated (no login gate).
bool isPublic(Destination dest) => _publicHeads.contains(dest.path.split('/').first);

/// The surface to render. `dest` is null only for [EntrySurfaceKind.splash].
enum EntrySurfaceKind { splash, public, app }

class EntrySurface {
  const EntrySurface(this.kind, [this.dest]);
  final EntrySurfaceKind kind;
  final Destination? dest;

  @override
  bool operator ==(Object other) =>
      other is EntrySurface && other.kind == kind && other.dest == dest;

  @override
  int get hashCode => Object.hash(kind, dest);
}

/// auth × intent → the surface, encoded once for both ports. Unauthenticated + a
/// protected intent routes to sign-in and remembers the intent (params.next) so
/// login can continue there.
EntrySurface resolveEntry(AuthPhase phase, Destination? intent) {
  if (phase == AuthPhase.resolving) return const EntrySurface(EntrySurfaceKind.splash);

  final dest = intent ?? kHome;

  if (phase == AuthPhase.authenticated) return EntrySurface(EntrySurfaceKind.app, dest);

  // unauthenticated
  if (isPublic(dest)) return EntrySurface(EntrySurfaceKind.public, dest);
  final next = dest.path == kHome.path ? null : dest.path;
  return EntrySurface(
    EntrySurfaceKind.public,
    Destination(kSignIn.path, next != null ? {'next': next} : null),
  );
}
