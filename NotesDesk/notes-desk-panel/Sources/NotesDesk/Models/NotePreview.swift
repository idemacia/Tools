import Foundation

struct NotePreview: Equatable, Sendable {
    let id: String
    let title: String
    let body: String

    static let empty = NotePreview(id: "", title: "", body: "")

    var isEmpty: Bool {
        id.isEmpty && title.isEmpty && body.isEmpty
    }

    var displayTitle: String {
        title.isEmpty ? "无标题" : title
    }
}

enum NotesReaderError: LocalizedError {
    case automationDenied
    case folderNotFound(String)
    case emptyFolder(String)
    case invalidResponse
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .automationDenied:
            return "无法访问「备忘录」。请在系统设置 → 隐私与安全性 → 自动化中，允许 NotesDesk 控制「备忘录」。"
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
