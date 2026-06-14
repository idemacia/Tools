import Foundation

enum AppSettings {
    private enum Key {
        static let panelOpacity = "panelOpacity"
        static let fontSize = "fontSize"
        static let panelOriginX = "panelOriginX"
        static let panelOriginY = "panelOriginY"
        static let panelVisible = "panelVisible"
        static let viewMode = "viewMode"
        static let showCompletedSection = "showCompletedSection"
        static let quitOnClosePanel = "quitOnClosePanel"
        static let serverBaseURL = "serverBaseURL"
        static let apiToken = "apiToken"
        static let sessionCookie = "sessionCookie"
        static let webUsername = "webUsername"
        static let webPassword = "webPassword"
    }

    static var panelOpacity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Key.panelOpacity)
            return value == 0 ? 0.92 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.panelOpacity) }
    }

    static var fontSize: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Key.fontSize)
            return value == 0 ? 14 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.fontSize) }
    }

    static var panelOrigin: CGPoint {
        get {
            CGPoint(
                x: UserDefaults.standard.double(forKey: Key.panelOriginX),
                y: UserDefaults.standard.double(forKey: Key.panelOriginY)
            )
        }
        set {
            UserDefaults.standard.set(newValue.x, forKey: Key.panelOriginX)
            UserDefaults.standard.set(newValue.y, forKey: Key.panelOriginY)
        }
    }

    static var panelVisible: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.panelVisible) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Key.panelVisible)
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.panelVisible) }
    }

    static var viewMode: DeskViewMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Key.viewMode),
                  let mode = DeskViewMode(rawValue: raw)
            else {
                return .incomplete
            }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.viewMode) }
    }

    static var showCompletedSection: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.showCompletedSection) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Key.showCompletedSection)
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.showCompletedSection) }
    }

    static var quitOnClosePanel: Bool {
        get { UserDefaults.standard.bool(forKey: Key.quitOnClosePanel) }
        set { UserDefaults.standard.set(newValue, forKey: Key.quitOnClosePanel) }
    }

    /// 如 http://192.168.1.100:8080
    static var serverBaseURL: String {
        get { UserDefaults.standard.string(forKey: Key.serverBaseURL) ?? "http://127.0.0.1:8080" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.serverBaseURL) }
    }

    static var apiToken: String {
        get { UserDefaults.standard.string(forKey: Key.apiToken) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.apiToken) }
    }

    /// Web 登录 Session（/api/auth/login 后写入）
    static var sessionCookie: String {
        get { UserDefaults.standard.string(forKey: Key.sessionCookie) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.sessionCookie) }
    }

    static var webUsername: String {
        get { UserDefaults.standard.string(forKey: Key.webUsername) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.webUsername) }
    }

    static var webPassword: String {
        get { UserDefaults.standard.string(forKey: Key.webPassword) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.webPassword) }
    }

    static var hasApiAuth: Bool {
        !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var isConfigured: Bool {
        !serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
