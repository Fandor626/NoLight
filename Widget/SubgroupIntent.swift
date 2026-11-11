import AppIntents

/// Вибір підчерги для конкретного віджета ("Змінити віджет").
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

struct SelectSubgroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Підчерга"
    static var description = IntentDescription("Оберіть підчергу відключень, яку показує цей віджет.")

    @Parameter(title: "Підчерга", default: .s11)
    var subgroup: SubgroupOption
}
