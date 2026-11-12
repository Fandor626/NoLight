---
baseline_commit: d05fc8c16e7d2c607a781ff6cae8388abff3ae97
jira: NOL-28
branch: feature/NOL-28-travel-preview
stacked_on: main
---
# Story 5.1: Preview without saving

Status: review

## Story

As Bohdan,
I want to quickly view the schedule of any region and subgroup,
so that I don't create a place for a one-off check.

## Acceptance Criteria

1. Given the «Подорож» screen, When I choose region, queue and subgroup, Then I see the schedule without creating a place.
2. Given I viewed a schedule, When I tap «Зберегти як місце», Then a place is created with those parameters.

## Tasks / Subtasks

- [x] Task 1: `TravelSelection` (Shared): region / queue / sub, `sourceKey` (region default source), `transientPlace` (fixed id, never stored), `suggestedName`, `makePlace(name:)` (AC: 1, 2)
- [x] Task 2: `AppState.loadPreview(_:)`: cache first, then refresh only that source; `snapshot(forKey:)` / `error(forKey:)`; places are not touched (AC: 1)
- [x] Task 3: New tab «Подорож» (`TravelView`): cascade, state now, «Сьогодні / Завтра» timeline with outage list, stale/expired/error labels, pull to refresh (AC: 1)
- [x] Task 4: «Зберегти як місце» → name prompt (prefilled «<Область> обл., X.Y») → `AppState.addPlace` (AC: 2)
- [x] Task 5: Tests `TravelPreviewTests`

## Dev Notes

- The preview reuses the same repository/cache as places, so a later saved place opens instantly.
- Source = the region's default (Cherkasy → official site, other regions → API), same as a new place.
- NOL-29 (arrival time) builds on this screen.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Tab «Подорож» → choose e.g. Львівська, 2.1 → state now and schedule for today/tomorrow; Home still has the same places.
2. «Зберегти як місце» → keep/edit the name → «Зберегти» → the place appears on Home with the same region and subgroup.
3. ⌘U → `TravelPreviewTests` green.

### File List
- Shared/Models/TravelSelection.swift (new)
- App/TravelView.swift (new)
- App/AppState.swift
- App/RootView.swift
- Tests/TravelPreviewTests.swift (new)
- _bmad-output/implementation-artifacts/5-1-preview-without-saving.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
