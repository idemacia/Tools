import { parseTaskText } from '../parser/taskParser.js';
import type { IngestPayload, MessageSource } from '../models/types.js';
import { TaskStore } from '../store/taskStore.js';
import { TIMEZONE } from '../config/paths.js';

const store = new TaskStore();

export interface IngestResult {
  ok: boolean;
  action: string;
  message?: string;
  taskId?: string;
}

export function handleIngest(payload: IngestPayload): IngestResult {
  const trimmed = payload.text?.trim();
  if (!trimmed) return { ok: false, action: 'noop', message: 'empty' };

  const source = (payload.source ?? 'manual') as MessageSource;
  const receivedAt = payload.receivedAt ? new Date(payload.receivedAt) : new Date();
  const staffId = payload.senderStaffId ?? payload.senderName ?? null;

  const action = parseTaskText(
    trimmed,
    source,
    payload.id ?? null,
    staffId,
    receivedAt,
    TIMEZONE,
  );

  switch (action.type) {
    case 'create': {
      store.add(action.task);
      return { ok: true, action: 'create', taskId: action.task.id, message: action.task.text };
    }
    case 'complete': {
      if (action.taskId.startsWith('index:')) {
        const index = Number(action.taskId.slice('index:'.length));
        const task = store.completeAtIndex(index);
        return task
          ? { ok: true, action: 'complete', taskId: task.id, message: task.text }
          : { ok: false, action: 'complete', message: `未找到 #${index}` };
      }
      if (action.taskId.startsWith('text:')) {
        const target = action.taskId.slice('text:'.length);
        const task = store.completeMatching(target);
        return task
          ? { ok: true, action: 'complete', taskId: task.id, message: task.text }
          : { ok: false, action: 'complete', message: `未找到「${target}」` };
      }
      return { ok: false, action: 'complete', message: 'invalid' };
    }
    case 'list': {
      const summary = store.listSummary();
      return { ok: true, action: 'list', message: summary || '暂无未完成任务' };
    }
    case 'noop':
      return { ok: false, action: 'noop', message: action.reason };
    default:
      return { ok: false, action: 'unknown' };
  }
}

export function getTaskStore(): TaskStore {
  return store;
}
