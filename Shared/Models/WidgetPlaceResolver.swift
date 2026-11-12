import Foundation

/// Що показує віджет одного місця.
enum WidgetPlaceResolution: Equatable, Sendable {
    /// Вибране місце (або знайдене за підчергою старого віджета v1).
    case place(Place)
    /// Вибране місце видалено в застосунку.
    case deleted
    /// Віджет v1 з підчергою, для якої місця немає: показуємо саму підчергу.
    case legacy(Subgroup)

    var subgroup: Subgroup? {
        switch self {
        case .place(let place): return place.subgroup
        case .legacy(let subgroup): return subgroup
        case .deleted: return nil
        }
    }

    /// Звідки брати графік (віджети v1 і видалене місце — сайт Черкас, як у v1).
    var sourceKey: ScheduleSourceKey {
        if case .place(let place) = self { return place.sourceKey }
        return .cherkasySite
    }

    /// Заголовок картки віджета.
    var title: String {
        switch self {
        case .place(let place): return place.name
        case .legacy(let subgroup): return Place.defaultName(for: subgroup)
        case .deleted: return "Місце видалено"
        }
    }
}

enum WidgetPlaceResolver {
    /// - placeID: місце, вибране в «Змінити віджет» (nil для віджетів v1, налаштованих до появи місць).
    /// - legacySubgroup: підчерга зі старого параметра віджета v1.
    static func resolve(placeID: UUID?, legacySubgroup: Subgroup, places: [Place]) -> WidgetPlaceResolution {
        if let placeID {
            if let place = places.first(where: { $0.id == placeID }) { return .place(place) }
            return .deleted
        }
        if let place = places.first(where: { $0.subgroup == legacySubgroup }) { return .place(place) }
        return .legacy(legacySubgroup)
    }
}
