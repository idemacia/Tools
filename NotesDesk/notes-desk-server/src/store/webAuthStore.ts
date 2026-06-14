import { randomBytes, scryptSync, timingSafeEqual } from 'crypto';
import { getDb } from '../db/database.js';

const USERNAME_KEY = 'web_auth_username';
const PASSWORD_HASH_KEY = 'web_auth_password_hash';
const DEFAULT_USERNAME = 'admin';
const DEFAULT_PASSWORD = 'admin';
const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;

interface SessionRow {
  id: string;
  username: string;
  created_at: string;
  expires_at: string;
}

function hashPassword(password: string): string {
  const salt = randomBytes(16).toString('hex');
  const hash = scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(':');
  if (!salt || !hash) return false;
  const expected = Buffer.from(hash, 'hex');
  const actual = scryptSync(password, salt, 64);
  if (expected.length !== actual.length) return false;
  return timingSafeEqual(expected, actual);
}

function ensureDefaults(): void {
  const db = getDb();
  const username = db.prepare('SELECT value FROM settings WHERE key = ?').get(USERNAME_KEY) as
    | { value: string }
    | undefined;
  const passwordHash = db.prepare('SELECT value FROM settings WHERE key = ?').get(PASSWORD_HASH_KEY) as
    | { value: string }
    | undefined;

  if (!username) {
    db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run(
      USERNAME_KEY,
      DEFAULT_USERNAME,
    );
  }
  if (!passwordHash) {
    db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run(
      PASSWORD_HASH_KEY,
      hashPassword(DEFAULT_PASSWORD),
    );
  }
}

export function getWebUsername(): string {
  ensureDefaults();
  const row = getDb()
    .prepare('SELECT value FROM settings WHERE key = ?')
    .get(USERNAME_KEY) as { value: string };
  return row.value;
}

export function verifyWebLogin(username: string, password: string): boolean {
  ensureDefaults();
  const db = getDb();
  const userRow = db.prepare('SELECT value FROM settings WHERE key = ?').get(USERNAME_KEY) as {
    value: string;
  };
  const hashRow = db.prepare('SELECT value FROM settings WHERE key = ?').get(PASSWORD_HASH_KEY) as {
    value: string;
  };
  if (username !== userRow.value) return false;
  return verifyPassword(password, hashRow.value);
}

export function changeWebPassword(
  currentPassword: string,
  newPassword: string,
  newUsername?: string,
): { ok: boolean; error?: string } {
  ensureDefaults();
  const db = getDb();
  const hashRow = db.prepare('SELECT value FROM settings WHERE key = ?').get(PASSWORD_HASH_KEY) as {
    value: string;
  };
  const userRow = db.prepare('SELECT value FROM settings WHERE key = ?').get(USERNAME_KEY) as {
    value: string;
  };

  if (!verifyPassword(currentPassword, hashRow.value)) {
    return { ok: false, error: '当前密码不正确' };
  }
  if (newPassword.length < 4) {
    return { ok: false, error: '新密码至少 4 个字符' };
  }

  const upsert = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  upsert.run(PASSWORD_HASH_KEY, hashPassword(newPassword));
  if (newUsername?.trim()) {
    upsert.run(USERNAME_KEY, newUsername.trim());
    if (newUsername.trim() !== userRow.value) {
      db.prepare('DELETE FROM web_sessions WHERE username = ?').run(userRow.value);
    }
  }
  return { ok: true };
}

export function createSession(username: string): string {
  ensureSessionsTable();
  const id = randomBytes(32).toString('hex');
  const now = new Date();
  const expires = new Date(now.getTime() + SESSION_TTL_MS);
  getDb()
    .prepare(
      'INSERT INTO web_sessions (id, username, created_at, expires_at) VALUES (?, ?, ?, ?)',
    )
    .run(id, username, now.toISOString(), expires.toISOString());
  return id;
}

export function resolveSession(sessionId: string | undefined): string | null {
  if (!sessionId) return null;
  ensureSessionsTable();
  purgeExpiredSessions();
  const row = getDb()
    .prepare('SELECT username, expires_at FROM web_sessions WHERE id = ?')
    .get(sessionId) as SessionRow | undefined;
  if (!row) return null;
  if (new Date(row.expires_at) <= new Date()) {
    getDb().prepare('DELETE FROM web_sessions WHERE id = ?').run(sessionId);
    return null;
  }
  return row.username;
}

export function deleteSession(sessionId: string): void {
  ensureSessionsTable();
  getDb().prepare('DELETE FROM web_sessions WHERE id = ?').run(sessionId);
}

function purgeExpiredSessions(): void {
  getDb()
    .prepare('DELETE FROM web_sessions WHERE expires_at <= ?')
    .run(new Date().toISOString());
}

function ensureSessionsTable(): void {
  getDb().exec(`
    CREATE TABLE IF NOT EXISTS web_sessions (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL,
      created_at TEXT NOT NULL,
      expires_at TEXT NOT NULL
    );
  `);
}
