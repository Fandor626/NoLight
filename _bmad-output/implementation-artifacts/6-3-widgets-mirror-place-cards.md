---
baseline_commit: 87fe8388d83d3f407c0680ec433a55ed2383313e
jira: NOL-40
branch: feature/NOL-40-widgets-mirror-place-cards
stacked_on: feature/NOL-31-widget-states (PR #10)
---
# Story 6.3: Widgets mirror place cards

Status: review

## Story

As Bohdan,
I want my widgets to show the same place cards as the app («Дім», «Робота», …),
so that the app and the home screen are consistent and I recognise each place instantly.

## Acceptance Criteria

1. Given a place «Робота» (4.2), When I add a place widget for it, Then it shows «Робота», badge 4.2, the same state headline and next change as the app card, the timeline with a now-marker and the freshness label.
2. Given the same moment and data, Then the app card and the widget show identical state, next-change text and freshness.
3. Given I rename «Робота» to «Офіс», Then the widget shows «Офіс» after its reload, without reconfiguring.
4. Given a «Мої місця» widget, Then medium shows the first 2 places and large the first 4, in the app's order; reordering changes the widget order.
5. Given more places than fit, Then the widget shows «+N».
6. Given no places, Then «Мої місця» shows «Додайте місце в застосунку» and opens the app on tap.
7. Given I tap a place card in any widget, Then the app opens that place's details.
8. Given no data or expired data, Then widgets show unknown-type states exactly like the app, never «Світло є».

## Tasks / Subtasks

- [x] Task 1: `Shared/UI/PlaceCardContent.swift` — one card for app and widgets; `PlaceCardStyle` (.app, .widgetSmall, .widgetMedium, .widgetLarge, .listRow) changes only sizes/what fits; all texts from `SubgroupPresentation` (AC: 1, 2, 8)
- [x] Task 2: App `PlaceCardView` = `PlaceCardContent(.app)` + chevron (AC: 2)
- [x] Task 3: Place widget (S/M/L) = `PlaceCardContent` + refresh button; large adds tomorrow + today's outage list; `widgetURL` → `nolight://place/{id}` (AC: 1, 3, 7)
- [x] Task 4: New `PlacesListWidget` «Мої місця» (medium 2 / large 4, app order, «+N місць», empty state, row links) (AC: 4, 5, 6, 7)
- [x] Task 5: Deep link: URL scheme `nolight` in `project.yml` / `App/Info.plist`; `RootView.onOpenURL` → home tab + `AppState.openedPlaceID` → `HomeView` pushes `PlaceDetailView` (AC: 7)
- [x] Task 6: Tests `PlaceCardsTests` (layout, Ukrainian plurals, deep link parsing) (AC: 4, 5, 7, 8)

## Dev Notes

- Open question «tomorrow in the large "Мої місця" widget?» — resolved as **today only** to keep 4 rows readable; the single-place large widget keeps tomorrow.
- Renames/reorders reach widgets through `AppState.save()` → `WidgetCenter.reloadAllTimelines()`; both widget kinds read places from `PlaceStore` at render time.
- `«Мої місця»` uses a `StaticConfiguration` (no settings); its timeline merges `WidgetTimelinePlanner` dates of the shown places.
- Stacked on NOL-31 (PR #10).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5

### Completion Notes List

- Build and tests NOT run (no Swift toolchain/Xcode in the agent environment).

### Manual verification (device)
1. Place «Робота» 4.2 → add «Місце» widget (S/M/L) → same name, badge, headline, next change, timeline, freshness as the app card.
2. Rename to «Офіс» → widget updates after reload.
3. Add «Мої місця» medium & large → 2 / 4 places in app order; reorder in the app → order follows; with 5 places large shows «+1 місце».
4. Delete all places → «Додайте місце в застосунку».
5. Tap a card in either widget → app opens on that place's details.
6. ⌘U → `PlaceCardsTests` green.

### File List
- Shared/UI/PlaceCardContent.swift (new)
- Shared/Models/PlacesListLayout.swift (new)
- Shared/Support/DeepLink.swift (new)
- Widget/PlacesListWidget.swift (new)
- Tests/PlaceCardsTests.swift (new)
- Widget/SubgroupWidget.swift
- Widget/SubgroupWidgetView.swift
- App/HomeView.swift
- App/RootView.swift
- App/AppState.swift
- App/Info.plist
- project.yml
- _bmad-output/implementation-artifacts/6-3-widgets-mirror-place-cards.md (new)
- _bmad-output/implementation-artifacts/sprint-status.yaml
