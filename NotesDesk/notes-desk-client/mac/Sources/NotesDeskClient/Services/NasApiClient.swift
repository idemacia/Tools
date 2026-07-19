import Foundation

enum NasApiError: LocalizedError {
    case invalidURL
    case httpStatus(Int, String)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "服务器地址无效"
        case .httpStatus(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodeFailed: return "响应解析失败"
        }
    }
}

struct HealthResponse: Codable {
    let ok: Bool
    let bridge: Bool
}

struct TasksResponse: Codable {
    let tasks: [DeskTask]
}

struct TaskResponse: Codable {
    let task: DeskTask
}

struct ClearedResponse: Codable {
    let cleared: Int
}

struct PatchBody: Encodable {
    var action: String?
    var dueDate: String?
    /// 为 true 时编码 dueDate（含 null 清除）
    var includeDueDate = false

    enum CodingKeys: String, CodingKey {
        case action, dueDate
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let action { try c.encode(action, forKey: .action) }
        if includeDueDate {
            try c.encode(dueDate, forKey: .dueDate)
        }
    }
}

final class NasApiClient {
    static let shared = NasApiClient()
    private static let sessionCookieName = "notesdesk_session"

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        session = URLSession(configuration: .default)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func health() async throws -> HealthResponse {
        try await get("/health", auth: false)
    }

    func listTasks(
        view: String? = nil,
        status: String? = nil,
        date: String? = nil,
        q: String? = nil,
        includeCompleted: Bool? = nil
    ) async throws -> (tasks: [DeskTask], commentCounts: [String: Int]) {
        var components = URLComponents()
        components.queryItems = []
        if let view { components.queryItems?.append(URLQueryItem(name: "view", value: view)) }
        if let status { components.queryItems?.append(URLQueryItem(name: "status", value: status)) }
        if let date { components.queryItems?.append(URLQueryItem(name: "date", value: date)) }
        if let q, !q.isEmpty { components.queryItems?.append(URLQueryItem(name: "q", value: q)) }
        if let includeCompleted, !includeCompleted {
            components.queryItems?.append(URLQueryItem(name: "includeCompleted", value: "false"))
        }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        struct Res: Decodable {
            let tasks: [DeskTask]
            let commentCounts: [String: Int]?
        }
        let res: Res = try await get("/api/tasks\(query)", auth: true)
        return (res.tasks, res.commentCounts ?? [:])
    }

    /// month = YYYY-MM；黄=新建 / 红=未完成 / 绿=已完成
    func calendarDays(month: String) async throws -> CalendarDayMarks {
        struct Res: Decodable {
            let created: [String: Int]?
            let incomplete: [String: Int]?
            let completed: [String: Int]?
        }
        let encoded = month.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? month
        let res: Res = try await get("/api/tasks/calendar-days?month=\(encoded)", auth: true)
        return CalendarDayMarks(
            created: res.created ?? [:],
            incomplete: res.incomplete ?? [:],
            completed: res.completed ?? [:]
        )
    }

    func listComments(taskId: String) async throws -> [TaskComment] {
        struct Res: Decodable { let comments: [TaskComment] }
        let res: Res = try await get("/api/tasks/\(taskId)/comments", auth: true)
        return res.comments
    }

    func createComment(taskId: String, body: String) async throws -> TaskComment {
        struct Body: Encodable { let body: String }
        struct Res: Decodable { let comment: TaskComment }
        let res: Res = try await postAuth("/api/tasks/\(taskId)/comments", body: Body(body: body))
        return res.comment
    }

    func updateComment(taskId: String, commentId: String, body: String) async throws -> TaskComment {
        struct Body: Encodable { let body: String }
        struct Res: Decodable { let comment: TaskComment }
        return try await requestWithAuthRetry {
            var req = URLRequest(url: try self.url(for: "/api/tasks/\(taskId)/comments/\(commentId)"))
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try self.encoder.encode(Body(body: body))
            self.addAuth(&req)
            let (data, resp) = try await self.session.data(for: req)
            try self.validate(resp, data: data)
            guard let decoded = try? self.decoder.decode(Res.self, from: data) else {
                throw NasApiError.decodeFailed
            }
            return decoded.comment
        }
    }

    func deleteComment(taskId: String, commentId: String) async throws {
        struct Res: Decodable { let ok: Bool? }
        _ = try await delete("/api/tasks/\(taskId)/comments/\(commentId)") as Res
    }

    func completeTask(id: String) async throws -> DeskTask {
        let res: TaskResponse = try await patch("/api/tasks/\(id)", body: PatchBody(action: "complete"))
        return res.task
    }

    func uncompleteTask(id: String) async throws -> DeskTask {
        let res: TaskResponse = try await patch("/api/tasks/\(id)", body: PatchBody(action: "uncomplete"))
        return res.task
    }

    func setDueDate(id: String, dueDate: Date?) async throws -> DeskTask {
        let iso = dueDate.map { ISO8601DateFormatter().string(from: $0) }
        var body = PatchBody()
        body.includeDueDate = true
        body.dueDate = iso
        let res: TaskResponse = try await patch("/api/tasks/\(id)", body: body)
        return res.task
    }

    func clearCompleted() async throws -> Int {
        let res: ClearedResponse = try await delete("/api/tasks/completed")
        return res.cleared
    }

    func ingest(text: String) async throws {
        struct Body: Encodable { let text: String; let source: String }
        struct Result: Decodable { let ok: Bool; let message: String? }
        let res: Result = try await post("/ingest", body: Body(text: text, source: "manual"), auth: false)
        if !res.ok {
            throw NasApiError.httpStatus(422, res.message ?? "ingest failed")
        }
    }

    // MARK: - LLM / Settings / Stats

    func getLlmConfig() async throws -> ServerLlmConfig {
        let res: LlmConfigResponse = try await get("/api/config/llm", auth: true)
        return res.config
    }

    func saveLlmConfig(
        enabled: Bool,
        provider: String,
        baseUrl: String,
        apiKey: String?,
        model: String,
        maxTokens: Int,
        temperature: Double
    ) async throws -> ServerLlmConfig {
        struct Body: Encodable {
            let enabled: Bool
            let provider: String
            let baseUrl: String
            let apiKey: String?
            let model: String
            let maxTokens: Int
            let temperature: Double
        }
        let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let res: LlmConfigResponse = try await put(
            "/api/config/llm",
            body: Body(
                enabled: enabled,
                provider: provider,
                baseUrl: baseUrl,
                apiKey: (key?.isEmpty == false) ? key : nil,
                model: model,
                maxTokens: maxTokens,
                temperature: temperature
            )
        )
        return res.config
    }

    func testLlm(baseUrl: String, apiKey: String?, model: String) async throws -> String {
        struct Body: Encodable {
            let baseUrl: String
            let apiKey: String?
            let model: String
        }
        let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let res: OkMessageResponse = try await postAuth(
            "/api/config/llm/test",
            body: Body(
                baseUrl: baseUrl,
                apiKey: (key?.isEmpty == false) ? key : nil,
                model: model
            )
        )
        return res.message ?? "连接成功"
    }

    func getServerSettings() async throws -> ServerAppSettings {
        let res: ServerSettingsResponse = try await get("/api/settings", auth: true)
        return res.settings
    }

    func saveServerSettings(_ settings: ServerAppSettings) async throws -> ServerAppSettings {
        let res: ServerSettingsResponse = try await put("/api/settings", body: settings)
        return res.settings
    }

    func getPeriodStats(period: StatsPeriod, year: Int, week: Int?, month: Int?) async throws -> ServerPeriodStats {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "year", value: String(year))]
        if let week { components.queryItems?.append(URLQueryItem(name: "week", value: String(week))) }
        if let month { components.queryItems?.append(URLQueryItem(name: "month", value: String(month))) }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        let path: String
        switch period {
        case .week: path = "/api/stats/weekly\(query)"
        case .month: path = "/api/stats/monthly\(query)"
        case .year: path = "/api/stats/yearly\(query)"
        }
        struct Res: Decodable { let stats: ServerPeriodStats }
        let res: Res = try await get(path, auth: true)
        return res.stats
    }

    func runAnalysis(period: StatsPeriod, year: Int, week: Int?, month: Int?) async throws -> AnalysisRunResult {
        struct Body: Encodable {
            let period: String
            let year: Int
            let week: Int?
            let month: Int?
        }
        return try await postAuth(
            "/api/stats/analyze",
            body: Body(period: period.rawValue, year: year, week: week, month: month)
        )
    }

    /// Web 登录，成功后写入 AppSettings.sessionCookie
    func login(username: String, password: String) async throws {
        struct Body: Encodable { let username: String; let password: String }
        struct Ok: Decodable { let ok: Bool?; let username: String? }
        struct Err: Decodable { let error: String? }

        var req = URLRequest(url: try url(for: "/api/auth/login"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(Body(username: username, password: password))

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { return }
        guard http.statusCode == 200 else {
            if let err = try? JSONDecoder().decode(Err.self, from: data), let msg = err.error {
                throw NasApiError.httpStatus(http.statusCode, msg)
            }
            throw NasApiError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "登录失败")
        }

        _ = try? JSONDecoder().decode(Ok.self, from: data)
        let headerFields = http.allHeaderFields.reduce(into: [String: String]()) { fields, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                fields[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: req.url!)
        if let sid = cookies.first(where: { $0.name == Self.sessionCookieName })?.value {
            AppSettings.sessionCookie = sid
            return
        }
        if let setCookie = http.value(forHTTPHeaderField: "Set-Cookie"),
           let sid = parseSessionId(from: setCookie)
        {
            AppSettings.sessionCookie = sid
            return
        }
        throw NasApiError.httpStatus(401, "登录成功但未收到 Session")
    }

    /// 401 时若已保存账号密码则自动重新登录
    func ensureAuthenticated() async throws {
        if AppSettings.hasApiAuth { return }
        let user = AppSettings.webUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = AppSettings.webPassword
        guard !user.isEmpty, !pass.isEmpty else {
            throw NasApiError.httpStatus(401, "请在设置中填写 Web 用户名/密码，或配置 API Token")
        }
        try await login(username: user, password: pass)
    }

    private func parseSessionId(from setCookie: String) -> String? {
        for part in setCookie.split(separator: ";") {
            let s = part.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("\(Self.sessionCookieName)=") {
                return String(s.dropFirst(Self.sessionCookieName.count + 1))
            }
        }
        return nil
    }

    // MARK: - HTTP

    private func baseURL() throws -> URL {
        var raw = AppSettings.serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while raw.hasSuffix("/") { raw.removeLast() }
        guard let url = URL(string: raw) else { throw NasApiError.invalidURL }
        return url
    }

    private func url(for path: String) throws -> URL {
        let base = try baseURL()
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: trimmed, relativeTo: base)?.absoluteURL else {
            throw NasApiError.invalidURL
        }
        return url
    }

    private func get<T: Decodable>(_ path: String, auth: Bool) async throws -> T {
        if !auth {
            let req = URLRequest(url: try url(for: path))
            let (data, resp) = try await session.data(for: req)
            try validate(resp, data: data)
            guard let decoded = try? decoder.decode(T.self, from: data) else { throw NasApiError.decodeFailed }
            return decoded
        }
        return try await requestWithAuthRetry {
            var req = URLRequest(url: try url(for: path))
            addAuth(&req)
            let (data, resp) = try await session.data(for: req)
            try validate(resp, data: data)
            guard let decoded = try? decoder.decode(T.self, from: data) else { throw NasApiError.decodeFailed }
            return decoded
        }
    }

    private func patch<T: Decodable>(_ path: String, body: PatchBody) async throws -> T {
        try await requestWithAuthRetry {
            var req = URLRequest(url: try url(for: path))
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(body)
            addAuth(&req)
            let (data, resp) = try await session.data(for: req)
            try validate(resp, data: data)
            guard let decoded = try? decoder.decode(T.self, from: data) else { throw NasApiError.decodeFailed }
            return decoded
        }
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B, auth: Bool) async throws -> T {
        if auth {
            return try await requestWithAuthRetry {
                try await self.postOnce(path, body: body, auth: true)
            }
        }
        return try await postOnce(path, body: body, auth: false)
    }

    private func postAuth<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await requestWithAuthRetry {
            try await self.postOnce(path, body: body, auth: true)
        }
    }

    private func postOnce<T: Decodable, B: Encodable>(_ path: String, body: B, auth: Bool) async throws -> T {
        var req = URLRequest(url: try url(for: path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        if auth { addAuth(&req) }
        let (data, resp) = try await session.data(for: req)
        try validate(resp, data: data)
        guard let decoded = try? decoder.decode(T.self, from: data) else { throw NasApiError.decodeFailed }
        return decoded
    }

    private func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        try await requestWithAuthRetry {
            var req = URLRequest(url: try self.url(for: path))
            req.httpMethod = "PUT"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try self.encoder.encode(body)
            self.addAuth(&req)
            let (data, resp) = try await self.session.data(for: req)
            try self.validate(resp, data: data)
            guard let decoded = try? self.decoder.decode(T.self, from: data) else { throw NasApiError.decodeFailed }
            return decoded
        }
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        try await requestWithAuthRetry {
            var req = URLRequest(url: try url(for: path))
            req.httpMethod = "DELETE"
            addAuth(&req)
            let (data, resp) = try await session.data(for: req)
            try validate(resp, data: data)
            guard let decoded = try? decoder.decode(T.self, from: data) else { throw NasApiError.decodeFailed }
            return decoded
        }
    }

    private func requestWithAuthRetry<T>(_ work: () async throws -> T) async throws -> T {
        do {
            try await ensureAuthenticated()
            return try await work()
        } catch let err as NasApiError {
            if case .httpStatus(401, _) = err {
                AppSettings.sessionCookie = ""
                try await ensureAuthenticated()
                return try await work()
            }
            throw err
        }
    }

    private func addAuth(_ req: inout URLRequest) {
        let token = AppSettings.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return
        }
        let sid = AppSettings.sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sid.isEmpty {
            req.setValue("\(Self.sessionCookieName)=\(sid)", forHTTPHeaderField: "Cookie")
        }
    }

    private func validate(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200 ... 299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw NasApiError.httpStatus(http.statusCode, msg)
        }
    }

    private static func decodeDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        let formatters: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()
        for f in formatters {
            if let d = f.date(from: str) { return d }
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
    }
}
