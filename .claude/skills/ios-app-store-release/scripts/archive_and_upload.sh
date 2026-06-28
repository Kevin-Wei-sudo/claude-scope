#!/usr/bin/env bash
# ClaudeScope iOS —— 归档并上传到 App Store Connect。
# 前置：版本号已在 project.yml + Info.plist 同步递增；
#       build/ExportOptions.plist 已写回（见 reference/ExportOptions.md）。
# 用法：从仓库根目录运行  bash .claude/skills/ios-app-store-release/scripts/archive_and_upload.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT/ios/ClaudeScope"

echo "==> xcodegen generate"
xcodegen generate

echo "==> pod install"
pod install

echo "==> 确认 build/ExportOptions.plist 存在"
test -f build/ExportOptions.plist || {
  echo "缺少 build/ExportOptions.plist —— 见 reference/ExportOptions.md" >&2
  exit 1
}

echo "==> xcodebuild archive"
xcodebuild archive \
  -workspace ClaudeScope.xcworkspace \
  -scheme ClaudeScope \
  -configuration Release \
  -archivePath build/ClaudeScope.xcarchive \
  -destination 'generic/platform=iOS'

echo "==> xcodebuild -exportArchive (destination=upload)"
xcodebuild -exportArchive \
  -archivePath build/ClaudeScope.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist

echo "==> 完成。去 App Store Connect 等构建处理（5–15 分钟），再提交审核。"
