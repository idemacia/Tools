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

public sealed class TaskComment
{
    public string Id { get; set; } = "";
    public string TaskId { get; set; } = "";
    public string Body { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public sealed class CalendarDayMarks
{
    public Dictionary<string, int> Created { get; set; } = new();
    public Dictionary<string, int> Incomplete { get; set; } = new();
    public Dictionary<string, int> Completed { get; set; } = new();
}

public sealed class TaskListResult
{
    public List<DeskTask> Tasks { get; set; } = new();
    public Dictionary<string, int> CommentCounts { get; set; } = new();
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

/// <summary>Asia/Shanghai 日历日 YYYY-MM-DD。</summary>
public static class ShanghaiTime
{
    private static readonly TimeZoneInfo Tz = ResolveTz();

    private static TimeZoneInfo ResolveTz()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("China Standard Time"); }
        catch
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById("Asia/Shanghai"); }
            catch { return TimeZoneInfo.Local; }
        }
    }

    public static string DayString(DateTime? utcOrLocal = null)
    {
        var src = utcOrLocal ?? DateTime.UtcNow;
        var utc = src.Kind switch
        {
            DateTimeKind.Utc => src,
            DateTimeKind.Local => src.ToUniversalTime(),
            _ => DateTime.SpecifyKind(src, DateTimeKind.Utc)
        };
        var local = TimeZoneInfo.ConvertTimeFromUtc(utc, Tz);
        return local.ToString("yyyy-MM-dd");
    }

    public static string MonthString(DateTime? utcOrLocal = null) =>
        DayString(utcOrLocal)[..7];

    public static DateTime? FromDayString(string day)
    {
        if (!DateTime.TryParseExact(day, "yyyy-MM-dd", null,
                System.Globalization.DateTimeStyles.None, out var d))
            return null;
        return d;
    }

    public static string ShiftDay(string day, int delta)
    {
        var d = FromDayString(day) ?? DateTime.Today;
        return d.AddDays(delta).ToString("yyyy-MM-dd");
    }
}
