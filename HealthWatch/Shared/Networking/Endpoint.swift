import Foundation

struct Endpoint: Sendable {
    let path: String
    let method: HTTPMethod
    let body: (any Encodable & Sendable)?
    let queryItems: [URLQueryItem]?

    enum HTTPMethod: String, Sendable {
        case GET, POST, PUT, DELETE
    }

    init(path: String, method: HTTPMethod, body: (any Encodable & Sendable)? = nil, queryItems: [URLQueryItem]? = nil) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
    }

    // MARK: - iOS Endpoints

    /// Fetch all individuals assigned to this staff member
    static func getIndividuals() -> Endpoint {
        Endpoint(path: "/api/v1/individuals", method: .GET)
    }

    /// Fetch health data for an individual
    static func getHealth(
        individualId: String,
        from: Date,
        to: Date,
        metric: String? = nil
    ) -> Endpoint {
        var items = [
            URLQueryItem(name: "from", value: ISO8601DateFormatter().string(from: from)),
            URLQueryItem(name: "to", value: ISO8601DateFormatter().string(from: to))
        ]
        if let metric {
            items.append(URLQueryItem(name: "metric", value: metric))
        }
        return Endpoint(
            path: "/api/v1/individuals/\(individualId)/health",
            method: .GET,
            queryItems: items
        )
    }

    /// Request a watch-scoped token for provisioning
    static func provisionWatch(individualId: String) -> Endpoint {
        Endpoint(path: "/api/v1/individuals/\(individualId)/provision", method: .POST)
    }

    /// Fetch active alerts
    static func getAlerts() -> Endpoint {
        Endpoint(path: "/api/v1/alerts", method: .GET)
    }

    // MARK: - Watch Endpoints

    /// Push health data from watch
    static func pushHealthData(_ payload: HealthPayload) -> Endpoint {
        Endpoint(path: "/api/v1/health-data", method: .POST, body: payload)
    }

    /// Device heartbeat
    static func heartbeat(individualId: String, deviceId: String) -> Endpoint {
        Endpoint(
            path: "/api/v1/device/heartbeat",
            method: .POST,
            queryItems: [
                URLQueryItem(name: "individualId", value: individualId),
                URLQueryItem(name: "deviceId", value: deviceId)
            ]
        )
    }
}
