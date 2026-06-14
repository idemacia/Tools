using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Input;
using NotesDeskClient.Win.Controls;
using NotesDeskClient.Win.Models;
using NotesDeskClient.Win.Services;
using NotesDeskClient.Win.ViewModels;
using Application = System.Windows.Application;

namespace NotesDeskClient.Win;

public partial class MainWindow : Window, INotifyPropertyChanged
{
    private readonly DeskViewModel _viewModel;

    public MainWindow(DeskViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;
        _viewModel.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName is nameof(DeskViewModel.IncompleteTasks)
                or nameof(DeskViewModel.CompletedTasks)
                or nameof(DeskViewModel.ShowCompletedSection))
                NotifyEmptyStateChanged();
        };
        Closing += MainWindow_Closing;
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

    private async void AddTask_Click(object sender, RoutedEventArgs e)
    {
        await _viewModel.AddTaskAsync(NewTaskBox.Text);
        NewTaskBox.Clear();
    }

    private async void NewTaskBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
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
        if (sender is TaskRowControl { TaskItem: { } task })
            await _viewModel.SetDueDateAsync(task.Id, sender is TaskRowControl row ? row.Tag as DateTime? : null);
    }
}
