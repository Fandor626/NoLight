import Foundation

/// Посилання з віджетів у застосунок: `nolight://place/{uuid}` і `nolight://home`.
enum DeepLink {
    static let scheme = "nolight"

    static func place(_ id: UUID) -> URL { URL(string: "\(scheme)://place/\(id.uuidString)")! }
    static let home = URL(string: "\(scheme)://home")!

    /// UUID місця з посилання або nil, якщо посилання не на місце.
    static func placeID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host == "place" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
