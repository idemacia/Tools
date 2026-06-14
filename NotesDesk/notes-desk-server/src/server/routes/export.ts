import { Router } from 'express';
import { getTaskStore } from '../../ingest/ingestHandler.js';
import {
  dailyStats,
  weeklyStats,
  monthlyStats,
  yearlyStats,
} from '../../stats/periodStats.js';

const router = Router();

router.get('/tasks', (req, res) => {
  const format = String(req.query.format ?? 'json');
  const tasks = getTaskStore().allTasks();

  if (format === 'csv') {
    const header = 'id,text,created_at,due_date,completed_at,source';
    const rows = tasks.map((t) =>
      [t.id, csvEscape(t.text), t.createdAt, t.dueDate ?? '', t.completedAt ?? '', t.source].join(','),
    );
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename="tasks.csv"');
    // UTF-8 BOM：Excel（尤其中文版）才能正确识别中文
    res.send('\uFEFF' + [header, ...rows].join('\n'));
    return;
  }

  res.json({ tasks });
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
