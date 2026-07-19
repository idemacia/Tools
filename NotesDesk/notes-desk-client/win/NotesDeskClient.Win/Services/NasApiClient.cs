using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using NotesDeskClient.Win.Models;

namespace NotesDeskClient.Win.Services;

public sealed class NasApiClient
{
    private const string SessionCookieName = "notesdesk_session";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly HttpClient _http = new()
    {
        // 登录后自己管 Cookie，避免默认 Cookie 容器干扰
    };

    public async Task<HealthStatus> HealthAsync(CancellationToken ct = default)
    {
        return (await GetAsync<HealthStatus>("/health", auth: false, ct))!;
    }

    public async Task LoginAsync(string username, string password, CancellationToken ct = default)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, BuildUri("/api/auth/login"))
        {
            Content = JsonContent.Create(new { username, password }, options: JsonOptions)
        };
        using var resp = await _http.SendAsync(req, ct);
        var body = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException($"HTTP {(int)resp.StatusCode}: {body}");

        if (TryParseSessionFromHeaders(resp, out var sid))
        {
            AppSettings.SessionCookie = sid;
            return;
        }
        throw new HttpRequestException("登录成功但未收到 Session");
    }

    public async Task EnsureAuthenticatedAsync(CancellationToken ct = default)
    {
        if (AppSettings.HasApiAuth) return;
        var user = AppSettings.WebUsername.Trim();
        var pass = AppSettings.WebPassword;
        if (string.IsNullOrEmpty(user) || string.IsNullOrEmpty(pass))
            throw new HttpRequestException("请在设置中填写 Web 用户名/密码，或配置 API Token");
        await LoginAsync(user, pass, ct);
    }

    public async Task<TaskListResult> ListTasksAsync(
        string? view = null,
        string? status = null,
        string? date = null,
        string? q = null,
        bool? includeCompleted = null,
        CancellationToken ct = default)
    {
        var parts = new List<string>();
        if (view != null) parts.Add($"view={Uri.EscapeDataString(view)}");
        if (status != null) parts.Add($"status={Uri.EscapeDataString(status)}");
        if (date != null) parts.Add($"date={Uri.EscapeDataString(date)}");
        if (!string.IsNullOrEmpty(q)) parts.Add($"q={Uri.EscapeDataString(q)}");
        if (includeCompleted == false) parts.Add("includeCompleted=false");
        var query = parts.Count > 0 ? "?" + string.Join("&", parts) : "";
        var res = await GetAsync<TasksResponse>($"/api/tasks{query}", auth: true, ct);
        return new TaskListResult
        {
            Tasks = res?.Tasks ?? new List<DeskTask>(),
            CommentCounts = res?.CommentCounts ?? new Dictionary<string, int>()
        };
    }

    public async Task<CalendarDayMarks> CalendarDaysAsync(string month, CancellationToken ct = default)
    {
        var encoded = Uri.EscapeDataString(month);
        var res = await GetAsync<CalendarDaysResponse>($"/api/tasks/calendar-days?month={encoded}", auth: true, ct);
        return new CalendarDayMarks
        {
            Created = res?.Created ?? new Dictionary<string, int>(),
            Incomplete = res?.Incomplete ?? new Dictionary<string, int>(),
            Completed = res?.Completed ?? new Dictionary<string, int>()
        };
    }

    public async Task<List<TaskComment>> ListCommentsAsync(string taskId, CancellationToken ct = default)
    {
        var res = await GetAsync<CommentsResponse>($"/api/tasks/{taskId}/comments", auth: true, ct);
        return res?.Comments ?? new List<TaskComment>();
    }

    public async Task<TaskComment> CreateCommentAsync(string taskId, string body, CancellationToken ct = default)
    {
        var res = await PostAsync<CommentResponse>($"/api/tasks/{taskId}/comments", new { body }, auth: true, ct);
        return res!.Comment;
    }

    public async Task<TaskComment> UpdateCommentAsync(string taskId, string commentId, string body, CancellationToken ct = default)
    {
        var res = await PatchAsync<CommentResponse>($"/api/tasks/{taskId}/comments/{commentId}", new { body }, ct);
        return res!.Comment;
    }

    public async Task DeleteCommentAsync(string taskId, string commentId, CancellationToken ct = default)
    {
        await DeleteAsync<object>($"/api/tasks/{taskId}/comments/{commentId}", ct);
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
        return await SendWithAuthRetry(async () =>
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, BuildUri(path));
            if (auth) AddAuth(req);
            using var resp = await _http.SendAsync(req, ct);
            await EnsureSuccess(resp);
            return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
        }, auth, ct);
    }

    private async Task<T?> PostAsync<T>(string path, object body, bool auth, CancellationToken ct)
    {
        return await SendWithAuthRetry(async () =>
        {
            using var req = new HttpRequestMessage(HttpMethod.Post, BuildUri(path))
            {
                Content = JsonContent.Create(body, options: JsonOptions)
            };
            if (auth) AddAuth(req);
            using var resp = await _http.SendAsync(req, ct);
            await EnsureSuccess(resp);
            return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
        }, auth, ct);
    }

    private async Task<T?> PatchAsync<T>(string path, object body, CancellationToken ct)
    {
        return await SendWithAuthRetry(async () =>
        {
            using var req = new HttpRequestMessage(HttpMethod.Patch, BuildUri(path))
            {
                Content = JsonContent.Create(body, options: JsonOptions)
            };
            AddAuth(req);
            using var resp = await _http.SendAsync(req, ct);
            await EnsureSuccess(resp);
            return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
        }, auth: true, ct);
    }

    private async Task<T?> DeleteAsync<T>(string path, CancellationToken ct)
    {
        return await SendWithAuthRetry(async () =>
        {
            using var req = new HttpRequestMessage(HttpMethod.Delete, BuildUri(path));
            AddAuth(req);
            using var resp = await _http.SendAsync(req, ct);
            await EnsureSuccess(resp);
            if (resp.Content.Headers.ContentLength is 0 or null)
            {
                var text = await resp.Content.ReadAsStringAsync(ct);
                if (string.IsNullOrWhiteSpace(text)) return default;
                return JsonSerializer.Deserialize<T>(text, JsonOptions);
            }
            return await resp.Content.ReadFromJsonAsync<T>(JsonOptions, ct);
        }, auth: true, ct);
    }

    private async Task<T?> SendWithAuthRetry<T>(Func<Task<T?>> work, bool auth, CancellationToken ct)
    {
        if (!auth) return await work();
        try
        {
            await EnsureAuthenticatedAsync(ct);
            return await work();
        }
        catch (HttpRequestException ex) when (ex.Message.Contains("HTTP 401"))
        {
            AppSettings.SessionCookie = "";
            await EnsureAuthenticatedAsync(ct);
            return await work();
        }
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
        {
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            return;
        }
        var sid = AppSettings.SessionCookie.Trim();
        if (!string.IsNullOrEmpty(sid))
            req.Headers.TryAddWithoutValidation("Cookie", $"{SessionCookieName}={sid}");
    }

    private static bool TryParseSessionFromHeaders(HttpResponseMessage resp, out string sid)
    {
        sid = "";
        if (resp.Headers.TryGetValues("Set-Cookie", out var values))
        {
            foreach (var raw in values)
            {
                foreach (var part in raw.Split(';'))
                {
                    var s = part.Trim();
                    if (s.StartsWith(SessionCookieName + "=", StringComparison.OrdinalIgnoreCase))
                    {
                        sid = s[(SessionCookieName.Length + 1)..];
                        return !string.IsNullOrEmpty(sid);
                    }
                }
            }
        }
        return false;
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
        public Dictionary<string, int>? CommentCounts { get; set; }
    }

    private sealed class CalendarDaysResponse
    {
        public Dictionary<string, int>? Created { get; set; }
        public Dictionary<string, int>? Incomplete { get; set; }
        public Dictionary<string, int>? Completed { get; set; }
    }

    private sealed class CommentsResponse
    {
        public List<TaskComment> Comments { get; set; } = new();
    }

    private sealed class CommentResponse
    {
        public TaskComment Comment { get; set; } = new();
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
