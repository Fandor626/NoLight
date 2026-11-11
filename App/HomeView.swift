import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showingAddPlace = false
    @State private var lastAddedID: UUID?
    @State private var showingManage = false
    @State private var renaming: Place?
    @State private var deleting: Place?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            DataStatusBanners(state: state, now: context.date)

                            if state.places.isEmpty {
                                EmptyStateView { showingAddPlace = true }
                            } else {
                                ForEach(state.places) { place in
                                    NavigationLink(value: place) {
                                        PlaceCardView(
                                            name: place.name,
                                            presentation: SubgroupPresentation(snapshot: state.snapshot,
                                                                               subgroup: place.subgroup, now: context.date))
                                    }
                                    .buttonStyle(.plain)
                                    .id(place.id)
                                    .contextMenu {
                                        Button { renaming = place } label: {
                                            Label("Перейменувати", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) { deleting = place } label: {
                                            Label("Видалити", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable { await state.refresh() }
                    .onChange(of: lastAddedID) { _, id in
                        guard let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Світло")
            .navigationDestination(for: Place.self) { PlaceDetailView(placeID: $0.id) }
            .toolbar {
                if !state.places.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Керувати") { showingManage = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddPlace = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Додати місце")
                }
            }
            .sheet(isPresented: $showingAddPlace) {
                AddPlaceView { place in
                    state.addPlace(place)
                    lastAddedID = place.id
                }
            }
            .sheet(isPresented: $showingManage) { ManagePlacesView() }
            .placeActions(renaming: $renaming, deleting: $deleting)
        }
    }
}

struct EmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash.fill").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Немає збережених місць").font(.headline)
            Text("Додайте місце (наприклад, Дім чи Роботу), щоб бачити його графік відключень.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Додати місце", action: action).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

/// Картка місця: назва, стан, найближча зміна, шкала 24 год і свіжість даних.
struct PlaceCardView: View {
    let name: String
    let presentation: SubgroupPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SubgroupBadge(text: presentation.subgroup.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                    Text(presentation.headline)
                        .font(.headline)
                        .foregroundStyle(presentation.status.state.textColor)
                    if let detail = presentation.detail {
                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            TimelineBarView(intervals: presentation.today.intervals, nowMinute: presentation.minuteNow, barHeight: 16)
            HStack {
                if presentation.showsStaleWarning { StaleWarningLabel() }
                Spacer()
                if let updated = presentation.updatedText { Text(updated).foregroundStyle(.secondary) }
            }
            .font(.caption2)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Повідомлення про помилки та застарілість даних.
struct DataStatusBanners: View {
    let state: AppState
    let now: Date

    var body: some View {
        let reliability = StatusCalculator.reliability(fetchedAt: state.snapshot?.fetchedAt, now: now)
        VStack(spacing: 8) {
            if let error = state.lastError {
                Banner(icon: "wifi.exclamationmark", tint: .orange,
                       text: error.message + (state.snapshot == nil ? "" : " Показано збережені дані."))
            }
            switch reliability {
            case .stale:
                Banner(icon: "exclamationmark.triangle.fill", tint: .orange,
                       text: "Дані можуть бути застарілими. Останнє успішне оновлення: "
                             + KyivTime.shortDateTimeString(state.snapshot?.fetchedAt ?? now) + ".")
            case .expired:
                Banner(icon: "clock.badge.exclamationmark.fill", tint: .red,
                       text: "Збережені дані надто старі й не показуються як актуальні. Оновіть, коли з’явиться інтернет.")
            case .none:
                if state.lastError == nil && !state.isRefreshing {
                    Banner(icon: "arrow.down.circle", tint: .blue, text: "Дані ще не завантажено.")
                }
            case .fresh:
                EmptyView()
            }
            if state.isRefreshing {
                HStack(spacing: 8) { ProgressView(); Text("Оновлення…").font(.footnote).foregroundStyle(.secondary) }
            }
        }
    }
}

struct Banner: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
