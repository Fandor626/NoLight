---
baseline_commit: d9a491090d41490593aa509035effabe626381e0
jira: NOL-43
branch: feature/NOL-43-keep-countdown
stacked_on: main
---
# Story 9.2: Keep the countdown on the Lock Screen

Status: review

## Story

As Bohdan,
I want the Lock Screen countdown to be removed only from the app,
so that an accidental swipe or collapse doesn't make it disappear.

## Acceptance Criteria

1. Given a running countdown, When I swipe it away on the Lock Screen, Then it comes back the next time the app runs (foreground or background refresh).
2. Given a running countdown, When I tap «Зупинити відлік» in the app, Then it disappears and does not come back.
3. Given the 8-hour limit is near, When the app runs, Then the countdown is renewed without my action.
4. Given Live Activities are disabled in Settings, Then the app shows why the countdown can't be kept.

## Tasks / Subtasks

- [x] Task 1: `LiveActivityKeepStore` (App Group `liveActivityKept.v1`): places with «завжди на екрані»; set on start, cleared only by «Зупинити відлік» / the toggle or when the place is deleted (AC: 1, 2)
- [x] Task 2: `LiveActivityRestorePlanner` (pure): kept + not running → start; running ≥ 7.5 h → renew; deleted place → forget (AC: 1, 3)
- [x] Task 3: `LiveActivityManager.restore` on every app activation (`scenePhase == .active`, after refresh) (AC: 1, 3)
- [x] Task 4: Place settings → «Заблокований екран» → «Відлік завжди на екрані» toggle with explanation; error text when Live Activities are disabled (AC: 2, 4)
- [x] Task 5: Tests `LiveActivityRestoreTests`

## Dev Notes

- iOS does not let an app block dismissing a Live Activity, and `Activity.request` only works while the app is in the foreground. So a dismissed countdown comes back when the app is opened (AC1 "background refresh" can only *update* a running activity, not start one — documented in the UI footer).
- Push-to-start (no need to open the app) would need an APNs server — left as an open question in Jira.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Place details → «…» → «Відлік на заблокованому екрані» → lock → swipe the countdown away → open NoLight → it is back.
2. «…» → «Зупинити відлік» → open/close the app → it does not come back.
3. Place settings → «Відлік завжди на екрані» toggles the same thing; with Live Activities off in Settings → red explanation.
4. ⌘U → `LiveActivityRestoreTests` green.

### File List
- Shared/Data/LiveActivityKeepStore.swift (new)
- Shared/Models/PlaceActivity.swift
- App/LiveActivityManager.swift
- App/AppState.swift
- App/NoLightApp.swift
- App/PlaceDetailView.swift
- App/PlaceSettingsView.swift
- Tests/LiveActivityRestoreTests.swift (new)
- _bmad-output/implementation-artifacts/9-2-keep-countdown-on-lock-screen.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
