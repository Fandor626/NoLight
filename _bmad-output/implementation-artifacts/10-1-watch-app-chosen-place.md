---
baseline_commit: 79e89f473d81e340c28e86f2514dc83bb50d0b0a
jira: NOL-46
branch: feature/NOL-46-watch-app
stacked_on: feature/NOL-43-keep-countdown (both change PlaceSettingsView)
---
# Story 10.1: Watch app with my chosen place

Status: review

## Story

As Bohdan,
I want a NoLight app on my Apple Watch with one place I choose,
so that I can check the power state from my wrist.

## Acceptance Criteria

1. Given places on the iPhone, When I open the watch app, Then I see them and can choose one.
2. Given a chosen place, Then the watch shows its state, the time until the next change and the −2 h … +2 h timeline.
3. Given the iPhone is not nearby, When the watch has internet, Then it refreshes the schedule itself.
4. Given data older than 24 h or no data, Then the watch shows «Невідомо» / «Застаріло», not «Світло є».

## Tasks / Subtasks

- [x] Task 1: `TimelineWindow` (Shared, pure): −2 h … +2 h slice over yesterday/today/tomorrow, gaps and expired data → «невідомо», change points, now marker (AC: 2, 4)
- [x] Task 2: `WatchPayload` + `WatchPlaceStore` (Shared): places, iPhone-preferred place and `ColorTheme` via `updateApplicationContext`; a new iPhone choice overrides the watch choice once; deleted place → first place (AC: 1)
- [x] Task 3: iPhone `WatchSync`: activates `WCSession`, sends after any place change, color change and the new «Показувати на годиннику» toggle in place settings (AC: 1)
- [x] Task 4: watchOS target `NoLightWatch` (`project.yml`, single-target app, watchOS 10+, embedded in the iOS app, same App Group id, same git-based version); `Shared/` without `UI/` and ActivityKit files (AC: 1–4)
- [x] Task 5: Watch UI: place card (name, subgroup, state, countdown or detail, `WatchTimelineBar`, «Застаріло» / «Дані застаріли», «Оновлено …»), place picker «На годиннику», empty state «Додайте місце в NoLight на iPhone» (AC: 1, 2, 4)
- [x] Task 6: `WatchState.refresh` fetches the place's source on the watch itself (`ScheduleRepository`, cache in the watch App Group) (AC: 3)
- [x] Task 7: Tests `TimelineWindowTests`, `WatchPayloadTests`

## Dev Notes

- Requires xcodegen ≥ 2.38 (single-target watchOS `application`) and the watchOS SDK in Xcode.
- First signing: choose the Team for the new `NoLightWatch` target; the App Group must be enabled for `com.bohdanol.NoLight.watchkitapp`.
- `scripts/set-version.sh` now counts `Watch`, `WatchShared`, `WatchWidget` too; the watch version must equal the iPhone version.
- Stacked on NOL-43 only to avoid a conflict in `PlaceSettingsView`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment). The watchOS target is new and untested — expect possible signing/target fixes on first build.

### Manual verification
1. `xcodegen generate` → select `NoLightWatch` scheme (or run the iOS app with a paired watch / watch simulator).
2. Watch: places from the iPhone, list button → choose a place → card with state, countdown and −2 h … +2 h bar.
3. iPhone: place settings → «Показувати на годиннику» → the watch switches to that place.
4. Turn off iPhone Bluetooth, keep watch Wi-Fi → pull to refresh on the watch → «Оновлено о …» updates.
5. ⌘U → `TimelineWindowTests`, `WatchPayloadTests` green.

### File List
- project.yml
- scripts/set-version.sh
- Watch/** (new: app, state, receiver, views, Info.plist, entitlements, Assets)
- WatchShared/WatchViews.swift (new)
- Shared/Models/TimelineWindow.swift (new)
- Shared/Models/WatchPayload.swift (new)
- App/WatchSync.swift (new)
- App/AppState.swift
- App/NoLightApp.swift
- App/ColorSettingsView.swift
- App/PlaceSettingsView.swift
- Tests/WatchTests.swift (new)
- _bmad-output/implementation-artifacts/10-1-watch-app-chosen-place.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
