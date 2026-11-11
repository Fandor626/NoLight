---
baseline_commit: c50adeb20868b37334315ee2f4bdb14e528db08e
jira: NOL-11
branch: feature/NOL-11-add-a-place
---
# Story 1.2: Add a place

Status: review

## Story

As Bohdan,
I want to add a new place (e.g. Work),
so that I can see its schedule separately from Home.

## Acceptance Criteria

1. Given the add form, When I enter a name and choose region → queue → subgroup and save, Then the place is stored and shown in the list.
2. Given I already have many places, When I add another, Then it is accepted (no limit).
3. Given the name field is empty, When I try to save, Then saving is disabled.
4. Given a region without data, When I select it, Then an explanation is shown instead of an empty screen.
5. Given this story, Then only Cherkasy can be selected.

## Tasks / Subtasks

- [x] Task 1: `PlaceDraft` validation in `Shared/Models/Place.swift` (AC: 1, 3, 5)
  - [x] 1.1 Trimmed name 1…40 chars, valid subgroup, region with data; `makePlace()`.
  - [x] 1.2 `Region.selectable` (Cherkasy only) and `Region.hasScheduleData`.
- [x] Task 2: `App/AddPlaceView.swift` form (AC: 1, 3, 4, 5)
  - [x] 2.1 Name field (focused on open), region picker, queue picker, subgroup segmented picker.
  - [x] 2.2 «Зберегти» disabled while invalid; «Скасувати» saves nothing.
  - [x] 2.3 Region without data → footer explanation, no queue/subgroup section.
- [x] Task 3: Home screen uses the form (AC: 1, 2)
  - [x] 3.1 «+» and empty-state button open `AddPlaceView`; new place appended and scrolled into view.
  - [x] 3.2 Remove the interim `SubgroupPickerView` and `AppState.togglePlace/hasPlace` from NOL-10.
- [x] Task 4: Unit tests `PlaceDraftTests` (AC: 1, 3, 5)

## Dev Notes

- Builds on NOL-10 (`Place`, `PlaceStore`, `AppState.addPlace`). No limit on the number of places (FR-1).
- Duplicate subgroups across places are allowed (different names may share a subgroup).
- Only Cherkasy now; `Region.selectable` is the single switch NOL-15 extends with API regions. The "region without data" branch is in place but unreachable until then.
- Name length cap (40) is a UI guard so the card title fits; not in the PRD — easy to change in `PlaceDraft.maxNameLength`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#NOL-11]
- [Source: prd.md#FR-1, FR-2]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (Xcode)
1. «+» → form opens with the name field focused; «Зберегти» is disabled until a name is typed.
2. Name «Робота», queue 4, subgroup 4.2 → save → card «Робота» at the end of the list, scrolled into view.
3. Add a few more places → all accepted.
4. «Скасувати» → nothing added.
5. ⌘U → `PlaceDraftTests` green.

### File List
- App/AddPlaceView.swift (new)
- App/SubgroupPickerView.swift (deleted)
- App/HomeView.swift
- App/AppState.swift
- Shared/Models/Place.swift
- Tests/PlaceStoreTests.swift
- _bmad-output/implementation-artifacts/1-2-add-a-place.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
