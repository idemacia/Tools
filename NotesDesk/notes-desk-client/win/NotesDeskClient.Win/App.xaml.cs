using System.Drawing;
using System.Windows;
using System.Windows.Forms;
using NotesDeskClient.Win.Services;
using NotesDeskClient.Win.ViewModels;
using Application = System.Windows.Application;

namespace NotesDeskClient.Win;

public partial class App : Application
{
    private NotifyIcon? _trayIcon;
    private MainWindow? _mainWindow;
    private SettingsWindow? _settingsWindow;
    private readonly DeskViewModel _viewModel = new();

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _viewModel.StartPolling();
        _mainWindow = new MainWindow(_viewModel);
        _mainWindow.LocationChanged += (_, _) => SaveWindowOriginDebounced();
        SetupTrayIcon();
        WireViewModelEvents();

        var origin = AppSettings.PanelOrigin;
        if (origin.HasValue)
        {
            _mainWindow.Left = origin.Value.X;
            _mainWindow.Top = origin.Value.Y;
        }
        else
        {
            _mainWindow.WindowStartupLocation = WindowStartupLocation.CenterScreen;
        }

        ShowPanel(forceFront: true);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _viewModel.StopPolling();
        _trayIcon?.Dispose();
        base.OnExit(e);
    }

    private void SetupTrayIcon()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add(new ToolStripLabel(_viewModel.StatusMessage) { Name = "statusLabel" });
        menu.Items.Add(new ToolStripSeparator());

        var connItem = new ToolStripMenuItem("NAS：未连接") { Enabled = false, Name = "connLabel" };
        menu.Items.Add(connItem);
        menu.Items.Add(new ToolStripSeparator());

        var showPanel = new ToolStripMenuItem("显示浮窗", null, (_, _) => ShowPanel()) { Checked = true, CheckOnClick = true };
        showPanel.CheckedChanged += (_, _) =>
        {
            if (showPanel.Checked) ShowPanel();
            else HidePanel();
        };
        menu.Items.Add(showPanel);
        menu.Items.Add(new ToolStripMenuItem("设置…", null, (_, _) => OpenSettings()));
        menu.Items.Add(new ToolStripMenuItem("刷新", null, async (_, _) => await _viewModel.RefreshFromServerAsync()));
        menu.Items.Add(new ToolStripMenuItem("完成最近一条", null, async (_, _) => await _viewModel.CompleteMostRecentAsync()));
        menu.Items.Add(new ToolStripMenuItem("清除已完成", null, async (_, _) => await _viewModel.ClearCompletedAsync()));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripLabel($"服务器: {AppSettings.ServerBaseUrl}") { Enabled = false });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("退出 NotesDesk Client", null, (_, _) => Shutdown()));

        _trayIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "NotesDesk Client",
            Visible = true,
            ContextMenuStrip = menu
        };
        _trayIcon.DoubleClick += (_, _) => ShowPanel(forceFront: true);

        _viewModel.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(DeskViewModel.StatusMessage))
                UpdateTrayLabel("statusLabel", _viewModel.StatusMessage);
            if (args.PropertyName is nameof(DeskViewModel.ServerConnected) or nameof(DeskViewModel.BridgeConnected))
            {
                var text = _viewModel.ServerConnected
                    ? (_viewModel.BridgeConnected ? "NAS · 钉钉桥在线" : "NAS · 钉钉桥离线")
                    : "NAS：未连接";
                UpdateTrayLabel("connLabel", text);
            }
            if (args.PropertyName == nameof(DeskViewModel.ShowSettings) && _viewModel.ShowSettings)
                OpenSettings();
        };
    }

    private void WireViewModelEvents()
    {
        _viewModel.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(DeskViewModel.PanelVisible))
            {
                if (_viewModel.PanelVisible) ShowPanel();
                else HidePanel();
            }
        };
    }

    private void UpdateTrayLabel(string name, string text)
    {
        if (_trayIcon?.ContextMenuStrip?.Items[name] is ToolStripItem item)
            item.Text = text;
    }

    private void ShowPanel(bool forceFront = false)
    {
        if (_mainWindow == null) return;
        _mainWindow.Show();
        _viewModel.PanelVisible = true;
        if (forceFront)
        {
            _mainWindow.Activate();
            _mainWindow.Topmost = true;
            _mainWindow.Topmost = false;
        }
        _ = _viewModel.RefreshFromServerAsync();
    }

    private void HidePanel()
    {
        _mainWindow?.Hide();
        _viewModel.PanelVisible = false;
    }

    public void RequestClosePanel()
    {
        if (AppSettings.QuitOnClosePanel)
            Shutdown();
        else
            HidePanel();
    }

    private void OpenSettings()
    {
        ShowPanel(forceFront: true);
        if (_settingsWindow == null || !_settingsWindow.IsLoaded)
        {
            _settingsWindow = new SettingsWindow(_viewModel);
            _settingsWindow.Owner = _mainWindow;
            _settingsWindow.Closed += (_, _) =>
            {
                _viewModel.ShowSettings = false;
                _settingsWindow = null;
            };
        }
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    private System.Timers.Timer? _saveOriginTimer;

    private void SaveWindowOriginDebounced()
    {
        _saveOriginTimer?.Stop();
        _saveOriginTimer = new System.Timers.Timer(300) { AutoReset = false };
        _saveOriginTimer.Elapsed += (_, _) =>
        {
            Dispatcher.Invoke(() =>
            {
                if (_mainWindow == null) return;
                AppSettings.PanelOrigin = (_mainWindow.Left, _mainWindow.Top);
            });
        };
        _saveOriginTimer.Start();
    }
}
