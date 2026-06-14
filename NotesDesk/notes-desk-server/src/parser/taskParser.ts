import { v4 as uuidv4 } from 'uuid';
import type { DeskTask, MessageSource, TaskIngestAction } from '../models/types.js';

function startOfDay(date: Date, timeZone: string): Date {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const y = Number(parts.find((p) => p.type === 'year')?.value);
  const m = Number(parts.find((p) => p.type === 'month')?.value);
  const d = Number(parts.find((p) => p.type === 'day')?.value);
  return new Date(Date.UTC(y, m - 1, d));
}

function dueDateFromMonthDay(
  month: number,
  day: number,
  reference: Date,
  timeZone: string,
): Date | null {
  const refStart = startOfDay(reference, timeZone);
  const y = refStart.getUTCFullYear();
  let date = new Date(Date.UTC(y, month - 1, day));
  if (date < refStart) {
    date = new Date(Date.UTC(y + 1, month - 1, day));
  }
  return date;
}

function parseDateToken(token: string, reference: Date, timeZone: string): Date | null {
  if (token.includes('/')) {
    const bits = token.split('/');
    if (bits.length !== 2) return null;
    const month = Number(bits[0]);
    const day = Number(bits[1]);
    if (!month || !day) return null;
    return dueDateFromMonthDay(month, day, reference, timeZone);
  }

  if (token.includes('-')) {
    const bits = token.split('-');
    if (bits.length === 3) {
      const year = Number(bits[0]);
      const month = Number(bits[1]);
      const day = Number(bits[2]);
      if (!year || !month || !day) return null;
      return new Date(Date.UTC(year, month - 1, day));
    }
    if (bits.length === 2) {
      const month = Number(bits[0]);
      const day = Number(bits[1]);
      if (!month || !day) return null;
      return dueDateFromMonthDay(month, day, reference, timeZone);
    }
  }

  return null;
}

function parseDuePrefix(
  text: string,
  reference: Date,
  timeZone: string,
): { dueDate: Date; text: string } | null {
  const spaceIdx = text.indexOf(' ');
  if (spaceIdx <= 0) return null;
  const dateToken = text.slice(0, spaceIdx);
  const body = text.slice(spaceIdx + 1).trim();
  const dueDate = parseDateToken(dateToken, reference, timeZone);
  if (!dueDate || !body) return null;
  return { dueDate, text: body };
}

export function parseTaskText(
  text: string,
  source: MessageSource,
  messageId: string | null,
  staffId: string | null,
  receivedAt: Date,
  timeZone: string,
): TaskIngestAction {
  const trimmed = text.trim();
  if (!trimmed) return { type: 'noop', reason: '空消息' };

  if (trimmed === '列表') {
    return { type: 'list', summary: '' };
  }

  if (trimmed.startsWith('完成')) {
    const remainder = trimmed.slice(2).trim();
    if (remainder.startsWith('#')) {
      const indexText = remainder.slice(1).trim();
      const index = Number(indexText);
      if (index > 0) {
        return { type: 'complete', taskId: `index:${index}`, text: trimmed };
      }
      return { type: 'noop', reason: '无效的完成编号' };
    }
    if (!remainder) return { type: 'noop', reason: '缺少完成目标' };
    return { type: 'complete', taskId: `text:${remainder}`, text: trimmed };
  }

  if (trimmed.startsWith('截止')) {
    const remainder = trimmed.slice(2).trim();
    const parsed = parseDuePrefix(remainder, receivedAt, timeZone);
    if (parsed) {
      const now = receivedAt.toISOString();
      const task: DeskTask = {
        id: messageId ?? uuidv4(),
        text: parsed.text,
        createdAt: now,
        dueDate: parsed.dueDate.toISOString(),
        completedAt: null,
        remindedAt: null,
        source,
        dingtalkMessageId: source === 'dingtalk' ? messageId : null,
        dingtalkStaffId: staffId,
        updatedAt: now,
      };
      return { type: 'create', task };
    }
  }

  const now = receivedAt.toISOString();
  const task: DeskTask = {
    id: messageId ?? uuidv4(),
    text: trimmed,
    createdAt: now,
    dueDate: null,
    completedAt: null,
    remindedAt: null,
    source,
    dingtalkMessageId: source === 'dingtalk' ? messageId : null,
    dingtalkStaffId: staffId,
    updatedAt: now,
  };
  return { type: 'create', task };
}
