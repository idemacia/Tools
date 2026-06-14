namespace NotesDeskClient.Win.Models;

public static class AppConstants
{
    public const int PollIntervalSeconds = 30;
    public const string AppSupportSubdirectory = "NotesDeskClient";
}

public enum MessageSource
{
    Feishu,
    Dingtalk,
    Manual
}

public enum DeskViewMode
{
    Incomplete,
    Today,
    History
}

public sealed class DeskTask
{
    public string Id { get; set; } = "";
    public string Text { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime? DueDate { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime? RemindedAt { get; set; }
    public MessageSource Source { get; set; } = MessageSource.Manual;
    public string? DingtalkMessageId { get; set; }
    public string? DingtalkStaffId { get; set; }

    public bool IsCompleted => CompletedAt.HasValue;

    public bool IsOverdue()
    {
        return !IsCompleted && DueDate.HasValue && DueDate.Value < DateTime.Now;
    }
}

public sealed class TaskPeriodStats
{
    public int Planned { get; init; }
    public int Completed { get; init; }
    public int Incomplete { get; init; }
}

public sealed class HealthStatus
{
    public bool Ok { get; set; }
    public bool Bridge { get; set; }
}

public static class DeskViewModeExtensions
{
    public static string DisplayName(this DeskViewMode mode) => mode switch
    {
        DeskViewMode.Incomplete => "全部未完成",
        DeskViewMode.Today => "今日",
        DeskViewMode.History => "历史",
        _ => mode.ToString()
    };
}
