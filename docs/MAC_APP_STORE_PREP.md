# Mac App Store Prep

This document is the shortest path from the current local project state to a first macOS App Store upload for `ClaudeScope`.

## Current project status

The repo already has an App Store-oriented build flavor:

- Bundle ID: `io.sandwichlab.claudescope`
- App Sandbox entitlement enabled
- Network client entitlement enabled
- Sparkle disabled in App Store builds
- App Store builds use `Application Support/ClaudeScope` instead of `~/.config/claude-scope`

Local command:

```sh
make app-store
```

That command currently produces a sandboxed local `.app`, but it is still ad-hoc signed.

## What is still missing

You still need:

1. An Apple Distribution signing certificate installed in Keychain
2. A `Mac App Store Connect` provisioning profile for `io.sandwichlab.claudescope`
3. A build path that signs with the App Store identity instead of ad-hoc signing
4. A way to archive/export and upload the build to App Store Connect

## What to prepare in Apple backend

### 1. Certificates

In Apple Developer:

- Go to `Certificates, Identifiers & Profiles`
- Create or download an Apple Distribution certificate for the team that owns the app

After installing it locally, this command should stop saying `0 valid identities found`:

```sh
security find-identity -v -p codesigning
```

### 2. Provisioning profile

In Apple Developer:

- Go to `Profiles`
- Create a new profile
- Type: `Mac App Store Connect`
- App ID: `io.sandwichlab.claudescope`
- Certificate: select the Apple Distribution certificate

Download the `.provisionprofile` file and open it to install it locally.

Installed profiles usually land in:

```text
~/Library/MobileDevice/Provisioning Profiles/
```

### 3. App Store Connect app record

In App Store Connect:

- Create the macOS app record
- Bundle ID: `io.sandwichlab.claudescope`
- SKU: for example `sandwichlab-claudescope-mac-001`

## Recommended local path from here

### Option A: Xcode-driven archive

This is the easiest first upload path.

1. Open the package folder in Xcode
2. Create or use a macOS app scheme for `ClaudeScope`
3. Set the team and signing identity
4. Use the installed Mac App Store provisioning profile
5. Archive the app
6. Validate the archive
7. Upload to App Store Connect

### Option B: Scripted signing/export

This is better for automation, but needs more repo work:

1. Build with `APP_STORE=1`
2. Embed the provisioning profile
3. Sign the app with the Apple Distribution identity and entitlements
4. Export an App Store package/archive
5. Upload with Transporter or Xcode

## Practical next step

Before we touch the signing script again, make sure these two local checks pass:

```sh
security find-identity -v -p codesigning
find "$HOME/Library/MobileDevice/Provisioning Profiles" -type f -name '*.provisionprofile'
```

Once both exist, the next coding step is to wire the actual App Store signing identity and embedded provisioning profile into `macos/scripts/build.sh`.
