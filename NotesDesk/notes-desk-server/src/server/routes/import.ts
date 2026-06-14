import { Router } from 'express';
import { getTaskStore } from '../../ingest/ingestHandler.js';
import type { DeskTask } from '../../models/types.js';

const router = Router();

router.post('/tasks', (req, res) => {
  const body = req.body;
  let tasks: DeskTask[] = [];

  if (Array.isArray(body)) {
    tasks = body as DeskTask[];
  } else if (body && Array.isArray(body.tasks)) {
    tasks = body.tasks as DeskTask[];
  } else {
    res.status(400).json({ error: 'expected tasks array or { tasks: [] }' });
    return;
  }

  const normalized = tasks.map((t) => ({
    id: t.id ?? crypto.randomUUID(),
    text: t.text,
    createdAt: t.createdAt ?? new Date().toISOString(),
    dueDate: t.dueDate ?? null,
    completedAt: t.completedAt ?? null,
    remindedAt: t.remindedAt ?? null,
    source: t.source ?? 'manual',
    dingtalkMessageId: t.dingtalkMessageId ?? null,
    dingtalkStaffId: t.dingtalkStaffId ?? null,
    updatedAt: t.updatedAt ?? new Date().toISOString(),
  }));

  const imported = getTaskStore().importFromJson(normalized);
  res.json({ imported, total: normalized.length });
});

export default router;
