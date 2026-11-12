---
baseline_commit: 859a44f32e24bb5289741cd6040670ad5695b135
jira: NOL-27
branch: feature/NOL-27-night-bounds-settings
stacked_on: feature/NOL-26-night-day-split
---
# Story 4.3: Night bounds settings

Status: review

## Story

As Bohdan,
I want to change when night starts and ends,
so that it matches my routine.

## Acceptance Criteria

1. Given settings, When I set custom bounds, Then statistics are recalculated.
2. Given start equals end, Then a validation error is shown.

## Tasks / Subtasks

- [x] Task 1: `NightBoundsStore` (App Group, keys `nightStartMinute` / `nightEndMinute`): default 00:00–06:00, invalid or corrupted values → default, `save` rejects start == end (AC: 1, 2)
- [x] Task 2: `SettingsView` section «Статистика»: two `DatePicker(.hourAndMinute)` in Europe/Kyiv, red error «Початок і кінець ночі не можуть збігатися.», «Скинути до 00:00–06:00» (AC: 1, 2)
- [x] Task 3: `StatisticsView` reads the stored bounds, so statistics use them as soon as they are opened (AC: 1)
- [x] Task 4: Tests `NightBoundsSettingsTests`

## Dev Notes

- An invalid choice is never saved: the previous valid bounds keep being used until the error is fixed.
- `NightTime` (Shared) converts minute-of-day ↔ `Date` for the pickers.
- Stacked on NOL-26.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Settings → «Статистика» → set 22:00–06:00 → place details → «Статистика» → «Ніч 22:00–06:00» with recalculated hours.
2. Set start = end → red validation error; statistics keep the previous bounds.
3. ⌘U → `NightBoundsSettingsTests` green.

### File List
- Shared/Data/NightBoundsStore.swift (new)
- Shared/Models/NightBounds.swift
- App/SettingsView.swift
- App/StatisticsView.swift
- Tests/NightBoundsSettingsTests.swift (new)
- _bmad-output/implementation-artifacts/4-3-night-bounds-settings.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
