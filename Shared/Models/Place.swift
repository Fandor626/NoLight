import Foundation

/// Область. Поки що лише Черкаська; інші з'являться разом з API (NOL-15).
enum Region: String, Codable, Hashable, Sendable, CaseIterable {
    case cherkasy

    var title: String {
        switch self {
        case .cherkasy: return "Черкаська"
        }
    }
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
}
