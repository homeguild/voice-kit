// GENERATED from voice-kit/fixtures/device-personas.json by scripts/gen-personas.mjs.
// Do NOT edit — run `npm run gen:personas`. The JSON is the source of truth.
import type { DevicePersona } from "./device";

export const DEVICE_PERSONAS: DevicePersona[] = [
  {
    "id": "fresh_install",
    "title": "Brand-new install, never opened",
    "state": {}
  },
  {
    "id": "returning_unauth",
    "title": "Returning, not signed in — 3 opens over 5 days",
    "state": {
      "appOpenCount": 3,
      "firstOpenDaysAgo": 5,
      "lastSeenDaysAgo": 0
    }
  },
  {
    "id": "waitlisted",
    "title": "Joined the waitlist, one prior open",
    "state": {
      "appOpenCount": 1,
      "firstOpenDaysAgo": 2,
      "lastSeenDaysAgo": 2,
      "waitlistState": "joined"
    }
  },
  {
    "id": "onboarding_midway",
    "title": "Mid-onboarding — step 2 of the setup",
    "state": {
      "appOpenCount": 4,
      "firstOpenDaysAgo": 1,
      "lastSeenDaysAgo": 0,
      "onboardingStep": 2
    }
  },
  {
    "id": "lapsed",
    "title": "Long-time device, gone quiet 30 days",
    "state": {
      "appOpenCount": 12,
      "firstOpenDaysAgo": 90,
      "lastSeenDaysAgo": 30
    }
  }
];
