import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case connectionHint(String)
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .connectionHint(let message):
            return message
        case .serverError(let code, let message):
            return "서버 오류 (\(code)): \(message)"
        case .decodingError(let error):
            return "데이터 파싱 오류: \(error.localizedDescription)"
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        }
    }
}

final class APIService {
    static let shared = APIService()
    private static let customBaseURLKey = "study_agents_api_base_url"

    private(set) var baseURL: String = APIService.resolveInitialBaseURL()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private static func resolveInitialBaseURL() -> String {
        if let storedURL = UserDefaults.standard.string(forKey: customBaseURLKey),
           !storedURL.trimmed.isEmpty {
            return normalizedBaseURL(storedURL)
        }

        if let envURL = ProcessInfo.processInfo.environment["STUDY_AGENTS_API_BASE_URL"],
           !envURL.trimmed.isEmpty {
            return normalizedBaseURL(envURL)
        }

        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "StudyAgentsAPIBaseURL") as? String,
           !plistURL.trimmed.isEmpty {
            return normalizedBaseURL(plistURL)
        }

        return normalizedBaseURL("http://localhost:8000/api/v1")
    }

    static func normalizedBaseURL(_ urlString: String) -> String {
        var value = urlString.trimmed

        while value.hasSuffix("/") {
            value.removeLast()
        }

        if !value.hasSuffix("/api/v1") {
            value += "/api/v1"
        }

        return value
    }

    func updateBaseURL(_ newValue: String) {
        let trimmed = newValue.trimmed
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.customBaseURLKey)
            baseURL = Self.resolveInitialBaseURL()
            return
        }

        let normalized = Self.normalizedBaseURL(trimmed)
        UserDefaults.standard.set(normalized, forKey: Self.customBaseURLKey)
        baseURL = normalized
    }

    func resetBaseURL() {
        UserDefaults.standard.removeObject(forKey: Self.customBaseURLKey)
        baseURL = Self.resolveInitialBaseURL()
    }

    // MARK: - Sessions

    func healthCheck() async throws -> HealthCheckResponse {
        guard let url = URL(string: "\(rootBaseURL)/health") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try validateResponse(data: data, response: response)
            return try decodeOrThrow(data)
        } catch {
            throw mapNetworkError(error, url: url)
        }
    }

    func createSession(_ body: StudySessionCreate) async throws -> StudySession {
        try await post("/sessions", body: body)
    }

    func getSession(id: String) async throws -> StudySession {
        try await get("/sessions/\(id)")
    }

    // MARK: - Plan

    func generatePlan(sessionId: String) async throws -> StudyPlan {
        try await post("/sessions/\(sessionId)/plan", body: EmptyBody())
    }

    func generateCustomPlan(sessionId: String, days: Int, hoursPerDay: [String: Double]) async throws -> StudyPlan {
        struct Request: Codable {
            let daysRemaining: Int
            let studyHoursPerDay: [String: Double]
        }

        return try await post(
            "/sessions/\(sessionId)/plan/custom",
            body: Request(daysRemaining: days, studyHoursPerDay: hoursPerDay)
        )
    }

    // MARK: - Mind Map

    func getMindMap(sessionId: String) async throws -> MindMapResponse {
        try await get("/sessions/\(sessionId)/mindmap")
    }

    // MARK: - Exam Analysis

    func analyzeExam(sessionId: String, content: String) async throws -> String {
        struct Request: Codable { let examContent: String }
        struct Response: Codable { let analysis: String }

        let response: Response = try await post(
            "/sessions/\(sessionId)/analyze-exam",
            body: Request(examContent: content)
        )
        return response.analysis
    }

    // MARK: - Notifications

    func setNotification(sessionId: String, req: NotificationScheduleRequest) async throws {
        struct Response: Codable { let sessionId: String? }
        let _: Response = try await post("/sessions/\(sessionId)/notifications", body: req)
    }

    func cancelNotification(sessionId: String) async throws {
        guard let url = URL(string: "\(baseURL)/sessions/\(sessionId)/notifications") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(data: data, response: response)
        } catch {
            throw mapNetworkError(error, url: url)
        }
    }

    // MARK: - Helpers

    private var rootBaseURL: String {
        if baseURL.hasSuffix("/api/v1") {
            return String(baseURL.dropLast("/api/v1".count))
        }
        return baseURL
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try validateResponse(data: data, response: response)
            return try decodeOrThrow(data)
        } catch {
            throw mapNetworkError(error, url: url)
        }
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(data: data, response: response)
            return try decodeOrThrow(data)
        } catch {
            throw mapNetworkError(error, url: url)
        }
    }

    private func validateResponse(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(
                http.statusCode,
                extractErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }

    private func decodeOrThrow<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = payload["message"] as? String, !message.isEmpty {
                return message
            }

            if let detail = payload["detail"] as? String, !detail.isEmpty {
                return detail
            }

            if let detail = payload["detail"] as? [[String: Any]] {
                let joined = detail
                    .compactMap { ($0["msg"] as? String) ?? ($0["message"] as? String) }
                    .joined(separator: " / ")
                return joined.isEmpty ? nil : joined
            }
        }

        return String(data: data, encoding: .utf8)?.trimmedOrNil
    }

    private func mapNetworkError(_ error: Error, url: URL) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }

        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return .networkError(error)
        }

        let host = url.host?.lowercased() ?? ""
        let isLoopbackHost = host == "localhost" || host == "127.0.0.1"

        if !isSimulator && isLoopbackHost {
            return .connectionHint(
                "실제 아이폰에서는 localhost가 맥북을 가리키지 않습니다. 앱에서 서버 주소를 맥북 로컬 IP 형태로 바꿔주세요. 예: http://192.168.0.23:8000/api/v1"
            )
        }

        switch nsError.code {
        case NSURLErrorCannotConnectToHost,
             NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotFindHost,
             NSURLErrorNotConnectedToInternet:
            return .connectionHint(
                "StudyAgents 백엔드에 연결하지 못했습니다. 백엔드가 실행 중인지, 서버 주소가 맞는지 확인해주세요. 현재 주소: \(baseURL)"
            )
        default:
            return .networkError(error)
        }
    }
}

private struct EmptyBody: Codable {}

struct HealthCheckResponse: Codable {
    let status: String
    let service: String
}
