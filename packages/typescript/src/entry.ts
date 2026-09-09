/**
 * The entry gate — `AppState = { auth, intent }` → the surface to show
 * (docs/app-state.md). Auth is the OUTER switch; view/nav lives only inside the
 * authenticated branch. Shared + pure so both ports gate identically: the
 * `#/today`-on-signin incoherence is impossible because an unauthenticated
 * visitor's intent resolves to sign-in, and the URL reflects THAT.
 *
 * `intent` is a Destination — a canonical, scheme/host-agnostic deeplink path
 * (scenario-driven-development.md §4) that can be injected at launch. Each port
 * adapts URL/hash (web) or universal-link/scheme (Flutter) ↔ Destination.
 */

export type AuthPhase = "resolving" | "unauthenticated" | "authenticated";

/** A canonical destination — the deeplink target. `path` is the logical route
 *  incl. ids ("today", "inbox/voice/123", "settings/agent", "invite/{token}"). */
export interface Destination {
  path: string;
  /** Extra launch params not part of the route (e.g. onboarding step). */
  params?: Record<string, string>;
}

export const HOME: Destination = { path: "today" };
export const SIGN_IN: Destination = { path: "signin" };

/** Path heads reachable WITHOUT a session — public deeplinks that don't gate. */
const PUBLIC_HEADS = ["signin", "create", "reset", "invite", "launch", "welcome"];

/** True when a destination is reachable unauthenticated (no login gate). */
export function isPublic(dest: Destination): boolean {
  const head = dest.path.split("/")[0] ?? "";
  return PUBLIC_HEADS.includes(head);
}

export type EntrySurface =
  | { kind: "splash" }
  | { kind: "public"; dest: Destination }
  | { kind: "app"; dest: Destination };

/**
 * auth × intent → the surface, encoded once for both ports. Unauthenticated + a
 * protected intent routes to sign-in and remembers the intent (`params.next`) so
 * login can continue there. Onboarding/upsell branches slot into the
 * authenticated arm later without touching callers.
 */
export function resolveEntry(phase: AuthPhase, intent: Destination | null): EntrySurface {
  if (phase === "resolving") return { kind: "splash" };

  const dest = intent ?? HOME;

  if (phase === "authenticated") return { kind: "app", dest };

  // unauthenticated
  if (isPublic(dest)) return { kind: "public", dest };
  const next = dest.path === HOME.path ? undefined : dest.path;
  return { kind: "public", dest: { path: SIGN_IN.path, params: next ? { next } : undefined } };
}
