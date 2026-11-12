import AppIntents

/// Місце для «Змінити віджет»: той самий список і порядок, що в застосунку.
struct PlaceEntity: AppEntity, Identifiable {
    let id: UUID
    let name: String
    let subgroupID: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Місце"
    static var defaultQuery = PlaceQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "Підчерга \(subgroupID)")
    }

    init(place: Place) {
        id = place.id
        name = place.name
        subgroupID = place.subgroup.id
    }
}

struct PlaceQuery: EntityQuery {
    private var places: [Place] { PlaceStore.shared.places }

    func entities(for identifiers: [UUID]) async throws -> [PlaceEntity] {
        places.filter { identifiers.contains($0.id) }.map(PlaceEntity.init(place:))
    }

    func suggestedEntities() async throws -> [PlaceEntity] {
        places.map(PlaceEntity.init(place:))
    }

    func defaultResult() async -> PlaceEntity? {
        places.first.map(PlaceEntity.init(place:))
    }
}

/// Підчерга старих віджетів v1. Лишається прихованим параметром, щоб уже додані віджети не зламалися.
enum SubgroupOption: String, AppEnum, CaseIterable {
    case s11 = "1.1", s12 = "1.2", s21 = "2.1", s22 = "2.2", s31 = "3.1", s32 = "3.2"
    case s41 = "4.1", s42 = "4.2", s51 = "5.1", s52 = "5.2", s61 = "6.1", s62 = "6.2"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Підчерга"

    static var caseDisplayRepresentations: [SubgroupOption: DisplayRepresentation] = [
        .s11: "1.1", .s12: "1.2", .s21: "2.1", .s22: "2.2", .s31: "3.1", .s32: "3.2",
        .s41: "4.1", .s42: "4.2", .s51: "5.1", .s52: "5.2", .s61: "6.1", .s62: "6.2",
    ]

    var subgroup: Subgroup { Subgroup(id: rawValue) ?? Subgroup(queue: 1, sub: 1)! }
}

/// Налаштування віджета. Назву типу не змінюємо: від неї залежить збереження налаштувань доданих віджетів.
struct SelectSubgroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Місце"
    static var description = IntentDescription("Оберіть місце, графік якого показує цей віджет.")

    @Parameter(title: "Місце")
    var place: PlaceEntity?

    /// Параметр віджетів v1 (не показується в налаштуваннях).
    @Parameter(title: "Підчерга", default: .s11)
    var subgroup: SubgroupOption

    static var parameterSummary: some ParameterSummary {
        Summary("Місце: \(\.$place)")
    }

    var resolution: WidgetPlaceResolution {
        WidgetPlaceResolver.resolve(placeID: place?.id, legacySubgroup: subgroup.subgroup,
                                    places: PlaceStore.shared.places)
    }
}
