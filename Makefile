.PHONY: build app app-store zip dmg release-artifacts verify-release install clean

build:
	cd macos && swift build -c release

app:
	bash macos/scripts/build.sh

app-store:
	bash macos/scripts/build.sh --app-store

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
