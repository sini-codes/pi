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

5. Tag push triggers `.github/workflows/build-binaries.yml`: builds 6 platform binaries and
   publishes the GitHub release automatically (~10 min). Verify:

```powershell
gh run list --repo sini-codes/pi --workflow build-binaries.yml --limit 1
gh release view v<VERSION> --repo sini-codes/pi
```

6. Team picks it up via `pi update` or the installer one-liner:

```powershell
irm https://raw.githubusercontent.com/sini-codes/pi/feat/pwsh-parallel-tool/install.ps1 | iex
```

## Gotchas

- [ALWAYS] Run `npm run hydrate:model-data` after fresh clone before tests/checks — model JSON is generated, not committed
- [NEVER] Re-run a release for the same version after tag push; bump `N` and release again
- If CI fails at release-notes extraction, the CHANGELOG section heading does not match the tag version
- Fork-specific files to keep intact when rebasing on upstream: `install.ps1`, the `publish-npm: if false` patch in `build-binaries.yml`, GitHub-releases URL in `src/utils/version-check.ts`, binary self-update in `src/package-manager-cli.ts`
