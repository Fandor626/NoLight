---
baseline_commit: 68a40d9f986012c87998ddf7ac2d3d3e3865b8b3
jira: NOL-31
branch: feature/NOL-31-widget-states
stacked_on: feature/NOL-30-place-in-widget (PR #9)
---
# Story 6.2: Widget states

Status: review

## Story

As Bohdan,
I want the widget to show «застаріло» and errors, and a button that refreshes data,
so that I can trust the widget.

## Acceptance Criteria

1. Given data older than 1 hour, Then the widget shows a «застаріло» warning.
2. Given a source error, Then the last schedule is shown with a mark, not an empty widget.
3. Given I tap the refresh button, Then a refresh runs and the widget reloads.

## Tasks / Subtasks

- [x] Task 1: `AppConfig.staleAfter` 4 h → 1 h (PRD FR-9); tests updated (AC: 1)
- [x] Task 2: `RefreshStatusStore` (App Group) + `ScheduleRepository.refresh` records the last failure and clears it on success (AC: 2, 3)
- [x] Task 3: Widget entry `refreshFailed` (failure newer than the last success); S: icon, M/L: «Не вдалося оновити» label; the cached schedule stays visible (AC: 2)
- [x] Task 4: Refresh button (`RefreshScheduleIntent`, v1) goes through the same repository, so it records/clears the status (AC: 3)
- [x] Task 5: Tests `RefreshStatusTests`, updated `testReliabilityThresholds`

## Dev Notes

- Before: the widget used `refreshIfNeeded`, which silently fell back to the cache, so a source error was invisible in the widget.
- The 1-hour threshold also changes the app banners (same `StatusCalculator.reliability`). This is what PRD FR-9 / NOL-16 ask for; NOL-16 no longer needs to change the constant.
- Expired data (> 24 h) is still shown as unknown, never as «Світло є» (unchanged).
- Stacked on NOL-30 (PR #9).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (device)
1. Leave the phone > 1 h without refresh → widget shows the stale warning.
2. Airplane mode → tap the widget refresh button → the schedule stays, «Не вдалося оновити» (icon on small) appears.
3. Back online → refresh → the mark disappears and «Оновлено …» updates.
4. ⌘U → `RefreshStatusTests` and `ScheduleLogicTests` green.

### File List
- Shared/Data/RefreshStatusStore.swift (new)
- Tests/RefreshStatusTests.swift (new)
- Shared/Data/ScheduleRepository.swift
- Shared/Support/AppConfig.swift
- Widget/SubgroupWidget.swift
- Widget/SubgroupWidgetView.swift
- Tests/ScheduleLogicTests.swift
- _bmad-output/implementation-artifacts/6-2-widget-states.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
