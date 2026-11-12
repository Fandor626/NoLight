---
baseline_commit: 66dcca14850e819e33ddf5dd52681a3fd83c06fa
jira: NOL-20
branch: feature/NOL-20-background-refresh
stacked_on: feature/NOL-19-refresh-mode (PR #14)
---
# Story 3.2: Background refresh

Status: review

## Story

As Bohdan,
I want schedules to refresh in the background,
so that they are current without opening the app.

## Acceptance Criteria

1. Given automatic refresh, When iOS runs the background task, Then all places are refreshed and widgets reload.
2. Given the interval setting, Then a note next to it says iOS does not guarantee the exact interval.
3. Given an error during a background refresh, Then the cache does not change.

## Tasks / Subtasks

- [x] Task 1: `BackgroundRefresh.perform`: refresh only when `allowsBackgroundRefresh` (automatic); always reschedule (`defer`) using the NOL-19 interval (AC: 1)
- [x] Task 2: Note under the interval picker (`RefreshCopy.intervalNote`): «Це побажання, а не розклад: iOS сама вирішує…» (AC: 2)
- [x] Task 3: Error path: `ScheduleRepository.refresh` leaves the cache untouched and records the failure (existing, NOL-31) — covered by `DataLayerTests.testFailedRefreshDoesNotOverwriteCache` (AC: 3)
- [x] Task 4: Tests `BackgroundRefreshPolicyTests`

## Dev Notes

- "All places refreshed": every place currently uses the same source (oblenergo site), and one `refresh()` updates all subgroups at once, so all places and widgets are covered. With Epic 2 (API source) `perform` must refresh every source used by any place; with NOL-21 it must replan notifications — both noted in code.
- The interval is applied as `earliestBeginDate` (NOL-19); iOS decides the actual time.
- Stacked on NOL-19 (PR #14).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (Xcode)
1. Automatic mode → background the app → in the debugger: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.bohdanol.NoLight.refresh"]` → resume → «Оновлено …» changes, widgets reload.
2. Manual mode → simulate the same → nothing is fetched.
3. Airplane mode → simulate → cached schedule unchanged, widgets show «Не вдалося оновити».
4. Settings → interval → the note about iOS timing is under the picker.
5. ⌘U → `BackgroundRefreshPolicyTests` green.

### File List
- App/BackgroundRefresh.swift
- App/SettingsView.swift
- Shared/Data/RefreshSettings.swift
- Tests/RefreshSettingsTests.swift
- _bmad-output/implementation-artifacts/3-2-background-refresh.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
