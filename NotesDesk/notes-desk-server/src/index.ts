import { ensureDataDirs, HOST, PORT, TIMEZONE } from './config/paths.js';
import { getDb } from './db/database.js';
import { createApp } from './server/app.js';
import { startDingTalkBridge, stopDingTalkBridge } from './bridge/dingtalkBridge.js';
import { ReminderScheduler } from './reminder/scheduler.js';
import { AnalysisScheduler } from './analytics/analysisScheduler.js';

process.env.TZ = TIMEZONE;

process.on('unhandledRejection', (reason) => {
  console.error('[process] unhandledRejection (process kept alive):', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[process] uncaughtException:', err);
});

ensureDataDirs();
getDb();

const app = createApp();
const reminderScheduler = new ReminderScheduler();
const analysisScheduler = new AnalysisScheduler();

app.listen(PORT, HOST, () => {
  console.log(`[notes-desk-server] listening on http://${HOST}:${PORT}`);
  console.log(`[notes-desk-server] DATA_DIR=${process.env.DATA_DIR ?? './data'}`);
  startDingTalkBridge();
  reminderScheduler.start();
  analysisScheduler.start();
});

process.on('SIGINT', () => {
  reminderScheduler.stop();
  analysisScheduler.stop();
  stopDingTalkBridge();
  process.exit(0);
});

process.on('SIGTERM', () => {
  reminderScheduler.stop();
  analysisScheduler.stop();
  stopDingTalkBridge();
  process.exit(0);
});
