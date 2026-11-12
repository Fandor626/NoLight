import SwiftUI

@main
@MainActor
struct NoLightApp: App {
    @State private var state = AppState.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .task {
                    WatchSync.shared.activate()
                    await state.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await state.refresh()
                    await state.restoreLiveActivities()
                }
            case .background: BackgroundRefresh.schedule()
            default: break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.perform()
        }
    }
}
