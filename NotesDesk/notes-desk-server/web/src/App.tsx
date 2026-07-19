import { useCallback, useEffect, useState } from 'react';
import { api } from './api/client';
import { Sidebar } from './components/Sidebar';
import { TaskList } from './components/TaskList';
import { TaskDetail } from './components/TaskDetail';
import { NewTaskForm } from './components/NewTaskForm';
import { StatsPanel } from './components/StatsPanel';
import { SettingsPanel } from './components/SettingsPanel';
import { LoginPage } from './components/LoginPage';
import type { DeskTask, ViewMode } from './types';

function todayStr(): string {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
}

export default function App() {
  const [authUser, setAuthUser] = useState<string | null>(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [view, setView] = useState<ViewMode>('incomplete');
  const [tasks, setTasks] = useState<DeskTask[]>([]);
  const [commentCounts, setCommentCounts] = useState<Record<string, number>>({});
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [showCompleted, setShowCompleted] = useState(true);
  const [bridge, setBridge] = useState(false);
  const [creating, setCreating] = useState(false);
  const [filterDate, setFilterDate] = useState('');
  const [searchQ, setSearchQ] = useState('');
  const [searchDraft, setSearchDraft] = useState('');

  useEffect(() => {
    void api
      .me()
      .then((r) => setAuthUser(r.username))
      .catch(() => setAuthUser(null))
      .finally(() => setAuthLoading(false));
  }, []);

  const loadTasks = useCallback(async () => {
    const q = searchQ.trim() || undefined;

    // 有搜索词：全库（含已完成），不叠加日期/视图过滤
    if (q) {
      const res = await api.listTasks({ q, includeCompleted: true });
      setTasks(res.tasks);
      setCommentCounts(res.commentCounts ?? {});
      setSelectedId((prev) => {
        if (prev && res.tasks.some((t) => t.id === prev)) return prev;
        return res.tasks[0]?.id ?? null;
      });
      return;
    }

    if (filterDate) {
      const res = await api.listTasks({
        date: filterDate,
        includeCompleted: true,
      });
      setTasks(res.tasks);
      setCommentCounts(res.commentCounts ?? {});
      setSelectedId((prev) => {
        if (prev && res.tasks.some((t) => t.id === prev)) return prev;
        return res.tasks[0]?.id ?? null;
      });
      return;
    }

    const viewParam = view === 'today' ? 'today' : undefined;
    const status =
      view === 'completed'
        ? 'completed'
        : view === 'incomplete' || view === 'today'
          ? 'incomplete'
          : undefined;
    const res = await api.listTasks({
      view: viewParam,
      status,
    });
    setTasks(res.tasks);
    setCommentCounts(res.commentCounts ?? {});
    setSelectedId((prev) => {
      if (prev && res.tasks.some((t) => t.id === prev)) return prev;
      return res.tasks[0]?.id ?? null;
    });
  }, [view, filterDate, searchQ]);

  // 输入即搜（防抖 250ms）
  useEffect(() => {
    const t = setTimeout(() => setSearchQ(searchDraft.trim()), 250);
    return () => clearTimeout(t);
  }, [searchDraft]);

  useEffect(() => {
    if (!authUser) return;
    void api.health().then((h) => setBridge(h.bridge)).catch(() => setBridge(false));
  }, [authUser]);

  useEffect(() => {
    if (!authUser || view === 'stats' || view === 'settings') return;
    void loadTasks();
    const t = setInterval(() => void loadTasks(), 5000);
    return () => clearInterval(t);
  }, [view, loadTasks, authUser]);

  if (authLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-detail-bg text-text-secondary">
        加载中…
      </div>
    );
  }

  if (!authUser) {
    return <LoginPage onSuccess={setAuthUser} />;
  }

  const selected = tasks.find((t) => t.id === selectedId) ?? null;
  const incompleteCount = tasks.filter((t) => !t.completedAt).length;

  const toggleComplete = async (id: string) => {
    const task = tasks.find((t) => t.id === id);
    if (!task) return;
    await api.patchTask(id, { action: task.completedAt ? 'uncomplete' : 'complete' });
    await loadTasks();
  };

  const setDueDate = async (id: string, dueDate: string | null) => {
    await api.patchTask(id, { dueDate });
    await loadTasks();
  };

  const createTask = async (text: string, dueDate: string | null = null) => {
    let taskId: string | undefined;
    if (dueDate) {
      const res = await api.createTask({ text, dueDate });
      taskId = res.task.id;
    } else {
      const res = await api.ingest(text);
      if (!res.ok) throw new Error(res.message ?? '创建失败');
      taskId = res.taskId;
    }
    setCreating(false);
    await loadTasks();
    if (taskId) setSelectedId(taskId);
  };

  return (
    <div className="flex h-full min-h-screen">
      <Sidebar
        view={view}
        onChange={(v) => {
          setFilterDate('');
          setView(v);
        }}
        bridge={bridge}
        incompleteCount={incompleteCount}
      />
      {view === 'stats' ? (
        <StatsPanel />
      ) : view === 'settings' ? (
        <SettingsPanel username={authUser} onUsernameChange={setAuthUser} onLogout={() => setAuthUser(null)} />
      ) : (
        <>
          <TaskList
            tasks={tasks}
            commentCounts={commentCounts}
            selectedId={selectedId}
            showCompleted={showCompleted}
            filterDate={filterDate}
            searchDraft={searchDraft}
            onFilterDateChange={setFilterDate}
            onSearchDraftChange={setSearchDraft}
            onSearchSubmit={() => setSearchQ(searchDraft.trim())}
            onClearSearch={() => {
              setSearchDraft('');
              setSearchQ('');
            }}
            onToday={() => setFilterDate(todayStr())}
            onClearDate={() => setFilterDate('')}
            onToggleShowCompleted={() => setShowCompleted((v) => !v)}
            onSelect={(id) => {
              setCreating(false);
              setSelectedId(id);
            }}
            onComplete={toggleComplete}
            onCreate={(text) => createTask(text)}
            onNewTask={() => {
              setCreating(true);
              setSelectedId(null);
            }}
          />
          {creating ? (
            <NewTaskForm onSubmit={createTask} onCancel={() => setCreating(false)} />
          ) : (
            <TaskDetail
              task={selected}
              onComplete={(id, completed) =>
                void api.patchTask(id, { action: completed ? 'complete' : 'uncomplete' }).then(loadTasks)
              }
              onDueDate={(id, due) => void setDueDate(id, due)}
              onCommentsChanged={() => void loadTasks()}
            />
          )}
        </>
      )}
    </div>
  );
}
