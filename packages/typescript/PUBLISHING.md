# Publishing `@homeguild/conversation-kit`

Private package, served from **GitHub Packages** (npm.pkg.github.com). Not on the
public npm registry, not open source. The apps consume it privately; this doc is
the one-`npm publish`-away flow.

## What ships

Only `src/` (TypeScript source) — see `files` in `package.json`. Consumers
transpile it (Next.js `transpilePackages`), so there's no build step here. The
`prepublishOnly` script gates every publish on `typecheck` + `test`.

## One-time auth

Create a GitHub Personal Access Token (classic) with **`read:packages`** and
**`write:packages`** scopes, then expose it as `NODE_AUTH_TOKEN`:

```bash
export NODE_AUTH_TOKEN=ghp_xxx   # never commit this
```

The committed `.npmrc` maps the `@homeguild` scope to GitHub Packages and reads
the token from that env var — no secret is ever stored in the repo.

## Publish

```bash
cd packages/typescript
npm version patch          # or minor/major — GH Packages rejects re-publishing a version
npm publish                # prepublishOnly runs typecheck + tests first
```

`publishConfig` targets GitHub Packages with `access: restricted` (private).

## Consuming it (the apps)

**Local dev** keeps the fast sibling dependency — no registry, no publish, instant
hot-reload against kit edits:

```jsonc
// apps/triclinium/package.json
"@homeguild/conversation-kit": "file:../../../voice-kit/packages/typescript"
```

**CI / deploy** resolves a published version from GitHub Packages instead. In the
app repo:

1. Add an `.npmrc` (same scope mapping as here) so `npm install` can find the
   scope:
   ```
   @homeguild:registry=https://npm.pkg.github.com
   //npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}
   ```
2. Point the dependency at a version for the deployed build:
   ```jsonc
   "@homeguild/conversation-kit": "^0.1.0"
   ```
   (Keep the `file:` override locally — e.g. via a git-ignored `.npmrc`/overrides,
   or a separate lockfile — so day-to-day iteration doesn't need a publish.)
3. **Jenkins:** inject `NODE_AUTH_TOKEN` into the Triclinium build environment
   before `npm ci` / `npm install`.

`next.config.ts` already handles both modes: it widens the Turbopack root only
when the sibling checkout is present (local), and leaves it pinned to the app
when it isn't (CI, where the kit is a normal `node_modules` install). No change
needed there.

## Future hardening (optional)

Publishing TS source means every consumer must transpile it. If a consumer ever
can't (some bundlers won't process `node_modules` TS), add a build step here
(`tsup`/`tsc` → `dist/` with `.js` + `.d.ts`) and repoint `main`/`types`/`exports`
at `dist`. Not needed while Triclinium (which transpiles) is the only consumer.
