import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var tab = Tab.home

    enum Tab { case home, settings }

    var body: some View {
        TabView(selection: $tab) {
            HomeView().tabItem { Label("Графіки", systemImage: "bolt.fill") }.tag(Tab.home)
            SettingsView().tabItem { Label("Налаштування", systemImage: "gearshape.fill") }.tag(Tab.settings)
        }
        // Посилання з віджетів: nolight://place/{id} відкриває місце, nolight://home — головний екран.
        .onOpenURL { url in
            guard url.scheme == DeepLink.scheme else { return }
            tab = .home
            state.openedPlaceID = DeepLink.placeID(from: url)
        }
    }
}
