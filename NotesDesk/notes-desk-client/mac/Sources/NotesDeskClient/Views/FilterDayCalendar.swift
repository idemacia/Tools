import SwiftUI

struct CalendarDayMarks: Equatable, Sendable {
    var created: [String: Int] = [:]
    var incomplete: [String: Int] = [:]
    var completed: [String: Int] = [:]
}

/// 月历筛选：黄=新建 / 红=未完成 / 绿=已完成（可并存）。
struct FilterDayCalendar: View {
    let selected: String?
    let marks: CalendarDayMarks
    var onSelect: (String) -> Void
    var onToday: () -> Void
    var onClear: () -> Void
    var onMonthChange: (String) -> Void

    @State private var year: Int
    @State private var month: Int

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let today = StatsDateHelper.dayString()

    init(
        selected: String?,
        marks: CalendarDayMarks,
        onSelect: @escaping (String) -> Void,
        onToday: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onMonthChange: @escaping (String) -> Void
    ) {
        self.selected = selected
        self.marks = marks
        self.onSelect = onSelect
        self.onToday = onToday
        self.onClear = onClear
        self.onMonthChange = onMonthChange
        let anchor = selected.flatMap(StatsDateHelper.date(fromDayString:)) ?? Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        _year = State(initialValue: cal.component(.year, from: anchor))
        _month = State(initialValue: cal.component(.month, from: anchor))
    }

    private var monthKey: String {
        String(format: "%04d-%02d", year, month)
    }

    private var cells: [String?] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }
        let weekdaySun0 = cal.component(.weekday, from: first) // 1=Sun
        let pad = (weekdaySun0 + 5) % 7 // Mon-first
        let days = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        var out: [String?] = Array(repeating: nil, count: pad)
        for d in 1...days {
            out.append(String(format: "%04d-%02d-%02d", year, month, d))
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button("‹") { shiftMonth(-1) }
                    .buttonStyle(.plain)
                Text("\(year)年\(month)月")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
                Button("›") { shiftMonth(1) }
                    .buttonStyle(.plain)
                Button("今天") { onToday() }
                    .font(.caption2)
                if selected != nil {
                    Button("清除") { onClear() }
                        .font(.caption2)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(weekdays, id: \.self) { w in
                    Text(w)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }

            HStack(spacing: 8) {
                legendDot(Color(red: 1, green: 0.8, blue: 0), "新建")
                legendDot(Color.red, "未完成")
                legendDot(Color.green, "已完成")
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .onAppear { onMonthChange(monthKey) }
        .onChange(of: selected) { newValue in
            guard let s = newValue, let date = StatsDateHelper.date(fromDayString: s) else { return }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
            year = cal.component(.year, from: date)
            month = cal.component(.month, from: date)
            onMonthChange(monthKey)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
        }
    }

    private func dayCell(_ day: String) -> some View {
        let isSelected = day == selected
        let isToday = day == today
        let nCreated = marks.created[day] ?? 0
        let nIncomplete = marks.incomplete[day] ?? 0
        let nCompleted = marks.completed[day] ?? 0
        var helpParts: [String] = []
        if nCreated > 0 { helpParts.append("新建 \(nCreated)") }
        if nIncomplete > 0 { helpParts.append("未完成 \(nIncomplete)") }
        if nCompleted > 0 { helpParts.append("已完成 \(nCompleted)") }

        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 2) {
                Text("\(Int(day.suffix(2)) ?? 0)")
                    .font(.system(size: 11, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.orange : Color.primary))
                HStack(spacing: 2) {
                    if nCreated > 0 {
                        Circle().fill(Color(red: 1, green: 0.8, blue: 0)).frame(width: 4, height: 4)
                    }
                    if nIncomplete > 0 {
                        Circle().fill(Color.red).frame(width: 4, height: 4)
                    }
                    if nCompleted > 0 {
                        Circle().fill(Color.green).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.orange : (isToday ? Color.orange.opacity(0.18) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .help(helpParts.joined(separator: " · "))
    }

    private func shiftMonth(_ delta: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let next = cal.date(byAdding: .month, value: delta, to: first)
        else { return }
        year = cal.component(.year, from: next)
        month = cal.component(.month, from: next)
        onMonthChange(monthKey)
    }
}
