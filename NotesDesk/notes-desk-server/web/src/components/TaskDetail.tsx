import { useState } from 'react';
import type { DeskTask } from '../types';

interface Props {
  task: DeskTask | null;
  onComplete: (id: string, completed: boolean) => void;
  onDueDate: (id: string, dueDate: string | null) => void;
}

export function TaskDetail({ task, onComplete, onDueDate }: Props) {
  const [dueLocal, setDueLocal] = useState('');

  if (!task) {
    return (
      <div className="flex flex-1 items-center justify-center bg-detail-bg text-text-secondary">
        选择一条任务
      </div>
    );
  }

  const completed = Boolean(task.completedAt);
  const dueValue = dueLocal || (task.dueDate ? task.dueDate.slice(0, 16) : '');

  return (
    <div className="flex flex-1 flex-col bg-detail-bg p-8">
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
    </div>
  );
}
