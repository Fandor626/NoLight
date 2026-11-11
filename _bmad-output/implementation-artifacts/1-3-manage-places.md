---
baseline_commit: 0c121f4586190d1bcc0480a648360e7f8f803de1
jira: NOL-12
branch: feature/NOL-12-manage-places
stacked_on: feature/NOL-11-add-a-place (PR #5)
---
# Story 1.3: Manage places

Status: review

## Story

As Bohdan,
I want to rename, reorder and delete places,
so that the list matches my situation.

## Acceptance Criteria

1. Given several places, When I change their order, Then the order persists after relaunch.
2. Given a place, When I rename it, Then the new name is shown everywhere in the app (and in widgets once NOL-30 is done).
3. Given a place, When I delete it and confirm, Then it disappears.
4. Given a deleted place had scheduled notifications, Then they are cancelled.

## Tasks / Subtasks

- [x] Task 1: `AppState.renamePlace`, `movePlaces`, `removePlace` as the single deletion point (AC: 1, 2, 3)
- [x] Task 2: `Place.normalizedName` shared by the add form and rename (AC: 2)
- [x] Task 3: `ManagePlacesView` («Мої місця»): EditButton + drag to reorder, swipe → «Перейменувати» / «Видалити», tap → rename (AC: 1, 2, 3)
- [x] Task 4: Home: «Керувати» button, card context menu «Перейменувати» / «Видалити»; shared `placeActions` modifier with rename alert and delete confirmation (AC: 2, 3)
- [x] Task 5: Tests `PlaceManagementTests` (AC: 1, 2)

## Dev Notes

- Order = array order in `PlaceStore` (`places.v1`); `movePlaces` uses SwiftUI `move(fromOffsets:toOffset:)`.
- AC4: there are no scheduled notifications yet (NOL-21). `AppState.removePlace` is the single deletion point; NOL-21 cancels pending requests there. Nothing to cancel today.
- Every change saves and reloads widget timelines; widgets show places from NOL-30.
- Stacked on NOL-11 (PR #5) because both change `HomeView`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (Xcode)
1. Home → «Керувати» → «Змінити» → drag places → «Готово» → relaunch → order kept.
2. Swipe a place → «Перейменувати» → new name → shown on the home card.
3. Long-press a card → «Видалити» → confirmation → place disappears; «Скасувати» keeps it.
4. Rename to blank → «Зберегти» disabled (or ignored).
5. ⌘U → `PlaceManagementTests` green.

### File List
- App/PlaceActions.swift (new)
- App/AppState.swift
- App/HomeView.swift
- Shared/Models/Place.swift
- Tests/PlaceStoreTests.swift
- _bmad-output/implementation-artifacts/1-3-manage-places.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
