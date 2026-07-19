import { Router } from 'express';
import { getTaskStore } from '../../ingest/ingestHandler.js';
import { commentStore } from '../../store/commentStore.js';
import { TIMEZONE } from '../../config/paths.js';
import type { DeskTask, TaskComment } from '../../models/types.js';
import {
  weeklyStats,
  monthlyStats,
  yearlyStats,
} from '../../stats/periodStats.js';

const router = Router();

function dayKey(iso: string | null | undefined): string | null {
  if (!iso) return null;
  return new Date(iso).toLocaleDateString('en-CA', { timeZone: TIMEZONE });
}

/** Inclusive YYYY-MM-DD range on task createdAt (calendar day in TIMEZONE). */
function filterByCreatedRange(tasks: DeskTask[], from?: string, to?: string): DeskTask[] {
  const fromOk = from && /^\d{4}-\d{2}-\d{2}$/.test(from) ? from : null;
  const toOk = to && /^\d{4}-\d{2}-\d{2}$/.test(to) ? to : null;
  if (!fromOk && !toOk) return tasks;
  return tasks.filter((t) => {
    const d = dayKey(t.createdAt);
    if (!d) return false;
    if (fromOk && d < fromOk) return false;
    if (toOk && d > toOk) return false;
    return true;
  });
}

router.get('/tasks', (req, res) => {
  const format = String(req.query.format ?? 'json');
  const from = req.query.from != null ? String(req.query.from) : undefined;
  const to = req.query.to != null ? String(req.query.to) : undefined;

  if (from && !/^\d{4}-\d{2}-\d{2}$/.test(from)) {
    res.status(400).json({ error: 'from must be YYYY-MM-DD' });
    return;
  }
  if (to && !/^\d{4}-\d{2}-\d{2}$/.test(to)) {
    res.status(400).json({ error: 'to must be YYYY-MM-DD' });
    return;
  }
  if (from && to && from > to) {
    res.status(400).json({ error: 'from must be <= to' });
    return;
  }

  const tasks = filterByCreatedRange(getTaskStore().allTasks(), from, to);
  const comments = commentStore.listByTaskIds(tasks.map((t) => t.id));
  const commentsByTask = new Map<string, TaskComment[]>();
  for (const c of comments) {
    const list = commentsByTask.get(c.taskId) ?? [];
    list.push(c);
    commentsByTask.set(c.taskId, list);
  }

  if (format === 'csv') {
    const header = 'id,text,created_at,due_date,completed_at,source,comments';
    const rows = tasks.map((t) => {
      const bodies = (commentsByTask.get(t.id) ?? []).map((c) => c.body).join(' | ');
      return [
        t.id,
        csvEscape(t.text),
        t.createdAt,
        t.dueDate ?? '',
        t.completedAt ?? '',
        t.source,
        csvEscape(bodies),
      ].join(',');
    });
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    const rangeTag = [from, to].filter(Boolean).join('_') || 'all';
    res.setHeader('Content-Disposition', `attachment; filename="tasks-${rangeTag}.csv"`);
    res.send('\uFEFF' + [header, ...rows].join('\n'));
    return;
  }

  const tasksWithComments = tasks.map((t) => ({
    ...t,
    comments: commentsByTask.get(t.id) ?? [],
  }));

  res.json({
    exportedAt: new Date().toISOString(),
    timezone: TIMEZONE,
    from: from ?? null,
    to: to ?? null,
    taskCount: tasks.length,
    commentCount: comments.length,
    tasks: tasksWithComments,
    comments,
  });
});

router.get('/stats', (req, res) => {
  const period = String(req.query.period ?? 'month');
  const year = Number(req.query.year ?? new Date().getFullYear());
  const store = getTaskStore();
  let stats;
  if (period === 'week') stats = weeklyStats(store, year, Number(req.query.week ?? 1));
  else if (period === 'year') stats = yearlyStats(store, year);
  else stats = monthlyStats(store, year, Number(req.query.month ?? 1));

  if (req.query.format === 'csv') {
    const lines = Object.entries(stats).map(([k, v]) => `${k},${v}`);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.send('\uFEFF' + ['key,value', ...lines].join('\n'));
    return;
  }
  res.json({ stats });
});

function csvEscape(value: string): string {
  if (value.includes(',') || value.includes('"') || value.includes('\n')) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

export default router;
