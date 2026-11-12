---
baseline_commit: b33d701c1829dcd96fae2c7072fae96f2ac2805a
jira: NOL-16
branch: feature/NOL-16-trust-and-freshness-labels
stacked_on: feature/NOL-15-any-region-from-api (PR #16)
---
# Story 2.2: Trust and freshness labels

Status: review

## Story

As Bohdan,
I want to see where data comes from and how fresh it is,
so that I don't rely on an outdated schedule.

## Acceptance Criteria

1. Given a schedule from the API, When it is shown, Then it is labelled «неофіційне джерело».
2. Given data older than 1 hour, When I view the place, Then a «застаріло» warning is shown; after 24 hours — «протерміновано».
3. Given no network, When I open the app, Then the last successful schedule is shown with «оновлено о…».
4. Given a network error, Then the cache is not erased.

## Tasks / Subtasks

- [x] Task 1: `UnofficialSourceBadge` on app cards, all widget sizes, «Мої місця» rows and place details for API places (AC: 1)
- [x] Task 2: «Застаріло» (≥ 1 h, threshold from NOL-31) and new «Протерміновано» (≥ 24 h) labels/icons on the shared card; banners reworded (AC: 2)
- [x] Task 3: `updatedText` → «Оновлено о 12:00» (same day) / «Оновлено 10.11 12:00» (AC: 3)
- [x] Task 4: Regression test: API network error keeps the cache (AC: 4)
- [x] Task 5: Tests `TrustLabelsTests`

## Dev Notes

- Freshness = time of the last successful fetch by the app (`fetchedAt`), as before. The API file's own update time is shown in details as «Оновлено в API: …» (from NOL-15); stale API regions additionally show «Графік ще не опублікований» for today.
- Expired data keeps the existing rule: shown as unknown, never as «Світло є».
- Stacked on NOL-15 (PR #16).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Place in an API region → «неофіційне джерело» on the card, widget and details; Cherkasy site place → no badge.
2. Don't refresh for > 1 h → «Застаріло»; > 24 h → «Протерміновано» and unknown state.
3. Airplane mode → last schedule with «Оновлено о …».
4. ⌘U → `TrustLabelsTests` green.

### File List
- Tests/TrustLabelsTests.swift (new)
- Shared/UI/SharedViews.swift
- Shared/UI/PlaceCardContent.swift
- Shared/Models/StatusCalculator.swift
- App/HomeView.swift
- App/PlaceDetailView.swift
- Widget/SubgroupWidget.swift
- Widget/SubgroupWidgetView.swift
- Widget/PlacesListWidget.swift
- _bmad-output/implementation-artifacts/2-2-trust-and-freshness-labels.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
