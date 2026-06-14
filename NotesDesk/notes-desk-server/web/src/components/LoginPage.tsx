import { useState } from 'react';
import { api } from '../api/client';

interface Props {
  onSuccess: (username: string) => void;
}

export function LoginPage({ onSuccess }: Props) {
  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const res = await api.login(username, password);
      onSuccess(res.username);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-sidebar-bg p-6">
      <form
        onSubmit={(e) => void submit(e)}
        className="w-full max-w-sm space-y-4 rounded-2xl border border-black/5 bg-detail-bg p-8 shadow-sm"
      >
        <div>
          <h1 className="text-xl font-semibold">NotesDesk</h1>
          <p className="mt-1 text-sm text-text-secondary">登录后查看与管理待办</p>
        </div>
        {error && <p className="text-sm text-overdue">{error}</p>}
        <label className="block text-sm">
          <span className="mb-1 block text-text-secondary">用户名</span>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="w-full rounded-lg border border-black/10 px-3 py-2"
            autoComplete="username"
          />
        </label>
        <label className="block text-sm">
          <span className="mb-1 block text-text-secondary">密码</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-lg border border-black/10 px-3 py-2"
            autoComplete="current-password"
          />
        </label>
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-lg bg-accent py-2.5 text-sm text-white disabled:opacity-50"
        >
          {loading ? '登录中…' : '登录'}
        </button>
        <p className="text-center text-xs text-text-secondary">默认账号 admin / admin，登录后请在设置中修改</p>
      </form>
    </div>
  );
}
