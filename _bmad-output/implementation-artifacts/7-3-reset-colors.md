---
baseline_commit: 503a1d896ed02d8090b993ff790082847c6ffed1
jira: NOL-34
branch: feature/NOL-34-reset-colors
stacked_on: feature/NOL-33-color-presets
---
# Story 7.3: Reset colors

Status: review

## Story

As Bohdan,
I want to reset colors to the defaults,
so that I can go back to the original look.

## Acceptance Criteria

1. Given changed colors, When I tap «Скинути», Then the default colors are restored.

## Tasks / Subtasks

- [x] Task 1: `ColorSettings.reset()`: removes the stored override (`colorTheme.v1`) so defaults apply in the app and widgets (AC: 1)
- [x] Task 2: «Кольори» → «Скинути кольори» (disabled when already default) → confirmation «Повернути стандартні кольори?» → reset + widget reload (AC: 1)
- [x] Task 3: Tests `ColorResetTests`

## Dev Notes

- Stacked on NOL-33.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. Pick any preset or custom color → «Скинути кольори» → «Скинути» → the soft green/red return in the app and widgets; the button becomes disabled.
2. ⌘U → `ColorResetTests` green.

### File List
- Shared/Models/ColorTheme.swift
- App/ColorSettingsView.swift
- Tests/ColorResetTests.swift (new)
- _bmad-output/implementation-artifacts/7-3-reset-colors.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
