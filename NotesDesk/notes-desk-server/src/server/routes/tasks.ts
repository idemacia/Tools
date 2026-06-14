import { Router } from 'express';
import { getTaskStore } from '../../ingest/ingestHandler.js';
import type { DeskTask, MessageSource } from '../../models/types.js';
import { TIMEZONE } from '../../config/paths.js';

const router = Router();

function filterTasks(view: string | undefined, status: string | undefined) {
  const store = getTaskStore();
  let tasks = store.allTasks();

  if (status === 'incomplete') tasks = tasks.filter((t) => !t.completedAt);
  else if (status === 'completed') tasks = tasks.filter((t) => t.completedAt);

  if (view === 'today') {
    const now = new Date();
    const dayStr = now.toLocaleDateString('en-CA', { timeZone: TIMEZONE });
    tasks = tasks.filter((t) => {
      const created = new Date(t.createdAt).toLocaleDateString('en-CA', { timeZone: TIMEZONE });
      const due = t.dueDate
        ? new Date(t.dueDate).toLocaleDateString('en-CA', { timeZone: TIMEZONE })
        : null;
      return created === dayStr || due === dayStr;
    });
    tasks = tasks.filter((t) => !t.completedAt);
  }

  return tasks;
}

router.get('/', (req, res) => {
  const tasks = filterTasks(req.query.view as string, req.query.status as string);
  res.json({ tasks });
});

router.post('/', (req, res) => {
  const store = getTaskStore();
  const body = req.body as Partial<DeskTask>;
  if (!body.text?.trim()) {
    res.status(400).json({ error: 'text required' });
    return;
  }
  const now = new Date().toISOString();
  const task: DeskTask = {
    id: body.id ?? crypto.randomUUID(),
    text: body.text.trim(),
    createdAt: body.createdAt ?? now,
    dueDate: body.dueDate ?? null,
    completedAt: null,
    remindedAt: null,
    source: (body.source as MessageSource) ?? 'manual',
    dingtalkMessageId: null,
    dingtalkStaffId: body.dingtalkStaffId ?? null,
    updatedAt: now,
  };
  store.add(task);
  res.status(201).json({ task });
});

router.patch('/:id', (req, res) => {
  const store = getTaskStore();
  const { action, dueDate } = req.body as { action?: string; dueDate?: string | null };
  const id = req.params.id;

  if (action === 'complete') {
    const task = store.complete(id);
    if (!task) {
      res.status(404).json({ error: 'not found' });
      return;
    }
    res.json({ task });
    return;
  }
  if (action === 'uncomplete') {
    const task = store.uncomplete(id);
    if (!task) {
      res.status(404).json({ error: 'not found' });
      return;
    }
    res.json({ task });
    return;
  }
  if (dueDate !== undefined) {
    const task = store.setDueDate(id, dueDate);
    if (!task) {
      res.status(404).json({ error: 'not found' });
      return;
    }
    res.json({ task });
    return;
  }

  res.status(400).json({ error: 'unknown patch' });
});

router.delete('/completed', (_req, res) => {
  const count = getTaskStore().clearCompleted();
  res.json({ cleared: count });
});

export default router;
