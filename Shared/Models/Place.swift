import Foundation

/// Область. Поки що лише Черкаська; інші з'являться разом з API (NOL-15).
enum Region: String, Codable, Hashable, Sendable, CaseIterable {
    case cherkasy

    var title: String {
        switch self {
        case .cherkasy: return "Черкаська"
        }
    }

    /// Чи є для області графіки. Для областей без даних форма показує пояснення (NOL-15 додасть такі області).
    var hasScheduleData: Bool {
        switch self {
        case .cherkasy: return true
        }
    }

    /// Області, доступні для вибору. Поки що лише Черкаська (NOL-11); решта — з API у NOL-15.
    static var selectable: [Region] { [.cherkasy] }
}

/// Звідки береться графік місця. API OE_OUTAGE_DATA додається в NOL-15 / NOL-17.
enum PlaceSource: String, Codable, Hashable, Sendable {
    case oblenergoSite
}

/// Збережене місце: назва + область + підчерга + джерело (Дім, Робота…).
struct Place: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var region: Region
    var subgroup: Subgroup
    var source: PlaceSource

    init(id: UUID = UUID(), name: String, region: Region = .cherkasy,
         subgroup: Subgroup, source: PlaceSource = .oblenergoSite) {
        self.id = id
        self.name = name
        self.region = region
        self.subgroup = subgroup
        self.source = source
    }

    /// Назва за замовчуванням для місця, створеного з підчерги.
    static func defaultName(for subgroup: Subgroup) -> String { "Підчерга \(subgroup.id)" }

    static let maxNameLength = 40

    /// Обрізає пробіли; nil — якщо назва порожня або довша за `maxNameLength`.
    static func normalizedName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name.count > maxNameLength ? nil : name
    }
}

/// Чернетка форми «Додати місце»: перевірка й створення місця (без UI, тестується окремо).
struct PlaceDraft: Equatable, Sendable {
    static let maxNameLength = Place.maxNameLength

    var name = ""
    var region: Region = .cherkasy
    var queue = 1
    var sub = 1

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var subgroup: Subgroup? { Subgroup(queue: queue, sub: sub) }

    var isValid: Bool {
        Place.normalizedName(name) != nil && region.hasScheduleData && subgroup != nil
    }

    func makePlace(id: UUID = UUID()) -> Place? {
        guard isValid, let subgroup else { return nil }
        return Place(id: id, name: trimmedName, region: region, subgroup: subgroup, source: .oblenergoSite)
    }
}
