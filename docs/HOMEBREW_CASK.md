# Homebrew Cask Plan

This project already has most of the pieces needed for Homebrew Cask distribution:

- GitHub Releases are tag-driven
- the release workflow produces a stable DMG file name: `ClaudeScope.dmg`
- the app bundle name is stable: `ClaudeScope.app`

That means the remaining work is mostly release packaging and repository setup, not app code changes.

## Recommended Structure

Use this layout for your fork:

1. App repository
   This repository
   Owns source code, GitHub Releases, ZIP/DMG artifacts, Sparkle appcast

2. Homebrew tap repository
   Example: `yourname/homebrew-tap`
   Owns a cask file such as `Casks/claude-scope.rb`

This keeps app releases and Homebrew packaging separate, which is the standard Homebrew pattern for personal or niche apps.

## Install UX

Once the tap exists, users install with:

```sh
brew install --cask yourname/tap/claude-scope
```

And upgrade with:

```sh
brew upgrade --cask yourname/tap/claude-scope
```

## Release Requirements

Each GitHub Release should publish:

- `ClaudeScope.dmg`
- a version tag like `v0.1.0`

The cask should point to the DMG asset URL:

```text
https://github.com/<owner>/<repo>/releases/download/vX.Y.Z/ClaudeScope.dmg
```

## Cask Template

A starting template is included at:

`packaging/homebrew/claude-scope.rb.example`

Before publishing, replace:

- `__APP_VERSION__`
- `__DMG_SHA256__`
- `__OWNER__`
- `__REPO__`
- `__HOMEPAGE__`

You can get the SHA with:

```sh
shasum -a 256 macos/ClaudeScope.dmg
```

## Recommended Release Flow

For each release:

1. Push tag `vX.Y.Z`
2. Let GitHub Actions publish the DMG
3. Download or inspect the DMG SHA256
4. Update the cask in your tap repo
5. Push the tap change

## Optional Automation

If you want to reduce manual work later, you can automate step 4 with a second workflow that:

- waits for a GitHub Release
- computes or fetches the new SHA256
- opens a PR against your tap repo updating the cask

That is optional. Manual cask updates are perfectly fine at first.

## Notes

- Homebrew users usually expect a signed and ideally notarized app
- Sparkle and Homebrew can coexist: Homebrew handles install, Sparkle handles in-app updates
- If you prefer Homebrew-only upgrades, you can keep Sparkle disabled in your fork
