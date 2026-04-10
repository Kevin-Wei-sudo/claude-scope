# Apple Signing and Notarization Setup

This document is the minimum setup needed to ship `ClaudeScope` without macOS Gatekeeper warnings.

## Current state

The release pipeline currently builds and packages correctly, but `macos/scripts/build.sh` still uses ad-hoc signing:

```bash
codesign --force --sign - "$APP_BUNDLE"
```

That is enough for local testing, but not enough for public distribution through DMG, GitHub Releases, or Homebrew Cask.

## What you need before CI work

### 1. Apple Developer membership

You need an active Apple Developer Program account.

Without it, you cannot issue a `Developer ID Application` certificate or notarize the app.

### 2. A real bundle identifier

The app is currently using:

```text
io.sandwichlab.claudescope
```

For public release, use a stable reverse-domain identifier that you control:

```text
io.sandwichlab.claudescope
```

Location:

- [Info.plist](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/Resources/Info.plist)

### 3. Developer ID Application certificate

In Apple Developer / Keychain Access, create or download a certificate like:

```text
Developer ID Application: Your Name (TEAMID)
```

This is the signing identity used for the `.app` and usually also for the final `.dmg`.

### 4. Notarization credentials

Use one of these two approaches:

1. App Store Connect API key
2. Apple ID + app-specific password + Team ID

Recommended for CI: App Store Connect API key.

### 5. Sparkle compatibility

Sparkle signing is separate from Apple signing.

You already have `SPARKLE_PRIVATE_KEY` in the release workflow. Keep that.

Apple notarization does not replace Sparkle signing, and Sparkle signing does not replace Apple notarization.

## Recommended secret names for this repo

When we wire CI, use these repository secrets:

- `APPLE_SIGNING_CERT_BASE64`
- `APPLE_SIGNING_CERT_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `APPLE_SIGNING_IDENTITY`
- `APPLE_TEAM_ID`
- `APPLE_NOTARY_API_KEY_ID`
- `APPLE_NOTARY_API_ISSUER_ID`
- `APPLE_NOTARY_API_PRIVATE_KEY`
- `SPARKLE_PRIVATE_KEY`

Recommended variable:

- `APP_BUNDLE_ID`

Example value:

```text
io.kevinwei.claudescope
```

## What each secret is for

### `APPLE_SIGNING_CERT_BASE64`

A base64-encoded `.p12` export of your `Developer ID Application` certificate and private key.

Generate it locally from a `.p12`:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

### `APPLE_SIGNING_CERT_PASSWORD`

The export password used when creating that `.p12`.

### `APPLE_KEYCHAIN_PASSWORD`

A temporary password that CI uses for an ephemeral keychain.

This can be any strong random string.

### `APPLE_SIGNING_IDENTITY`

The exact identity string shown by `security find-identity`, for example:

```text
Developer ID Application: Kevin Wei (TEAMID)
```

### `APPLE_TEAM_ID`

Your Apple developer team ID.

### `APPLE_NOTARY_API_KEY_ID`

The App Store Connect API key ID.

### `APPLE_NOTARY_API_ISSUER_ID`

The issuer ID for that API key.

### `APPLE_NOTARY_API_PRIVATE_KEY`

The full contents of the `.p8` private key.

## One-time local preparation

### 1. Pick the final bundle ID

Before public notarized releases, update:

- [Info.plist](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/Resources/Info.plist)

### 2. Export the signing certificate

In Keychain Access:

1. Find your `Developer ID Application` certificate
2. Export it as `.p12`
3. Protect it with a password

### 3. Create an App Store Connect API key

Create a key with access suitable for notarization workflows, then save:

- Key ID
- Issuer ID
- `.p8` private key contents

### 4. Add GitHub secrets

In the `Kevin-Wei-sudo/claude-scope` repository, add the secrets listed above.

## What will change in CI later

Once the secrets exist, the release workflow should be extended to:

1. Import the `Developer ID Application` certificate into a temporary keychain
2. Codesign nested Sparkle items
3. Codesign `Sparkle.framework`
4. Codesign `ClaudeScope.app` with `--options runtime`
5. Build the DMG
6. Codesign the DMG
7. Submit the DMG or app to Apple with `notarytool`
8. Wait for approval
9. Staple the notarization ticket
10. Upload the notarized DMG and ZIP to the GitHub Release

## Suggested local verification commands

After we wire signing, these are the checks that should pass locally or in CI:

```sh
codesign --verify --deep --strict --verbose=2 macos/ClaudeScope.app
spctl --assess --type execute --verbose=4 macos/ClaudeScope.app
spctl --assess --type open --verbose=4 macos/ClaudeScope.dmg
```

## Important repo-specific notes

### Bundle ID

Use `io.sandwichlab.claudescope` for long-term public distribution.

### Homebrew

Your Homebrew tap now works, but Gatekeeper trust still depends on signed and notarized release artifacts.

Homebrew installation success does not mean macOS will allow the app to open.

### Release workflow

Current release workflow:

- [release.yml](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/.github/workflows/release.yml)

Current build script:

- [build.sh](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/scripts/build.sh)

These are the two places we should update next.

## Recommended next step

Once you have the Apple certificate, Team ID, and notary API key ready, the next step is to update the build script and GitHub Actions workflow to perform real signing and notarization automatically.
