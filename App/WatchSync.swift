import Foundation
import WatchConnectivity

/// Надсилає на Apple Watch місця, вибране місце й кольори (NOL-46).
/// `updateApplicationContext` зберігає лише останній стан і доставляється, щойно годинник доступний.
final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Поточні місця з App Group — після будь-якої зміни місць, кольорів або вибору для годинника.
    func send(places: [Place] = PlaceStore.shared.places) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let payload = WatchPayload(places: places,
                                   preferredPlaceID: WatchPlaceStore.shared.placeID,
                                   theme: ColorThemeStore.shared.theme,
                                   sentAt: .now)
        try? session.updateApplicationContext(payload.applicationContext())
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated { send() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Користувач змінив годинник — активуємо сесію для нового.
        WCSession.default.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) { send() }
}
