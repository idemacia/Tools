using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using NotesDeskClient.Win.Models;

namespace NotesDeskClient.Win.Services;

public sealed class NasApiClient
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly HttpClient _http = new();

    public async Task<HealthStatus> HealthAsync(CancellationToken ct = default)
    {
        return (await GetAsync<HealthStatus>("/health", auth: false, ct))!;
    }

    public async Task<List<DeskTask>> ListTasksAsync(string? view = null, string? status = null, CancellationToken ct = default)
    {
        var q = new List<string>();
        if (view != null) q.Add($"view={Uri.EscapeDataString(view)}");
        if (status != null) q.Add($"status={Uri.EscapeDataString(status)}");
        var query = q.Count > 0 ? "?" + string.Join("&", q) : "";
        var res = await GetAsync<TasksResponse>($"/api/tasks{query}", auth: true, ct);
        return res?.Tasks ?? new List<DeskTask>();
    }

    public async Task<DeskTask> CompleteAsync(string id, CancellationToken ct = default)
    {
        var res = await PatchAsync<TaskResponse>($"/api/tasks/{id}", new { action = "complete" }, ct);
        return res!.Task;
    }

    public async Task<DeskTask> UncompleteAsync(string id, CancellationToken ct = default)
    {
        var res = await PatchAsync<TaskResponse>($"/api/tasks/{id}", new { action = "uncomplete" }, ct);
        return res!.Task;
    }

    public async Task<DeskTask> SetDueDateAsync(string id, DateTime? dueDate, CancellationToken ct = default)
    {
        var res = await PatchAsync<TaskResponse>($"/api/tasks/{id}", new { dueDate = dueDate?.ToUniversalTime().ToString("o") }, ct);
        return res!.Task;
    }

    public async Task<int> ClearCompletedAsync(CancellationToken ct = default)
    {
        var res = await DeleteAsync<ClearedResponse>("/api/tasks/completed", ct);
        return res?.Cleared ?? 0;
    }

    public async Task IngestAsync(string text, CancellationToken ct = default)
    {
        var res = await PostAsync<IngestResult>("/ingest", new { text, source = "manual" }, auth: false, ct);
        if (res is not { Ok: true })
            throw new InvalidOperationException(res?.Message ?? "ingest failed");
    }

    private async Task<T?> GetAsync<T>(string path, bool auth, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Get, BuildUri(path));
        if (auth) AddAuth(req);
        using var resp = await _http.SendAsync(req, ct);
        await EnsureSuccess(resp);
        return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
    }

    private async Task<T?> PostAsync<T>(string path, object body, bool auth, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, BuildUri(path))
        {
            Content = JsonContent.Create(body, options: JsonOptions)
        };
        if (auth) AddAuth(req);
        using var resp = await _http.SendAsync(req, ct);
        await EnsureSuccess(resp);
        return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
    }

    private async Task<T?> PatchAsync<T>(string path, object body, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Patch, BuildUri(path))
        {
            Content = JsonContent.Create(body, options: JsonOptions)
        };
        AddAuth(req);
        using var resp = await _http.SendAsync(req, ct);
        await EnsureSuccess(resp);
        return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
    }

    private async Task<T?> DeleteAsync<T>(string path, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Delete, BuildUri(path));
        AddAuth(req);
        using var resp = await _http.SendAsync(req, ct);
        await EnsureSuccess(resp);
        return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
    }

    private static Uri BuildUri(string path)
    {
        var baseUrl = AppSettings.ServerBaseUrl.TrimEnd('/');
        var p = path.StartsWith('/') ? path : "/" + path;
        return new Uri(baseUrl + p);
    }

    private static void AddAuth(HttpRequestMessage req)
    {
        var token = AppSettings.ApiToken.Trim();
        if (!string.IsNullOrEmpty(token))
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    private static async Task EnsureSuccess(HttpResponseMessage resp)
    {
        if (resp.IsSuccessStatusCode) return;
        var body = await resp.Content.ReadAsStringAsync();
        throw new HttpRequestException($"HTTP {(int)resp.StatusCode}: {body}");
    }

    private sealed class TasksResponse
    {
        public List<DeskTask> Tasks { get; set; } = new();
    }

    private sealed class TaskResponse
    {
        public DeskTask Task { get; set; } = new();
    }

    private sealed class ClearedResponse
    {
        public int Cleared { get; set; }
    }

    private sealed class IngestResult
    {
        public bool Ok { get; set; }
        public string? Message { get; set; }
    }
}
