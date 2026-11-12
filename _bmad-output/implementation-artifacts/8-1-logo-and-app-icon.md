---
baseline_commit: fc8fcf82de75cbbf483bc726f62582bdc69e7742
jira: NOL-35
branch: feature/NOL-35-logo-and-app-icon
stacked_on: main
---
# Story 8.1: Logo and app icon

Status: review

## Story

As Bohdan,
I want my own logo and app icon,
so that the app looks finished.

## Acceptance Criteria

1. Given a build, Then the new icon is shown on the home screen.
2. The icon set covers all sizes required by iOS 17+ (single 1024×1024 + dark and tinted variants).

## Tasks / Subtasks

- [x] Task 1: Logo design (SVG sources in `design/logo/`): a lightning bolt split in half — lit left half (power on), dimmed right half (power off) (AC: 1)
- [x] Task 2: `App/Assets.xcassets/AppIcon.appiconset`: 1024×1024 default (navy gradient, no alpha), dark (transparent background) and tinted (grayscale) variants (AC: 1, 2)
- [x] Task 3: `Logo.imageset` (bolt only, 120 pt, @1x/@2x/@3x) — used in Settings «Про застосунок» and by NOL-36 (AC: 1)
- [x] Task 4: `project.yml`: `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` for the app target (AC: 1)
- [x] Task 5: `design/logo/README.md` with re-export commands

## Dev Notes

- Icon rendered with `rsvg-convert` from the SVG sources; preview: `design/logo/preview.png`.
- The widget gallery uses the containing app's icon; launch screen and widget gallery items are NOL-36.
- No unit tests: asset-only change; verify on device.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build NOT run (no Swift toolchain/Xcode in the agent environment). Run `xcodegen generate` after merging.

### Manual verification
1. `xcodegen generate` → build & run → the new icon on the home screen.
2. Home screen customization → Dark / Tinted → dark and tinted variants are used.
3. Settings → «Про застосунок» → logo + «NoLight».

### File List
- App/Assets.xcassets/** (new)
- design/logo/** (new)
- project.yml
- App/SettingsView.swift
- _bmad-output/implementation-artifacts/8-1-logo-and-app-icon.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
