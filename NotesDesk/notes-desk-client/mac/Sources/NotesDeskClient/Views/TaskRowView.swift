import SwiftUI

struct TaskRowView: View {
    let task: DeskTask
    let fontSize: Double
    let isCompleted: Bool
    var onComplete: () -> Void
    var onUncomplete: () -> Void
    var onDueDateChange: (Date?) -> Void

    @State private var showDueDatePicker = false
    @State private var draftDueDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            actionButton
            VStack(alignment: .leading, spacing: 4) {
                Text(task.text)
                    .font(.system(size: fontSize, weight: isCompleted ? .regular : .medium))
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                metaRow
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var actionButton: some View {
        Button {
            if isCompleted { onUncomplete() } else { onComplete() }
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: fontSize + 2))
                .foregroundStyle(isCompleted ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            if let dueDate = task.dueDate {
                Text(dueDateLabel(dueDate))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(dueBadgeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(dueBadgeColor)
            }
            if !isCompleted {
                Button {
                    draftDueDate = task.dueDate ?? defaultDueDate()
                    showDueDatePicker.toggle()
                } label: {
                    Text(task.dueDate == nil ? "设截止" : "改截止")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $showDueDatePicker, arrowEdge: .bottom) {
                    dueDatePickerContent
                }
            }
            Text(sourceTimeLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var dueDatePickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("截止时间").font(.headline)
            DatePicker("", selection: $draftDueDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Button("清除") {
                    onDueDateChange(nil)
                    showDueDatePicker = false
                }
                Spacer()
                Button("确定") {
                    onDueDateChange(draftDueDate)
                    showDueDatePicker = false
                }
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private var dueBadgeColor: Color {
        if isCompleted { return .secondary }
        return task.isOverdue() ? .red : .orange
    }

    private func dueDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm 截止"
        return f.string(from: date)
    }

    private func defaultDueDate() -> Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var sourceTimeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let time = f.string(from: isCompleted ? (task.completedAt ?? task.createdAt) : task.createdAt)
        let source: String = switch task.source {
        case .dingtalk: "钉钉"
        case .feishu: "飞书"
        case .manual: "本地"
        }
        return isCompleted ? "完成 \(time)" : "\(time) · \(source)"
    }
}
