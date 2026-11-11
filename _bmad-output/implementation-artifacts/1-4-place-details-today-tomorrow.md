---
baseline_commit: c8fc323b9a7f5d02fc905a66559fc606c49d729d
jira: NOL-13
branch: feature/NOL-13-place-details-today-tomorrow
stacked_on: feature/NOL-12-manage-places (PR #6)
---
# Story 1.4: Place details: today and tomorrow

Status: review

## Story

As Bohdan,
I want to open a place and see power and outage intervals,
so that I can plan today and tomorrow.

## Acceptance Criteria

1. Given I tap a place card, When details open, Then there is a «Сьогодні / Завтра» switch with a timeline and list of intervals.
2. Given tomorrow's schedule isn't published, When I pick «Завтра», Then «Графік ще не опублікований» is shown instead of an empty timeline.
3. Given an interval crosses midnight, Then it is shown correctly on both days.

## Tasks / Subtasks

- [x] Task 1: `SubgroupDetailView` → `PlaceDetailView(placeID:)`: title = current place name, badge + region, «Місце видалено» if the place disappears (AC: 1)
- [x] Task 2: Placeholder instead of the timeline when the day has no published schedule (AC: 2)
  - [x] 2.1 `DayScheduleKind.placeholderTitle` / `placeholderMessage` in `Shared/Models/Schedule.swift`; interval list reuses the message.
- [x] Task 3: Tests for the placeholder and the midnight-crossing interval (AC: 2, 3)

## Dev Notes

- The «Сьогодні / Завтра» switch, timeline and interval list already existed in v1 (`SubgroupDetailView`); this story binds them to a place.
- Midnight crossing is handled by `ScheduleSnapshot.schedule(for:dateKey:)` (`spillover`) — no change needed, now covered by a test.
- Looking the place up by id keeps the title in sync after a rename (NOL-12) and handles deletion while open.
- Stacked on NOL-12 (PR #6).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (Xcode)
1. Tap a place card → title is the place name, «Сьогодні» timeline + intervals.
2. Before tomorrow's post is published → «Завтра» shows «Графік ще не опублікований», not a grey bar.
3. With an outage 23:00–02:00 → it ends at 24:00 today and starts at 00:00 tomorrow.
4. ⌘U → new ScheduleLogicTests green.

### File List
- App/PlaceDetailView.swift (renamed from App/SubgroupDetailView.swift)
- App/HomeView.swift
- Shared/Models/Schedule.swift
- Tests/ScheduleLogicTests.swift
- _bmad-output/implementation-artifacts/1-4-place-details-today-tomorrow.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
