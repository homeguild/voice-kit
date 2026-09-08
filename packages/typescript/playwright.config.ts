import { defineConfig } from "@playwright/test";

/**
 * Visual goldens for the React port — the twin of the Flutter golden_toolkit
 * suite. Each scenario (from the shared fixtures) is rendered to static HTML and
 * screenshotted in a pinned Chromium; the PNG baseline is the L2 gate. Baselines
 * are platform-suffixed (goldens are platform-sensitive), so regenerate on the
 * CI runner's OS. Update with:  npx playwright test --update-snapshots
 */
export default defineConfig({
  testDir: "./visual",
  fullyParallel: true,
  use: {
    viewport: { width: 420, height: 900 },
  },
  expect: {
    // A little tolerance for sub-pixel AA differences; catches real changes.
    toHaveScreenshot: { maxDiffPixelRatio: 0.01 },
  },
  projects: [{ name: "chromium", use: { browserName: "chromium" } }],
});
