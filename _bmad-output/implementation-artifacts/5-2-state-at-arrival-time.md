---
baseline_commit: 0c5143fe0c318526aeb95d96540f2aef2e63d599
jira: NOL-29
branch: feature/NOL-29-state-at-arrival
stacked_on: feature/NOL-28-travel-preview
---
# Story 5.2: State at arrival time

Status: review

## Story

As Bohdan,
I want to enter my arrival time or trip duration,
so that I know whether there will be power when I get there.

## Acceptance Criteria

1. Given a selected subgroup, When I enter an arrival time or a duration from now, Then I see the state at that moment and the next change after it.
2. Given arrival after midnight, Then the next day's schedule is used, or «Невідомо» if it isn't published.

## Tasks / Subtasks

- [x] Task 1: `ArrivalCalculator` (Shared): `ArrivalInput` (Kyiv clock time — already passed today means tomorrow — or duration 0…48 h), arrival `Date`, `dayOffset` (AC: 1, 2)
- [x] Task 2: Forecast = `StatusCalculator.status(today:tomorrow:now: arrival)` on the stale-aware presentation; after tomorrow → «Невідомо» (AC: 1, 2)
- [x] Task 3: `ArrivalForecast` copy: «Світло буде / Світла не буде / Невідомо», next change («Далі відключення о…», «Світло з’явиться о… (завтра)»), «Приїзд сьогодні/завтра о…» (AC: 1, 2)
- [x] Task 4: «Подорож» → section «Коли приїдете»: «Час приїзду» (DatePicker, Kyiv time) / «Тривалість поїздки» (Stepper, 15 min step) (AC: 1)
- [x] Task 5: Tests `ArrivalForecastTests`

## Dev Notes

- Expired data (>24 h) never gives a confident answer: the forecast is «Невідомо».
- Stacked on NOL-28.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification
1. «Подорож» → choose a subgroup → «Тривалість поїздки» 2 год 30 хв → state at arrival + next change.
2. «Час приїзду» earlier than now (e.g. 01:00) → «Приїзд завтра о 01:00»; if tomorrow isn't published → «Невідомо».
3. ⌘U → `ArrivalForecastTests` green.

### File List
- Shared/Models/ArrivalForecast.swift (new)
- App/TravelView.swift
- Tests/ArrivalForecastTests.swift (new)
- _bmad-output/implementation-artifacts/5-2-state-at-arrival-time.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
