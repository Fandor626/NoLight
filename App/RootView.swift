import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Графіки", systemImage: "bolt.fill") }
            SettingsView().tabItem { Label("Налаштування", systemImage: "gearshape.fill") }
        }
    }
}
