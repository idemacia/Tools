import SwiftUI
import WidgetKit

struct NotesDeskWidget: Widget {
    let kind = "NotesDeskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotesWidgetProvider()) { entry in
            NotesWidgetView(entry: entry)
        }
        .configurationDisplayName("NotesDesk")
        .description("显示 Host 所选文件夹中第一条备忘录。请在菜单栏选择文件夹。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
