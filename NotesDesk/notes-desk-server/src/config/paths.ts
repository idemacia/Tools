import fs from 'node:fs';
import path from 'node:path';

const dataDir = process.env.DATA_DIR ?? path.join(process.cwd(), 'data');

export const paths = {
  dataDir,
  configDir: path.join(dataDir, 'config'),
  storeDir: path.join(dataDir, 'store'),
  backupDir: path.join(dataDir, 'backup'),
  logsDir: path.join(dataDir, 'logs'),
  dbFile: path.join(dataDir, 'store', 'notesdesk.db'),
  dingtalkConfig: path.join(dataDir, 'config', 'dingtalk.json'),
  llmConfig: path.join(dataDir, 'config', 'llm.json'),
};

export function ensureDataDirs(): void {
  for (const dir of [paths.configDir, paths.storeDir, paths.backupDir, paths.logsDir]) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

export const PORT = Number(process.env.PORT ?? 8080);
export const HOST = process.env.HOST ?? '0.0.0.0';
export const NOTESDESK_TOKEN = process.env.NOTESDESK_TOKEN ?? '';
export const TIMEZONE = process.env.TZ ?? 'Asia/Shanghai';
