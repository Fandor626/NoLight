---
baseline_commit: 8c374f763a148b997f2fca099ed97a1cebf53584
jira: NOL-18
branch: feature/NOL-18-source-comparison-screen
stacked_on: feature/NOL-17-source-choice-for-cherkasy (PR #18)
---
# Story 2.4: Source comparison screen

Status: review

## Story

As Bohdan,
I want to compare the site and the API for my subgroup,
so that I see where they differ and choose the primary one.

## Acceptance Criteria

1. Given a Cherkasy place, When I open «Порівняння джерел», Then I see two timelines side by side, each source's update time, and highlighted differences in intervals.
2. Given one source is unavailable, When I open the screen, Then it says which one is unavailable and still shows the other.
3. Given I see a difference, When I tap «Зробити основним», Then the place's source changes (NOL-17).

## Tasks / Subtasks

- [x] Task 1: `SourceComparison.differences` (per-minute, merged ranges; only when both are published) (AC: 1)
- [x] Task 2: `AppState.loadComparison`: cache of both Cherkasy sources at once, network refresh when older than 15 min or on pull-to-refresh (AC: 1, 2)
- [x] Task 3: `SourceComparisonView` (details «…» menu → «Порівняння джерел», Cherkasy only): Today/Tomorrow, a card per source with update time, «Основне» / «Зробити основним», «Джерело недоступне: …»; «Різниця» card with a highlighted bar, total minutes and ranges (AC: 1, 2, 3)
- [x] Task 4: Tests `SourceComparisonTests`

## Dev Notes

- The two cards are stacked vertically (iPhone width), which is the readable form of "side by side" on a phone.
- «Зробити основним» calls `AppState.setSource` from NOL-17.
- Stacked on NOL-17 (PR #18).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Cherkasy place → details → «…» → «Порівняння джерел» → two timelines with update times; differences highlighted in «Різниця».
2. Airplane mode with only one cached source → that card says «Джерело недоступне: …», the other is still shown.
3. «Зробити основним» on «API» → «Основне» moves; home card shows «неофіційне джерело».
4. ⌘U → `SourceComparisonTests` green.

### File List
- App/SourceComparisonView.swift (new)
- Shared/Models/SourceComparison.swift (new)
- Tests/SourceComparisonTests.swift (new)
- App/AppState.swift
- App/PlaceDetailView.swift
- _bmad-output/implementation-artifacts/2-4-source-comparison-screen.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
