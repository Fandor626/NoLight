import Foundation

/// Центральна конфігурація. App Group береться з Info.plist (ключ AppGroupIdentifier ← build setting APP_GROUP_ID).
enum AppConfig {
    /// Офіційний список новин — тут Черкасиобленерго публікує щоденні графіки ГПВ.
    static let newsListURL = URL(string: "https://www.cherkasyoblenergo.com/news?lang=uk")!
    static let siteURL = URL(string: "https://www.cherkasyoblenergo.com/vidkliuchennia?lang=uk")!

    /// Після цього часу без успішного оновлення дані можуть бути неактуальними.
    static let staleAfter: TimeInterval = 4 * 3600
    /// Після цього часу збережені дані більше не показуються як актуальні.
    static let expiredAfter: TimeInterval = 24 * 3600

    static let fallbackAppGroupID = "group.com.example.NoLight"

    static var appGroupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String) ?? fallbackAppGroupID
    }

    static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }
}
