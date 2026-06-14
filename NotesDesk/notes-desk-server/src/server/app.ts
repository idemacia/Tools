import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import express from 'express';
import cors from 'cors';
import { parseCookies } from './cookies.js';
import { authMiddleware, sessionMiddleware } from './middleware/auth.js';
import { handleIngest } from '../ingest/ingestHandler.js';
import { isBridgeRunning } from '../bridge/dingtalkBridge.js';
import tasksRouter from './routes/tasks.js';
import statsRouter from './routes/stats.js';
import configRouter from './routes/config.js';
import settingsRouter from './routes/settings.js';
import importRouter from './routes/import.js';
import exportRouter from './routes/export.js';
import authRouter from './routes/auth.js';

export function createApp(): express.Application {
  const app = express();
  app.use(cors({ origin: true, credentials: true }));
  app.use(express.json({ limit: '2mb' }));
  app.use((req, _res, next) => {
    (req as express.Request & { cookies?: Record<string, string> }).cookies = parseCookies(
      req.headers.cookie,
    );
    next();
  });

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      bridge: isBridgeRunning(),
      time: new Date().toISOString(),
    });
  });

  app.post('/ingest', (req, res) => {
    const result = handleIngest(req.body);
    res.status(result.ok ? 200 : 422).json(result);
  });

  app.use('/api', sessionMiddleware);
  app.use('/api/auth', authRouter);
  app.use('/api', authMiddleware);
  app.use('/api/tasks', tasksRouter);
  app.use('/api/stats', statsRouter);
  app.use('/api/config', configRouter);
  app.use('/api/settings', settingsRouter);
  app.use('/api/import', importRouter);
  app.use('/api/export', exportRouter);

  const webDist = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../web/dist');
  if (fs.existsSync(webDist)) {
    app.use(express.static(webDist));
    app.get('*', (req, res, next) => {
      if (
        req.path.startsWith('/api') ||
        req.path === '/health' ||
        req.path === '/ingest'
      ) {
        next();
        return;
      }
      res.sendFile(path.join(webDist, 'index.html'));
    });
  }

  return app;
}
