import { DWClient, EventAck, TOPIC_ROBOT } from 'dingtalk-stream-sdk-nodejs';
import {
  loadDingTalkConfig,
  resolvedClientId,
  resolvedClientSecret,
} from '../config/dingtalkConfig.js';
import { handleIngest } from '../ingest/ingestHandler.js';

let client: DWClient | null = null;
let connected = false;
let retryTimer: ReturnType<typeof setTimeout> | null = null;
let connectAttempt = 0;

function extractText(data: Record<string, unknown>): string {
  const textObj = data.text as { content?: string } | undefined;
  const raw = textObj?.content ?? data.content ?? '';
  if (typeof raw !== 'string') return '';
  return raw.replace(/^@[^\s]+\s*/, '').trim();
}

function clearRetryTimer(): void {
  if (retryTimer) {
    clearTimeout(retryTimer);
    retryTimer = null;
  }
}

function scheduleReconnect(reason: string): void {
  if (retryTimer) return;
  connectAttempt += 1;
  const delayMs = Math.min(120_000, 5_000 * 2 ** Math.min(connectAttempt - 1, 5));
  console.warn(
    `[dingtalk-bridge] will retry in ${Math.round(delayMs / 1000)}s (attempt ${connectAttempt}, ${reason})`,
  );
  retryTimer = setTimeout(() => {
    retryTimer = null;
    startDingTalkBridge();
  }, delayMs);
}

export function stopDingTalkBridge(): void {
  clearRetryTimer();
  connected = false;
  if (client) {
    try {
      client.disconnect();
    } catch {
      /* ignore */
    }
    client = null;
    console.log('[dingtalk-bridge] stopped');
  }
}

export function startDingTalkBridge(): boolean {
  clearRetryTimer();
  connected = false;

  const config = loadDingTalkConfig();
  if (!config) {
    console.warn('[dingtalk-bridge] no dingtalk.json, skip');
    client = null;
    return false;
  }

  const clientId = resolvedClientId(config);
  const clientSecret = resolvedClientSecret(config);
  if (!clientId || !clientSecret) {
    console.warn('[dingtalk-bridge] missing credentials');
    client = null;
    return false;
  }

  if (clientId.includes('xxxx') || clientSecret.includes('xxxx')) {
    console.warn('[dingtalk-bridge] placeholder credentials');
    client = null;
    return false;
  }

  if (client) {
    try {
      client.disconnect();
    } catch {
      /* ignore */
    }
  }

  client = new DWClient({
    clientId,
    clientSecret,
  });

  console.log('[dingtalk-bridge] starting Stream…');

  client
    .registerCallbackListener(TOPIC_ROBOT, async (res) => {
      try {
        const data = JSON.parse(res.data) as Record<string, unknown>;
        const text = extractText(data);
        if (!text) return;

        const messageId = res.headers?.messageId ?? crypto.randomUUID();
        handleIngest({
          id: messageId,
          text,
          source: 'dingtalk',
          senderName: (data.senderNick as string) ?? null,
          senderStaffId: (data.senderStaffId as string) ?? null,
          receivedAt: new Date().toISOString(),
        });

        console.log(`[dingtalk-bridge] forwarded: ${text.slice(0, 40)}`);
        if (res.headers?.messageId) {
          client!.send(res.headers.messageId, { status: 'SUCCESS' });
        }
      } catch (err) {
        console.error('[dingtalk-bridge] message error:', err);
      }
    })
    .registerAllEventListener(() => ({ status: EventAck.SUCCESS }));

  void client
    .connect()
    .then(() => {
      connected = true;
      connectAttempt = 0;
      console.log('[dingtalk-bridge] Stream connected');
    })
    .catch((err: unknown) => {
      connected = false;
      client = null;
      const msg =
        err && typeof err === 'object' && 'message' in err
          ? String((err as { message?: string }).message)
          : String(err);
      const status =
        err && typeof err === 'object' && 'response' in err
          ? (err as { response?: { status?: number } }).response?.status
          : undefined;
      console.error(
        `[dingtalk-bridge] connect failed${status ? ` (HTTP ${status})` : ''}: ${msg}`,
      );
      if (status === 503 || status === 502 || status === 429 || !status) {
        scheduleReconnect(status ? `HTTP ${status}` : 'network error');
      } else {
        scheduleReconnect('connect error');
      }
    });

  return true;
}

export function restartDingTalkBridge(): boolean {
  connectAttempt = 0;
  return startDingTalkBridge();
}

export function isBridgeRunning(): boolean {
  return connected && client != null;
}
