import Foundation

enum AdministrationAction: String {
    case calibrate
    case reboot
}

struct HelmAPIClient {
    let baseURL: URL
    let session: URLSession

    init(
        baseURL: URL = URL(string: "https://blueseaeye.eu/api")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchHelmReadings(settings: AppSettings) async throws -> HelmReadings {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("helm"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "window", value: String(settings.averageWindow)),
            URLQueryItem(name: "source", value: settings.courseSource.rawValue),
            URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970 * 1000)))
        ]

        let (data, response) = try await session.data(from: components.url!)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(HelmReadings.self, from: data)
    }

    func performAdministrationAction(_ action: AdministrationAction) async throws {
        let url = baseURL.appendingPathComponent(action.rawValue)
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.httpStatus(code: response.statusCode, body: body)
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpStatus(code: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Nieprawidłowa odpowiedź serwera."
        case let .httpStatus(code, body):
            if let body, !body.isEmpty {
                return "Błąd serwera \(code): \(body)"
            }
            return "Błąd serwera \(code)."
        }
    }
}
