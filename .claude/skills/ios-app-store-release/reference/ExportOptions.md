# ExportOptions plist（被 .gitignore，发版前写回）

两个文件都放在 `ios/ClaudeScope/build/` 下。区别只有 `destination`：
- `ExportOptions.plist` → `upload`：导出时直接上传 App Store Connect。
- `ExportOptions-local.plist` → `export`：只在本地产出 `.ipa`，之后用 Transporter 手动传。

## build/ExportOptions.plist（直接上传）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>MUC47AUXYQ</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>io.sandwichlab.claudescope</key>
        <string>ClaudeScope iOS App Store</string>
    </dict>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
```

## build/ExportOptions-local.plist（仅本地导出 .ipa）

同上，仅最后 `destination` 改为：

```xml
    <key>destination</key>
    <string>export</string>
```
