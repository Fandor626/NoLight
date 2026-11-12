---
baseline_commit: f9985ed343e2279334c668520792802105ee83a2
jira: NOL-33
branch: feature/NOL-33-color-presets
stacked_on: feature/NOL-32-color-picker
---
# Story 7.2: Color presets

Status: review

## Story

As Bohdan,
I want to choose a ready-made preset,
so that I quickly get a good combination.

## Acceptance Criteria

1. Given the colors screen, Then there are several presets, including ones for color blindness.
2. Given a preset is chosen, Then the colors apply to the app and widgets.

## Tasks / Subtasks

- [x] Task 1: `ColorPreset` (Shared): «Стандартні», «Висока контрастність», «Синій / помаранчевий» (deuteranopia/protanopia), «Бірюзовий / малиновий» (tritanopia); `matching(_:)` (AC: 1)
- [x] Task 2: `ColorContrast` (WCAG 2.x): every non-default preset ≥ 3:1 against the card background in light (#FFFFFF) and dark (#1C1C1E) themes (epic AC2)
- [x] Task 3: «Кольори» → «Готові набори»: swatches, checkmark on the current preset, «Зараз вибрано власні кольори» when custom; tap applies to app and widgets (AC: 1, 2)
- [x] Task 4: Tests `ColorPresetsTests`

## Dev Notes

- Open question from the task (exact preset list) resolved by the agent: the four presets above. Contrast values: high contrast 5.3/6.2 (light), 9.8/6.1 (dark); blue/orange 5.3/5.0, 6.9/8.3; teal/magenta 5.2/5.9, 9.0/6.5.
- The default palette keeps its look (light «Світло є» is 2.8:1 on white); presets fix that for those who need it.
- Stacked on NOL-32.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. «Кольори» → «Синій / помаранчевий» → checkmark moves, preview, Home and widgets use blue/orange.
2. Change one color with the picker → no preset is checked, footer «Зараз вибрано власні кольори».
3. ⌘U → `ColorPresetsTests` green.

### File List
- Shared/Models/ColorPresets.swift (new)
- App/ColorSettingsView.swift
- Tests/ColorPresetsTests.swift (new)
- _bmad-output/implementation-artifacts/7-2-color-presets.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
