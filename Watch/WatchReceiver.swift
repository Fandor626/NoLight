import Foundation
import WatchConnectivity

/// Приймає місця, вибране на iPhone місце й кольори (NOL-46) і зберігає їх в App Group годинника.
final class WatchReceiver: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchReceiver()
    private var onUpdate: (@MainActor () -> Void)?

    func activate(onUpdate: @escaping @MainActor () -> Void) {
        self.onUpdate = onUpdate
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // Контекст, що прийшов, поки застосунок був закритий.
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ context: [String: Any]) {
        guard let payload = WatchPayload.decode(context) else { return }
        PlaceStore.shared.places = payload.places
        ColorThemeStore.shared.save(payload.theme)
        WatchPlaceStore.shared.apply(payload)
        let callback = onUpdate
        Task { @MainActor in callback?() }
    }
}
