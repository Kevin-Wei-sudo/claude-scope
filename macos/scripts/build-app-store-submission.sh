#!/usr/bin/env bash
#
# Produce a signed .pkg suitable for Mac App Store Connect upload.
#
# Prerequisites (installed on this machine already — see
# `security find-identity -v`):
#   - "Apple Distribution: Asan KERMAN (MUC47AUXYQ)"
#   - "3rd Party Mac Developer Installer: Asan KERMAN (MUC47AUXYQ)"
#   - ClaudeScope Mac App Store provisioning profile in
#     ~/Library/MobileDevice/Provisioning Profiles/
#
# Output: macos/ClaudeScope.pkg
#
# Flow:
#   1. reuse `build.sh --app-store-local` to produce the .app bundle
#      (sandboxed, ad-hoc signed — we re-sign in step 4)
#   2. embed the Mac App Store provisioning profile
#   3. fix bundle metadata that App Store Connect rejects
#   4. re-sign with Apple Distribution + entitlements + hardened runtime
#   5. wrap into a .pkg signed with the installer identity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="ClaudeScope"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
PKG_PATH="$PROJECT_DIR/$APP_NAME.pkg"
ENTITLEMENTS="$PROJECT_DIR/Resources/ClaudeScope.entitlements"

DISTRIBUTION_IDENTITY="${DISTRIBUTION_IDENTITY:-Apple Distribution: Asan KERMAN (MUC47AUXYQ)}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-3rd Party Mac Developer Installer: Asan KERMAN (MUC47AUXYQ)}"
PROFILE_PATH="${PROFILE_PATH:-$HOME/Library/MobileDevice/Provisioning Profiles/ClaudeScope_Mac_App_Store.provisionprofile}"

cd "$PROJECT_DIR"

echo "==> Step 1/5: Building sandboxed .app (reusing app-store-local)"
bash "$SCRIPT_DIR/build.sh" --app-store-local

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Error: expected $APP_BUNDLE after build" >&2
    exit 1
fi

if [[ ! -f "$PROFILE_PATH" ]]; then
    echo "Error: provisioning profile not found at $PROFILE_PATH" >&2
    echo "Download it from developer.apple.com and install by opening the .provisionprofile file." >&2
    exit 1
fi

echo "==> Step 2/5: Embedding provisioning profile"
cp "$PROFILE_PATH" "$APP_BUNDLE/Contents/embedded.provisionprofile"

echo "==> Step 3/5: Scrubbing extended attributes + patching nested bundle Info.plists"
xattr -cr "$APP_BUNDLE"

# SwiftPM generates a resource bundle like `ClaudeScope_ClaudeScope.bundle`
# whose Info.plist only contains CFBundleDevelopmentRegion. App Store Connect
# validation rejects any nested bundle that lacks CFBundleIdentifier (error 409,
# "Missing Bundle Identifier"), so we patch it in here before re-signing.
MAIN_BUNDLE_ID="$("/usr/libexec/PlistBuddy" -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist")"
MAIN_VERSION="$("/usr/libexec/PlistBuddy" -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
MAIN_BUILD="$("/usr/libexec/PlistBuddy" -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"

while IFS= read -r nested_plist; do
    # Walk up until we hit a `.bundle` directory (handles both shallow SwiftPM
    # bundles and Contents/ wrappers).
    nested_bundle_dir="$(dirname "$nested_plist")"
    while [[ "$nested_bundle_dir" != "$APP_BUNDLE" && "$nested_bundle_dir" != *.bundle ]]; do
        nested_bundle_dir="$(dirname "$nested_bundle_dir")"
    done
    nested_name="$(basename "$nested_bundle_dir" .bundle)"
    # Stable suffix so a future signature over the same bundle is reproducible.
    nested_id="$MAIN_BUNDLE_ID.resources.${nested_name//_/-}"
    echo "    patching $nested_bundle_dir (id=$nested_id)"
    "/usr/libexec/PlistBuddy" -c "Add :CFBundleIdentifier string $nested_id" "$nested_plist" 2>/dev/null \
        || "/usr/libexec/PlistBuddy" -c "Set :CFBundleIdentifier $nested_id" "$nested_plist"
    "/usr/libexec/PlistBuddy" -c "Add :CFBundleName string $nested_name" "$nested_plist" 2>/dev/null || true
    "/usr/libexec/PlistBuddy" -c "Add :CFBundlePackageType string BNDL" "$nested_plist" 2>/dev/null || true
    "/usr/libexec/PlistBuddy" -c "Add :CFBundleShortVersionString string $MAIN_VERSION" "$nested_plist" 2>/dev/null || true
    "/usr/libexec/PlistBuddy" -c "Add :CFBundleVersion string $MAIN_BUILD" "$nested_plist" 2>/dev/null || true
done < <(
    # SwiftPM bundles on macOS are shallow (Info.plist at bundle root), but we
    # also match the regular nested `Contents/Info.plist` layout just in case.
    { find "$APP_BUNDLE" -path '*.bundle/Info.plist' 2>/dev/null
      find "$APP_BUNDLE" -path '*.bundle/Contents/Info.plist' 2>/dev/null; }
)

echo "==> Step 4/5: Re-signing with Apple Distribution"
# Frameworks / nested bundles first (App Store builds shouldn't have Sparkle
# embedded, but guard in case something else gets added later).
while IFS= read -r nested; do
    codesign --force --sign "$DISTRIBUTION_IDENTITY" \
             --options runtime \
             --timestamp \
             "$nested"
done < <(find "$APP_BUNDLE" \( -name "*.framework" -o -name "*.app" -o -name "*.xpc" -o -name "*.dylib" \) -type d -mindepth 1 2>/dev/null | sort -r)

codesign --force --sign "$DISTRIBUTION_IDENTITY" \
         --entitlements "$ENTITLEMENTS" \
         --options runtime \
         --timestamp \
         "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> Step 5/5: Building signed installer package"
rm -f "$PKG_PATH"
productbuild --component "$APP_BUNDLE" /Applications \
             --sign "$INSTALLER_IDENTITY" \
             "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"

echo
echo "==> Submission package ready: $PKG_PATH"
echo
echo "Upload with either method:"
echo "  A) Transporter.app (GUI, recommended first time):"
echo "       open -a Transporter \"$PKG_PATH\""
echo "  B) xcrun altool (CLI, needs APP_SPECIFIC_PASSWORD stored in keychain):"
echo "       xcrun altool --upload-app -f \"$PKG_PATH\" -t macos \\"
echo "         -u YOUR_APPLE_ID -p @keychain:ASC_APP_SPECIFIC_PASSWORD"
