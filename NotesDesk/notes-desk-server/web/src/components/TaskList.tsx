import type { DeskTask } from '../types';
import { NewTaskForm } from './NewTaskForm';

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function sourceLabel(s: string): string {
  if (s === 'dingtalk') return '钉钉';
  if (s === 'feishu') return '飞书';
  return '本地';
}

function isOverdue(task: DeskTask): boolean {
  if (task.completedAt || !task.dueDate) return false;
  return new Date(task.dueDate) < new Date();
}

interface Props {
  tasks: DeskTask[];
  selectedId: string | null;
  showCompleted: boolean;
  onToggleShowCompleted: () => void;
  onSelect: (id: string) => void;
  onComplete: (id: string) => void;
  onCreate: (text: string) => Promise<void>;
  onNewTask: () => void;
}

export function TaskList({
  tasks,
  selectedId,
  showCompleted,
  onToggleShowCompleted,
  onSelect,
  onComplete,
  onCreate,
  onNewTask,
}: Props) {
  const incomplete = tasks.filter((t) => !t.completedAt);
  const completed = tasks.filter((t) => t.completedAt);

  const renderRow = (task: DeskTask) => {
    const selected = task.id === selectedId;
    const overdue = isOverdue(task);
    return (
      <div
        key={task.id}
        role="button"
        tabIndex={0}
        onClick={() => onSelect(task.id)}
        onKeyDown={(e) => e.key === 'Enter' && onSelect(task.id)}
        className={`flex cursor-pointer items-start gap-3 border-b border-black/5 px-4 py-3 transition-colors ${
          selected ? 'bg-[#f2f2f7]' : 'hover:bg-[#fafafa]'
        }`}
      >
        <button
          type="button"
          className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${
            task.completedAt ? 'border-complete bg-complete text-white' : 'border-text-secondary/40'
          }`}
          onClick={(e) => {
            e.stopPropagation();
            onComplete(task.id);
          }}
          aria-label={task.completedAt ? '恢复' : '完成'}
        >
          {task.completedAt ? '✓' : ''}
        </button>
        <div className="min-w-0 flex-1">
          <div className={`truncate text-sm font-medium ${task.completedAt ? 'text-text-secondary line-through' : ''}`}>
            {task.text}
          </div>
          <div className="mt-1 flex flex-wrap gap-2 text-xs text-text-secondary">
            <span>{formatTime(task.createdAt)}</span>
            <span>· {sourceLabel(task.source)}</span>
            {overdue && !task.completedAt && <span className="text-overdue">逾期</span>}
            {task.dueDate && (
              <span className={overdue ? 'text-overdue' : 'text-accent'}>
                截止 {formatTime(task.dueDate)}
              </span>
            )}
          </div>
        </div>
      </div>
    );
  };

  return (
    <section className="flex h-full w-80 shrink-0 flex-col border-r border-black/5 bg-list-bg">
      <div className="flex items-center justify-between border-b border-black/5 px-4 py-3">
        <span className="text-sm font-semibold">任务</span>
        <div className="flex items-center gap-2">
          <button
            type="button"
            className="flex h-7 w-7 items-center justify-center rounded-lg bg-accent text-sm font-bold text-white hover:opacity-90"
            onClick={onNewTask}
            title="新建备忘录"
          >
            +
          </button>
          <button type="button" className="text-xs text-accent" onClick={onToggleShowCompleted}>
            {showCompleted ? '隐藏已完成' : '显示已完成'}
          </button>
        </div>
      </div>
      <NewTaskForm
        compact
        onSubmit={async (text) => {
          await onCreate(text);
        }}
      />
      <div className="flex-1 overflow-y-auto">
        {incomplete.length === 0 && completed.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-text-secondary">暂无任务</p>
        )}
        {incomplete.map(renderRow)}
        {showCompleted && completed.length > 0 && (
          <>
            <div className="bg-[#fafafa] px-4 py-2 text-xs font-medium text-text-secondary">已完成</div>
            {completed.map(renderRow)}
          </>
        )}
      </div>
    </section>
  );
}
