# Usage Intelligence PRD Draft

## Summary

`Usage Intelligence` is the premium product layer for ClaudeScope.

It upgrades ClaudeScope from a passive usage viewer into an active usage coach that helps users:

- predict when they may hit limits
- receive proactive reminders before they run into trouble
- get actionable suggestions to save usage or use spare capacity better

This document defines the product structure for:

- Predictions
- Alerts
- Suggestions

It also includes a mac-first implementation plan based on the current ClaudeScope codebase.

## Why This Matters

Claude usage tracking alone is useful, but it is easy for competitors to replicate.

The defensible value is not only:

- showing the current percentage

The stronger product value is:

- forecasting what is likely to happen next
- warning the user before they get blocked
- telling the user what to do about it

That is the core of `Usage Intelligence`.

## Product Positioning

Current positioning:

- Claude usage tracker

Target positioning:

- Track your limits
- Predict your usage
- Use Claude smarter

Internal shorthand:

- `Usage Intelligence`
- Chinese internal shorthand: `用量智能`

## Users

### Primary Users

- Heavy Claude users who frequently approach 5-hour or 7-day limits
- Developers, writers, researchers, and operators who depend on Claude daily
- Users who want to avoid being interrupted mid-session

### Secondary Users

- Light users who want to improve ROI from their Claude subscription
- Users who want reminders about reset times or unused capacity

## User Problems

Users currently struggle with:

- not knowing when they will hit a usage ceiling
- realizing they are near a limit too late
- not knowing which model is driving most of the usage
- not knowing whether to save usage or use more of it
- not knowing when they should wait for reset versus continue working

## Product Goals

### Core Goals

1. Help users avoid unexpected limit collisions
2. Help users make better use of their available Claude budget
3. Give users concrete, personalized, low-friction guidance

### Business Goals

1. Create clear paid differentiation from simple tracking apps
2. Make ClaudeScope valuable enough for one-time purchase or Pro unlock
3. Create a premium feature layer that can later extend to iOS and widgets

## Non-Goals

For the initial mac-first release, this feature set will not:

- change the user's Claude prompts automatically
- optimize prompts on the user's behalf
- require cloud-based analytics
- depend on LLM-generated advice for the MVP

The MVP should be rules-based and local-first.

## Product Modules

Usage Intelligence has 3 user-facing modules:

1. Predictions
2. Alerts
3. Suggestions

---

## 1. Predictions

### Goal

Answer:

- What is likely to happen next?

### Feature 1.1: Limit Collision Prediction

Predict when the user is likely to enter a high-risk state for:

- 5-hour window
- 7-day window

Use recent slopes from:

- last 30 minutes
- last 2 hours
- last 24 hours
- last 7 days

Example outputs:

- `At your current pace, you may reach the 5-hour high-risk zone in 2.1 hours`
- `At your current pace, you are unlikely to hit your 7-day limit today`

### Feature 1.2: Reset-Aware Safe Budget

Estimate how much the user can safely consume before the next reset.

Example outputs:

- `Before the next 5-hour reset, try to keep this window under another 18%`
- `You likely have 34% of weekly headroom remaining`

### Feature 1.3: Peak-Time Forecast

Identify the user's historically risky time periods.

Example outputs:

- `Weeknights from 8 PM to 10 PM are your highest-pressure hours`
- `Tuesday afternoon is your most likely 7-day acceleration window`

### Feature 1.4: Model Pressure Forecast

Estimate which model is contributing most to future pressure.

Example outputs:

- `Sonnet is currently driving most of your weekly pressure`
- `Opus usage is low and unlikely to change this window much`

---

## 2. Alerts

### Goal

Answer:

- Should the user be notified now?

### Feature 2.1: Threshold Alerts

Support configurable alerts for:

- 5-hour window
- 7-day window
- extra usage

Suggested threshold presets:

- 50%
- 70%
- 80%
- 90%
- 95%

Default recommendation:

- 80%
- 90%

### Feature 2.2: Reset Alerts

Support:

- pre-reset reminders
- post-reset reminders

Examples:

- `5-hour reset in 30 minutes`
- `Weekly budget has reset`

### Feature 2.3: Peak-Time Alerts

Alert before the user's historically risky usage periods.

Examples:

- `You usually burn usage quickly between 8 PM and 10 PM`
- `This is one of your highest-risk windows`

### Feature 2.4: Anomaly Alerts

Detect unusually high or unusually low usage relative to the user's baseline.

Examples:

- `Your usage pace today is 2.3x above normal`
- `This week is significantly below your usual usage`

---

## 3. Suggestions

### Goal

Answer:

- What should the user do now?

### Core Principle

Suggestions must be:

- personal
- specific
- actionable

Avoid generic advice like:

- `Use Claude more efficiently`

Prefer advice like:

- `You usually spike in the evening. Save long-context work for after tonight's reset`

### Suggestion Type 3.1: Save Usage

For users with high usage pressure.

Examples:

- delay large tasks until after reset
- avoid peak usage windows
- reduce model-heavy sessions
- batch prompts instead of many back-and-forth turns

### Suggestion Type 3.2: Use Spare Capacity Better

For users with low usage or unusually large headroom.

Examples:

- use spare capacity for document summarization
- move routine writing or coding reviews into Claude
- process high-context work before the next reset

### Suggestion Type 3.3: Timing Suggestions

Recommend when to do heavier work.

Examples:

- `Good time for heavy tasks`
- `Wait for the next reset before starting a large session`

### Suggestion Type 3.4: Model Mix Suggestions

Recommend where the user may over-index or under-use a model.

Examples:

- `Sonnet is taking most of your weekly load`
- `You have room to use Claude more for low-risk tasks this week`

### Suggestion Output Formats

Suggestions should be normalized into 3 UI card types:

1. Risk card
2. Action card
3. Opportunity card

Examples:

- `Risk: You may enter the 5-hour high-risk zone in 1.8 hours`
- `Action: Save long document work for after tonight's reset`
- `Opportunity: You still have significant weekly headroom for summary-heavy tasks`

## Mac UX Entry Points

The current macOS app already has strong entry points for introducing Usage Intelligence.

### Entry Point 1: Popover Summary Card

Add a single intelligence summary card near the top of the main popover.

Priority order:

1. risk
2. action
3. opportunity

Examples:

- `Safe for now`
- `High risk this evening`
- `Good time for heavier work`

### Entry Point 2: Insights Section

Add a dedicated section in the popover for:

- Predictions
- Alerts
- Suggestions

### Entry Point 3: Settings

Add configuration for:

- prediction sensitivity
- alert types
- peak-time reminders
- suggestion style or verbosity

### Entry Point 4: Notifications

Deliver:

- threshold alerts
- reset alerts
- anomaly alerts
- peak-time alerts

## Mac MVP Scope

Start with a rules-based local MVP.

### Phase 1

- limit collision prediction
- 80% and 90% threshold alerts
- reset reminders

### Phase 2

- peak-time detection
- anomaly detection
- first-generation save-usage suggestions
- first-generation use-more suggestions

### Phase 3

- model pressure forecasting
- ranked suggestion cards
- weekly intelligence summary
- richer explanation layer

## Pricing Fit

This feature set is a strong candidate for Pro.

### Free

- current usage
- history charts
- basic threshold alerts

### Pro

- collision prediction
- reset reminders
- peak-time alerts
- anomaly alerts
- model pressure analysis
- personalized suggestions
- weekly intelligence summary

## Mac-First Technical Plan

The current mac app already contains the necessary foundations:

- polling and refresh flow in [UsageService.swift](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/Sources/ClaudeScope/UsageService.swift)
- local notifications in [NotificationService.swift](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/Sources/ClaudeScope/NotificationService.swift)
- retained usage history in [UsageHistoryService.swift](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/Sources/ClaudeScope/UsageHistoryService.swift)
- main UI in [PopoverView.swift](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/Sources/ClaudeScope/PopoverView.swift)
- configuration UI in [SettingsView.swift](/Users/dabuniu/lexi_project/claude_usage_bar/claude-usage-bar/macos/Sources/ClaudeScope/SettingsView.swift)

### Recommended New Components

Add these new files:

- `UsageIntelligenceService.swift`
- `UsageIntelligenceModels.swift`
- `UsageIntelligenceRules.swift`
- `UsageInsightsView.swift`

Optional later:

- `UsageIntelligenceStore.swift`

### Responsibilities

#### `UsageIntelligenceModels.swift`

Define:

- risk level
- prediction result
- alert recommendation
- suggestion card
- explanation metadata

#### `UsageIntelligenceRules.swift`

Pure logic layer for:

- slope calculations
- peak-time buckets
- anomaly comparisons
- suggestion generation

This layer should be easy to test.

#### `UsageIntelligenceService.swift`

Runtime orchestration layer.

Responsibilities:

- read current usage from `UsageService`
- read history from `UsageHistoryService`
- compute predictions and suggestions
- expose `@Published` outputs to the UI
- hand notification-worthy events to `NotificationService`

#### `UsageInsightsView.swift`

Small SwiftUI rendering layer for:

- summary card
- predictions list
- suggestions list

## Data Inputs for MVP

Use only data already available or easy to add:

- `usage.fiveHour.utilization`
- `usage.sevenDay.utilization`
- per-model utilization where available
- reset timestamps
- locally stored historical usage points
- polling timestamps

## Rules for Initial Prediction

### Collision Prediction

Use simple slope estimation:

- `delta utilization / delta time`

Prefer:

- 30-minute slope for near-term risk
- 24-hour slope for medium-term confidence

If recent data is sparse, downgrade confidence.

### Peak-Time Detection

Bucket history by:

- day of week
- hour of day

Track average utilization increase by bucket.

### Anomaly Detection

Compare:

- today's pace vs last 7-day median pace
- current hour bucket vs historical average for same bucket

### Suggestions

Generate from rule templates.

Example rule:

- if 5-hour projected risk is high and reset is within 90 minutes
- then suggest delaying heavy work until reset

Example rule:

- if 7-day utilization is low and reset is far away
- then suggest higher-value usage opportunities

## Notification Expansion Plan

The current `NotificationService` already supports threshold notifications.

Extend it to support:

- `resetSoon`
- `resetNow`
- `peakWindowIncoming`
- `usageAnomalyHigh`
- `usageOpportunity`

Keep alert deduplication to avoid spam.

Recommended later additions:

- last-fired timestamp per alert type
- cool-down periods
- per-alert enable/disable settings

## Settings Additions

Add a new `Usage Intelligence` section to settings.

Suggested settings:

- enable predictions
- enable suggestions
- threshold presets
- enable reset reminders
- enable peak-time reminders
- enable anomaly reminders

Optional later:

- suggestion tone: concise / detailed

## Success Metrics

### Product Metrics

- percentage of active users who enable at least one intelligence feature
- percentage of active users who view insights cards
- percentage of users who keep alerts enabled
- percentage of users who trigger a suggestion and later stay under risk thresholds

### Business Metrics

- conversion uplift from tracker-only to Pro
- retention improvement among Pro users
- reduced churn among heavy users

## Risks

### Risk 1: Advice feels generic

Mitigation:

- tie every suggestion to user history or current window state

### Risk 2: Too many alerts

Mitigation:

- dedupe
- cool-down windows
- safe defaults

### Risk 3: Prediction confidence is weak with sparse history

Mitigation:

- expose confidence tier
- degrade gracefully
- avoid overclaiming

## Recommended Build Order

1. Add `UsageIntelligenceModels`
2. Add pure rule logic for collision prediction
3. Add summary card in mac popover
4. Extend notifications for reset reminders
5. Add first rule-based save-usage and use-more suggestions
6. Add settings toggles
7. Add peak-time and anomaly logic

## Immediate Next Step

The best next engineering move is:

1. implement a mac-only `UsageIntelligenceService`
2. ship one summary card in the popover
3. add collision prediction + reset reminders first

That is the smallest meaningful version that upgrades ClaudeScope from a viewer into a coach.
