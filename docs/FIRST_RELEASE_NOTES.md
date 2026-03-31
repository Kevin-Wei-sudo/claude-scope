# ClaudeScope v0.1.0

First public release of ClaudeScope, a macOS menu bar app for checking Claude usage at a glance.

## Highlights

- Renamed the project from `Claude Usage Bar` to `ClaudeScope`
- Added Simplified Chinese localization and in-app language switching
- Improved Chinese UI copy and polling interval labels
- Added a one-line install script
- Added Homebrew Cask packaging guidance and template
- Kept the menu bar usage view, history chart, OAuth sign-in flow, and Sparkle update support

## Install

- DMG: download `ClaudeScope.dmg` from this release
- Homebrew:

```sh
brew install --cask Kevin-Wei-sudo/tap/claude-scope
```

- Script:

```sh
curl -fsSL https://raw.githubusercontent.com/Kevin-Wei-sudo/claude-scope/main/scripts/install.sh | bash
```

## Notes

- Requires macOS 14+
- Local source builds keep Sparkle auto-update disabled unless `SU_FEED_URL` is injected during packaging
- Existing local data from earlier `claude-usage-bar` builds is still read for compatibility
