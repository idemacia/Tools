import { v4 as uuidv4 } from 'uuid';
import type Database from 'better-sqlite3';
import { getDb } from '../db/database.js';
import type { TaskComment, TaskCommentRow } from '../models/types.js';
import { rowToComment } from '../models/types.js';

export class CommentStore {
  private db: Database.Database;

  constructor(db?: Database.Database) {
    this.db = db ?? getDb();
  }

  listByTask(taskId: string): TaskComment[] {
    const rows = this.db
      .prepare(
        `SELECT * FROM task_comments WHERE task_id = ? ORDER BY created_at ASC`,
      )
      .all(taskId) as TaskCommentRow[];
    return rows.map(rowToComment);
  }

  listByTaskIds(taskIds: string[]): TaskComment[] {
    if (taskIds.length === 0) return [];
    const placeholders = taskIds.map(() => '?').join(',');
    const rows = this.db
      .prepare(
        `SELECT * FROM task_comments WHERE task_id IN (${placeholders})
         ORDER BY created_at ASC`,
      )
      .all(...taskIds) as TaskCommentRow[];
    return rows.map(rowToComment);
  }

  /** Insert comment if id is new; returns whether inserted. */
  importOne(comment: TaskComment): boolean {
    if (this.getById(comment.id)) return false;
    this.db
      .prepare(
        `INSERT INTO task_comments (id, task_id, body, created_at, updated_at)
         VALUES (@id, @task_id, @body, @created_at, @updated_at)`,
      )
      .run({
        id: comment.id,
        task_id: comment.taskId,
        body: comment.body,
        created_at: comment.createdAt,
        updated_at: comment.updatedAt,
      });
    return true;
  }

  getById(id: string): TaskComment | null {
    const row = this.db.prepare('SELECT * FROM task_comments WHERE id = ?').get(id) as
      | TaskCommentRow
      | undefined;
    return row ? rowToComment(row) : null;
  }

  create(taskId: string, body: string): TaskComment {
    const now = new Date().toISOString();
    const comment: TaskComment = {
      id: uuidv4(),
      taskId,
      body,
      createdAt: now,
      updatedAt: now,
    };
    this.db
      .prepare(
        `INSERT INTO task_comments (id, task_id, body, created_at, updated_at)
         VALUES (@id, @task_id, @body, @created_at, @updated_at)`,
      )
      .run({
        id: comment.id,
        task_id: comment.taskId,
        body: comment.body,
        created_at: comment.createdAt,
        updated_at: comment.updatedAt,
      });
    return comment;
  }

  update(id: string, body: string): TaskComment | null {
    const existing = this.getById(id);
    if (!existing) return null;
    const updatedAt = new Date().toISOString();
    this.db
      .prepare(`UPDATE task_comments SET body = ?, updated_at = ? WHERE id = ?`)
      .run(body, updatedAt, id);
    return { ...existing, body, updatedAt };
  }

  delete(id: string): boolean {
    const result = this.db.prepare('DELETE FROM task_comments WHERE id = ?').run(id);
    return result.changes > 0;
  }

  countsByTaskIds(taskIds: string[]): Record<string, number> {
    if (taskIds.length === 0) return {};
    const placeholders = taskIds.map(() => '?').join(',');
    const rows = this.db
      .prepare(
        `SELECT task_id, COUNT(*) AS cnt FROM task_comments
         WHERE task_id IN (${placeholders})
         GROUP BY task_id`,
      )
      .all(...taskIds) as Array<{ task_id: string; cnt: number }>;
    const out: Record<string, number> = {};
    for (const row of rows) out[row.task_id] = row.cnt;
    return out;
  }

  /** task IDs whose comment body contains needle (case-insensitive). */
  taskIdsMatchingBody(needle: string): Set<string> {
    const q = needle.trim().toLowerCase();
    if (!q) return new Set();
    const rows = this.db
      .prepare(`SELECT DISTINCT task_id, body FROM task_comments`)
      .all() as Array<{ task_id: string; body: string }>;
    const hit = new Set<string>();
    for (const row of rows) {
      if (row.body.toLowerCase().includes(q)) hit.add(row.task_id);
    }
    return hit;
  }
}

export const commentStore = new CommentStore();
