---
baseline_commit: 8ed57c3ad05ee3d286c94eb622d2e316f9738dc8
jira: NOL-17
branch: feature/NOL-17-source-choice-for-cherkasy
stacked_on: feature/NOL-16-trust-and-freshness-labels (PR #17)
---
# Story 2.3: Source choice for Cherkasy

Status: review

## Story

As Bohdan,
I want to choose either the oblenergo site or the API for Cherkasy,
so that I use the source I trust.

## Acceptance Criteria

1. Given a Cherkasy place, When I open its settings, Then I can choose «Сайт обленерго» (default) or «API».
2. Given I changed the source, When I return home, Then the card and widgets show the schedule from the new source with the matching label.
3. Given a place in another region, Then there is no source choice and the API is used.

## Tasks / Subtasks

- [x] Task 1: `Place.availableSources`, `PlaceSource.shortTitle` (AC: 1, 3)
- [x] Task 2: `PlaceSettingsView` (details toolbar): region, subgroup, source picker for Cherkasy; read-only «API» for other regions (AC: 1, 3)
- [x] Task 3: `AppState.setSource`: save, reload widgets, load cache + refresh the new source at once (AC: 2)
- [x] Task 4: Tests `SourceChoiceTests`

## Dev Notes

- The card/widget label follows `place.sourceKey` (NOL-16 badge appears for API).
- Stacked on NOL-16 (PR #17).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Cherkasy place → details → slider icon → «Сайт обленерго / API» → choose «API» → back home: card shows «неофіційне джерело» and the API schedule; widget for this place follows.
2. Place in another region → settings show «Джерело: API», no picker.
3. ⌘U → `SourceChoiceTests` green.

### File List
- App/PlaceSettingsView.swift (new)
- Tests/SourceChoiceTests.swift (new)
- App/AppState.swift
- App/PlaceDetailView.swift
- Shared/Models/Place.swift
- _bmad-output/implementation-artifacts/2-3-source-choice-for-cherkasy.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
