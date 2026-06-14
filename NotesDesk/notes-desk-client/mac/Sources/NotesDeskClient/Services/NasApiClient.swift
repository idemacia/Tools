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

    func listTasks(view: String? = nil, status: String? = nil) async throws -> [DeskTask] {
        var components = URLComponents()
        components.queryItems = []
        if let view { components.queryItems?.append(URLQueryItem(name: "view", value: view)) }
        if let status { components.queryItems?.append(URLQueryItem(name: "status", value: status)) }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        let res: TasksResponse = try await get("/api/tasks\(query)", auth: true)
        return res.tasks
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
