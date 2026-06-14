import Foundation

public struct NoteSnapshot: Codable, Sendable, Equatable {
    public let folderID: String
    public let folderDisplayName: String
    public let note: NotePreview
    public let updatedAt: Date
    public let errorMessage: String?

    public init(
        folderID: String,
        folderDisplayName: String,
        note: NotePreview,
        updatedAt: Date,
        errorMessage: String?
    ) {
        self.folderID = folderID
        self.folderDisplayName = folderDisplayName
        self.note = note
        self.updatedAt = updatedAt
        self.errorMessage = errorMessage
    }

    public static func success(folder: NotesFolder, note: NotePreview) -> NoteSnapshot {
        NoteSnapshot(
            folderID: folder.id,
            folderDisplayName: folder.displayName,
            note: note,
            updatedAt: Date(),
            errorMessage: nil
        )
    }

    public static func failure(folder: NotesFolder, message: String) -> NoteSnapshot {
        NoteSnapshot(
            folderID: folder.id,
            folderDisplayName: folder.displayName,
            note: .empty,
            updatedAt: Date(),
            errorMessage: message
        )
    }

    public static func placeholder(message: String) -> NoteSnapshot {
        NoteSnapshot(
            folderID: "",
            folderDisplayName: "",
            note: .empty,
            updatedAt: Date(),
            errorMessage: message
        )
    }
}
