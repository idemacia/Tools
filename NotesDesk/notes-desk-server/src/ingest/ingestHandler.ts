import { parseTaskText, splitTaskLines } from '../parser/taskParser.js';
import type { IngestPayload, MessageSource } from '../models/types.js';
import { TaskStore } from '../store/taskStore.js';
import { TIMEZONE } from '../config/paths.js';

const store = new TaskStore();

export interface IngestResult {
  ok: boolean;
  action: string;
  message?: string;
  taskId?: string;
  /** 批量创建时的任务 ID */
  taskIds?: string[];
  /** 批量创建数量 */
  created?: number;
}

function applyAction(
  action: ReturnType<typeof parseTaskText>,
): { ok: boolean; action: string; message?: string; taskId?: string } {
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

export function handleIngest(payload: IngestPayload): IngestResult {
  const trimmed = payload.text?.trim();
  if (!trimmed) return { ok: false, action: 'noop', message: 'empty' };

  const source = (payload.source ?? 'manual') as MessageSource;
  const receivedAt = payload.receivedAt ? new Date(payload.receivedAt) : new Date();
  const staffId = payload.senderStaffId ?? payload.senderName ?? null;
  const lines = splitTaskLines(trimmed);

  if (lines.length <= 1) {
    const action = parseTaskText(
      lines[0] ?? trimmed,
      source,
      payload.id ?? null,
      staffId,
      receivedAt,
      TIMEZONE,
    );
    return applyAction(action);
  }

  const createdIds: string[] = [];
  const createdTexts: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!;
    const action = parseTaskText(
      line,
      source,
      payload.id && i === 0 ? payload.id : null,
      staffId,
      receivedAt,
      TIMEZONE,
    );
    if (action.type !== 'create') {
      return {
        ok: false,
        action: 'noop',
        message: `第 ${i + 1} 行不是有效待办：${line}`,
      };
    }
    store.add(action.task);
    createdIds.push(action.task.id);
    createdTexts.push(action.task.text);
  }

  return {
    ok: true,
    action: 'create_batch',
    created: createdIds.length,
    taskIds: createdIds,
    taskId: createdIds[0],
    message: `已添加 ${createdIds.length} 条：${createdTexts.join('、')}`,
  };
}

export function getTaskStore(): TaskStore {
  return store;
}
