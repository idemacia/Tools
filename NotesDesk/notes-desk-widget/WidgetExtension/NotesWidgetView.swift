import SwiftUI
import WidgetKit

struct NotesWidgetView: View {
    let entry: NotesWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(openURL)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            bodyText
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.primary)
        .containerBackground(for: .widget) {
            Color(.textBackgroundColor).opacity(0.85)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !entry.snapshot.folderDisplayName.isEmpty {
                Text(entry.snapshot.folderDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(titleText)
                .font(family == .systemSmall ? .subheadline : .headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(family == .systemSmall ? 2 : 3)
        }
    }

    private var bodyText: some View {
        Group {
            if let error = entry.snapshot.errorMessage, entry.snapshot.note.body.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entry.snapshot.note.isEmpty {
                Text(entry.snapshot.errorMessage ?? "暂无内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.snapshot.note.body)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var titleText: String {
        if entry.snapshot.note.isEmpty {
            return entry.snapshot.errorMessage ?? "NotesDesk"
        }
        return entry.snapshot.note.displayTitle
    }

    private var lineLimit: Int {
        switch family {
        case .systemSmall: return 6
        case .systemMedium: return 10
        case .systemLarge: return 24
        default: return 12
        }
    }

    private var openURL: URL? {
        guard !entry.snapshot.note.id.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = AppConstants.urlScheme
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "noteID", value: entry.snapshot.note.id),
        ]
        return components.url
    }
}
