import Foundation

/// Область. Черкаська має офіційний сайт обленерго; решта (і Черкаська як альтернатива) — API OE_OUTAGE_DATA (NOL-15).
enum Region: String, Codable, Hashable, Sendable, CaseIterable {
    case cherkasy, chernihiv, kharkiv, khmelnytskyi, lviv, poltava, ivanoFrankivsk
    case rivne, ternopil, zakarpattia, zaporizhzhia, zhytomyr

    var title: String {
        switch self {
        case .cherkasy: return "Черкаська"
        case .chernihiv: return "Чернігівська"
        case .kharkiv: return "Харківська"
        case .khmelnytskyi: return "Хмельницька"
        case .lviv: return "Львівська"
        case .poltava: return "Полтавська"
        case .ivanoFrankivsk: return "Івано-Франківська"
        case .rivne: return "Рівненська"
        case .ternopil: return "Тернопільська"
        case .zakarpattia: return "Закарпатська"
        case .zaporizhzhia: return "Запорізька"
        case .zhytomyr: return "Житомирська"
        }
    }

    /// Файл області в API OE_OUTAGE_DATA (`data/<name>.json`).
    var apiFileName: String {
        switch self {
        case .cherkasy: return "Cherkasyoblenergo"
        case .chernihiv: return "Chernihivoblenergo"
        case .kharkiv: return "Kharkivoblenerho"
        case .khmelnytskyi: return "Khmelnytskoblenerho"
        case .lviv: return "Lvivoblenerho"
        case .poltava: return "Poltavaoblenergo"
        case .ivanoFrankivsk: return "Prykarpattiaoblenerho"
        case .rivne: return "Rivneoblenergo"
        case .ternopil: return "Ternopiloblenerho"
        case .zakarpattia: return "Zakarpattiaoblenerho"
        case .zaporizhzhia: return "Zaporizhzhiaoblenergo"
        case .zhytomyr: return "Zhytomyroblenergo"
        }
    }

    /// Джерело за замовчуванням: Черкаси — офіційний сайт, інші — API (PRD FR-7).
    var defaultSource: PlaceSource { self == .cherkasy ? .oblenergoSite : .outageDataAPI }

    /// Чи може область мати графіки (усі області з API). Порожній або недоступний файл
    /// показується як «невідомо» з поясненням у картці, а не порожнім екраном.
    var hasScheduleData: Bool { true }

    /// Області для вибору: усі, що є в API, за абеткою; Черкаська першою.
    static var selectable: [Region] {
        [.cherkasy] + allCases.filter { $0 != .cherkasy }.sorted { $0.title < $1.title }
    }
}

/// Звідки береться графік місця.
enum PlaceSource: String, Codable, Hashable, Sendable {
    /// Офіційний сайт АТ «Черкасиобленерго» (лише Черкаська).
    case oblenergoSite
    /// Неофіційне API OE_OUTAGE_DATA (усі області).
    case outageDataAPI
}

extension PlaceSource {
    /// Коротка назва для вибору джерела (NOL-17).
    var shortTitle: String {
        switch self {
        case .oblenergoSite: return "Сайт обленерго"
        case .outageDataAPI: return "API"
        }
    }

    /// Підпис джерела під графіком.
    var title: String {
        switch self {
        case .oblenergoSite: return "АТ «Черкасиобленерго» (офіційний сайт)"
        case .outageDataAPI: return "OE_OUTAGE_DATA (неофіційне джерело)"
        }
    }
}

/// Ключ даних: одне джерело + область (кеш і оновлення окремі для кожного).
struct ScheduleSourceKey: Hashable, Codable, Sendable {
    let source: PlaceSource
    let region: Region

    static let cherkasySite = ScheduleSourceKey(source: .oblenergoSite, region: .cherkasy)

    /// Джерела, потрібні місцям, без повторів і в порядку місць. Без місць — сайт Черкас (як у v1).
    static func active(for places: [Place]) -> [ScheduleSourceKey] {
        var seen = Set<ScheduleSourceKey>()
        let keys = places.map(\.sourceKey).filter { seen.insert($0).inserted }
        return keys.isEmpty ? [.cherkasySite] : keys
    }
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

    /// Джерела, з яких можна вибрати (NOL-17): Черкаська — сайт або API; інші області — лише API.
    var availableSources: [PlaceSource] {
        region == .cherkasy ? [.oblenergoSite, .outageDataAPI] : [.outageDataAPI]
    }

    /// Звідки брати графік цього місця. Сайт обленерго є лише для Черкаської.
    var sourceKey: ScheduleSourceKey {
        ScheduleSourceKey(source: region == .cherkasy ? source : .outageDataAPI, region: region)
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
        return Place(id: id, name: trimmedName, region: region, subgroup: subgroup, source: region.defaultSource)
    }
}
