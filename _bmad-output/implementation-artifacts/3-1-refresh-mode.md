---
baseline_commit: e2cf2358ac57c232d74c943fd8eb0e1060a7c692
jira: NOL-19
branch: feature/NOL-19-refresh-mode
---
# Story 3.1: Refresh mode

Status: review

## Story

As Bohdan,
I want to choose manual or automatic refresh every N minutes/hours,
so that I control how often requests are made.

## Acceptance Criteria

1. Given the settings screen, When I choose «Автоматично», Then I can pick an interval from presets 15/30 min, 1/3/6 h; the minimum is 15 min.
2. Given «Лише вручну» is chosen, When the app is in the background, Then no background refresh is registered.
3. Given any mode, Then the home screen has a «Оновити» button.

## Tasks / Subtasks

- [x] Task 1: `RefreshMode`, `RefreshInterval` (presets 15/30/60/180/360 min), `RefreshSettingsStore` in the App Group; default = automatic, 30 min (v1 behaviour) (AC: 1)
- [x] Task 2: `BackgroundRefresh.schedule()` uses the store: manual → cancel the pending `BGAppRefreshTaskRequest`; automatic → `earliestBeginDate = now + interval` (AC: 2)
- [x] Task 3: Settings «Оновлення»: segmented «Автоматично / Лише вручну», interval picker (automatic only), footer text per mode; changes reschedule immediately (AC: 1, 2)
- [x] Task 4: Home toolbar «Оновити» button (spinner while refreshing); pull-to-refresh stays (AC: 3)
- [x] Task 5: Tests `RefreshSettingsTests`

## Dev Notes

- Widgets keep refreshing themselves via `refreshIfNeeded(maxAge:)` regardless of the mode (they are not background tasks of the app). **Open question (from NOL-19):** should manual mode also stop widget self-refresh? Not changed here; the footer says widgets still refresh.
- NOL-20 builds on this: background refresh of all places + interval note + notification replanning.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (Xcode)
1. Settings → «Оновлення»: «Автоматично» + interval presets; «Лише вручну» hides the interval and changes the footer.
2. «Лише вручну» → background the app → Debug → Simulate Background Fetch does nothing (no request pending; `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] getPendingTaskRequestsWithCompletionHandler:^(NSArray *a){ NSLog(@"%@", a); }]` shows none).
3. Home → arrow button refreshes (spinner while running).
4. ⌘U → `RefreshSettingsTests` green.

### File List
- Shared/Data/RefreshSettings.swift (new)
- Tests/RefreshSettingsTests.swift (new)
- App/BackgroundRefresh.swift
- App/SettingsView.swift
- App/HomeView.swift
- _bmad-output/implementation-artifacts/3-1-refresh-mode.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
