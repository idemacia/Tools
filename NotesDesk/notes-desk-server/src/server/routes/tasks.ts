import { Router } from 'express';
import { getTaskStore } from '../../ingest/ingestHandler.js';
import { commentStore } from '../../store/commentStore.js';
import type { DeskTask, MessageSource } from '../../models/types.js';
import { TIMEZONE } from '../../config/paths.js';
import { parseTaskText, splitTaskLines } from '../../parser/taskParser.js';

const router = Router();

/** Parse YYYY-MM-DD into [start, end) ISO strings in TIMEZONE. */
function dayBounds(dateStr: string): { start: string; end: string } | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return null;
  const [y, m, d] = dateStr.split('-').map(Number);
  // Build noon UTC then format in TZ to get offset-aware day start via en-CA date parts
  const probe = new Date(Date.UTC(y!, m! - 1, d!, 12, 0, 0));
  const dayInTz = probe.toLocaleDateString('en-CA', { timeZone: TIMEZONE });
  if (dayInTz !== dateStr) {
    // Fallback: treat as local calendar date in TIMEZONE using Intl offset
  }
  // Approximate: get offset at that calendar day
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: TIMEZONE,
    timeZoneName: 'longOffset',
  });
  const parts = formatter.formatToParts(probe);
  const tzName = parts.find((p) => p.type === 'timeZoneName')?.value ?? 'GMT+8';
  const match = tzName.match(/GMT([+-])(\d+)(?::(\d+))?/);
  let offsetMinutes = 8 * 60;
  if (match) {
    const sign = match[1] === '-' ? -1 : 1;
    offsetMinutes = sign * (Number(match[2]) * 60 + Number(match[3] ?? 0));
  }
  const startMs = Date.UTC(y!, m! - 1, d!, 0, 0, 0) - offsetMinutes * 60_000;
  const endMs = startMs + 24 * 60 * 60 * 1000;
  return { start: new Date(startMs).toISOString(), end: new Date(endMs).toISOString() };
}

function dayKey(iso: string | null | undefined): string | null {
  if (!iso) return null;
  return new Date(iso).toLocaleDateString('en-CA', { timeZone: TIMEZONE });
}

function filterTasks(opts: {
  view?: string;
  status?: string;
  date?: string;
  q?: string;
  includeCompleted?: boolean;
}): DeskTask[] {
  const store = getTaskStore();
  let tasks = store.allTasks();

  const q = opts.q?.trim().toLowerCase();
  // 有关键词时全库检索（正文 + 评论），忽略按日 / today / 未完成视图，避免「搜牛奶却看不到买牛奶」
  if (q) {
    const commentHits = commentStore.taskIdsMatchingBody(q);
    return tasks.filter(
      (t) => t.text.toLowerCase().includes(q) || commentHits.has(t.id),
    );
  }

  const date = opts.date?.trim();
  const isTodayView = opts.view === 'today' && !date;

  if (isTodayView) {
    const now = new Date();
    const dayStr = now.toLocaleDateString('en-CA', { timeZone: TIMEZONE });
    tasks = tasks.filter((t) => {
      const created = dayKey(t.createdAt);
      const due = dayKey(t.dueDate);
      return created === dayStr || due === dayStr;
    });
    tasks = tasks.filter((t) => !t.completedAt);
  } else if (date) {
    const bounds = dayBounds(date);
    if (bounds) {
      tasks = tasks.filter((t) => {
        const created = dayKey(t.createdAt);
        const due = dayKey(t.dueDate);
        return created === date || due === date;
      });
    }
    const includeCompleted = opts.includeCompleted !== false;
    if (!includeCompleted) {
      tasks = tasks.filter((t) => !t.completedAt);
    }
  }

  if (opts.status === 'incomplete') tasks = tasks.filter((t) => !t.completedAt);
  else if (opts.status === 'completed') tasks = tasks.filter((t) => t.completedAt);

  return tasks;
}

router.get('/', (req, res) => {
  const includeCompletedRaw = req.query.includeCompleted;
  const includeCompleted =
    includeCompletedRaw === undefined
      ? true
      : String(includeCompletedRaw) !== 'false' && String(includeCompletedRaw) !== '0';

  const tasks = filterTasks({
    view: req.query.view as string | undefined,
    status: req.query.status as string | undefined,
    date: req.query.date as string | undefined,
    q: req.query.q as string | undefined,
    includeCompleted,
  });

  const commentCounts = commentStore.countsByTaskIds(tasks.map((t) => t.id));
  res.json({ tasks, commentCounts });
});

/** Month marks: 黄=新建(createdAt)，红=未完成(created∪due)，绿=已完成(created∪due)。 */
router.get('/calendar-days', (req, res) => {
  const month = String(req.query.month ?? '');
  if (!/^\d{4}-\d{2}$/.test(month)) {
    res.status(400).json({ error: 'month=YYYY-MM required' });
    return;
  }
  const prefix = `${month}-`;
  const created: Record<string, number> = {};
  const incomplete: Record<string, number> = {};
  const completed: Record<string, number> = {};

  const bump = (map: Record<string, number>, day: string) => {
    map[day] = (map[day] ?? 0) + 1;
  };

  for (const t of getTaskStore().allTasks()) {
    const createdDay = dayKey(t.createdAt);
    const dueDay = dayKey(t.dueDate);

    if (createdDay?.startsWith(prefix)) {
      bump(created, createdDay);
    }

    const related = new Set<string>();
    if (createdDay?.startsWith(prefix)) related.add(createdDay);
    if (dueDay?.startsWith(prefix)) related.add(dueDay);

    for (const day of related) {
      if (t.completedAt) bump(completed, day);
      else bump(incomplete, day);
    }
  }

  res.json({ created, incomplete, completed });
});

router.post('/', (req, res) => {
  const store = getTaskStore();
  const body = req.body as Partial<DeskTask>;
  if (!body.text?.trim()) {
    res.status(400).json({ error: 'text required' });
    return;
  }

  const source = (body.source as MessageSource) ?? 'manual';
  const lines = splitTaskLines(body.text);
  const created: DeskTask[] = [];

  for (const line of lines) {
    const action = parseTaskText(line, source, null, body.dingtalkStaffId ?? null, new Date(), TIMEZONE);
    if (action.type === 'create') {
      const task: DeskTask = {
        ...action.task,
        id: body.id && created.length === 0 ? body.id : crypto.randomUUID(),
        createdAt: body.createdAt ?? action.task.createdAt,
        dueDate: body.dueDate ?? action.task.dueDate,
      };
      store.add(task);
      created.push(task);
    }
  }

  if (created.length === 0) {
    res.status(400).json({ error: 'no valid tasks in text' });
    return;
  }

  if (created.length === 1) {
    res.status(201).json({ task: created[0] });
    return;
  }

  res.status(201).json({ tasks: created, created: created.length });
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

// --- Comments ---

router.get('/:id/comments', (req, res) => {
  const task = getTaskStore().getById(req.params.id);
  if (!task) {
    res.status(404).json({ error: 'task not found' });
    return;
  }
  res.json({ comments: commentStore.listByTask(req.params.id) });
});

router.post('/:id/comments', (req, res) => {
  const task = getTaskStore().getById(req.params.id);
  if (!task) {
    res.status(404).json({ error: 'task not found' });
    return;
  }
  const body = String((req.body as { body?: string }).body ?? '').trim();
  if (!body) {
    res.status(400).json({ error: 'body required' });
    return;
  }
  const comment = commentStore.create(req.params.id, body);
  res.status(201).json({ comment });
});

router.patch('/:id/comments/:cid', (req, res) => {
  const task = getTaskStore().getById(req.params.id);
  if (!task) {
    res.status(404).json({ error: 'task not found' });
    return;
  }
  const existing = commentStore.getById(req.params.cid);
  if (!existing || existing.taskId !== req.params.id) {
    res.status(404).json({ error: 'comment not found' });
    return;
  }
  const body = String((req.body as { body?: string }).body ?? '').trim();
  if (!body) {
    res.status(400).json({ error: 'body required' });
    return;
  }
  const comment = commentStore.update(req.params.cid, body);
  res.json({ comment });
});

router.delete('/:id/comments/:cid', (req, res) => {
  const task = getTaskStore().getById(req.params.id);
  if (!task) {
    res.status(404).json({ error: 'task not found' });
    return;
  }
  const existing = commentStore.getById(req.params.cid);
  if (!existing || existing.taskId !== req.params.id) {
    res.status(404).json({ error: 'comment not found' });
    return;
  }
  commentStore.delete(req.params.cid);
  res.json({ ok: true });
});

export default router;
