---
baseline_commit: fd58c6cdf23ed79f3af98dfb1b7001be4b44fc02
jira: NOL-10
branch: feature/NOL-10-home-screen-places-v1-migration
---
# Story 1.1: Home screen with places list (v1 migration)

Status: ready-for-testing

## Story

As Bohdan,
I want to open the app and immediately see my place with its power state,
so that I don't have to pick my subgroup again after the update.

## Acceptance Criteria

1. Given v1 had subgroup 3.2 selected, When I launch the new version for the first time, Then a place «Дім» with subgroup 3.2 is on the home screen.
2. Given v1 had several subgroups selected, When migration runs, Then each becomes a place and none are lost.
3. Given migration already ran, When I relaunch, Then it does not run again and does not duplicate places.
4. Given a place card, Then it shows state, next change time and type, a 24-hour timeline with a now-marker, and freshness.
5. Given there is no data for a place, When I open the home screen, Then the state is unknown, never «Світло є».
6. All texts are Ukrainian and all times are Europe/Kyiv.

## Tasks / Subtasks

- [x] Task 1: `Place` model (AC: 1, 2)
  - [x] 1.1 `Shared/Models/Place.swift`: `Place` (id UUID, name, region, subgroup, source), `Region` (.cherkasy), `PlaceSource` (.oblenergoSite); Codable, Hashable, Sendable.
- [x] Task 2: `PlaceStore` + one-time migration (AC: 1, 2, 3)
  - [x] 2.1 `Shared/Data/PlaceStore.swift`: ordered `[Place]` as JSON in App Group UserDefaults (key `places.v1`).
  - [x] 2.2 `PlaceMigration.places(fromV1:)`: first subgroup → «Дім», others → «Підчерга X.Y»; region Cherkasy, source site.
  - [x] 2.3 `migrateFromV1IfNeeded`: runs once (flag `placesMigrated.v1`), never touches `selectedSubgroups.v1` (rollback safety).
- [x] Task 3: `AppState` works with places (AC: 1, 4)
  - [x] 3.1 Replace `selected: [Subgroup]` with `places: [Place]`; add/remove keep the store in sync; widgets reloaded on change.
- [x] Task 4: Home screen (AC: 4, 5, 6)
  - [x] 4.1 `PlaceCardView`: place name + subgroup badge, state headline + next change, 24 h timeline with now-marker, freshness/stale label.
  - [x] 4.2 Empty state «Немає збережених місць» + «Додати місце».
  - [x] 4.3 Interim add flow until NOL-11: the existing subgroup picker creates/removes a place «Підчерга X.Y».
- [x] Task 5: Unit tests (AC: 1, 2, 3)
  - [x] 5.1 `Tests/PlaceStoreTests.swift`: single/multiple migration, idempotence, no v1 data, persistence round-trip, corrupted data.

## Dev Notes

- No architecture doc; follow v1 code conventions (SwiftUI + @Observable `AppState`, App Group `UserDefaults(suiteName: AppConfig.appGroupID)`, `SettingsStore` pattern in `ScheduleRepository.swift`).
- **Current state:** `AppState.selected: [Subgroup]` persisted by `SettingsStore.selectedSubgroups` (key `selectedSubgroups.v1`). `HomeView` lists `SubgroupCardView`s; `SubgroupPickerView` toggles subgroups; context menu deletes.
- **Changes:** places replace the selection in the app UI only. **Preserve:** cache/refresh flow, `DataStatusBanners`, `SubgroupDetailView` (adapted in NOL-13), widgets (`SelectSubgroupIntent`, untouched until NOL-30), the `selectedSubgroups.v1` key.
- Status/next-change/freshness come from the existing `SubgroupPresentation` (already never shows "available" without data; expired data is shown as unknown).
- Order is the array order in the store (no separate `order` field needed; NOL-12 reorders the array).
- Decision recorded in Jira NOL-10 (open question resolved with the proposal): 2nd+ migrated places are named «Підчерга X.Y».
- Tests target compiles `Shared/` + `Tests/` only, so all testable logic lives in `Shared/`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#NOL-10]
- [Source: _bmad-output/planning-artifacts/prds/prd-NoLight-2026-11-11/prd.md#FR-1, FR-3]
- [Source: App/AppState.swift, App/HomeView.swift, Shared/Data/ScheduleRepository.swift (SettingsStore)]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Debug Log References

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- Implemented Place / PlaceStore / PlaceMigration in Shared/, AppState now holds places, home screen shows PlaceCardView.
- Build and tests NOT run: the agent environment has no Swift toolchain or Xcode. Verify in Xcode (checklist below).
- Card keeps v1 wording for states («Світло є» / «Світла немає» / «Немає актуальних даних»…), which already never shows power without data (AC5).
- Interim: «+» opens the subgroup picker, which now creates/removes places «Підчерга X.Y»; replaced by the add form in NOL-11.
- Place details still open SubgroupDetailView for the place's subgroup; adapted to places in NOL-13. Widgets unchanged (NOL-30).

### Manual verification (Xcode)
1. Install the current `main` build, select subgroup 3.2 (and optionally 1.1), then build this branch over it → home shows «Дім» (3.2) and «Підчерга 1.1».
2. Relaunch → no duplicates.
3. Fresh install → empty state «Немає збережених місць» with «Додати місце».
4. Airplane mode + no cache → card says «Даних ще немає», never «Світло є».
5. ⌘U → PlaceStoreTests and the existing suites pass.

### File List
- Shared/Models/Place.swift (new)
- Shared/Data/PlaceStore.swift (new)
- Tests/PlaceStoreTests.swift (new)
- App/AppState.swift
- App/HomeView.swift
- App/SubgroupPickerView.swift
- _bmad-output/implementation-artifacts/1-1-home-screen-places-v1-migration.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
