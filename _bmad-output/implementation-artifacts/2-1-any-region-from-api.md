---
baseline_commit: cd360a16e032fab613f7617758eb94304247d03c
jira: NOL-15
branch: feature/NOL-15-any-region-from-api
---
# Story 2.1: Pick any region from the API

Status: review

## Story

As Bohdan,
I want to choose any region in the cascade,
so that I can see schedules beyond Cherkasy.

## Acceptance Criteria

1. Given the OE_OUTAGE_DATA API is reachable, When I add a place, Then all regions with API data are listed and their queues/subgroups match the region file.
2. Given API values (yes/no, first/second/mfirst/msecond), When the app parses a file, Then they are normalized to available/outage/unknown; any unknown value gives unknown.
3. Given the region file has no data for a subgroup, When I open the place, Then «Невідомо» is shown.

## Tasks / Subtasks

- [x] Task 1: `Region` — all 12 regions in the API (titles, `apiFileName`, `defaultSource`); `selectable` = Cherkasy first, then A–Z (AC: 1)
- [x] Task 2: `PlaceSource.outageDataAPI`, `ScheduleSourceKey` (source + region), `Place.sourceKey` (site only for Cherkasy) (AC: 1)
- [x] Task 3: `OutageDataParser` (format verified on real files 12.11.2026) + `OutageDataService` (raw.githubusercontent.com, 14-day history merge) (AC: 2)
- [x] Task 4: `DaySchedule.build(… unknown:)` + optional `PublishedSchedulePost.unknown` (old cache still decodes) (AC: 2, 3)
- [x] Task 5: Per-source repositories: cache file and failure status per key; `ScheduleSourcing` protocol (AC: 1)
- [x] Task 6: `AppState` keeps snapshots/errors per key and refreshes all used keys in parallel; adding a place in a new region loads it at once; cards/details use `snapshot(for: place)`; details show the source (AC: 1, 3)
- [x] Task 7: Widgets (both kinds), the refresh button and the background task use each place's source (AC: 1)
- [x] Task 8: Tests `OutageDataTests`; updated region test

## Dev Notes

- **Value mapping (PRD §8 q2, resolved):** `yes` → available; `no` → outage; `first`/`second` → outage in the first/second 30 min; `mfirst`/`msecond` («можливе відключення») → **outage** (never promise power that may not be there, NFR6; better to prepare the generator); anything else or a missing hour → unknown for that hour only.
- Day key: `fact.data` keys are unix timestamps; some files use Kyiv midnight, others UTC midnight — both map to the same Kyiv date.
- Several regions in the API are stale (e.g. Lviv/Ternopil 17.10, Rivne 20.10). They are listed; today then shows «Графік ще не опублікований». Freshness/«неофіційне» labels come in NOL-16 — note that `fetchedAt` is our fetch time, NOL-16 should use the file's `lastUpdated` (kept as `publishedAt`).
- Cherkasy keeps the site as default; API for Cherkasy is selectable in NOL-17.
- Cache for the Cherkasy site keeps its v1 file name; API caches are `schedule-cache-outageDataAPI-<region>-v1.json`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment). Parser logic was checked against the real API files manually.

### Manual verification (device)
1. «Додати місце» → region list has 12 regions; pick «Чернігівська», queue 3 → card shows today's schedule from the API, details say «Джерело: OE_OUTAGE_DATA (неофіційне джерело)».
2. Pick «Львівська» (stale in the API) → «Графік ще не опублікований», not «Світло є».
3. Mixed places (Cherkasy site + API region) → pull-to-refresh updates both; airplane mode → both keep cached data.
4. Widgets for an API place show its schedule.
5. ⌘U → `OutageDataTests` green.

### File List
- Shared/Parsing/OutageDataParser.swift (new)
- Shared/Data/OutageDataService.swift (new)
- Tests/OutageDataTests.swift (new)
- Shared/Models/Place.swift
- Shared/Models/Schedule.swift
- Shared/Models/WidgetPlaceResolver.swift
- Shared/Data/ScheduleRepository.swift
- Shared/Data/ScheduleCache.swift
- Shared/Data/RefreshStatusStore.swift
- App/AppState.swift
- App/AddPlaceView.swift
- App/HomeView.swift
- App/PlaceDetailView.swift
- App/BackgroundRefresh.swift
- Widget/SubgroupWidget.swift
- Widget/PlacesListWidget.swift
- Widget/RefreshIntent.swift
- Tests/PlaceStoreTests.swift
- _bmad-output/implementation-artifacts/2-1-any-region-from-api.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
