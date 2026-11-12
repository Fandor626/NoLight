---
baseline_commit: 3d929ba382ac01e54d2fbbc410adaad7fd84951c
jira: NOL-39
branch: feature/NOL-39-live-activity
stacked_on: main
---
# Story 9.1: Countdown to the next change

Status: review

## Story

As Bohdan,
I want a countdown on the Lock Screen,
so that I don't have to open the app.

## Acceptance Criteria

1. Given a selected place, When I start the Live Activity, Then the Lock Screen shows the time until the next change.
2. Given 8 hours have passed, Then the activity ends and offers to start again.

## Tasks / Subtasks

- [x] Task 1: `PlaceActivityAttributes` (Shared): place id/name/subgroup + `PlaceActivityContent` (state, next change, next state, startedAt, updatedAt) (AC: 1)
- [x] Task 2: `PlaceActivityPlanner` (pure): content from `SubgroupPresentation`, stale date = next change or 8 h after start, expiry, copy («До відключення», «До появи світла», «Відлік завершено. Натисніть, щоб запустити знову.») (AC: 1, 2)
- [x] Task 3: `LiveActivityManager` (App): start / stop per place, update after every data refresh and place change (`AppState.replanNotifications`, background refresh), end for deleted places and after 8 h (AC: 1, 2)
- [x] Task 4: `PlaceLiveActivity` (widget extension): Lock Screen view with `Text(timerInterval:)` (counts down without pushes) + Dynamic Island; tap opens the place (`nolight://place/{id}`) (AC: 1, 2)
- [x] Task 5: Place details «…» → «Відлік на заблокованому екрані» / «Зупинити відлік»; alert when Live Activities are disabled (AC: 1, 2)
- [x] Task 6: `NSSupportsLiveActivities = YES` (`project.yml`, `App/Info.plist`)
- [x] Task 7: Tests `PlaceActivityTests`

## Dev Notes

- No push server: the timer runs on the device; after the change time the content is stale until the app (foreground or background refresh) updates it.
- After 8 h iOS ends the activity; the last view says «Відлік завершено. Натисніть, щоб запустити знову.» and tapping opens the place, where the menu starts it again.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment). Live Activities need a real device or a simulator with iOS 17+.

### Manual verification
1. `xcodegen generate` → run → place details → «…» → «Відлік на заблокованому екрані» → lock the device → place name, state and a countdown to the next change.
2. On iPhone with Dynamic Island → compact countdown; long-press → expanded view.
3. «…» → «Зупинити відлік» → the activity disappears.
4. After 8 h (or change the device clock) → «Відлік завершено…»; tap → place details → start again.
5. ⌘U → `PlaceActivityTests` green.

### File List
- Shared/Models/PlaceActivity.swift (new)
- App/LiveActivityManager.swift (new)
- Widget/PlaceLiveActivity.swift (new)
- Widget/SubgroupWidget.swift
- App/PlaceDetailView.swift
- App/AppState.swift
- App/BackgroundRefresh.swift
- project.yml
- App/Info.plist
- Tests/PlaceActivityTests.swift (new)
- _bmad-output/implementation-artifacts/9-1-countdown-to-next-change.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
