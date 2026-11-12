---
baseline_commit: 5e79fbeb424563fde901efb1d471a95434e9c48a
jira: NOL-47
branch: feature/NOL-47-watch-widget
stacked_on: feature/NOL-46-watch-app
---
# Story 10.2: Watch widget with a ±2 h timeline

Status: review

## Story

As Bohdan,
I want a widget on my watch face and in the Smart Stack with the chosen place,
so that I see the schedule around now at a glance.

## Acceptance Criteria

1. Given a chosen place, When I add the rectangular widget, Then I see the state and the −2 h … +2 h timeline with the now marker and the countdown.
2. Given the next change is within the window, Then the timeline shows the change point and the countdown updates without opening the app.
3. Given the window crosses midnight, Then tomorrow's schedule is used, or that part is gray «Невідомо» if not published.
4. Given 30 minutes before a change, Then the widget is given high relevance in the Smart Stack.
5. Given the color settings on the iPhone, Then the watch widget uses the same colors.

## Tasks / Subtasks

- [x] Task 1: watchOS widget extension `NoLightWatchWidget` (`project.yml`, embedded in `NoLightWatch`, same App Group and version) (AC: 1)
- [x] Task 2: `WatchPlaceProvider`: place chosen on the watch, cache of the watch App Group (`refreshIfNeeded` 30 min); entries every 15 min and at change points for 6 h, reload after 1 h (AC: 1, 2)
- [x] Task 3: Families: rectangular (name, state, `WatchTimelineBar`, `Text(timerInterval:)` countdown), circular (capacity gauge of the current interval + state icon), corner (icon + countdown label), inline («Світло до 18:00») (AC: 1, 2)
- [x] Task 4: `WatchComplication` (Shared, pure): inline text incl. «24:00» / «(завтра)», gauge progress, Smart Stack relevance (1.0 within 30 min of a change) (AC: 2, 4)
- [x] Task 5: `widgetAccentable` for tinted faces; colors from the synced `ColorTheme` (dark variants) (AC: 5)
- [x] Task 6: Tests `WatchComplicationTests` (midnight crossing covered by `TimelineWindowTests`, AC3)

## Dev Notes

- Stacked on NOL-46.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment). New watchOS extension — expect possible signing/target fixes on first build.

### Manual verification
1. `xcodegen generate` → run on the watch → long-press a watch face → Edit → Complications → NoLight (rectangular, circular, corner, inline).
2. Smart Stack: add NoLight; 30 min before a change it moves up.
3. Rectangular widget shows the bar with the now marker and a countdown that ticks.
4. Change colors on the iPhone → the watch widget uses them after the next update.
5. ⌘U → `WatchComplicationTests` green.

### File List
- project.yml
- WatchWidget/** (new)
- Shared/Models/WatchComplication.swift (new)
- Tests/WatchComplicationTests.swift (new)
- _bmad-output/implementation-artifacts/10-2-watch-widget-timeline.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
