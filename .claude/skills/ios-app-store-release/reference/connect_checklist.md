# App Store Connect 提交 checklist

## 构建上传后
- [ ] 等 5–15 分钟，构建从"正在处理"变为可选（TestFlight / 构建列表）。
- [ ] 收到 Apple 的处理完成邮件（或出现 ITMS 警告邮件，需处理）。

## 导出合规
- [ ] 项目 `Info.plist` 无 `ITSAppUsesNonExemptEncryption` → Connect 会问加密。
- [ ] 本 app 仅标准 HTTPS（豁免）→ 选"否 / 不使用非豁免加密"。
- [ ] 建议长期方案：给 `Info.plist` 加 `ITSAppUsesNonExemptEncryption = false`，免去每次手选。

## App 隐私（必须与 PrivacyInfo.xcprivacy 一致）
集成了 AppsFlyer + Meta(FBSDK) SDK，所以：
- [ ] 追踪（Tracking）= 是
- [ ] 数据类型：设备 ID（Device ID）—— 关联用户 + 用于追踪
- [ ] 数据类型：产品交互（Product Interaction）—— 关联用户 + 用于追踪
- [ ] 用途：分析（Analytics）+ 第三方广告（Third-Party Advertising）
- [ ] ATT 提示文案存在于 `Info.plist > NSUserTrackingUsageDescription`

## 提交版本
- [ ] 新建版本号（与 `MARKETING_VERSION` 一致）。
- [ ] 填写"本次更新内容"（What's New）。
- [ ] 选择刚处理完成的构建。
- [ ] 截图 / 描述 / 关键词无需每次改，复用即可（除非有 UI 变更）。
- [ ] 提交审核。

## 常见拒绝/坑
- 版本被标 "closed for new submissions"：marketing 版本必须进位到新 train。
- build 号重复：`project.yml` 的 `CURRENT_PROJECT_VERSION` 和 `Info.plist` 的
  `CFBundleVersion` 没同步，或没递增。
- 隐私清单与后台不一致：SDK 变更后同时改 `PrivacyInfo.xcprivacy` 和后台 Nutrition Label。
