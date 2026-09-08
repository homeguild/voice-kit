import { defineConfig } from "vitest/config";

// Unit/contract layer only. The visual goldens (visual/*.spec.ts) are Playwright's
// — kept out of vitest so the two runners don't fight over the same files.
export default defineConfig({
  test: {
    include: ["test/**/*.test.{ts,tsx}"],
  },
});
