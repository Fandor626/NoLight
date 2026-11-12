import Foundation

/// Скільки карток місць показує віджет «Мої місця» і що робити з рештою.
enum PlacesListLayout {
    static let mediumCapacity = 2
    static let largeCapacity = 4

    /// Перші `capacity` місць у порядку застосунку + кількість тих, що не влізли.
    static func visible(_ places: [Place], capacity: Int) -> (shown: [Place], overflow: Int) {
        let shown = Array(places.prefix(max(capacity, 0)))
        return (shown, places.count - shown.count)
    }

    /// «+1 місце», «+3 місця», «+5 місць»; nil, якщо все влізло.
    static func overflowText(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        let mod10 = count % 10, mod100 = count % 100
        let word: String
        if mod10 == 1 && mod100 != 11 { word = "місце" }
        else if (2...4).contains(mod10) && !(12...14).contains(mod100) { word = "місця" }
        else { word = "місць" }
        return "+\(count) \(word)"
    }
}
