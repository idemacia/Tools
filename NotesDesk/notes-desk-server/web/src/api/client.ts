import type {
  AnalysisResult,
  AppSettings,
  DeskTask,
  DingTalkConfigForm,
  LlmConfigForm,
  TaskPeriodStats,
} from '../types';

const TOKEN_KEY = 'notesdesk_token';

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) ?? '';
}

export function setToken(token: string): void {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init?.headers as Record<string, string> | undefined),
  };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(path, { ...init, headers, credentials: 'include' });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error((err as { error?: string }).error ?? res.statusText);
  }
  return res.json() as Promise<T>;
}

export const api = {
  login: (username: string, password: string) =>
    request<{ ok: boolean; username: string }>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),

  logout: () => request<{ ok: boolean }>('/api/auth/logout', { method: 'POST' }),

  me: () => request<{ username: string }>('/api/auth/me'),

  changePassword: (body: {
    currentPassword: string;
    newPassword: string;
    newUsername?: string;
  }) =>
    request<{ ok: boolean; username: string }>('/api/auth/change-password', {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  health: () =>
    fetch('/health', { credentials: 'include' }).then((r) => r.json()) as Promise<{
      ok: boolean;
      bridge: boolean;
    }>,

  listTasks: (view?: string, status?: string) => {
    const q = new URLSearchParams();
    if (view) q.set('view', view);
    if (status) q.set('status', status);
    const qs = q.toString();
    return request<{ tasks: DeskTask[] }>(`/api/tasks${qs ? `?${qs}` : ''}`);
  },

  patchTask: (id: string, body: { action?: string; dueDate?: string | null }) =>
    request<{ task: DeskTask }>(`/api/tasks/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),

  createTask: (body: { text: string; dueDate?: string | null }) =>
    request<{ task: DeskTask }>('/api/tasks', {
      method: 'POST',
      body: JSON.stringify({ ...body, source: 'manual' }),
    }),

  ingest: (text: string) =>
    fetch('/ingest', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, source: 'manual' }),
    }).then(async (res) => {
      const data = (await res.json()) as { ok: boolean; taskId?: string; message?: string };
      if (!res.ok) throw new Error(data.message ?? res.statusText);
      return data;
    }),

  getStats: (period: string, year: number, week?: number, month?: number) => {
    const q = new URLSearchParams({ year: String(year) });
    if (week != null) q.set('week', String(week));
    if (month != null) q.set('month', String(month));
    const path =
      period === 'month'
        ? `/api/stats/monthly?${q}`
        : period === 'year'
          ? `/api/stats/yearly?${q}`
          : `/api/stats/weekly?${q}`;
    return request<{ stats: TaskPeriodStats }>(path);
  },

  getSettings: () => request<{ settings: AppSettings }>('/api/settings'),

  saveSettings: (settings: Partial<AppSettings>) =>
    request<{ settings: AppSettings }>('/api/settings', {
      method: 'PUT',
      body: JSON.stringify(settings),
    }),

  getDingTalk: () =>
    request<{ config: (DingTalkConfigForm & { reminderUserIds?: string[] }) | null }>(
      '/api/config/dingtalk',
    ),

  saveDingTalk: (config: Record<string, unknown>) =>
    request('/api/config/dingtalk', { method: 'PUT', body: JSON.stringify(config) }),

  testDingTalk: (config: Record<string, unknown>) =>
    request<{ ok: boolean; message: string }>('/api/config/dingtalk/test', {
      method: 'POST',
      body: JSON.stringify(config),
    }),

  getLlm: () => request<{ config: LlmConfigForm }>('/api/config/llm'),

  saveLlm: (config: Record<string, unknown>) =>
    request('/api/config/llm', { method: 'PUT', body: JSON.stringify(config) }),

  testLlm: (config: Record<string, unknown>) =>
    request<{ ok: boolean; message: string }>('/api/config/llm/test', {
      method: 'POST',
      body: JSON.stringify(config),
    }),

  analyze: (body: { period: string; year: number; week?: number; month?: number }) =>
    request<{
      stats: TaskPeriodStats;
      analysis: AnalysisResult;
      periodLabel: string;
      pushed: boolean;
    }>('/api/stats/analyze', {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  exportDownload: (format: 'csv' | 'json') => {
    const token = getToken();
    const qs = new URLSearchParams({ format });
    if (token) qs.set('token', token);
    window.open(`/api/export/tasks?${qs}`, '_blank');
  },

  exportJsonBlob: async (): Promise<Blob> => {
    const token = getToken();
    const headers: Record<string, string> = {};
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await fetch('/api/export/tasks', { headers, credentials: 'include' });
    if (!res.ok) throw new Error('导出失败');
    const data = await res.json();
    return new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  },

  importTasks: (tasks: DeskTask[]) =>
    request<{ imported: number; total: number }>('/api/import/tasks', {
      method: 'POST',
      body: JSON.stringify({ tasks }),
    }),
};
