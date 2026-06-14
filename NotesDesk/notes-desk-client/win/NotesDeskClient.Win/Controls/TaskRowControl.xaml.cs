using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using NotesDeskClient.Win.Models;

namespace NotesDeskClient.Win.Controls;

public partial class TaskRowControl : UserControl
{
    public static readonly RoutedEvent CompleteRequestedEvent =
        EventManager.RegisterRoutedEvent(nameof(CompleteRequested), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(TaskRowControl));

    public static readonly RoutedEvent UncompleteRequestedEvent =
        EventManager.RegisterRoutedEvent(nameof(UncompleteRequested), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(TaskRowControl));

    public static readonly RoutedEvent DueDateChangedEvent =
        EventManager.RegisterRoutedEvent(nameof(DueDateChanged), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(TaskRowControl));

    public static readonly DependencyProperty TaskItemProperty =
        DependencyProperty.Register(nameof(TaskItem), typeof(DeskTask), typeof(TaskRowControl),
            new PropertyMetadata(null, OnTaskChanged));

    public static readonly DependencyProperty FontSizeProperty =
        DependencyProperty.Register(nameof(FontSize), typeof(double), typeof(TaskRowControl),
            new PropertyMetadata(14.0));

    public static readonly DependencyProperty IsCompletedModeProperty =
        DependencyProperty.Register(nameof(IsCompletedMode), typeof(bool), typeof(TaskRowControl),
            new PropertyMetadata(false, OnTaskChanged));

    public event RoutedEventHandler CompleteRequested
    {
        add => AddHandler(CompleteRequestedEvent, value);
        remove => RemoveHandler(CompleteRequestedEvent, value);
    }

    public event RoutedEventHandler UncompleteRequested
    {
        add => AddHandler(UncompleteRequestedEvent, value);
        remove => RemoveHandler(UncompleteRequestedEvent, value);
    }

    public event RoutedEventHandler DueDateChanged
    {
        add => AddHandler(DueDateChangedEvent, value);
        remove => RemoveHandler(DueDateChangedEvent, value);
    }

    public DeskTask? TaskItem
    {
        get => (DeskTask?)GetValue(TaskItemProperty);
        set => SetValue(TaskItemProperty, value);
    }

    public double FontSize
    {
        get => (double)GetValue(FontSizeProperty);
        set => SetValue(FontSizeProperty, value);
    }

    public bool IsCompletedMode
    {
        get => (bool)GetValue(IsCompletedModeProperty);
        set => SetValue(IsCompletedModeProperty, value);
    }

    public TaskRowControl()
    {
        InitializeComponent();
        for (var h = 0; h < 24; h++) HourBox.Items.Add(h.ToString("00"));
        for (var m = 0; m < 60; m += 5) MinuteBox.Items.Add(m.ToString("00"));
    }

    private static void OnTaskChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is TaskRowControl control) control.RefreshUI();
    }

    private void RefreshUI()
    {
        var task = TaskItem;
        if (task == null) return;

        TaskText.Text = task.Text;
        TaskText.FontSize = FontSize;
        TaskText.FontWeight = IsCompletedMode ? FontWeights.Normal : FontWeights.Medium;
        TaskText.Foreground = IsCompletedMode ? Brushes.Gray : Brushes.Black;
        TaskText.TextDecorations = IsCompletedMode ? TextDecorations.Strikethrough : null;

        ActionButton.Content = IsCompletedMode ? "✓" : "○";
        ActionButton.Foreground = IsCompletedMode ? Brushes.LimeGreen : Brushes.Gray;
        ActionButton.FontSize = FontSize + 2;

        if (task.DueDate.HasValue)
        {
            DueBadge.Visibility = Visibility.Visible;
            DueLabel.Text = $"{task.DueDate.Value:M/d HH:mm} 截止";
            var color = IsCompletedMode ? Brushes.Gray : task.IsOverdue() ? Brushes.Red : Brushes.Orange;
            DueBadge.Background = new SolidColorBrush(Color.FromArgb(40, color.R, color.G, color.B));
            DueLabel.Foreground = color;
        }
        else DueBadge.Visibility = Visibility.Collapsed;

        DueButton.Visibility = IsCompletedMode ? Visibility.Collapsed : Visibility.Visible;
        DueButton.Content = task.DueDate.HasValue ? "改截止" : "设截止";

        var time = IsCompletedMode
            ? (task.CompletedAt ?? task.CreatedAt).ToString("HH:mm")
            : task.CreatedAt.ToString("HH:mm");
        var source = task.Source switch
        {
            MessageSource.Dingtalk => "钉钉",
            MessageSource.Feishu => "飞书",
            _ => "本地"
        };
        MetaLabel.Text = IsCompletedMode ? $"完成 {time}" : $"{time} · {source}";
    }

    private void ActionButton_Click(object sender, RoutedEventArgs e)
    {
        if (TaskItem == null) return;
        RaiseEvent(new RoutedEventArgs(
            IsCompletedMode ? UncompleteRequestedEvent : CompleteRequestedEvent, this));
    }

    private void DueButton_Click(object sender, RoutedEventArgs e)
    {
        var task = TaskItem;
        if (task == null) return;
        var draft = task.DueDate ?? DateTime.Today.AddHours(18);
        DueDatePicker.SelectedDate = draft.Date;
        HourBox.SelectedItem = draft.Hour.ToString("00");
        MinuteBox.SelectedItem = (draft.Minute / 5 * 5).ToString("00");
        DuePopup.IsOpen = true;
    }

    private DateTime? BuildDraftDueDate()
    {
        if (DueDatePicker.SelectedDate == null) return null;
        var hour = HourBox.SelectedItem is string hs && int.TryParse(hs, out var h) ? h : 18;
        var minute = MinuteBox.SelectedItem is string ms && int.TryParse(ms, out var m) ? m : 0;
        return DueDatePicker.SelectedDate.Value.Date.AddHours(hour).AddMinutes(minute);
    }

    private void ClearDue_Click(object sender, RoutedEventArgs e)
    {
        Tag = null;
        RaiseEvent(new RoutedEventArgs(DueDateChangedEvent, this));
        DuePopup.IsOpen = false;
    }

    private void ConfirmDue_Click(object sender, RoutedEventArgs e)
    {
        Tag = BuildDraftDueDate();
        RaiseEvent(new RoutedEventArgs(DueDateChangedEvent, this));
        DuePopup.IsOpen = false;
    }
}
