---
name: ios-app-store-release
description: >-
  ClaudeScope iOS App Store 发版完整流程。触发词："iOS 上架"、"发 iOS 新版本"、
  "提交 App Store"、"打包 iOS"、"iOS release"、"bump iOS 版本"、"上 TestFlight"。
  覆盖：版本号递增 → xcodegen/pod → xcodebuild archive/export 上传 App Store Connect →
  Connect 后台元数据/隐私清单/导出合规 → 提交审核。仅针对 ios/ClaudeScope。
---

# ClaudeScope iOS App Store 发版

针对仓库里的 `ios/ClaudeScope`（bundle `io.sandwichlab.claudescope`，team `MUC47AUXYQ`）。
全程在本机用命令行 + Xcode 完成；没有 CI/fastlane。

## 0. 一次性前置（首发或换机时确认）

这些只需配置一次，发版前用命令核对即可：

```sh
# 1) 必须能看到 Apple Distribution 证书
security find-identity -v -p codesigning | grep "Apple Distribution"
# 2) 必须装好描述文件 "ClaudeScope iOS App Store"
ls "$HOME/Library/MobileDevice/Provisioning Profiles/"
# 3) 工具链
which xcodegen pod        # brew install xcodegen cocoapods
xcodebuild -version       # 需要 Xcode 16
```

还需要：App Store Connect 里已建好 app 记录（bundle `io.sandwichlab.claudescope`）。

> ⚠️ `ios/ClaudeScope/build/` 和 `Pods/`、`*.xcodeproj`、`*.xcworkspace` 都在 `.gitignore` 里，
> clone 后是空的。`ExportOptions.plist` 也不在仓库里 —— 见 [reference/ExportOptions.md](reference/ExportOptions.md)，
> 发版前先把两个 plist 写回 `ios/ClaudeScope/build/`。

## 1. 递增版本号（两处必须同步！）

iOS 的 build 号（`CFBundleVersion`）在同一 marketing 版本下必须**唯一且递增**，否则上传被拒。
本项目有个坑：build 号在**两个文件里都写死了**，必须一起改：

| 文件 | 字段 | 说明 |
|------|------|------|
| `ios/ClaudeScope/project.yml` | `MARKETING_VERSION` | 面向用户的版本，如 `1.0.6` |
| `ios/ClaudeScope/project.yml` | `CURRENT_PROJECT_VERSION` | build 号，如 `9` |
| `ios/ClaudeScope/Info.plist` | `CFBundleVersion` | **硬编码**，必须等于上面的 build 号 |

（`CFBundleShortVersionString` 用 `$(MARKETING_VERSION)` 变量，会自动同步，不用手改。）

发版规则：
- **同一 marketing 版本重传**（修审核问题）：只 +1 build 号（如 1.0.6 (9) → 1.0.6 (10)）。
- **新功能/新版本**：marketing 版本进位，build 号继续 +1。
- 若某个版本号被 App Store Connect 标记 "closed for new submissions"（被拒/过期），
  marketing 版本要**进位到新 train**（参考 commit `9943fab`：1.0.5 关闭 → 开 1.0.6）。

## 2. 生成工程并归档上传

在 `ios/ClaudeScope/` 下按顺序执行。脚本见 [scripts/archive_and_upload.sh](scripts/archive_and_upload.sh)，
等价于：

```sh
cd ios/ClaudeScope

# 从 project.yml 重新生成 .xcodeproj
xcodegen generate

# 重新生成 Pods + .xcworkspace（AppsFlyer + FBSDKCoreKit）
pod install

# 归档（注意是 workspace + scheme，不是 project）
xcodebuild archive \
  -workspace ClaudeScope.xcworkspace \
  -scheme ClaudeScope \
  -configuration Release \
  -archivePath build/ClaudeScope.xcarchive \
  -destination 'generic/platform=iOS'

# 导出并直接上传到 App Store Connect
# build/ExportOptions.plist 里 destination=upload（见 reference/ExportOptions.md）
xcodebuild -exportArchive \
  -archivePath build/ClaudeScope.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist
```

> 想先本地产出 `.ipa` 再用 Transporter 手动上传：把 `-exportOptionsPlist`
> 换成 `build/ExportOptions-local.plist`（`destination=export`），产物在 `build/export/ClaudeScope.ipa`。

成功标志：`xcodebuild -exportArchive` 末尾出现 `EXPORT SUCCEEDED` 且无 upload 报错。
**不要**只看 archive 成功就报告完成 —— 真正的成功是 Connect 后台几分钟后出现新构建。

## 3. App Store Connect 后台

构建上传后 5–15 分钟会在 TestFlight / "构建" 列表里出现（先 "正在处理"）。

1. **导出合规**：本项目 `Info.plist` **没有** `ITSAppUsesNonExemptEncryption`，
   所以每次提交 Connect 都会问"是否使用加密"。本 app 只用标准 HTTPS（豁免），选"否"即可。
   想一劳永逸：给 `Info.plist` 加 `ITSAppUsesNonExemptEncryption = false`（建议，省去每次手选）。
2. **App 隐私（Nutrition Label）**：因为集成了 AppsFlyer + Meta SDK，**追踪 = 是**。
   数据类型须与 [PrivacyInfo.xcprivacy](../../../ios/ClaudeScope/PrivacyInfo.xcprivacy) 一致：
   - 设备 ID（Device ID）—— 关联到用户 + 用于追踪
   - 产品交互（Product Interaction）—— 关联到用户 + 用于追踪
   - 用途：分析 + 第三方广告
   ATT 文案在 `Info.plist` 的 `NSUserTrackingUsageDescription`。
3. 新建版本 → 填 "本次更新内容" → 选刚处理好的构建 → 提交审核。

详细 checklist 见 [reference/connect_checklist.md](reference/connect_checklist.md)。

## 4. 提交后

- 提交前/后 commit 版本号改动。commit 信息沿用项目风格：
  `iOS 1.0.6 (9): <一句话说明>`（见 git log）。
- 遵守用户全局规则：**显式 `git add <path>`**，不要 `git add -A`；
  `build/`、`Pods/` 已被 gitignore，确认 `git status` 只动了 `project.yml` / `Info.plist` / 源码。
- 审核状态在 App Store Connect 查看，不要凭"上传成功"就报告"已上架"。
