# Google Play — Screenshot capture guide

## Required asset checklist

| Asset | Spec | Required? |
|-------|------|-----------|
| App icon | 512 × 512 PNG, 32-bit, ≤ 1 MB | **Yes** — uploaded directly in Play Console (separate from the in-APK icon) |
| Feature graphic | 1024 × 500 PNG/JPG, no alpha | **Yes** — appears at the top of the Play listing |
| Phone screenshots | 1080 × 1920 (or 1440 × 2560), portrait, 16:9, 24-bit PNG | **Yes** — at least 2, recommended 4–8 |
| 7-inch tablet | 1200 × 1920 portrait | Optional — skip unless you want tablet visibility |
| 10-inch tablet | 1600 × 2560 portrait | Optional |
| Promo video URL | YouTube link | Optional |

## Which screens to capture

Aim for 4 phone screenshots that tell a story top-to-bottom:

1. **Home** — show the Today's Snapshot card big "42%" + 5h/7d windows + Model Focus + Trend preview. Use demo data (signed-out state) so it always looks healthy.
2. **History** — Trend Line + 7D selected + Model Split + Recent Snapshots
3. **Settings** — Account card (signed in state, optional email blurred) + Notifications enabled with threshold slider visible
4. **Widget tab** — Live preview card showing the in-app preview of the home-screen widget

If you want 6, add:
5. Sign-in flow — SignInCard with code paste field
6. Home screen with the Medium widget pinned (take a real home-screen screenshot)

## How to capture

### From the emulator (recommended)

1. In Android Studio, start a Pixel 7 / Pixel 8 emulator, **API 35**, **arm64**
2. Run the app
3. Open **Extended controls** (`...` button on emulator toolbar) → **Camera** is irrelevant; use the Camera icon in the side toolbar to take a screenshot — saves to `~/Desktop` by default
4. Resolution depends on emulator profile. Pixel 7 = 1080 × 2400 (close enough to 1080 × 1920 — Play accepts 1080 × 2400 too)
5. Crop / pad in Preview if Play complains about aspect ratio

### From a real device (cleaner result)

1. Connect via USB
2. App → screen you want
3. `adb shell screencap -p /sdcard/shot.png && adb pull /sdcard/shot.png`
4. Repeat per screen

### Status bar tips

- For polish, hide developer notifications via the emulator's "Demo mode" or a real device's "Demo mode" (Settings → System → Developer options → System UI demo mode → Show)
- Battery 100%, time 09:00, no carrier badge

## Frames (optional but improves perceived quality)

Use Google's free [Device Art Generator](https://developer.android.com/distribute/marketing-tools/device-art-generator) to wrap each screenshot in a Pixel 8 frame. Output is exactly the right Play dimensions.

## Feature graphic (1024 × 500)

Quick recipe that doesn't need design tools:

- Background: solid teal `#2E8C80` matching app theme
- Left side: app icon (512×512) padded to 60% height, vertically centered
- Right side: white text "ClaudeScope" (display weight) above terracotta `#CC6B4A` text "Your Claude usage, without the guessing."

Templates in Figma / Canva ("Google Play Feature Graphic") finish this in 5 minutes.

## Where to put the files

Save final exports under `android/fastlane/metadata/android/<lang>/images/`:

```
android/fastlane/metadata/android/en-US/images/
├── icon/play_store_icon.png             # 512x512
├── featureGraphic/feature.png            # 1024x500
└── phoneScreenshots/
    ├── 01_home.png
    ├── 02_history.png
    ├── 03_settings.png
    └── 04_widget.png
```

Same layout under `zh-CN/` if you want a localized listing visual (recommended — Chinese users see English screenshots as a red flag).
