import { useEffect, useRef, useState } from 'react';

interface Props {
  onSubmit: (text: string, dueDate: string | null) => Promise<void>;
  onCancel?: () => void;
  compact?: boolean;
}

export function NewTaskForm({ onSubmit, onCancel, compact = false }: Props) {
  const [text, setText] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const inputRef = useRef<HTMLTextAreaElement | HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const submit = async () => {
    const trimmed = text.trim();
    if (!trimmed) {
      setError('请输入内容');
      return;
    }
    setSaving(true);
    setError('');
    try {
      await onSubmit(trimmed, dueDate ? new Date(dueDate).toISOString() : null);
      setText('');
      setDueDate('');
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      void submit();
    }
    if (e.key === 'Escape' && onCancel) {
      onCancel();
    }
  };

  if (compact) {
    return (
      <div className="border-b border-black/5 px-3 py-2">
        <div className="flex items-center gap-2">
          <input
            ref={inputRef as React.RefObject<HTMLInputElement>}
            type="text"
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                void submit();
              }
            }}
            placeholder="新建备忘录…"
            className="min-w-0 flex-1 rounded-lg border border-black/10 px-3 py-2 text-sm outline-none focus:border-accent"
            disabled={saving}
          />
          <button
            type="button"
            onClick={() => void submit()}
            disabled={saving || !text.trim()}
            className="shrink-0 rounded-lg bg-accent px-3 py-2 text-sm font-medium text-white disabled:opacity-40"
          >
            添加
          </button>
        </div>
        {error && <p className="mt-1 text-xs text-overdue">{error}</p>}
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col bg-detail-bg p-8">
      <h2 className="mb-6 text-xl font-semibold">新建备忘录</h2>
      <label className="block">
        <span className="mb-1 block text-xs text-text-secondary">内容</span>
        <textarea
          ref={inputRef as React.RefObject<HTMLTextAreaElement>}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="输入待办事项，支持自然语言日期如「6/1 交报告」"
          rows={4}
          className="w-full resize-none rounded-xl border border-black/10 px-4 py-3 text-base outline-none focus:border-accent"
          disabled={saving}
        />
      </label>
      <label className="mt-4 block">
        <span className="mb-1 block text-xs text-text-secondary">截止日期（可选）</span>
        <input
          type="datetime-local"
          value={dueDate}
          onChange={(e) => setDueDate(e.target.value)}
          className="rounded-lg border border-black/10 px-3 py-2 text-sm"
          disabled={saving}
        />
      </label>
      {error && <p className="mt-3 text-sm text-overdue">{error}</p>}
      <div className="mt-6 flex gap-3">
        <button
          type="button"
          onClick={() => void submit()}
          disabled={saving || !text.trim()}
          className="rounded-xl bg-accent px-5 py-2.5 text-sm font-medium text-white disabled:opacity-40"
        >
          {saving ? '保存中…' : '添加'}
        </button>
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            disabled={saving}
            className="rounded-xl bg-sidebar-active px-5 py-2.5 text-sm"
          >
            取消
          </button>
        )}
      </div>
      <p className="mt-4 text-xs text-text-secondary">提示：⌘/Ctrl + Enter 快速保存</p>
    </div>
  );
}
