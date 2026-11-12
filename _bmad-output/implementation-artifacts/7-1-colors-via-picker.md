---
baseline_commit: fc8fcf82de75cbbf483bc726f62582bdc69e7742
jira: NOL-32
branch: feature/NOL-32-color-picker
stacked_on: main
---
# Story 7.1: Pick colors with a picker

Status: review

## Story

As Bohdan,
I want to choose the color for «Світло є» and «Відключення»,
so that schedules are easy for me to read.

## Acceptance Criteria

1. Given color settings, When I change a color with the picker, Then it is visible immediately in the app and in widgets.
2. Given light and dark themes, Then the color is stored for both themes.

## Tasks / Subtasks

- [x] Task 1: `ColorTheme` (Shared): `RGBAColor` stored as hex, `ThemedColor` (light + dark) for «Світло є» and «Відключення»; default = current soft palette (AC: 2)
- [x] Task 2: `ColorThemeStore` (App Group, `colorTheme.v1`): corrupted data / nothing saved → default (AC: 1, 2)
- [x] Task 3: `ColorSettings` (Observable): the app sees changes immediately; the widget extension reads the store on every render (AC: 1)
- [x] Task 4: `PowerState.color/textColor` read the theme (dynamic light/dark `UIColor`) (AC: 1, 2)
- [x] Task 5: Settings → «Вигляд» → «Кольори»: preview + ColorPicker per state for «Світла тема» / «Темна тема»; reload widget timelines on change (AC: 1, 2)
- [x] Task 6: Tests `ColorThemeTests`

## Dev Notes

- «Невідомо» keeps the system gray.
- Saving the default theme removes the override, so NOL-34 (reset) only needs to remove the key.
- Sprint 5 stories set to ready-for-testing in sprint-status (merged).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Settings → «Вигляд» → «Кольори» → change «Відключення» in «Світла тема» → preview and Home cards change at once; widgets update.
2. Switch the device to dark mode → the «Темна тема» colors are used.
3. ⌘U → `ColorThemeTests` green.

### File List
- Shared/Models/ColorTheme.swift (new)
- Shared/UI/SharedViews.swift
- App/ColorSettingsView.swift (new)
- App/SettingsView.swift
- Tests/ColorThemeTests.swift (new)
- _bmad-output/implementation-artifacts/7-1-colors-via-picker.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
