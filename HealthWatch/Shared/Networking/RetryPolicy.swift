import Foundation

struct RetryPolicy: Sendable {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    static let `default` = RetryPolicy(maxRetries: 5, baseDelay: 2.0, maxDelay: 300.0)

    /// Calculate delay for a given attempt using exponential backoff with jitter
    func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...(exponential * 0.1))
        return min(exponential + jitter, maxDelay)
    }

    /// Execute an async operation with retry logic
    func execute<T>(operation: @Sendable () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry auth errors or client errors
                if let apiError = error as? APIError {
                    switch apiError {
                    case .unauthorized, .encodingFailed, .decodingFailed:
                        throw error
                    default:
                        break
                    }
                }

                if attempt < maxRetries {
                    let sleepDuration = delay(for: attempt)
                    try await Task.sleep(for: .seconds(sleepDuration))
                }
            }
        }
        throw lastError!
    }
}
