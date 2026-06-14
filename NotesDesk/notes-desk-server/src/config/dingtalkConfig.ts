import fs from 'node:fs';
import { paths } from '../config/paths.js';
import type { DingTalkConfig } from '../models/types.js';

export function loadDingTalkConfig(): DingTalkConfig | null {
  if (!fs.existsSync(paths.dingtalkConfig)) return null;
  try {
    return JSON.parse(fs.readFileSync(paths.dingtalkConfig, 'utf8')) as DingTalkConfig;
  } catch {
    return null;
  }
}

export function saveDingTalkConfig(config: DingTalkConfig): void {
  fs.mkdirSync(paths.configDir, { recursive: true });
  fs.writeFileSync(paths.dingtalkConfig, JSON.stringify(config, null, 2), 'utf8');
}

export function resolvedClientId(config: DingTalkConfig): string | null {
  return config.clientId ?? config.appKey ?? null;
}

export function resolvedClientSecret(config: DingTalkConfig): string | null {
  return config.clientSecret ?? config.appSecret ?? null;
}

export function maskSecret(value: string | undefined | null): string {
  if (!value) return '';
  if (value.length <= 8) return '***';
  return `${value.slice(0, 4)}***${value.slice(-4)}`;
}

export function publicDingTalkConfig(config: DingTalkConfig | null): Record<string, unknown> | null {
  if (!config) return null;
  const secret = resolvedClientSecret(config);
  return {
    clientId: resolvedClientId(config),
    clientSecret: secret ? maskSecret(secret) : '',
    robotCode: config.robotCode ?? '',
    reminderUserIds: config.reminderUserIds ?? [],
    debug: config.debug ?? false,
    hasClientSecret: Boolean(secret),
  };
}

export async function testDingTalkConnection(clientId: string, clientSecret: string): Promise<void> {
  const response = await fetch('https://api.dingtalk.com/v1.0/oauth2/accessToken', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ appKey: clientId, appSecret: clientSecret }),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`钉钉凭证无效: ${response.status} ${body}`);
  }
  const data = (await response.json()) as { accessToken?: string };
  if (!data.accessToken) throw new Error('钉钉返回无 accessToken');
}
