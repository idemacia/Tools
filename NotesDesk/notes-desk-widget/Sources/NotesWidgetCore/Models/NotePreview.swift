import Foundation

public struct NotePreview: Equatable, Sendable, Codable {
    public let id: String
    public let title: String
    public let body: String

    public static let empty = NotePreview(id: "", title: "", body: "")

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }

    public var isEmpty: Bool {
        id.isEmpty && title.isEmpty && body.isEmpty
    }

    public var displayTitle: String {
        title.isEmpty ? "无标题" : title
    }
}

public enum NotesReaderError: LocalizedError {
    case automationDenied
    case folderNotFound(String)
    case emptyFolder(String)
    case invalidResponse
    case scriptFailed(String)

    public var errorDescription: String? {
        switch self {
        case .automationDenied:
            return "无法访问「备忘录」。请在 系统设置 → 隐私与安全性 → 自动化 中，允许 NotesDeskWidget 控制「备忘录」。"
        case .folderNotFound(let name):
            return "未找到文件夹：\(name)"
        case .emptyFolder(let name):
            return "文件夹「\(name)」中没有备忘录。"
        case .invalidResponse:
            return "读取备忘录返回格式异常。"
        case .scriptFailed(let message):
            return message
        }
    }
}
