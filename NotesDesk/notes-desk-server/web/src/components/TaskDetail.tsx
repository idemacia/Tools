import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { DeskTask, TaskComment } from '../types';

interface Props {
  task: DeskTask | null;
  onComplete: (id: string, completed: boolean) => void;
  onDueDate: (id: string, dueDate: string | null) => void;
  onCommentsChanged?: () => void;
}

export function TaskDetail({ task, onComplete, onDueDate, onCommentsChanged }: Props) {
  const [dueLocal, setDueLocal] = useState('');
  const [comments, setComments] = useState<TaskComment[]>([]);
  const [draft, setDraft] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editBody, setEditBody] = useState('');
  const [msg, setMsg] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setDueLocal('');
    setDraft('');
    setEditingId(null);
    setMsg('');
    if (!task) {
      setComments([]);
      return;
    }
    void (async () => {
      try {
        const res = await api.listComments(task.id);
        setComments(res.comments);
      } catch (e) {
        setMsg(e instanceof Error ? e.message : String(e));
      }
    })();
  }, [task?.id]);

  if (!task) {
    return (
      <div className="flex flex-1 items-center justify-center bg-detail-bg text-text-secondary">
        选择一条任务
      </div>
    );
  }

  const completed = Boolean(task.completedAt);
  const dueValue = dueLocal || (task.dueDate ? task.dueDate.slice(0, 16) : '');

  const refreshComments = async () => {
    const res = await api.listComments(task.id);
    setComments(res.comments);
    onCommentsChanged?.();
  };

  const addComment = async () => {
    const body = draft.trim();
    if (!body) return;
    setLoading(true);
    setMsg('');
    try {
      await api.createComment(task.id, body);
      setDraft('');
      await refreshComments();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  };

  const saveEdit = async () => {
    if (!editingId) return;
    const body = editBody.trim();
    if (!body) return;
    setLoading(true);
    try {
      await api.updateComment(task.id, editingId, body);
      setEditingId(null);
      await refreshComments();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  };

  const removeComment = async (cid: string) => {
    setLoading(true);
    try {
      await api.deleteComment(task.id, cid);
      await refreshComments();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-1 flex-col overflow-y-auto bg-detail-bg p-8">
      <h2 className={`text-2xl font-semibold ${completed ? 'text-text-secondary line-through' : ''}`}>
        {task.text}
      </h2>
      <div className="mt-6 space-y-4 text-sm">
        <div>
          <div className="text-text-secondary">创建</div>
          <div>{new Date(task.createdAt).toLocaleString('zh-CN')}</div>
        </div>
        <div>
          <div className="mb-1 text-text-secondary">截止日期</div>
          <input
            type="datetime-local"
            value={dueValue}
            onChange={(e) => setDueLocal(e.target.value)}
            className="rounded-lg border border-black/10 px-3 py-2"
          />
          <button
            type="button"
            className="ml-2 rounded-lg bg-sidebar-active px-3 py-2 text-sm"
            onClick={() =>
              onDueDate(task.id, dueLocal ? new Date(dueLocal).toISOString() : null)
            }
          >
            保存截止
          </button>
        </div>
        <div>
          <div className="text-text-secondary">来源</div>
          <div>{task.source}</div>
        </div>
      </div>
      <div className="mt-8">
        <button
          type="button"
          className={`rounded-xl px-5 py-2.5 text-sm font-medium text-white ${
            completed ? 'bg-text-secondary' : 'bg-complete'
          }`}
          onClick={() => onComplete(task.id, !completed)}
        >
          {completed ? '恢复为未完成' : '标记完成'}
        </button>
      </div>

      <section className="mt-10 border-t border-black/5 pt-6">
        <h3 className="mb-3 text-sm font-semibold">评论 / 复盘</h3>
        {msg && <p className="mb-2 text-xs text-overdue">{msg}</p>}
        <div className="mb-4 space-y-3">
          {comments.length === 0 && (
            <p className="text-xs text-text-secondary">暂无评论，可记录完成情况或心得。</p>
          )}
          {comments.map((c) => (
            <div key={c.id} className="rounded-lg bg-sidebar-bg p-3 text-sm">
              {editingId === c.id ? (
                <div className="space-y-2">
                  <textarea
                    value={editBody}
                    onChange={(e) => setEditBody(e.target.value)}
                    rows={3}
                    className="w-full rounded border border-black/10 px-2 py-1 text-sm"
                  />
                  <div className="flex gap-2">
                    <button
                      type="button"
                      className="rounded bg-accent px-3 py-1 text-xs text-white"
                      disabled={loading}
                      onClick={() => void saveEdit()}
                    >
                      保存
                    </button>
                    <button
                      type="button"
                      className="rounded bg-sidebar-active px-3 py-1 text-xs"
                      onClick={() => setEditingId(null)}
                    >
                      取消
                    </button>
                  </div>
                </div>
              ) : (
                <>
                  <p className="whitespace-pre-wrap leading-relaxed">{c.body}</p>
                  <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-text-secondary">
                    <span>{new Date(c.createdAt).toLocaleString('zh-CN')}</span>
                    <button
                      type="button"
                      className="text-accent"
                      onClick={() => {
                        setEditingId(c.id);
                        setEditBody(c.body);
                      }}
                    >
                      编辑
                    </button>
                    <button
                      type="button"
                      className="text-overdue"
                      disabled={loading}
                      onClick={() => void removeComment(c.id)}
                    >
                      删除
                    </button>
                  </div>
                </>
              )}
            </div>
          ))}
        </div>
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          rows={3}
          placeholder="写下完成情况或复盘心得…"
          className="w-full rounded-lg border border-black/10 px-3 py-2 text-sm"
        />
        <button
          type="button"
          className="mt-2 rounded-lg bg-accent px-4 py-2 text-sm text-white disabled:opacity-50"
          disabled={loading || !draft.trim()}
          onClick={() => void addComment()}
        >
          添加评论
        </button>
      </section>
    </div>
  );
}
