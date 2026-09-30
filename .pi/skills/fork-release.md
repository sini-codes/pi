---
name: fork-release
description: Release a new version of this pwsh fork (sini-codes/pi) to the team via GitHub Releases. Use when asked to release, publish, ship, or distribute a fork update.
---

# Fork Release (sini-codes/pi)

This repo is a fork of earendil-works/pi with native pwsh support on branch `feat/pwsh-parallel-tool`.
Distribution is GitHub Releases only (npm publishing disabled in CI). Team installs/updates via
`install.ps1`; `pi update` on binary installs hands off to that installer; startup version checks
hit `https://api.github.com/repos/sini-codes/pi/releases/latest`.

- Remotes: `origin` = upstream `earendil-works/pi` (read-only), `fork` = `sini-codes/pi` (push target)
- Version scheme: `<upstream-base>-pwsh.<N>`, e.g. `0.82.1-pwsh.2`. Bump `N` for fork changes; adopt new base after rebasing on newer upstream (e.g. `0.83.0-pwsh.1`)
- Tag = `v` + exact version. [NEVER] reuse or re-push a tag; make a new version instead
- All packages version in lockstep; CI extracts release notes from the CHANGELOG section matching the version exactly

## Release steps

1. Bump versions and sync inter-package deps:

```powershell
$env:npm_config_min_release_age = "0"   # bypass npm age gate for lockfile ops
npm version <VERSION> -ws --no-git-tag-version
node scripts/sync-versions.js
```

2. Regenerate lockfiles (version is baked into them):

```powershell
npm install --package-lock-only --ignore-scripts
node scripts/generate-coding-agent-shrinkwrap.mjs
node scripts/generate-coding-agent-install-lock.mjs
```

3. Add a `## [<VERSION>] - YYYY-MM-DD` section at the top of `packages/coding-agent/CHANGELOG.md`
   with the changes. [MUST] Heading version matches exactly — CI extracts it as release notes and
   fails without it.

4. Commit, tag, push tag to fork:

```powershell
$env:PI_ALLOW_LOCKFILE_CHANGE = "1"
git add <changed files>   # package.json files, lockfiles, CHANGELOG
git commit -m "release: v<VERSION>"
git tag v<VERSION>
git push fork feat/pwsh-parallel-tool v<VERSION>
```

5. Dispatch the build workflow manually — tag pushes do NOT auto-trigger CI on this fork
   (observed on every release so far). The run builds 6 platform binaries and publishes the
   GitHub release automatically (~3 min):

```powershell
gh workflow run build-binaries.yml --repo sini-codes/pi --ref v<VERSION> -f tag=v<VERSION>
gh run list --repo sini-codes/pi --workflow build-binaries.yml --limit 1   # grab run id
gh run watch <RUN_ID> --repo sini-codes/pi --exit-status
gh release view v<VERSION> --repo sini-codes/pi
```

6. Team picks it up via `pi update` or the installer one-liner:

```powershell
irm https://raw.githubusercontent.com/sini-codes/pi/feat/pwsh-parallel-tool/install.ps1 | iex
```

## Gotchas

- [NEVER] Let internal `@earendil-works/*` deps use caret ranges (`^<base>-pwsh.N`). Upstream now publishes plain releases to npm, and semver ranks `0.84.4` above `0.84.4-pwsh.N`, so npm installs a real nested registry copy under `packages/coding-agent/node_modules/` instead of the workspace symlink. That breaks `build-coding-agent-bundle.mjs` (bundle inputs no longer match `packages/ai/dist/...`). `scripts/sync-versions.js` pins fork versions exactly; if nested `packages/*/node_modules/@earendil-works/` directories appear (any workspace, not just coding-agent), delete them ALL before regenerating the lockfile — npm records leftover physical copies into a fresh lock even with `--package-lock-only`. Regenerate with root `node_modules` renamed away AND `node_modules/.package-lock.json` deleted, then verify `npm run build` before tagging.
- [ALWAYS] Run a full local `npm run build` (bundle included) before pushing the tag — CI failures burn the tag and force a version bump.

- [ALWAYS] Run `npm run build` (full workspace, from repo root) after releasing or changing source if a global npm-linked `pi` points at this repo — the link executes compiled `dist/`, and stale dist keeps old behavior (e.g. old pi.dev version checker showing bogus "new version" notices). CI binaries are unaffected.
- [ALWAYS] Keep the `-pwsh.N` suffix in every version/tag. Prerelease semver compares below the bare base version: a plain `0.82.1` tag would rank above `0.82.1-pwsh.N` yet below nothing useful, and clients on suffixed versions would stop seeing updates.
- [ALWAYS] Run `npm run hydrate:model-data` after fresh clone before tests/checks — model JSON is generated, not committed
- [NEVER] Re-run a release for the same version after tag push; bump `N` and release again
- If CI fails at release-notes extraction, the CHANGELOG section heading does not match the tag version
- Fork-specific files to keep intact when rebasing on upstream: `install.ps1`, the `publish-npm: if false` patch in `build-binaries.yml`, GitHub-releases URL in `src/utils/version-check.ts`, binary self-update in `src/package-manager-cli.ts`
