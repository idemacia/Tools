import type Database from 'better-sqlite3';
import { getDb } from '../db/database.js';
import type { DeskTask, TaskRow } from '../models/types.js';
import { rowToTask, taskToRow, shouldRemind } from '../models/types.js';

type EventType = 'created' | 'completed' | 'uncompleted' | 'due_set' | 'due_changed' | 'reminded' | 'deleted';

export class TaskStore {
  private db: Database.Database;

  constructor(db?: Database.Database) {
    this.db = db ?? getDb();
  }

  private logEvent(taskId: string, eventType: EventType, payload?: unknown): void {
    this.db
      .prepare(
        `INSERT INTO task_events (task_id, event_type, occurred_at, payload) VALUES (?, ?, ?, ?)`,
      )
      .run(taskId, eventType, new Date().toISOString(), payload ? JSON.stringify(payload) : null);
  }

  allTasks(): DeskTask[] {
    const rows = this.db
      .prepare('SELECT * FROM tasks ORDER BY created_at ASC')
      .all() as TaskRow[];
    return rows.map(rowToTask);
  }

  incompleteTasks(): DeskTask[] {
    return this.allTasks().filter((t) => !t.completedAt);
  }

  completedTasks(limit = 50): DeskTask[] {
    return this.allTasks()
      .filter((t) => t.completedAt)
      .sort((a, b) => (b.completedAt ?? '').localeCompare(a.completedAt ?? ''))
      .slice(0, limit);
  }

  getById(id: string): DeskTask | null {
    const row = this.db.prepare('SELECT * FROM tasks WHERE id = ?').get(id) as TaskRow | undefined;
    return row ? rowToTask(row) : null;
  }

  add(task: DeskTask): DeskTask | null {
    if (this.getById(task.id)) return null;
    const row = taskToRow(task);
    this.db
      .prepare(
        `INSERT INTO tasks (id, text, created_at, due_date, completed_at, reminded_at, source, dingtalk_msg_id, dingtalk_staff_id, updated_at)
         VALUES (@id, @text, @created_at, @due_date, @completed_at, @reminded_at, @source, @dingtalk_msg_id, @dingtalk_staff_id, @updated_at)`,
      )
      .run(row);
    this.logEvent(task.id, 'created');
    return task;
  }

  update(task: DeskTask): void {
    const row = taskToRow({ ...task, updatedAt: new Date().toISOString() });
    this.db
      .prepare(
        `UPDATE tasks SET text=@text, due_date=@due_date, completed_at=@completed_at, reminded_at=@reminded_at,
         source=@source, dingtalk_msg_id=@dingtalk_msg_id, dingtalk_staff_id=@dingtalk_staff_id, updated_at=@updated_at
         WHERE id=@id`,
      )
      .run(row);
  }

  complete(taskId: string, at = new Date()): DeskTask | null {
    const task = this.getById(taskId);
    if (!task || task.completedAt) return null;
    task.completedAt = at.toISOString();
    task.updatedAt = at.toISOString();
    this.update(task);
    this.logEvent(taskId, 'completed');
    return task;
  }

  completeMatching(text: string): DeskTask | null {
    const needle = text.toLowerCase();
    const tasks = this.incompleteTasks();
    for (let i = tasks.length - 1; i >= 0; i--) {
      if (tasks[i].text.toLowerCase().includes(needle)) {
        return this.complete(tasks[i].id);
      }
    }
    return null;
  }

  completeAtIndex(index: number): DeskTask | null {
    if (index < 1) return null;
    const tasks = this.incompleteTasks();
    if (index > tasks.length) return null;
    return this.complete(tasks[index - 1].id);
  }

  uncomplete(taskId: string): DeskTask | null {
    const task = this.getById(taskId);
    if (!task || !task.completedAt) return null;
    task.completedAt = null;
    task.updatedAt = new Date().toISOString();
    this.update(task);
    this.logEvent(taskId, 'uncompleted');
    return task;
  }

  setDueDate(taskId: string, dueDate: string | null): DeskTask | null {
    const task = this.getById(taskId);
    if (!task) return null;
    const old = task.dueDate;
    task.dueDate = dueDate;
    task.remindedAt = null;
    task.updatedAt = new Date().toISOString();
    this.update(task);
    this.logEvent(taskId, old == null ? 'due_set' : 'due_changed', { old, new: dueDate });
    return task;
  }

  markReminded(taskId: string, at = new Date()): void {
    const task = this.getById(taskId);
    if (!task) return;
    task.remindedAt = at.toISOString();
    task.updatedAt = at.toISOString();
    this.update(task);
    this.logEvent(taskId, 'reminded');
  }

  clearCompleted(): number {
    const completed = this.completedTasks(10_000);
    const del = this.db.prepare('DELETE FROM tasks WHERE id = ?');
    for (const t of completed) {
      del.run(t.id);
      this.logEvent(t.id, 'deleted', { reason: 'clear_completed' });
    }
    return completed.length;
  }

  tasksNeedingReminder(delayHours: number, now = new Date()): DeskTask[] {
    return this.incompleteTasks().filter((t) => shouldRemind(t, delayHours, now));
  }

  listSummary(): string {
    const tasks = this.incompleteTasks();
    if (!tasks.length) return '暂无未完成任务';
    return tasks
      .map((task, i) => {
        let line = `#${i + 1} ${task.text}`;
        if (task.dueDate) {
          const d = new Date(task.dueDate);
          line += ` · 截止 ${d.getMonth() + 1}/${d.getDate()}`;
        }
        return line;
      })
      .join('\n');
  }

  importFromJson(tasks: DeskTask[]): number {
    let count = 0;
    for (const task of tasks) {
      if (!this.getById(task.id)) {
        this.add(task);
        count++;
      }
    }
    return count;
  }
}
