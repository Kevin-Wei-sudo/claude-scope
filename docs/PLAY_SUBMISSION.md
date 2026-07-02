# Google Play — first submission checklist

End-to-end recipe from "I have a Play Developer account approved" to "ClaudeScope is in production."

Account path: **US Organization** under B Green Financial Services LLC (D-U-N-S verified). Organization accounts skip the 12-tester / 14-day closed-test gate that personal accounts face — Step 7 below becomes optional once Step 0 passes.

---

## 0. Prerequisites

- [ ] Play Developer account approved (identity verification done) — **currently suspended, awaiting appeal**
- [x] Anthropic OAuth client `9d1c250a-e61b-44d9-88ed-5944d1962f5e` still active (we share this with iOS/macOS, no Play-specific change needed)
- [x] Privacy policy URL is publicly reachable — reuse `https://kevin-wei-sudo.github.io/claude-scope/privacy.html` from the iOS/macOS site

## Prep work that can be done while waiting on the account appeal

- [x] Audit code for data collection (AnalyticsService.kt, AndroidManifest) — matches [PLAY_DATA_SAFETY.md](PLAY_DATA_SAFETY.md)
- [x] Data Safety form answers drafted — see [PLAY_DATA_SAFETY.md](PLAY_DATA_SAFETY.md)
- [x] IARC Content Rating answers drafted — see [PLAY_CONTENT_RATING.md](PLAY_CONTENT_RATING.md)
- [x] Fastlane metadata (en-US + zh-CN title/short/full/changelog) reviewed — see [android/fastlane/metadata/android/](../android/fastlane/metadata/android/)
- [x] 512×512 app icon generated — `exports/play/icon_512.png` (regenerate via `python3 scripts/gen_play_assets.py`)
- [x] 1024×500 feature graphic generated — `exports/play/feature_graphic.png`
- [ ] Upload keystore generated — see Step 1 below (blocked: user must run `keytool` interactively)
- [ ] Signed release AAB built — see Step 2 below (blocked on keystore)
- [ ] Phone screenshots × 4 × 2 languages — see [PLAY_SCREENSHOTS.md](PLAY_SCREENSHOTS.md) (blocked on emulator session)

## 1. Generate the upload key (one-time, local-only)

Play App Signing keeps the *app* signing key on Google's side. You only need an *upload* key on your machine.

```sh
mkdir -p android/keystore
keytool -genkey -v \
  -keystore android/keystore/claudescope-upload.jks \
  -keyalg RSA -keysize 2048 -validity 25000 \
  -alias claudescope
```

Then create `android/keystore.properties` (already in `.gitignore`):

```properties
storeFile=keystore/claudescope-upload.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=claudescope
keyPassword=YOUR_KEY_PASSWORD
```

⚠️ Keep the keystore in a password manager / encrypted backup. Losing it means you can't push updates until you go through Google's key reset flow (1–2 weeks).

## 2. Build the release AAB

```sh
make android-release-aab
```

Output: `android/app/build/outputs/bundle/release/app-release.aab`

If `keystore.properties` is missing the build still produces an unsigned AAB — Play won't accept it. Check `gradlew bundleRelease` log for `Signing config "release" not found`.

## 3. Create the Play Console app

In Play Console → **Create app**:

- App name: ClaudeScope
- Default language: English (US)
- App or game: App
- Free or paid: Free
- Declarations: confirm Developer Program Policies + US export laws

## 4. Set the package name on first AAB upload

Go to **Internal testing** → **Create new release** → upload `app-release.aab`. Play Console binds the package name to your app the first time. Verify it shows `io.sandwichlab.claudescope`.

If you want **Play App Signing**, accept the prompt that appears on first upload ("Use Play App Signing"). Google will generate the app signing key; your local upload key signs the AAB you upload, Google re-signs it for distribution.

## 5. Fill the App content section (must be 100% green)

- [ ] **Privacy policy** — paste the iOS/macOS privacy URL
- [ ] **App access** — "All functionality is available without restrictions" (we have OAuth login but reviewers can install and see demo data without an account)
- [ ] **Ads** — No
- [ ] **Content rating** — fill the IARC questionnaire (see [PLAY_CONTENT_RATING.md](PLAY_CONTENT_RATING.md))
- [ ] **Target audience** — 18+ (developer tool, no children)
- [ ] **News app?** — No
- [ ] **COVID-19 contact tracing?** — No
- [ ] **Data safety** — paste from [PLAY_DATA_SAFETY.md](PLAY_DATA_SAFETY.md)
- [ ] **Government app?** — No
- [ ] **Financial features?** — No
- [ ] **Health features?** — No

## 6. Fill the Store listing

In **Main store listing**:

- [ ] **App name** — copy from `android/fastlane/metadata/android/en-US/title.txt`
- [ ] **Short description** — copy from `short_description.txt`
- [ ] **Full description** — copy from `full_description.txt`
- [ ] **App icon** — upload `images/icon/play_store_icon.png` (512×512)
- [ ] **Feature graphic** — upload `images/featureGraphic/feature.png` (1024×500)
- [ ] **Phone screenshots** — upload from `images/phoneScreenshots/`
- [ ] **App category** — Tools
- [ ] **Tags** — pick "Productivity", "Tools"
- [ ] **Contact details** — your email
- [ ] **External marketing** — None unless you want Play to push to other Google surfaces

In **Custom store listings → Simplified Chinese**: repeat with `zh-CN/` files.

## 7. Run the closed test (the 14-day clock starts here)

Required for personal Play developer accounts created after Nov 13, 2023.

- [ ] **Internal testing** track → upload AAB → release notes from `changelogs/1.txt`
- [ ] Add **at least 12 testers** to a Google Group (recommended — easier to manage than emails directly)
- [ ] Email/share the **opt-in URL** Play gives you
- [ ] Each tester has to install via the opt-in link AND open the app at least once
- [ ] Wait **14 calendar days** with all 12 actively testing

## 8. Promote to Production

Once the 14 days have elapsed:

- [ ] Production track → Create new release → reuse the same AAB (or upload a fresh one)
- [ ] Roll out to **20%** initially (lower blast radius if anything breaks)
- [ ] First production review takes 1–7 days; subsequent updates 2–24 hours

## 9. Post-launch quick wins

- Set up **Play Developer Reporting API** key for download/uninstall metrics
- Enable **Pre-launch reports** (free automated testing on real Pixel hardware)
- Hook **Play Console → Crashes & ANRs** into your week-1 retro

## Versioning recipe

Each AAB upload requires a new `versionCode`. Convention to mirror iOS:

| iOS / macOS `CFBundleShortVersionString` | Android `versionName` | Android `versionCode` |
|------------------------------------------|----------------------|----------------------|
| 0.1.0 | 0.1.0 | 1 |
| 0.1.1 | 0.1.1 | 2 |
| 1.0.0 | 1.0.0 | 100 |
| 1.0.1 | 1.0.1 | 101 |

Bump both fields in [android/app/build.gradle.kts](../android/app/build.gradle.kts) before each release tag.
