import Foundation

/// Підчерга відключень: 1.1 ... 6.2.
struct Subgroup: Hashable, Comparable, Identifiable, Sendable, Codable {
    let queue: Int
    let sub: Int

    init?(queue: Int, sub: Int) {
        guard (1...6).contains(queue), (1...2).contains(sub) else { return nil }
        self.queue = queue
        self.sub = sub
    }

    init?(id: String) {
        let parts = id.split(separator: ".")
        guard parts.count == 2, let q = Int(parts[0]), let s = Int(parts[1]) else { return nil }
        self.init(queue: q, sub: s)
    }

    var id: String { "\(queue).\(sub)" }

    static let all: [Subgroup] = (1...6).flatMap { q in (1...2).compactMap { Subgroup(queue: q, sub: $0) } }

    static func < (l: Subgroup, r: Subgroup) -> Bool { (l.queue, l.sub) < (r.queue, r.sub) }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let v = Subgroup(id: s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Невірна підчерга: \(s)")
        }
        self = v
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(id)
    }
}
