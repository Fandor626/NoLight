---
baseline_commit: d05fc8c16e7d2c607a781ff6cae8388abff3ae97
jira: NOL-42
branch: feature/NOL-42-manual-mode-widgets
stacked_on: main
---
# Story 3.7: Manual mode also stops widget self-refresh

Status: review

## Story

As Bohdan,
I want «Лише вручну» to also stop widgets from fetching schedules on their own,
so that no network requests happen unless I ask for them.

## Acceptance Criteria

1. Given manual mode, When WidgetKit reloads a widget timeline, Then no network request is made and the cached schedule is shown.
2. Given manual mode, When I tap the refresh button on a widget, Then the schedule is fetched.
3. Given automatic mode, When the cache is older than 15 minutes, Then the widget refreshes as before.
4. Given manual mode and stale or expired cache, Then the widget shows the «Застаріло» / «Протерміновано» labels as usual.

## Tasks / Subtasks

- [x] Task 1: `RefreshMode.allowsWidgetSelfRefresh` / `RefreshSettingsStore.allowsWidgetSelfRefresh` (automatic only) (AC: 1, 3)
- [x] Task 2: `ScheduleRepository.widgetSnapshot(allowsSelfRefresh:)`: cache only, or `refreshIfNeeded(maxAge: 15 min)` (AC: 1, 3)
- [x] Task 3: `SubgroupWidget` and `PlacesListWidget` timelines use it; `RefreshScheduleIntent` (widget button) unchanged (AC: 1, 2)
- [x] Task 4: Settings footer for manual mode updated
- [x] Task 5: Tests `WidgetManualModeTests` (AC: 1–4)

## Dev Notes

- Decision from Bohdan (Sprint 5): manual mode must stop widget self-refresh.
- Timelines still contain entries at planned change times, so widgets switch states from the cache without network.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Settings → «Лише вручну» → wait for a widget reload (or re-add a widget) with a cache older than 15 min → the widget keeps the old data and shows «Застаріло» after 1 h.
2. Tap the widget refresh button → data is fetched.
3. Switch back to «Автоматично» → widgets refresh themselves again.
4. ⌘U → `WidgetManualModeTests` green.

### File List
- Shared/Data/RefreshSettings.swift
- Shared/Data/ScheduleRepository.swift
- Widget/SubgroupWidget.swift
- Widget/PlacesListWidget.swift
- App/SettingsView.swift
- Tests/WidgetManualModeTests.swift (new)
- _bmad-output/planning-artifacts/epics.md
- _bmad-output/implementation-artifacts/3-7-manual-mode-stops-widget-refresh.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
