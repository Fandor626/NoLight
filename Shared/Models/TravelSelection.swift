import Foundation

/// Вибір на екрані «Подорож» (NOL-28): область → черга → підчерга без створення місця.
struct TravelSelection: Equatable, Sendable {
    var region: Region = .cherkasy
    var queue = 1
    var sub = 1

    var subgroup: Subgroup? { Subgroup(queue: queue, sub: sub) }

    /// Звідки брати графік: те саме джерело, що отримало б нове місце в цій області.
    var sourceKey: ScheduleSourceKey { ScheduleSourceKey(source: region.defaultSource, region: region) }

    /// Тимчасове місце для перегляду: НЕ зберігається в PlaceStore.
    var transientPlace: Place? {
        guard let subgroup else { return nil }
        return Place(id: Self.transientID, name: suggestedName, region: region, subgroup: subgroup,
                     source: region.defaultSource)
    }

    /// «Львівська обл., 2.1» — назва за замовчуванням для «Зберегти як місце».
    var suggestedName: String {
        "\(region.title) обл., " + (subgroup?.id ?? "\(queue).\(sub)")
    }

    /// Справжнє місце з тими самими параметрами. nil — назва порожня/задовга або підчерга некоректна.
    func makePlace(name: String, id: UUID = UUID()) -> Place? {
        guard let subgroup, region.hasScheduleData, let name = Place.normalizedName(name) else { return nil }
        return Place(id: id, name: name, region: region, subgroup: subgroup, source: region.defaultSource)
    }

    /// Стабільний id тимчасового місця, щоб він не збігався зі збереженими.
    static let transientID = UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE")!
}

/// «2 год 30 хв» для інтервалів у перегляді подорожі.
enum TravelFormat {
    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if m == 0 { return "\(h) год" }
        if h == 0 { return "\(m) хв" }
        return "\(h) год \(m) хв"
    }
}
