import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class AppState {
    private(set) var selected: [Subgroup]
    private(set) var snapshot: ScheduleSnapshot?
    private(set) var isRefreshing = false
    private(set) var lastError: ScheduleError?

    @ObservationIgnored private let repository: ScheduleRepository
    @ObservationIgnored private let settings: SettingsStore

    init(repository: ScheduleRepository, settings: SettingsStore) {
        self.repository = repository
        self.settings = settings
        self.selected = settings.selectedSubgroups
    }

    static func live() -> AppState {
        let repository = ScheduleRepository.live(onUpdate: { WidgetCenter.shared.reloadAllTimelines() })
        return AppState(repository: repository, settings: .shared)
    }

    /// Спочатку миттєво показуємо кеш, потім оновлюємо з мережі.
    func start() async {
        snapshot = await repository.cachedSnapshot()
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await repository.refresh()
            lastError = nil
        } catch is CancellationError {
        } catch let error as ScheduleError {
            lastError = error
            snapshot = await repository.cachedSnapshot()
        } catch {
            lastError = .serverUnavailable(status: nil)
            snapshot = await repository.cachedSnapshot()
        }
    }

    func isSelected(_ subgroup: Subgroup) -> Bool { selected.contains(subgroup) }
    func toggle(_ subgroup: Subgroup) { isSelected(subgroup) ? remove(subgroup) : add(subgroup) }

    func add(_ subgroup: Subgroup) {
        guard !isSelected(subgroup) else { return }
        selected.append(subgroup)
        selected.sort()
        settings.selectedSubgroups = selected
    }

    func remove(_ subgroup: Subgroup) {
        selected.removeAll { $0 == subgroup }
        settings.selectedSubgroups = selected
    }
}
