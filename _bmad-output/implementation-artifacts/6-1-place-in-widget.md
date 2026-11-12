---
baseline_commit: 97a6d6381a897f62d9ebca7bc41f89451c517439
jira: NOL-30
branch: feature/NOL-30-place-in-widget
stacked_on: chore/NOL-40-add-widgets-mirror-cards-story (PR #8)
---
# Story 6.1: Choose a place in a widget

Status: review

## Story

As Bohdan,
I want to pick a place for each widget,
so that I can have Home and Work on my screen at the same time.

## Acceptance Criteria

1. Given widget configuration, When I pick a place from the list, Then the widget shows its schedule (small, medium, large).
2. Given a v1 widget configured with a subgroup, Then it keeps working after migration.
3. Given the place was deleted, Then the widget shows «Місце видалено, оберіть інше».

## Tasks / Subtasks

- [x] Task 1: `PlaceEntity` + `PlaceQuery` over `PlaceStore.shared` (same names and order as the app; default = first place) (AC: 1)
- [x] Task 2: `SelectSubgroupIntent` gets `place: PlaceEntity?`; the v1 `subgroup` parameter stays but is hidden by `parameterSummary`; type name kept so existing widget configurations survive (AC: 1, 2)
- [x] Task 3: `WidgetPlaceResolver` in `Shared/`: place → `.place`; missing place → `.deleted`; no place (v1) → place with the same subgroup, else `.legacy(subgroup)` (AC: 1, 2, 3)
- [x] Task 4: Widget entry carries the title; all sizes show the place name; deleted → «Місце видалено, оберіть інше» (AC: 1, 3)
- [x] Task 5: Tests `WidgetPlaceResolverTests` (AC: 1, 2, 3)

## Dev Notes

- Changing the intent's type name would reset every widget's configuration, so `SelectSubgroupIntent` keeps its name; only its title/description change («Місце»).
- Renames show up after the next timeline reload: `AppState.save()` already calls `WidgetCenter.reloadAllTimelines()`, and the resolver reads names from `PlaceStore`, not from the saved entity.
- Layout stays close to v1; the full "widget = app card" redesign and deep links are NOL-40.
- Stacked on PR #8 (docs for NOL-40) because both touch `sprint-status.yaml`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).
- **Risk to check:** that `parameterSummary` hides the legacy «Підчерга» parameter in «Змінити віджет». If it is still visible, it is harmless (only used when no place is chosen).

### Manual verification (Xcode / device)
1. Add places «Дім» (3.2) and «Робота» (4.2). Add two widgets → «Змінити віджет» → pick «Дім» and «Робота» → both show their names and schedules in S/M/L.
2. Install over a build with a v1 widget set to 3.2 → it shows «Дім» (the migrated place).
3. Delete «Робота» in the app → its widget shows «Місце видалено, оберіть інше».
4. Rename «Дім» → widget shows the new name after reload.
5. ⌘U → `WidgetPlaceResolverTests` green.

### File List
- Shared/Models/WidgetPlaceResolver.swift (new)
- Tests/WidgetPlaceResolverTests.swift (new)
- Widget/SubgroupIntent.swift
- Widget/SubgroupWidget.swift
- Widget/SubgroupWidgetView.swift
- _bmad-output/implementation-artifacts/6-1-place-in-widget.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
