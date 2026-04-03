import Foundation

actor APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let tokenStore: TokenStore

    init(baseURL: URL, tokenStore: TokenStore) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.baseURL = baseURL
        self.tokenStore = tokenStore
    }

    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var request = try buildRequest(for: endpoint)

        if let token = await tokenStore.currentToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try JSONDecoder.healthWatch.decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed(underlying: error)
            }
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
        case 500...599:
            throw APIError.serverError(statusCode: http.statusCode)
        default:
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    /// Fire-and-forget send, ignoring response body
    func sendIgnoringResponse(_ endpoint: Endpoint) async throws {
        var request = try buildRequest(for: endpoint)

        if let token = await tokenStore.currentToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            throw APIError.httpError(statusCode: http.statusCode, data: Data())
        }
    }

    // MARK: - Private

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder.healthWatch.encode(body)
        }

        return request
    }
}
