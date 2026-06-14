import Foundation

public enum AppConstants {
    public static let appGroupID = "group.com.notesdesk.widget"
    public static let urlScheme = "noteswidget"

    /// 调试开关：true 时使用写死数据。
    public static let widgetUseHardcodedTestData = false

    /// Host 本地快照服务端口（Widget 扩展通过 localhost 读取，绕过 App Group 沙盒限制）
    public static let widgetSnapshotPort: UInt16 = 19876

    /// Host 轮询备忘录间隔（沙盒内 FSEvents 不可靠，需定时 AppleScript 同步）
    public static let hostSyncPollInterval: TimeInterval = 5

    /// Widget 时间线刷新间隔（reloadTimelines 可能被系统限流，此为兜底轮询）
    public static let widgetTimelineRefreshInterval: TimeInterval = 10
}
