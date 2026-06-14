import type { DeskTask, DingTalkConfig } from '../models/types.js';
import {
  loadDingTalkConfig,
  resolvedClientId,
  resolvedClientSecret,
} from '../config/dingtalkConfig.js';

export type ConfigStatus =
  | 'ready'
  | 'missingCredentials'
  | 'missingRobotCode'
  | 'missingRecipients';

export function validateConfig(task?: DeskTask): ConfigStatus {
  const config = loadDingTalkConfig();
  if (!config) return 'missingCredentials';
  const clientId = resolvedClientId(config);
  const clientSecret = resolvedClientSecret(config);
  if (!clientId || !clientSecret) return 'missingCredentials';
  if (!config.robotCode) return 'missingRobotCode';
  if (task) {
    const ids = resolvedUserIds(task, config);
    if (!ids.length) return 'missingRecipients';
  }
  return 'ready';
}

function resolvedUserIds(task: DeskTask, config: DingTalkConfig): string[] {
  if (task.dingtalkStaffId) return [task.dingtalkStaffId];
  return config.reminderUserIds ?? [];
}

function formatDelay(hours: number): string {
  if (hours < 1) {
    const minutes = Math.max(1, Math.round(hours * 60));
    return `${minutes} 分钟`;
  }
  if (hours % 1 === 0) return `${hours} 小时`;
  return `${hours.toFixed(1)} 小时`;
}

async function fetchAccessToken(clientId: string, clientSecret: string): Promise<string> {
  const response = await fetch('https://api.dingtalk.com/v1.0/oauth2/accessToken', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ appKey: clientId, appSecret: clientSecret }),
  });
  if (!response.ok) throw new Error(`accessToken ${response.status}`);
  const data = (await response.json()) as { accessToken?: string };
  if (!data.accessToken) throw new Error('no accessToken');
  return data.accessToken;
}

async function batchSend(
  accessToken: string,
  robotCode: string,
  userIds: string[],
  content: string,
): Promise<void> {
  const response = await fetch('https://api.dingtalk.com/v1.0/robot/oToMessages/batchSend', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-acs-dingtalk-access-token': accessToken,
    },
    body: JSON.stringify({
      robotCode,
      userIds,
      msgKey: 'sampleText',
      msgParam: JSON.stringify({ content }),
    }),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`batchSend failed: ${body}`);
  }
}

let lastLoggedStatus: ConfigStatus | null = null;

/** 向配置的 reminderUserIds 发送文本（分析报告、通知等） */
export async function sendDingTalkText(content: string): Promise<boolean> {
  const config = loadDingTalkConfig();
  if (!config) return false;
  const clientId = resolvedClientId(config);
  const clientSecret = resolvedClientSecret(config);
  if (!clientId || !clientSecret || !config.robotCode) return false;

  const userIds = config.reminderUserIds ?? [];
  if (!userIds.length) {
    if (lastLoggedStatus !== 'missingRecipients') {
      lastLoggedStatus = 'missingRecipients';
      console.warn('[dingtalk] no reminderUserIds for push');
    }
    return false;
  }

  try {
    const token = await fetchAccessToken(clientId, clientSecret);
    await batchSend(token, config.robotCode, userIds, content);
    return true;
  } catch (err) {
    console.error('[dingtalk] send text failed:', err);
    return false;
  }
}

export async function sendReminder(task: DeskTask, delayHours: number): Promise<boolean> {
  const status = validateConfig(task);
  if (status !== 'ready') {
    if (lastLoggedStatus !== status) {
      lastLoggedStatus = status;
      console.warn('[reminder] config:', status);
    }
    return false;
  }

  const config = loadDingTalkConfig()!;
  const clientId = resolvedClientId(config)!;
  const clientSecret = resolvedClientSecret(config)!;
  const userIds = resolvedUserIds(task, config);
  if (!userIds.length) return false;

  const dueHint = task.dueDate
    ? new Date(task.dueDate).toLocaleString('zh-CN', {
        month: 'numeric',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    : null;

  const content = dueHint
    ? `【NotesDesk 提醒】「${task.text}」截止 ${dueHint} 起 ${formatDelay(delayHours)} 仍未完成`
    : `【NotesDesk 提醒】「${task.text}」创建 ${formatDelay(delayHours)} 后仍未完成`;

  try {
    const token = await fetchAccessToken(clientId, clientSecret);
    await batchSend(token, config.robotCode!, userIds, content);
    return true;
  } catch (err) {
    console.error('[reminder] send failed:', err);
    return false;
  }
}