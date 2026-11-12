import SwiftUI

@main
struct NoLightWatchApp: App {
    @State private var state = WatchState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(state)
                .task {
                    WatchReceiver.shared.activate { state.reloadFromStores() }
                    await state.refresh()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await state.refresh() } }
        }
    }
}
