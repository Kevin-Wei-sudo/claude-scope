.PHONY: build app app-store-local app-store-submission zip dmg release-artifacts verify-release install clean \
        android-debug android-release-aab android-clean

build:
	cd macos && swift build -c release

app:
	bash macos/scripts/build.sh

# Produces a sandboxed, ad-hoc-signed .app for local verification only.
# NOT an App Store upload artifact — that requires Apple Distribution signing +
# a Mac App Store provisioning profile (see docs/MAC_APP_STORE_PREP.md).
app-store-local:
	bash macos/scripts/build.sh --app-store-local

# Produces a signed .pkg ready for Mac App Store Connect upload.
# Requires Apple Distribution + 3rd Party Mac Developer Installer identities
# in keychain and the ClaudeScope Mac App Store provisioning profile installed.
app-store-submission:
	bash macos/scripts/build-app-store-submission.sh

zip:
	bash macos/scripts/build.sh --zip
	bash macos/scripts/verify-release.sh macos/ClaudeScope.zip

dmg:
	bash macos/scripts/build.sh --dmg
	bash macos/scripts/verify-release.sh macos/ClaudeScope.dmg

release-artifacts:
	bash macos/scripts/build.sh --zip --dmg
	bash macos/scripts/verify-release.sh macos/ClaudeScope.zip
	bash macos/scripts/verify-release.sh macos/ClaudeScope.dmg

verify-release:
	bash macos/scripts/verify-release.sh macos/ClaudeScope.zip
	if [ -f macos/ClaudeScope.dmg ]; then bash macos/scripts/verify-release.sh macos/ClaudeScope.dmg; fi

install: app
	rm -rf /Applications/ClaudeScope.app
	cp -R macos/ClaudeScope.app /Applications/

clean:
	cd macos && swift package clean
	rm -rf macos/ClaudeScope.app macos/ClaudeScope.zip macos/ClaudeScope.dmg

# ---- Android ----
# Requires Android Studio or an ANDROID_HOME + JDK 17 environment.
# The gradlew wrapper is generated on first open in Android Studio; if you
# need it standalone, run `gradle wrapper --gradle-version 8.10` inside android/ once.

android-debug:
	cd android && ./gradlew assembleDebug

# Produces a signed AAB (release/app-release.aab) ready for Play Console upload.
# Requires android/keystore.properties pointing at your upload key — see
# docs/PLAY_SUBMISSION.md for setup.
android-release-aab:
	cd android && ./gradlew bundleRelease
	@echo "==> AAB output:"
	@ls -lh android/app/build/outputs/bundle/release/*.aab

android-clean:
	cd android && ./gradlew clean
