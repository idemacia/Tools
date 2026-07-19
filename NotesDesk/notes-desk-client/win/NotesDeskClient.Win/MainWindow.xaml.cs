using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using NotesDeskClient.Win.Controls;
using NotesDeskClient.Win.Models;
using NotesDeskClient.Win.Services;
using NotesDeskClient.Win.ViewModels;
using Application = System.Windows.Application;

namespace NotesDeskClient.Win;

public partial class MainWindow : Window, INotifyPropertyChanged
{
    private readonly DeskViewModel _viewModel;
    private readonly DispatcherTimer _searchDebounce = new() { Interval = TimeSpan.FromMilliseconds(250) };

    public MainWindow(DeskViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;
        _viewModel.PropertyChanged += OnViewModelPropertyChanged;
        _searchDebounce.Tick += (_, _) =>
        {
            _searchDebounce.Stop();
            _viewModel.ApplySearch(SearchBox.Text);
        };
        Closing += MainWindow_Closing;
        Loaded += (_, _) =>
        {
            DayCalendar.SelectedDay = _viewModel.FilterDate;
            DayCalendar.SetMarks(_viewModel.CalendarMarks);
        };
        NotifyEmptyStateChanged();
    }

    public Visibility ShowEmptyPlaceholder =>
        _viewModel.IncompleteTasks.Count == 0 && _viewModel.CompletedTasks.Count == 0
            ? Visibility.Visible : Visibility.Collapsed;

    public Visibility HasNoIncomplete =>
        _viewModel.IncompleteTasks.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

    public Visibility HasCompletedTasks =>
        _viewModel.CompletedTasks.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

    public Visibility ShowCompletedList =>
        _viewModel.ShowCompletedSection && _viewModel.CompletedTasks.Count > 0
            ? Visibility.Visible : Visibility.Collapsed;

    public string CompletedHeader => $"已完成（{_viewModel.CompletedTasks.Count}）";
    public string CompletedToggleLabel => _viewModel.ShowCompletedSection ? "隐藏" : "显示";

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName is nameof(DeskViewModel.IncompleteTasks)
            or nameof(DeskViewModel.CompletedTasks)
            or nameof(DeskViewModel.ShowCompletedSection)
            or nameof(DeskViewModel.CommentCounts))
            NotifyEmptyStateChanged();

        if (args.PropertyName == nameof(DeskViewModel.CalendarMarks))
            DayCalendar.SetMarks(_viewModel.CalendarMarks);

        if (args.PropertyName == nameof(DeskViewModel.FilterDate))
            DayCalendar.SelectedDay = _viewModel.FilterDate;
    }

    private void NotifyEmptyStateChanged()
    {
        OnPropertyChanged(nameof(ShowEmptyPlaceholder));
        OnPropertyChanged(nameof(HasNoIncomplete));
        OnPropertyChanged(nameof(HasCompletedTasks));
        OnPropertyChanged(nameof(ShowCompletedList));
        OnPropertyChanged(nameof(CompletedHeader));
        OnPropertyChanged(nameof(CompletedToggleLabel));
    }

    private void OnPropertyChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    private void MainWindow_Closing(object? sender, CancelEventArgs e)
    {
        if (AppSettings.QuitOnClosePanel) return;
        e.Cancel = true;
        if (Application.Current is App app)
            app.RequestClosePanel();
    }

    private void Header_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2) return;
        DragMove();
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e) =>
        _viewModel.ShowSettings = true;

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        if (Application.Current is App app)
            app.RequestClosePanel();
    }

    private void ToggleCompleted_Click(object sender, RoutedEventArgs e) =>
        _viewModel.ShowCompletedSection = !_viewModel.ShowCompletedSection;

    private void DayCalendar_DaySelected(object sender, RoutedEventArgs e)
    {
        if (sender is DayCalendarControl { Tag: string day })
            _viewModel.FilterDate = day;
    }

    private void DayCalendar_TodayRequested(object sender, RoutedEventArgs e) =>
        _viewModel.FilterDate = ShanghaiTime.DayString();

    private void DayCalendar_ClearRequested(object sender, RoutedEventArgs e) =>
        _viewModel.FilterDate = null;

    private void DayCalendar_MonthChanged(object sender, RoutedEventArgs e)
    {
        if (sender is DayCalendarControl cal)
            _viewModel.SetCalendarMonth(cal.MonthKey);
    }

    private void SearchBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        _searchDebounce.Stop();
        _searchDebounce.Start();
    }

    private void ClearSearch_Click(object sender, RoutedEventArgs e)
    {
        SearchBox.Clear();
        _viewModel.ApplySearch("");
    }

    private async void AddTask_Click(object sender, RoutedEventArgs e)
    {
        await _viewModel.AddTaskAsync(NewTaskBox.Text);
        NewTaskBox.Clear();
    }

    private async void TaskRow_CompleteRequested(object sender, RoutedEventArgs e)
    {
        if (sender is TaskRowControl { TaskItem: { } task })
            await _viewModel.CompleteTaskAsync(task.Id);
    }

    private async void TaskRow_UncompleteRequested(object sender, RoutedEventArgs e)
    {
        if (sender is TaskRowControl { TaskItem: { } task })
            await _viewModel.UncompleteTaskAsync(task.Id);
    }

    private async void TaskRow_DueDateChanged(object sender, RoutedEventArgs e)
    {
        if (sender is TaskRowControl { TaskItem: { } task } row)
            await _viewModel.SetDueDateAsync(task.Id, row.Tag as DateTime?);
    }

    private async void TaskRow_CommentsRequested(object sender, RoutedEventArgs e)
    {
        if (sender is not TaskRowControl { TaskItem: { } task }) return;
        var win = new CommentsWindow(task) { Owner = this };
        win.ShowDialog();
        await _viewModel.RefreshFromServerAsync();
    }
}
