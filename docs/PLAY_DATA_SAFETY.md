# Google Play — Data Safety form answers

Pre-filled answers for the Play Console "App content → Data safety" section,
based on what the Android app actually does (verified against
`io.sandwichlab.claudescope` source).

Update this doc whenever you add SDKs or new network calls — Google audits
this form and mismatches with reality can hold up review for weeks.

---

## Section 1: Data collection and security

**Does your app collect or share any of the required user data types?**

> **Yes** — for analytics / app functionality only. See per-category table below.

Reasoning summary:

- The OAuth access/refresh tokens are held only on-device (EncryptedSharedPreferences). Not collected or shared in the Play sense.
- Usage metrics (5h / 7d percentages) are device-local and only round-trip to Anthropic's API.
- **AppsFlyer** (`com.appsflyer:af-android-sdk`) is linked for install attribution + in-app event logging. See [AnalyticsService.kt](../android/app/src/main/kotlin/io/sandwichlab/claudescope/service/analytics/AnalyticsService.kt) for the full event surface.
- **Facebook SDK Core** (`com.facebook.android:facebook-core`) is linked for Meta attribution.
- Both SDKs collect the Google Advertising ID + device coarse identifiers for attribution.
- No crash reporter, no ad network, no server-side ClaudeScope account.

**Is all of the user data collected by your app encrypted in transit?**

> **Yes** — HTTPS for Anthropic endpoints, AppsFlyer, and Facebook.

**Do you provide a way for users to request that their data be deleted?**

> **Yes** — `Settings → Sign Out` deletes the encrypted token and clears on-device state. For analytics data deletion, users can email the developer contact or reset their advertising ID (which breaks further association).

---

## Section 2: Per-data-type declarations

The only categories Google cares about (given our SDKs):

| Category | Collected? | Shared? | Purpose | Optional? |
|----------|-----------|---------|---------|-----------|
| **Device or other IDs** (Advertising ID) | **Yes** | **Yes** (to AppsFlyer, Meta) | Analytics, Advertising or marketing | No — core attribution |
| **App activity → App interactions** (event names like `tab_selected`, `usage_fetched`) | **Yes** | **Yes** (to AppsFlyer) | Analytics | No |
| **App info and performance → Other app performance data** (install events) | **Yes** | **Yes** (to AppsFlyer, Meta) | Analytics | No |
| Personal info (name, email) | No | No | — Email obtained from `/userinfo` is held in process memory only and never transmitted to analytics SDKs | — |
| Financial info | No | No | — | — |
| Health, messages, photos, audio, files, calendar, contacts, location | No | No | — | — |
| Web browsing, Crash logs, Diagnostics | No | No | — | — |

When the form asks for user control: mark "No" for "Users can ask you to delete their data" specifically for Advertising ID — Google will accept this if we note that resetting the GAID effectively erases the linkage.

---

## Section 3: Security practices

| Question | Answer |
|----------|--------|
| Is your data encrypted in transit? | Yes |
| Can users request data deletion? | Partially — sign-out clears on-device; GAID reset removes analytics linkage |
| Have you committed to follow the [Play Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335)? | Not applicable — app is not targeted at children |

---

## Permissions on the manifest

| Permission | Why we declare it |
|------------|-------------------|
| `INTERNET` | OAuth flow + `/api/oauth/usage` polling + SDK network traffic |
| `ACCESS_NETWORK_STATE` | AppsFlyer / Facebook SDK connectivity detection |
| `POST_NOTIFICATIONS` | Required on Android 13+ to fire usage threshold alerts; only requested at runtime when the user toggles alerts on in Settings |
| `com.google.android.gms.permission.AD_ID` | Required on Android 13+ for AppsFlyer / FB SDK to read the Google Advertising ID used in install attribution |

---

## Privacy policy requirements

When linking privacy policy URL in Play Console, the policy **must** disclose:

- AppsFlyer as a data processor (GAID, IP, install/session timestamps, event names)
- Meta/Facebook SDK as a data processor (same categories + FB attribution IDs)
- User's ability to opt out via Android system "Delete advertising ID"
- Data retention windows (AppsFlyer default: 90 days of logs, 24 months of aggregated)

The existing iOS privacy policy at `https://kevin-wei-sudo.github.io/claude-scope/privacy.html` already mentions AppsFlyer — verify Meta is also called out before linking in Play Console. If not, update both iOS and Android to point at the same refreshed policy.
