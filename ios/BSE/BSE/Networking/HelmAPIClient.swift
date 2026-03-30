import Foundation

enum AdministrationAction: String {
    case calibrate
    case reboot
}

struct HelmAPIClient {
    let baseURL: URL
    let session: URLSession
    private let requestTimeout: TimeInterval

    init(
        baseURL: URL = URL(string: "https://blueseaeye.eu/api")!,
        session: URLSession? = nil,
        requestTimeout: TimeInterval = 4
    ) {
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
        self.session = session ?? Self.makeDefaultSession(timeout: requestTimeout)
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

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(HelmReadings.self, from: data)
    }

    func performAdministrationAction(_ action: AdministrationAction) async throws {
        let url = baseURL.appendingPathComponent(action.rawValue)
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await data(for: request)
        try validate(response: response, data: data)
    }

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let session = self.session
        let timeout = self.requestTimeout

        return try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask {
                try await session.data(for: request)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw APIError.timeout
            }

            guard let result = try await group.next() else {
                throw APIError.invalidResponse
            }
            group.cancelAll()
            return result
        }
    }

    private static func makeDefaultSession(timeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        return URLSession(configuration: configuration)
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
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Nieprawidłowa odpowiedź serwera."
        case let .httpStatus(code, body):
            if let body, !body.isEmpty {
                return "Błąd serwera \(code): \(body)"
            }
            return "Błąd serwera \(code)."
        case .timeout:
            return "Przekroczono czas oczekiwania na odpowiedź steru."
        }
    }
}
