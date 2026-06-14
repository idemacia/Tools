import type { Request, Response, NextFunction } from 'express';
import { NOTESDESK_TOKEN } from '../../config/paths.js';
import { resolveSession } from '../../store/webAuthStore.js';
import { SESSION_COOKIE } from '../cookies.js';

declare global {
  namespace Express {
    interface Request {
      webUser?: string;
      cookies?: Record<string, string>;
    }
  }
}

function bearerOrQueryToken(req: Request): string | undefined {
  const header = req.headers.authorization;
  if (header?.startsWith('Bearer ')) return header.slice(7);
  const q = req.query.token;
  return typeof q === 'string' ? q : undefined;
}

export function sessionMiddleware(req: Request, _res: Response, next: NextFunction): void {
  const sessionId = req.cookies?.[SESSION_COOKIE] as string | undefined;
  const username = resolveSession(sessionId);
  if (username) req.webUser = username;
  next();
}

export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  const publicPaths = ['/auth/login', '/auth/me', '/auth/logout'];
  if (publicPaths.includes(req.path)) {
    next();
    return;
  }

  if (req.webUser) {
    next();
    return;
  }

  const token = bearerOrQueryToken(req);
  if (NOTESDESK_TOKEN && token === NOTESDESK_TOKEN) {
    next();
    return;
  }

  res.status(401).json({ error: 'Unauthorized' });
}
