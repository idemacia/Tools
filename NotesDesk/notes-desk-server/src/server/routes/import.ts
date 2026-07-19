import { Router } from 'express';
import { getTaskStore } from '../../ingest/ingestHandler.js';
import { commentStore } from '../../store/commentStore.js';
import type { DeskTask, TaskComment } from '../../models/types.js';

const router = Router();

type TaskWithComments = DeskTask & { comments?: TaskComment[] };

router.post('/tasks', (req, res) => {
  const body = req.body;
  let tasks: TaskWithComments[] = [];
  let topComments: TaskComment[] = [];

  if (Array.isArray(body)) {
    tasks = body as TaskWithComments[];
  } else if (body && Array.isArray(body.tasks)) {
    tasks = body.tasks as TaskWithComments[];
    if (Array.isArray(body.comments)) {
      topComments = body.comments as TaskComment[];
    }
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

  const nestedComments: TaskComment[] = [];
  for (const t of tasks) {
    if (!Array.isArray(t.comments)) continue;
    for (const c of t.comments) {
      nestedComments.push({
        id: c.id ?? crypto.randomUUID(),
        taskId: c.taskId ?? t.id,
        body: c.body,
        createdAt: c.createdAt ?? new Date().toISOString(),
        updatedAt: c.updatedAt ?? new Date().toISOString(),
      });
    }
  }

  const allComments = [
    ...topComments.map((c) => ({
      id: c.id ?? crypto.randomUUID(),
      taskId: c.taskId,
      body: c.body,
      createdAt: c.createdAt ?? new Date().toISOString(),
      updatedAt: c.updatedAt ?? new Date().toISOString(),
    })),
    ...nestedComments,
  ];

  // Dedupe by id (prefer first)
  const seen = new Set<string>();
  let commentsImported = 0;
  for (const c of allComments) {
    if (!c.taskId || !c.body?.trim()) continue;
    if (seen.has(c.id)) continue;
    seen.add(c.id);
    // Only import if parent task exists
    if (!getTaskStore().getById(c.taskId)) continue;
    if (commentStore.importOne(c)) commentsImported++;
  }

  res.json({
    imported,
    total: normalized.length,
    commentsImported,
    commentsTotal: allComments.length,
  });
});

export default router;
