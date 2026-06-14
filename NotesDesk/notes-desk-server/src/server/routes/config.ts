import { Router } from 'express';
import {
  loadDingTalkConfig,
  saveDingTalkConfig,
  publicDingTalkConfig,
  testDingTalkConnection,
  resolvedClientSecret,
} from '../../config/dingtalkConfig.js';
import {
  loadLlmConfig,
  saveLlmConfig,
  publicLlmConfig,
  testLlmConnection,
} from '../../config/llmConfig.js';
import { restartDingTalkBridge } from '../../bridge/dingtalkBridge.js';
import type { DingTalkConfig, LlmConfig } from '../../models/types.js';

const router = Router();

router.get('/dingtalk', (_req, res) => {
  res.json({ config: publicDingTalkConfig(loadDingTalkConfig()) });
});

router.put('/dingtalk', (req, res) => {
  const body = req.body as DingTalkConfig & { clientSecret?: string };
  const existing = loadDingTalkConfig() ?? {};

  let clientSecret = body.clientSecret ?? body.appSecret;
  if (!clientSecret || clientSecret.includes('***')) {
    clientSecret = resolvedClientSecret(existing) ?? undefined;
  }

  const config: DingTalkConfig = {
    ...existing,
    clientId: body.clientId ?? body.appKey ?? existing.clientId,
    clientSecret,
    robotCode: body.robotCode ?? existing.robotCode,
    reminderUserIds: body.reminderUserIds ?? existing.reminderUserIds,
    debug: body.debug ?? existing.debug,
  };

  saveDingTalkConfig(config);
  const restarted = restartDingTalkBridge();
  res.json({ config: publicDingTalkConfig(config), bridgeRestarted: restarted });
});

router.post('/dingtalk/test', async (req, res) => {
  try {
    const body = req.body as { clientId?: string; clientSecret?: string };
    const existing = loadDingTalkConfig();
    let secret = body.clientSecret;
    if (!secret || secret.includes('***')) {
      secret = resolvedClientSecret(existing ?? {}) ?? undefined;
    }
    const clientId = body.clientId ?? existing?.clientId ?? existing?.appKey;
    if (!clientId || !secret) {
      res.status(400).json({ error: '请填写 Client ID 和 Client Secret' });
      return;
    }
    await testDingTalkConnection(clientId, secret);
    res.json({ ok: true, message: '钉钉连接成功' });
  } catch (err) {
    res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
  }
});

router.get('/llm', (_req, res) => {
  res.json({ config: publicLlmConfig(loadLlmConfig()) });
});

router.put('/llm', (req, res) => {
  const body = req.body as LlmConfig & { apiKey?: string };
  const existing = loadLlmConfig();

  let apiKey = body.apiKey;
  if (!apiKey || apiKey.includes('***')) {
    apiKey = existing.apiKey;
  }

  const config: LlmConfig = {
    ...existing,
    enabled: body.enabled ?? existing.enabled,
    provider: body.provider ?? existing.provider,
    baseUrl: body.baseUrl ?? existing.baseUrl,
    apiKey,
    model: body.model ?? existing.model,
    maxTokens: body.maxTokens ?? existing.maxTokens,
    temperature: body.temperature ?? existing.temperature,
  };

  saveLlmConfig(config);
  res.json({ config: publicLlmConfig(config) });
});

router.post('/llm/test', async (req, res) => {
  try {
    const body = req.body as LlmConfig;
    const existing = loadLlmConfig();
    const config: LlmConfig = {
      ...existing,
      ...body,
      apiKey: body.apiKey && !body.apiKey.includes('***') ? body.apiKey : existing.apiKey,
    };
    const reply = await testLlmConnection(config);
    res.json({ ok: true, message: 'LLM 连接成功', reply });
  } catch (err) {
    res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
  }
});

export default router;
