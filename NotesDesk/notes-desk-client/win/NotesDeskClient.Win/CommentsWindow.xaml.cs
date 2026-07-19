using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using NotesDeskClient.Win.Models;
using NotesDeskClient.Win.Services;

namespace NotesDeskClient.Win;

public partial class CommentsWindow : Window
{
    private readonly DeskTask _task;
    private readonly NasApiClient _api = new();
    private string? _editingId;

    public CommentsWindow(DeskTask task)
    {
        InitializeComponent();
        _task = task;
        TaskTitle.Text = task.Text;
        Loaded += async (_, _) => await ReloadAsync();
    }

    private async Task ReloadAsync()
    {
        try
        {
            var comments = await _api.ListCommentsAsync(_task.Id);
            CommentsPanel.Children.Clear();
            if (comments.Count == 0)
            {
                CommentsPanel.Children.Add(new TextBlock
                {
                    Text = "暂无评论",
                    FontSize = 12,
                    Foreground = Brushes.Gray
                });
                HideFeedback();
                return;
            }

            foreach (var c in comments)
                CommentsPanel.Children.Add(BuildCommentCard(c));
            HideFeedback();
        }
        catch (Exception ex)
        {
            ShowFeedback(ex.Message);
        }
    }

    private UIElement BuildCommentCard(TaskComment c)
    {
        var card = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(30, 0, 0, 0)),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(8),
            Margin = new Thickness(0, 0, 0, 8)
        };
        var root = new StackPanel();

        if (_editingId == c.Id)
        {
            var editor = new TextBox
            {
                Text = c.Body,
                AcceptsReturn = true,
                TextWrapping = TextWrapping.Wrap,
                MinHeight = 48
            };
            root.Children.Add(editor);
            var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 6, 0, 0) };
            var cancel = new Button { Content = "取消", Margin = new Thickness(0, 0, 8, 0), Padding = new Thickness(8, 2, 8, 2) };
            cancel.Click += (_, _) =>
            {
                _editingId = null;
                _ = ReloadAsync();
            };
            var save = new Button { Content = "保存", Padding = new Thickness(8, 2, 8, 2) };
            save.Click += async (_, _) =>
            {
                var body = editor.Text.Trim();
                if (string.IsNullOrEmpty(body)) return;
                try
                {
                    await _api.UpdateCommentAsync(_task.Id, c.Id, body);
                    _editingId = null;
                    await ReloadAsync();
                }
                catch (Exception ex) { ShowFeedback(ex.Message); }
            };
            row.Children.Add(cancel);
            row.Children.Add(save);
            root.Children.Add(row);
        }
        else
        {
            root.Children.Add(new TextBlock
            {
                Text = c.Body,
                FontSize = 12,
                TextWrapping = TextWrapping.Wrap
            });
            var meta = new Grid { Margin = new Thickness(0, 4, 0, 0) };
            meta.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            meta.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            var time = new TextBlock
            {
                Text = c.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                FontSize = 10,
                Foreground = Brushes.Gray,
                VerticalAlignment = VerticalAlignment.Center
            };
            var actions = new StackPanel { Orientation = Orientation.Horizontal };
            var edit = new Button
            {
                Content = "编辑",
                FontSize = 11,
                Background = Brushes.Transparent,
                BorderThickness = new Thickness(0),
                Foreground = Brushes.Gray,
                Cursor = System.Windows.Input.Cursors.Hand,
                Margin = new Thickness(8, 0, 0, 0)
            };
            edit.Click += (_, _) =>
            {
                _editingId = c.Id;
                _ = ReloadAsync();
            };
            var del = new Button
            {
                Content = "删除",
                FontSize = 11,
                Background = Brushes.Transparent,
                BorderThickness = new Thickness(0),
                Foreground = Brushes.Red,
                Cursor = System.Windows.Input.Cursors.Hand,
                Margin = new Thickness(8, 0, 0, 0)
            };
            del.Click += async (_, _) =>
            {
                try
                {
                    await _api.DeleteCommentAsync(_task.Id, c.Id);
                    if (_editingId == c.Id) _editingId = null;
                    await ReloadAsync();
                }
                catch (Exception ex) { ShowFeedback(ex.Message); }
            };
            actions.Children.Add(edit);
            actions.Children.Add(del);
            Grid.SetColumn(time, 0);
            Grid.SetColumn(actions, 1);
            meta.Children.Add(time);
            meta.Children.Add(actions);
            root.Children.Add(meta);
        }

        card.Child = root;
        return card;
    }

    private async void Add_Click(object sender, RoutedEventArgs e)
    {
        var body = DraftBox.Text.Trim();
        if (string.IsNullOrEmpty(body)) return;
        AddButton.IsEnabled = false;
        try
        {
            await _api.CreateCommentAsync(_task.Id, body);
            DraftBox.Clear();
            await ReloadAsync();
        }
        catch (Exception ex)
        {
            ShowFeedback(ex.Message);
        }
        finally
        {
            AddButton.IsEnabled = true;
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private void ShowFeedback(string msg)
    {
        Feedback.Text = msg;
        Feedback.Visibility = Visibility.Visible;
    }

    private void HideFeedback() => Feedback.Visibility = Visibility.Collapsed;
}
