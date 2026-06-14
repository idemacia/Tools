import { useEffect, useRef, useState } from 'react';
import { api, getToken, setToken } from '../api/client';
import type { AppSettings, DeskTask, DingTalkConfigForm, LlmConfigForm } from '../types';

interface Props {
  username: string;
  onUsernameChange: (name: string) => void;
  onLogout: () => void;
}

export function SettingsPanel({ username, onUsernameChange, onLogout }: Props) {
  const [ding, setDing] = useState<DingTalkConfigForm>({
    clientId: '',
    clientSecret: '',
    robotCode: '',
    reminderUserIds: '',
  });
  const [llm, setLlm] = useState<LlmConfigForm>({
    enabled: false,
    provider: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    apiKey: '',
    model: 'gpt-4o-mini',
    maxTokens: 2048,
    temperature: 0.3,
  });
  const [settings, setSettings] = useState<AppSettings>({
    reminderDelayHours: 1,
    remindersEnabled: true,
    showCompletedSection: true,
    analysisScheduleEnabled: true,
    analysisPushToDingTalk: true,
    weeklyAnalysisEnabled: true,
    weeklyAnalysisWeekday: 1,
    weeklyAnalysisHour: 8,
    monthlyAnalysisEnabled: true,
    monthlyAnalysisDay: 1,
    monthlyAnalysisHour: 8,
    yearlyAnalysisEnabled: true,
    yearlyAnalysisMonth: 1,
    yearlyAnalysisDay: 1,
    yearlyAnalysisHour: 8,
  });
  const [token, setTokenState] = useState(getToken());
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newUsername, setNewUsername] = useState(username);
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const importRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    void (async () => {
      try {
        const [d, l, s] = await Promise.all([api.getDingTalk(), api.getLlm(), api.getSettings()]);
        if (d.config) {
          setDing({
            clientId: d.config.clientId ?? '',
            clientSecret: '',
            robotCode: d.config.robotCode ?? '',
            reminderUserIds: Array.isArray(d.config.reminderUserIds)
              ? d.config.reminderUserIds.join(', ')
              : String(d.config.reminderUserIds ?? ''),
            hasClientSecret: d.config.hasClientSecret,
          });
        }
        setLlm({
          enabled: l.config.enabled ?? false,
          provider: l.config.provider ?? 'openai',
          baseUrl: l.config.baseUrl ?? '',
          apiKey: '',
          model: l.config.model ?? 'gpt-4o-mini',
          maxTokens: l.config.maxTokens ?? 2048,
          temperature: l.config.temperature ?? 0.3,
          hasApiKey: l.config.hasApiKey,
        });
        setSettings(s.settings);
      } catch (e) {
        setErr(e instanceof Error ? e.message : String(e));
      }
    })();
  }, []);

  const flash = (text: string, isErr = false) => {
    if (isErr) setErr(text);
    else setMsg(text);
    setTimeout(() => {
      setMsg('');
      setErr('');
    }, 3000);
  };

  const saveDing = async () => {
    try {
      const ids = ding.reminderUserIds.split(/[,，\s]+/).filter(Boolean);
      await api.saveDingTalk({
        clientId: ding.clientId,
        clientSecret: ding.clientSecret || undefined,
        robotCode: ding.robotCode,
        reminderUserIds: ids,
      });
      flash('钉钉配置已保存，桥已重启');
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const testDing = async () => {
    try {
      const r = await api.testDingTalk({
        clientId: ding.clientId,
        clientSecret: ding.clientSecret || undefined,
      });
      flash(r.message);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const saveLlm = async () => {
    try {
      await api.saveLlm({
        enabled: llm.enabled,
        provider: llm.provider,
        baseUrl: llm.baseUrl,
        apiKey: llm.apiKey || undefined,
        model: llm.model,
        maxTokens: llm.maxTokens,
        temperature: llm.temperature,
      });
      flash('AI 配置已保存');
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const testLlm = async () => {
    try {
      const r = await api.testLlm({
        baseUrl: llm.baseUrl,
        apiKey: llm.apiKey || undefined,
        model: llm.model,
      });
      flash(r.message);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const savePassword = async () => {
    try {
      const r = await api.changePassword({
        currentPassword,
        newPassword,
        newUsername: newUsername.trim() !== username ? newUsername.trim() : undefined,
      });
      onUsernameChange(r.username);
      setCurrentPassword('');
      setNewPassword('');
      flash('账号密码已更新');
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const logout = async () => {
    try {
      await api.logout();
      onLogout();
    } catch {
      onLogout();
    }
  };

  const saveReminder = async () => {
    try {
      await api.saveSettings(settings);
      flash('提醒设置已保存');
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const exportJson = async () => {
    try {
      const blob = await api.exportJsonBlob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `tasks-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      flash('JSON 已下载');
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const importJsonFile = async (file: File) => {
    try {
      const text = await file.text();
      const parsed = JSON.parse(text) as { tasks?: DeskTask[] } | DeskTask[];
      const tasks = Array.isArray(parsed) ? parsed : parsed.tasks;
      if (!tasks?.length) {
        flash('文件中没有 tasks 数组', true);
        return;
      }
      const r = await api.importTasks(tasks);
      flash(`已导入 ${r.imported} 条（共 ${r.total} 条）`);
    } catch (e) {
      flash(e instanceof Error ? e.message : String(e), true);
    }
  };

  const field = (
    label: string,
    value: string,
    onChange: (v: string) => void,
    opts?: { secret?: boolean; placeholder?: string },
  ) => (
    <label className="block">
      <span className="mb-1 block text-xs text-text-secondary">{label}</span>
      <input
        type={opts?.secret ? 'password' : 'text'}
        value={value}
        placeholder={opts?.placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-black/10 px-3 py-2 text-sm"
      />
    </label>
  );

  return (
    <div className="flex-1 overflow-y-auto bg-detail-bg p-8">
      <h2 className="mb-6 text-xl font-semibold">设置</h2>
      {msg && <p className="mb-4 text-sm text-complete">{msg}</p>}
      {err && <p className="mb-4 text-sm text-overdue">{err}</p>}

      <section className="mb-8 space-y-3 rounded-xl border border-black/5 p-5">
        <h3 className="font-medium">钉钉连接</h3>
        {field('Client ID', ding.clientId, (v) => setDing({ ...ding, clientId: v }))}
        {field('Client Secret', ding.clientSecret, (v) => setDing({ ...ding, clientSecret: v }), {
          secret: true,
          placeholder: ding.hasClientSecret ? '已保存，留空则不修改' : '',
        })}
        {field('Robot Code', ding.robotCode, (v) => setDing({ ...ding, robotCode: v }))}
        {field('提醒用户 Staff ID', ding.reminderUserIds, (v) => setDing({ ...ding, reminderUserIds: v }), {
          placeholder: '多个用英文逗号分隔',
        })}
        <div className="flex gap-2 pt-2">
          <button type="button" className="rounded-lg bg-sidebar-active px-4 py-2 text-sm" onClick={() => void testDing()}>
            测试连接
          </button>
          <button type="button" className="rounded-lg bg-accent px-4 py-2 text-sm text-white" onClick={() => void saveDing()}>
            保存并重启桥
          </button>
        </div>
      </section>

      <section className="mb-8 space-y-3 rounded-xl border border-black/5 p-5">
        <h3 className="font-medium">AI 大模型（周/月/年分析）</h3>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={llm.enabled}
            onChange={(e) => setLlm({ ...llm, enabled: e.target.checked })}
          />
          启用 AI 分析
        </label>
        {field('API Base URL', llm.baseUrl, (v) => setLlm({ ...llm, baseUrl: v }))}
        {field('API Key', llm.apiKey, (v) => setLlm({ ...llm, apiKey: v }), {
          secret: true,
          placeholder: llm.hasApiKey ? '已保存，留空则不修改' : '',
        })}
        {field('模型', llm.model, (v) => setLlm({ ...llm, model: v }))}
        <div className="flex gap-2 pt-2">
          <button type="button" className="rounded-lg bg-sidebar-active px-4 py-2 text-sm" onClick={() => void testLlm()}>
            测试连接
          </button>
          <button type="button" className="rounded-lg bg-accent px-4 py-2 text-sm text-white" onClick={() => void saveLlm()}>
            保存
          </button>
        </div>
      </section>

      <section className="mb-8 space-y-3 rounded-xl border border-black/5 p-5">
        <h3 className="font-medium">提醒</h3>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={settings.remindersEnabled}
            onChange={(e) => setSettings({ ...settings, remindersEnabled: e.target.checked })}
          />
          启用钉钉提醒
        </label>
        <label className="block text-sm">
          延迟（小时） {settings.reminderDelayHours}
          <input
            type="range"
            min={0.1}
            max={24}
            step={0.1}
            value={settings.reminderDelayHours}
            onChange={(e) =>
              setSettings({ ...settings, reminderDelayHours: Number(e.target.value) })
            }
            className="mt-2 w-full"
          />
        </label>
        <button type="button" className="rounded-lg bg-sidebar-active px-4 py-2 text-sm" onClick={() => void saveReminder()}>
          保存提醒设置
        </button>
      </section>

      <section className="mb-8 space-y-3 rounded-xl border border-black/5 p-5">
        <h3 className="font-medium">AI 分析定时与推送</h3>
        <p className="text-xs text-text-secondary">
          定时任务在服务器本地时间（Asia/Shanghai）整点检查：周分析默认每周一 8:00（上一周）、月分析每月 1 日 8:00（上一月）、年分析 1 月 1 日 8:00（上一年）。分析完成后自动推送到钉钉 reminderUserIds。
        </p>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={settings.analysisScheduleEnabled}
            onChange={(e) => setSettings({ ...settings, analysisScheduleEnabled: e.target.checked })}
          />
          启用定时 AI 分析
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={settings.analysisPushToDingTalk}
            onChange={(e) => setSettings({ ...settings, analysisPushToDingTalk: e.target.checked })}
          />
          分析完成后推送钉钉（含手动触发）
        </label>
        <div className="grid gap-3 md:grid-cols-2">
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={settings.weeklyAnalysisEnabled}
              onChange={(e) => setSettings({ ...settings, weeklyAnalysisEnabled: e.target.checked })}
            />
            周分析
          </label>
          <label className="text-sm">
            星期
            <select
              value={settings.weeklyAnalysisWeekday}
              onChange={(e) => setSettings({ ...settings, weeklyAnalysisWeekday: Number(e.target.value) })}
              className="ml-2 rounded border border-black/10 px-2 py-1"
            >
              {['日', '一', '二', '三', '四', '五', '六'].map((d, i) => (
                <option key={d} value={i}>
                  周{d}
                </option>
              ))}
            </select>
            <input
              type="number"
              min={0}
              max={23}
              value={settings.weeklyAnalysisHour}
              onChange={(e) => setSettings({ ...settings, weeklyAnalysisHour: Number(e.target.value) })}
              className="ml-2 w-16 rounded border border-black/10 px-2 py-1"
            />
            时
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={settings.monthlyAnalysisEnabled}
              onChange={(e) => setSettings({ ...settings, monthlyAnalysisEnabled: e.target.checked })}
            />
            月分析
          </label>
          <label className="text-sm">
            每月
            <input
              type="number"
              min={1}
              max={28}
              value={settings.monthlyAnalysisDay}
              onChange={(e) => setSettings({ ...settings, monthlyAnalysisDay: Number(e.target.value) })}
              className="mx-2 w-16 rounded border border-black/10 px-2 py-1"
            />
            日
            <input
              type="number"
              min={0}
              max={23}
              value={settings.monthlyAnalysisHour}
              onChange={(e) => setSettings({ ...settings, monthlyAnalysisHour: Number(e.target.value) })}
              className="ml-2 w-16 rounded border border-black/10 px-2 py-1"
            />
            时
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={settings.yearlyAnalysisEnabled}
              onChange={(e) => setSettings({ ...settings, yearlyAnalysisEnabled: e.target.checked })}
            />
            年分析
          </label>
          <label className="text-sm">
            每年
            <input
              type="number"
              min={1}
              max={12}
              value={settings.yearlyAnalysisMonth}
              onChange={(e) => setSettings({ ...settings, yearlyAnalysisMonth: Number(e.target.value) })}
              className="mx-1 w-14 rounded border border-black/10 px-2 py-1"
            />
            月
            <input
              type="number"
              min={1}
              max={28}
              value={settings.yearlyAnalysisDay}
              onChange={(e) => setSettings({ ...settings, yearlyAnalysisDay: Number(e.target.value) })}
              className="mx-1 w-14 rounded border border-black/10 px-2 py-1"
            />
            日
            <input
              type="number"
              min={0}
              max={23}
              value={settings.yearlyAnalysisHour}
              onChange={(e) => setSettings({ ...settings, yearlyAnalysisHour: Number(e.target.value) })}
              className="ml-2 w-16 rounded border border-black/10 px-2 py-1"
            />
            时
          </label>
        </div>
        <button type="button" className="rounded-lg bg-sidebar-active px-4 py-2 text-sm" onClick={() => void saveReminder()}>
          保存分析设置
        </button>
      </section>

      <section className="mb-8 space-y-3 rounded-xl border border-black/5 p-5">
        <h3 className="font-medium">数据导入 / 导出</h3>
        <p className="text-xs text-text-secondary">
          导出备份任务；从桌面版 tasks.json 导入时使用 JSON（格式为 {'{ tasks: [...] }'} 或数组）。
        </p>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className="rounded-lg bg-sidebar-active px-4 py-2 text-sm"
            onClick={() => api.exportDownload('csv')}
          >
            导出 CSV
          </button>
          <button type="button" className="rounded-lg bg-sidebar-active px-4 py-2 text-sm" onClick={() => void exportJson()}>
            导出 JSON
          </button>
          <button
            type="button"
            className="rounded-lg bg-accent px-4 py-2 text-sm text-white"
            onClick={() => importRef.current?.click()}
          >
            从 JSON 导入
          </button>
          <input
            ref={importRef}
            type="file"
            accept=".json,application/json"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void importJsonFile(f);
              e.target.value = '';
            }}
          />
        </div>
      </section>

      <section className="mb-8 space-y-3 rounded-xl border border-black/5 p-5">
        <h3 className="font-medium">账号与安全</h3>
        <p className="text-xs text-text-secondary">当前用户：{username}</p>
        {field('新用户名（可选）', newUsername, setNewUsername)}
        {field('当前密码', currentPassword, setCurrentPassword, { secret: true })}
        {field('新密码', newPassword, setNewPassword, { secret: true })}
        <div className="flex flex-wrap gap-2">
          <button type="button" className="rounded-lg bg-accent px-4 py-2 text-sm text-white" onClick={() => void savePassword()}>
            修改密码
          </button>
          <button type="button" className="rounded-lg bg-sidebar-active px-4 py-2 text-sm" onClick={() => void logout()}>
            退出登录
          </button>
        </div>
      </section>

      <section className="space-y-3 rounded-xl border border-black/5 p-5">
        <h3 className="font-medium">API Token（瘦客户端可选）</h3>
        {field('NOTESDESK_TOKEN', token, setTokenState, { placeholder: '与 Docker 环境变量一致，可选' })}
        <button
          type="button"
          className="rounded-lg bg-sidebar-active px-4 py-2 text-sm"
          onClick={() => {
            setToken(token);
            flash('Token 已保存到浏览器');
          }}
        >
          保存 Token
        </button>
      </section>
    </div>
  );
}
