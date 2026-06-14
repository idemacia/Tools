using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Threading;
using NotesDeskClient.Win.Models;
using NotesDeskClient.Win.Services;

namespace NotesDeskClient.Win.ViewModels;

public sealed class DeskViewModel : INotifyPropertyChanged
{
    private readonly NasApiClient _api = new();
    private readonly DispatcherTimer _pollTimer = new();
    private readonly DispatcherTimer _dayBoundaryTimer = new();

    private List<DeskTask> _allIncomplete = new();
    private List<DeskTask> _allCompleted = new();

    private string _displayTitle = "待办";
    private string _statusMessage = "连接 NAS…";
    private bool _serverConnected;
    private bool _bridgeConnected;
    private List<DeskTask> _incompleteTasks = new();
    private List<DeskTask> _completedTasks = new();
    private bool _showCompletedSection;
    private bool _quitOnClosePanel;
    private bool _showSettings;
    private DeskViewMode _viewMode;
    private double _panelOpacity;
    private double _fontSize;
    private bool _panelVisible;

    public event PropertyChangedEventHandler? PropertyChanged;

    public DeskViewModel()
    {
        PanelOpacity = AppSettings.PanelOpacity;
        FontSize = AppSettings.FontSize;
        PanelVisible = AppSettings.PanelVisible;
        ViewMode = AppSettings.ViewMode;
        ShowCompletedSection = AppSettings.ShowCompletedSection;
        QuitOnClosePanel = AppSettings.QuitOnClosePanel;

        _pollTimer.Interval = TimeSpan.FromSeconds(AppConstants.PollIntervalSeconds);
        _pollTimer.Tick += async (_, _) => await RefreshFromServerAsync();

        ScheduleDayBoundaryRefresh();
        _ = RefreshFromServerAsync();
    }

    public string DisplayTitle
    {
        get => _displayTitle;
        private set => SetField(ref _displayTitle, value);
    }

    public string StatusMessage
    {
        get => _statusMessage;
        set => SetField(ref _statusMessage, value);
    }

    public bool ServerConnected
    {
        get => _serverConnected;
        set => SetField(ref _serverConnected, value);
    }

    public bool BridgeConnected
    {
        get => _bridgeConnected;
        set => SetField(ref _bridgeConnected, value);
    }

    public IReadOnlyList<DeskTask> IncompleteTasks => _incompleteTasks;
    public IReadOnlyList<DeskTask> CompletedTasks => _completedTasks;

    public bool ShowCompletedSection
    {
        get => _showCompletedSection;
        set
        {
            if (SetField(ref _showCompletedSection, value))
                AppSettings.ShowCompletedSection = value;
        }
    }

    public bool QuitOnClosePanel
    {
        get => _quitOnClosePanel;
        set
        {
            if (SetField(ref _quitOnClosePanel, value))
                AppSettings.QuitOnClosePanel = value;
        }
    }

    public bool ShowSettings
    {
        get => _showSettings;
        set => SetField(ref _showSettings, value);
    }

    public DeskViewMode ViewMode
    {
        get => _viewMode;
        set
        {
            if (SetField(ref _viewMode, value))
            {
                AppSettings.ViewMode = value;
                _ = RefreshFromServerAsync();
            }
        }
    }

    public double PanelOpacity
    {
        get => _panelOpacity;
        set
        {
            if (SetField(ref _panelOpacity, value))
                AppSettings.PanelOpacity = value;
        }
    }

    public double FontSize
    {
        get => _fontSize;
        set
        {
            if (SetField(ref _fontSize, value))
                AppSettings.FontSize = value;
        }
    }

    public bool PanelVisible
    {
        get => _panelVisible;
        set
        {
            if (SetField(ref _panelVisible, value))
                AppSettings.PanelVisible = value;
        }
    }

    public void StartPolling() => _pollTimer.Start();
    public void StopPolling() => _pollTimer.Stop();

    public async Task RefreshFromServerAsync()
    {
        if (!AppSettings.IsConfigured)
        {
            ServerConnected = false;
            BridgeConnected = false;
            StatusMessage = "请在设置中填写 NAS 地址";
            return;
        }

        try
        {
            var health = await _api.HealthAsync();
            ServerConnected = health.Ok;
            BridgeConnected = health.Bridge;
            StatusMessage = health.Bridge ? "NAS 已连接 · 钉钉桥在线" : "NAS 已连接 · 钉钉桥未启动";

            var viewParam = ViewMode == DeskViewMode.Today ? "today" : null;
            _allIncomplete = await _api.ListTasksAsync(viewParam, "incomplete");
            var limit = ViewMode == DeskViewMode.History ? 200 : 30;
            _allCompleted = (await _api.ListTasksAsync(status: "completed"))
                .OrderByDescending(t => t.CompletedAt ?? DateTime.MinValue)
                .Take(limit)
                .ToList();
            ApplyLists();
        }
        catch (Exception ex)
        {
            ServerConnected = false;
            BridgeConnected = false;
            StatusMessage = ex.Message;
        }
    }

    public async Task CompleteTaskAsync(string id)
    {
        try
        {
            var task = await _api.CompleteAsync(id);
            StatusMessage = $"已完成 · {task.Text}";
            await RefreshFromServerAsync();
        }
        catch (Exception ex) { StatusMessage = ex.Message; }
    }

    public async Task UncompleteTaskAsync(string id)
    {
        try
        {
            var task = await _api.UncompleteAsync(id);
            StatusMessage = $"已恢复 · {task.Text}";
            await RefreshFromServerAsync();
        }
        catch (Exception ex) { StatusMessage = ex.Message; }
    }

    public async Task SetDueDateAsync(string id, DateTime? dueDate)
    {
        try
        {
            await _api.SetDueDateAsync(id, dueDate);
            StatusMessage = dueDate == null ? "已清除截止日期" : "已更新截止日期";
            await RefreshFromServerAsync();
        }
        catch (Exception ex) { StatusMessage = ex.Message; }
    }

    public async Task AddTaskAsync(string text)
    {
        var trimmed = text.Trim();
        if (string.IsNullOrEmpty(trimmed)) return;
        try
        {
            await _api.IngestAsync(trimmed);
            StatusMessage = "已添加";
            await RefreshFromServerAsync();
        }
        catch (Exception ex) { StatusMessage = ex.Message; }
    }

    public async Task ClearCompletedAsync()
    {
        try
        {
            var n = await _api.ClearCompletedAsync();
            StatusMessage = $"已清除 {n} 条已完成";
            await RefreshFromServerAsync();
        }
        catch (Exception ex) { StatusMessage = ex.Message; }
    }

    public async Task CompleteMostRecentAsync()
    {
        if (_allIncomplete.Count == 0)
        {
            StatusMessage = "没有可完成的任务";
            return;
        }
        await CompleteTaskAsync(_allIncomplete[^1].Id);
    }

    public TaskPeriodStats DailyStats()
    {
        var today = DateTime.Today;
        var end = today.AddDays(1);
        var tasks = _allIncomplete.Concat(_allCompleted).Where(t =>
        {
            var createdIn = t.CreatedAt >= today && t.CreatedAt < end;
            var dueIn = t.DueDate.HasValue && t.DueDate.Value >= today && t.DueDate.Value < end;
            return createdIn || dueIn;
        }).ToList();
        var completed = tasks.Count(t => t.IsCompleted);
        return new TaskPeriodStats
        {
            Planned = tasks.Count,
            Completed = completed,
            Incomplete = tasks.Count - completed
        };
    }

    private void ApplyLists()
    {
        _incompleteTasks = FilteredIncompleteTasks();
        _completedTasks = _allCompleted;
        UpdateTitle();
        OnPropertyChanged(nameof(IncompleteTasks));
        OnPropertyChanged(nameof(CompletedTasks));
    }

    private List<DeskTask> FilteredIncompleteTasks()
    {
        if (ViewMode != DeskViewMode.Today) return _allIncomplete.ToList();
        var today = DateTime.Today;
        return _allIncomplete.Where(t =>
            t.CreatedAt.Date == today ||
            (t.DueDate.HasValue && t.DueDate.Value.Date == today)).ToList();
    }

    private void UpdateTitle()
    {
        DisplayTitle = ViewMode switch
        {
            DeskViewMode.History => "历史",
            _ => _incompleteTasks.Count == 0 ? "待办" : $"待办（{_incompleteTasks.Count} 项）"
        };
    }

    private void ScheduleDayBoundaryRefresh()
    {
        _dayBoundaryTimer.Stop();
        var now = DateTime.Now;
        var tomorrow = now.Date.AddDays(1).AddSeconds(5);
        _dayBoundaryTimer.Interval = tomorrow - now;
        if (_dayBoundaryTimer.Interval.TotalSeconds < 60)
            _dayBoundaryTimer.Interval = TimeSpan.FromMinutes(1);
        _dayBoundaryTimer.Tick += OnDayBoundary;
        _dayBoundaryTimer.Start();
    }

    private async void OnDayBoundary(object? sender, EventArgs e)
    {
        _dayBoundaryTimer.Tick -= OnDayBoundary;
        await RefreshFromServerAsync();
        ScheduleDayBoundaryRefresh();
    }

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        OnPropertyChanged(name);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
