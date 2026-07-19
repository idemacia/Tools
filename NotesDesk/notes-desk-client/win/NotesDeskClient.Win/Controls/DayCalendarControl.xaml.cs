using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using NotesDeskClient.Win.Models;

namespace NotesDeskClient.Win.Controls;

public partial class DayCalendarControl : UserControl
{
    public static readonly RoutedEvent DaySelectedEvent =
        EventManager.RegisterRoutedEvent(nameof(DaySelected), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(DayCalendarControl));

    public static readonly RoutedEvent TodayRequestedEvent =
        EventManager.RegisterRoutedEvent(nameof(TodayRequested), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(DayCalendarControl));

    public static readonly RoutedEvent ClearRequestedEvent =
        EventManager.RegisterRoutedEvent(nameof(ClearRequested), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(DayCalendarControl));

    public static readonly RoutedEvent MonthChangedEvent =
        EventManager.RegisterRoutedEvent(nameof(MonthChanged), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(DayCalendarControl));

    public event RoutedEventHandler DaySelected
    {
        add => AddHandler(DaySelectedEvent, value);
        remove => RemoveHandler(DaySelectedEvent, value);
    }

    public event RoutedEventHandler TodayRequested
    {
        add => AddHandler(TodayRequestedEvent, value);
        remove => RemoveHandler(TodayRequestedEvent, value);
    }

    public event RoutedEventHandler ClearRequested
    {
        add => AddHandler(ClearRequestedEvent, value);
        remove => RemoveHandler(ClearRequestedEvent, value);
    }

    public event RoutedEventHandler MonthChanged
    {
        add => AddHandler(MonthChangedEvent, value);
        remove => RemoveHandler(MonthChangedEvent, value);
    }

    private int _year;
    private int _month;
    private string? _selected;
    private CalendarDayMarks _marks = new();

    public string? SelectedDay
    {
        get => _selected;
        set
        {
            _selected = value;
            if (!string.IsNullOrEmpty(value) && value.Length >= 7)
            {
                if (int.TryParse(value[..4], out var y) && int.TryParse(value.Substring(5, 2), out var m))
                {
                    _year = y;
                    _month = m;
                }
            }
            Rebuild();
        }
    }

    public string MonthKey => $"{_year:D4}-{_month:D2}";

    public DayCalendarControl()
    {
        InitializeComponent();
        var today = ShanghaiTime.DayString();
        _year = int.Parse(today[..4]);
        _month = int.Parse(today.Substring(5, 2));
        Rebuild();
    }

    public void SetMarks(CalendarDayMarks marks)
    {
        _marks = marks;
        Rebuild();
    }

    private void PrevMonth_Click(object sender, RoutedEventArgs e) => ShiftMonth(-1);
    private void NextMonth_Click(object sender, RoutedEventArgs e) => ShiftMonth(1);
    private void Today_Click(object sender, RoutedEventArgs e) =>
        RaiseEvent(new RoutedEventArgs(TodayRequestedEvent, this));
    private void Clear_Click(object sender, RoutedEventArgs e) =>
        RaiseEvent(new RoutedEventArgs(ClearRequestedEvent, this));

    private void ShiftMonth(int delta)
    {
        var d = new DateTime(_year, _month, 1).AddMonths(delta);
        _year = d.Year;
        _month = d.Month;
        Rebuild();
        Tag = MonthKey;
        RaiseEvent(new RoutedEventArgs(MonthChangedEvent, this));
    }

    private void Rebuild()
    {
        MonthLabel.Text = $"{_year}年{_month}月";
        ClearButton.Visibility = string.IsNullOrEmpty(_selected) ? Visibility.Collapsed : Visibility.Visible;
        DaysGrid.Children.Clear();

        var first = new DateTime(_year, _month, 1);
        // Monday-first: Sunday=0 -> 6
        var pad = ((int)first.DayOfWeek + 6) % 7;
        var days = DateTime.DaysInMonth(_year, _month);
        var today = ShanghaiTime.DayString();

        for (var i = 0; i < pad; i++)
            DaysGrid.Children.Add(new Border { Height = 28 });

        for (var d = 1; d <= days; d++)
        {
            var day = $"{_year:D4}-{_month:D2}-{d:D2}";
            var isSelected = day == _selected;
            var isToday = day == today;
            var nC = _marks.Created.GetValueOrDefault(day);
            var nI = _marks.Incomplete.GetValueOrDefault(day);
            var nD = _marks.Completed.GetValueOrDefault(day);

            var panel = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            panel.Children.Add(new TextBlock
            {
                Text = d.ToString(),
                FontSize = 11,
                FontWeight = isSelected || isToday ? FontWeights.SemiBold : FontWeights.Normal,
                Foreground = isSelected ? Brushes.White : isToday ? Brushes.Orange : Brushes.Black,
                HorizontalAlignment = HorizontalAlignment.Center
            });
            var dots = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, Height = 5 };
            if (nC > 0) dots.Children.Add(Dot(Color.FromRgb(255, 204, 0)));
            if (nI > 0) dots.Children.Add(Dot(Colors.Red));
            if (nD > 0) dots.Children.Add(Dot(Colors.LimeGreen));
            panel.Children.Add(dots);

            var tip = new List<string>();
            if (nC > 0) tip.Add($"新建 {nC}");
            if (nI > 0) tip.Add($"未完成 {nI}");
            if (nD > 0) tip.Add($"已完成 {nD}");

            var btn = new Button
            {
                Content = panel,
                Tag = day,
                Background = isSelected
                    ? new SolidColorBrush(Colors.Orange)
                    : isToday
                        ? new SolidColorBrush(Color.FromArgb(40, 255, 149, 0))
                        : Brushes.Transparent,
                BorderThickness = new Thickness(0),
                Padding = new Thickness(0),
                Margin = new Thickness(1),
                Cursor = Cursors.Hand,
                ToolTip = tip.Count > 0 ? string.Join(" · ", tip) : null
            };
            btn.Click += (_, _) =>
            {
                Tag = day;
                RaiseEvent(new RoutedEventArgs(DaySelectedEvent, this));
            };
            DaysGrid.Children.Add(btn);
        }
    }

    private static Ellipse Dot(Color c) => new()
    {
        Width = 4,
        Height = 4,
        Margin = new Thickness(1, 0, 1, 0),
        Fill = new SolidColorBrush(c)
    };
}
