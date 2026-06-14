using System.Windows;
using NotesDeskClient.Win.Services;
using NotesDeskClient.Win.ViewModels;

namespace NotesDeskClient.Win;

public partial class SettingsWindow : Window
{
    private readonly DeskViewModel _viewModel;

    public SettingsWindow(DeskViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;
        ServerUrlBox.Text = AppSettings.ServerBaseUrl;
        ApiTokenBox.Password = AppSettings.ApiToken;
        RefreshStats();
    }

    private void RefreshStats()
    {
        var stats = _viewModel.DailyStats();
        StatPlanned.Text = stats.Planned.ToString();
        StatCompleted.Text = stats.Completed.ToString();
        StatIncomplete.Text = stats.Incomplete.ToString();
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private async void TestConnection_Click(object sender, RoutedEventArgs e)
    {
        TestButton.IsEnabled = false;
        var prevUrl = AppSettings.ServerBaseUrl;
        var prevToken = AppSettings.ApiToken;
        AppSettings.ServerBaseUrl = ServerUrlBox.Text;
        AppSettings.ApiToken = ApiTokenBox.Password;
        try
        {
            var client = new NasApiClient();
            var health = await client.HealthAsync();
            ShowFeedback(health.Ok
                ? (health.Bridge ? "连接成功 · 钉钉桥在线" : "连接成功 · 钉钉桥未启动")
                : "服务器返回异常", !health.Ok);
        }
        catch (Exception ex)
        {
            ShowFeedback(ex.Message, true);
        }
        finally
        {
            AppSettings.ServerBaseUrl = prevUrl;
            AppSettings.ApiToken = prevToken;
            TestButton.IsEnabled = true;
        }
    }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        AppSettings.ServerBaseUrl = ServerUrlBox.Text;
        AppSettings.ApiToken = ApiTokenBox.Password;
        ShowFeedback("已保存", false);
        await _viewModel.RefreshFromServerAsync();
        RefreshStats();
    }

    private void ShowFeedback(string text, bool isError)
    {
        Feedback.Text = text;
        Feedback.Foreground = isError
            ? System.Windows.Media.Brushes.Red
            : System.Windows.Media.Brushes.Green;
        Feedback.Visibility = Visibility.Visible;
    }
}
