/// Pre-account DEVICE STATE — the shared core of journey-testing axis 2
/// (docs/journey-testing.md). The 1:1 Dart mirror of the TS `device.ts`: the
/// state a device holds BEFORE an account exists, plus the persona → state
/// resolver both ports run so a seeded persona means the same thing on web and
/// Flutter. The platform store (SharedPreferences vs localStorage) is per-port;
/// these types + [resolvePersona] are the shared part. Clock-injected so
/// time-derived values are deterministic in tests.

/// A clock seam — inject a fixed one in tests so relative times are stable.
class Clock {
  const Clock(this.now);
  final DateTime Function() now;
}

final Clock systemClock = Clock(DateTime.now);

/// The persisted pre-account state. `firstOpenAt == null` ⇒ never opened.
class DeviceState {
  const DeviceState({
    required this.firstOpenAt,
    required this.appOpenCount,
    required this.lastSeenAt,
    required this.onboardingStep,
    required this.dismissedPrompts,
    required this.waitlistState,
    required this.abBucket,
  });

  final String? firstOpenAt;
  final int appOpenCount;
  final String? lastSeenAt;
  final int onboardingStep;
  final List<String> dismissedPrompts;
  final String waitlistState; // none | joined
  final String? abBucket;
}

/// A brand-new install — the default when nothing is persisted (fails safe).
const DeviceState kNewInstall = DeviceState(
  firstOpenAt: null,
  appOpenCount: 0,
  lastSeenAt: null,
  onboardingStep: 0,
  dismissedPrompts: [],
  waitlistState: 'none',
  abBucket: null,
);

/// A named device persona — a fixture that seeds a journey's axis 2. Times are
/// RELATIVE (`firstOpenDaysAgo`) so the fixture is stable; [resolvePersona]
/// anchors them against a clock at seed time.
class DevicePersona {
  const DevicePersona({required this.id, required this.title, required this.state});

  final String id;
  final String title;
  final Map<String, dynamic> state;
}

const int _dayMs = 86400000;

String? _daysAgo(Clock clock, Object? n) {
  if (n == null) return null;
  final ms = clock.now().millisecondsSinceEpoch - (n as num).toInt() * _dayMs;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
}

/// Resolve a persona's relative times into an absolute [DeviceState]. The clock
/// defaults to [systemClock] (a non-const closure can't be a default value).
DeviceState resolvePersona(DevicePersona persona, [Clock? clock]) {
  final c = clock ?? systemClock;
  final s = persona.state;
  return DeviceState(
    firstOpenAt: _daysAgo(c, s['firstOpenDaysAgo']),
    appOpenCount: (s['appOpenCount'] as int?) ?? 0,
    lastSeenAt: _daysAgo(c, s['lastSeenDaysAgo']),
    onboardingStep: (s['onboardingStep'] as int?) ?? 0,
    dismissedPrompts:
        ((s['dismissedPrompts'] as List?)?.cast<String>()) ?? const [],
    waitlistState: (s['waitlistState'] as String?) ?? 'none',
    abBucket: s['abBucket'] as String?,
  );
}

/// Whole days since the device's first open, or null if it never opened.
int? daysSinceInstall(DeviceState state, [Clock? clock]) {
  final first = state.firstOpenAt;
  if (first == null) return null;
  final c = clock ?? systemClock;
  final ms = c.now().millisecondsSinceEpoch - DateTime.parse(first).millisecondsSinceEpoch;
  return ms ~/ _dayMs;
}

/// True for a device that has never been opened (the fresh-install branch).
bool isFreshInstall(DeviceState state) =>
    state.appOpenCount == 0 && state.firstOpenAt == null;
