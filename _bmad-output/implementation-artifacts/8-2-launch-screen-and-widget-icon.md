---
baseline_commit: b78461d2b9cf99384ebedb987dc7dd26a82518ed
jira: NOL-36
branch: feature/NOL-36-launch-screen
stacked_on: feature/NOL-35-logo-and-app-icon
---
# Story 8.2: Launch screen and widget icon

Status: review

## Story

As Bohdan,
I want to see the logo at launch and in the widget gallery,
so that the brand is consistent.

## Acceptance Criteria

1. Given app launch, Then a launch screen with the logo is shown without flicker.
2. Given the widget gallery, Then the widget icon is shown.

## Tasks / Subtasks

- [x] Task 1: `LaunchBackground.colorset`: #F2F2F7 (light) / #000000 (dark) = `systemGroupedBackground` of the first screen, so there is no color flash (AC: 1)
- [x] Task 2: `UILaunchScreen` in `project.yml` and `App/Info.plist`: `UIImageName: Logo`, `UIColorName: LaunchBackground` (AC: 1)
- [x] Task 3: Widget gallery: widgets show the NoLight app icon from `AppIcon` (NOL-35); names «Місце» / «Мої місця» and descriptions already set (AC: 2)

## Dev Notes

- iOS takes the widget gallery icon from the containing app's icon, so no separate widget asset is needed.
- iOS caches launch screens: delete the app (or restart the device) before checking.
- Stacked on NOL-35.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build NOT run (no Swift toolchain/Xcode in the agent environment). Run `xcodegen generate` after merging.

### Manual verification
1. Delete the app → build & run → launch screen with the bolt on a light (or black in dark mode) background, then Home without a color flash.
2. Home screen → add widget → «NoLight» shows the new icon.

### File List
- App/Assets.xcassets/LaunchBackground.colorset/Contents.json (new)
- project.yml
- App/Info.plist
- _bmad-output/implementation-artifacts/8-2-launch-screen-and-widget-icon.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
