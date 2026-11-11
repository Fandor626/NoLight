import Foundation

protocol HTMLFetching: Sendable {
    func fetch(_ url: URL) async throws -> String
}

struct URLSessionHTMLFetcher: HTMLFetching {
    let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func fetch(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("uk-UA,uk;q=0.9", forHTTPHeaderField: "Accept-Language")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ScheduleError.serverUnavailable(status: http.statusCode)
            }
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) else {
                throw ScheduleError.parsingFailed("Невідоме кодування сторінки.")
            }
            return text
        } catch let error as ScheduleError {
            throw error
        } catch let error as URLError {
            throw Self.map(error)
        }
    }

    static func map(_ error: URLError) -> ScheduleError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        default:
            return .serverUnavailable(status: nil)
        }
    }
}
