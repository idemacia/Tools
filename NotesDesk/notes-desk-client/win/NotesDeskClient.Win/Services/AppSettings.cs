using System.IO;
using System.Text.Json;
using NotesDeskClient.Win.Models;

namespace NotesDeskClient.Win.Services;

public static class AppSettings
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private static string SettingsPath =>
        Path.Combine(AppPaths.AppDataDirectory, "settings.json");

    private static AppSettingsData Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var json = File.ReadAllText(SettingsPath);
                return JsonSerializer.Deserialize<AppSettingsData>(json) ?? new AppSettingsData();
            }
        }
        catch { /* ignore */ }
        return new AppSettingsData();
    }

    private static void Save(AppSettingsData data)
    {
        Directory.CreateDirectory(AppPaths.AppDataDirectory);
        File.WriteAllText(SettingsPath, JsonSerializer.Serialize(data, JsonOptions));
    }

    public static string ServerBaseUrl
    {
        get => Load().ServerBaseUrl ?? "http://127.0.0.1:8080";
        set { var d = Load(); d.ServerBaseUrl = value.Trim().TrimEnd('/'); Save(d); }
    }

    public static string ApiToken
    {
        get => Load().ApiToken ?? "";
        set { var d = Load(); d.ApiToken = value; Save(d); }
    }

    public static double PanelOpacity
    {
        get => Load().PanelOpacity <= 0 ? 0.92 : Load().PanelOpacity;
        set { var d = Load(); d.PanelOpacity = value; Save(d); }
    }

    public static double FontSize
    {
        get => Load().FontSize <= 0 ? 14 : Load().FontSize;
        set { var d = Load(); d.FontSize = value; Save(d); }
    }

    public static bool PanelVisible
    {
        get => Load().PanelVisible ?? true;
        set { var d = Load(); d.PanelVisible = value; Save(d); }
    }

    public static DeskViewMode ViewMode
    {
        get => Enum.TryParse<DeskViewMode>(Load().ViewMode, out var m) ? m : DeskViewMode.Incomplete;
        set { var d = Load(); d.ViewMode = value.ToString(); Save(d); }
    }

    public static bool ShowCompletedSection
    {
        get => Load().ShowCompletedSection ?? true;
        set { var d = Load(); d.ShowCompletedSection = value; Save(d); }
    }

    public static bool QuitOnClosePanel
    {
        get => Load().QuitOnClosePanel ?? false;
        set { var d = Load(); d.QuitOnClosePanel = value; Save(d); }
    }

    public static (double X, double Y)? PanelOrigin
    {
        get
        {
            var d = Load();
            if (d.PanelOriginX.HasValue && d.PanelOriginY.HasValue)
                return (d.PanelOriginX.Value, d.PanelOriginY.Value);
            return null;
        }
        set
        {
            var d = Load();
            if (value.HasValue)
            {
                d.PanelOriginX = value.Value.X;
                d.PanelOriginY = value.Value.Y;
            }
            else
            {
                d.PanelOriginX = null;
                d.PanelOriginY = null;
            }
            Save(d);
        }
    }

    public static bool IsConfigured => !string.IsNullOrWhiteSpace(ServerBaseUrl);

    private sealed class AppSettingsData
    {
        public string? ServerBaseUrl { get; set; }
        public string? ApiToken { get; set; }
        public double PanelOpacity { get; set; }
        public double FontSize { get; set; }
        public bool? PanelVisible { get; set; }
        public string? ViewMode { get; set; }
        public bool? ShowCompletedSection { get; set; }
        public bool? QuitOnClosePanel { get; set; }
        public double? PanelOriginX { get; set; }
        public double? PanelOriginY { get; set; }
    }
}

public static class AppPaths
{
    public static string AppDataDirectory =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            AppConstants.AppSupportSubdirectory);
}
