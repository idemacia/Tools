import { Router } from 'express';
import {
  changeWebPassword,
  createSession,
  deleteSession,
  getWebUsername,
  verifyWebLogin,
} from '../../store/webAuthStore.js';
import { SESSION_COOKIE } from '../cookies.js';
const router = Router();

const SESSION_MAX_AGE_SEC = 7 * 24 * 60 * 60;

function setSessionCookie(res: import('express').Response, sessionId: string): void {
  res.cookie(SESSION_COOKIE, sessionId, {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: SESSION_MAX_AGE_SEC * 1000,
    path: '/',
  });
}

router.post('/login', (req, res) => {
  const { username, password } = req.body as { username?: string; password?: string };
  if (!username || !password) {
    res.status(400).json({ error: '请输入用户名和密码' });
    return;
  }
  if (!verifyWebLogin(username, password)) {
    res.status(401).json({ error: '用户名或密码错误' });
    return;
  }
  const sessionId = createSession(username);
  setSessionCookie(res, sessionId);
  res.json({ ok: true, username });
});

router.post('/logout', (req, res) => {
  const sessionId = req.cookies?.[SESSION_COOKIE] as string | undefined;
  if (sessionId) deleteSession(sessionId);
  res.clearCookie(SESSION_COOKIE, { path: '/' });
  res.json({ ok: true });
});

router.get('/me', (req, res) => {
  if (!req.webUser) {
    res.status(401).json({ error: '未登录' });
    return;
  }
  res.json({ username: req.webUser });
});

router.post('/change-password', (req, res) => {
  if (!req.webUser) {
    res.status(401).json({ error: '未登录' });
    return;
  }
  const { currentPassword, newPassword, newUsername } = req.body as {
    currentPassword?: string;
    newPassword?: string;
    newUsername?: string;
  };
  if (!currentPassword || !newPassword) {
    res.status(400).json({ error: '请填写当前密码和新密码' });
    return;
  }
  const result = changeWebPassword(currentPassword, newPassword, newUsername);
  if (!result.ok) {
    res.status(400).json({ error: result.error ?? '修改失败' });
    return;
  }
  res.json({ ok: true, username: getWebUsername() });
});

export default router;
