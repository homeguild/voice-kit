/**
 * Pre-account DEVICE STATE — the shared, pure core of journey-testing axis 2
 * (docs/journey-testing.md). The state a device holds BEFORE an account exists
 * (new install?, app-open count, onboarding progress) plus the persona → state
 * resolver both ports run so a seeded persona means the same thing on web and
 * Flutter. The platform STORE (localStorage vs SharedPreferences) is per-port;
 * these types + `resolvePersona` are the shared part. Clock-injected so
 * time-derived values (days since install) are deterministic in tests.
 */

/** A clock seam — inject a fixed one in tests so relative times are stable. */
export interface Clock {
  now(): Date;
}

export const systemClock: Clock = { now: () => new Date() };

/** The persisted pre-account state. `firstOpenAt: null` ⇒ never opened. */
export interface DeviceState {
  firstOpenAt: string | null;
  appOpenCount: number;
  lastSeenAt: string | null;
  onboardingStep: number;
  dismissedPrompts: string[];
  waitlistState: "none" | "joined";
  abBucket: string | null;
}

/** A brand-new install — the default when nothing is persisted (fails safe). */
export const NEW_INSTALL: DeviceState = {
  firstOpenAt: null,
  appOpenCount: 0,
  lastSeenAt: null,
  onboardingStep: 0,
  dismissedPrompts: [],
  waitlistState: "none",
  abBucket: null,
};

/**
 * A named device persona — a fixture that seeds a journey's axis 2. Times are
 * RELATIVE (`firstOpenDaysAgo`) so the fixture is language-neutral and stable;
 * {@link resolvePersona} anchors them against a clock at seed time.
 */
export interface DevicePersona {
  id: string;
  title: string;
  state: {
    appOpenCount?: number;
    firstOpenDaysAgo?: number;
    lastSeenDaysAgo?: number;
    onboardingStep?: number;
    dismissedPrompts?: string[];
    waitlistState?: "none" | "joined";
    abBucket?: string | null;
  };
}

const DAY_MS = 86_400_000;

function daysAgo(clock: Clock, n: number | undefined): string | null {
  if (n == null) return null;
  return new Date(clock.now().getTime() - n * DAY_MS).toISOString();
}

/** Resolve a persona's relative times into an absolute {@link DeviceState}. */
export function resolvePersona(persona: DevicePersona, clock: Clock = systemClock): DeviceState {
  const s = persona.state;
  return {
    firstOpenAt: daysAgo(clock, s.firstOpenDaysAgo),
    appOpenCount: s.appOpenCount ?? 0,
    lastSeenAt: daysAgo(clock, s.lastSeenDaysAgo),
    onboardingStep: s.onboardingStep ?? 0,
    dismissedPrompts: s.dismissedPrompts ?? [],
    waitlistState: s.waitlistState ?? "none",
    abBucket: s.abBucket ?? null,
  };
}

/** Whole days since the device's first open, or null if it never opened. */
export function daysSinceInstall(state: DeviceState, clock: Clock = systemClock): number | null {
  if (!state.firstOpenAt) return null;
  return Math.floor((clock.now().getTime() - new Date(state.firstOpenAt).getTime()) / DAY_MS);
}

/** True for a device that has never been opened (the fresh-install branch). */
export function isFreshInstall(state: DeviceState): boolean {
  return state.appOpenCount === 0 && state.firstOpenAt === null;
}
