import fs from 'node:fs';
import { paths } from '../config/paths.js';
import type { LlmConfig } from '../models/types.js';
import { maskSecret } from './dingtalkConfig.js';

const DEFAULT_LLM: LlmConfig = {
  enabled: false,
  provider: 'openai',
  baseUrl: 'https://api.openai.com/v1',
  apiKey: '',
  model: 'gpt-4o-mini',
  maxTokens: 2048,
  temperature: 0.3,
};

export function loadLlmConfig(): LlmConfig {
  if (!fs.existsSync(paths.llmConfig)) return { ...DEFAULT_LLM };
  try {
    return { ...DEFAULT_LLM, ...JSON.parse(fs.readFileSync(paths.llmConfig, 'utf8')) };
  } catch {
    return { ...DEFAULT_LLM };
  }
}

export function saveLlmConfig(config: LlmConfig): void {
  fs.mkdirSync(paths.configDir, { recursive: true });
  fs.writeFileSync(paths.llmConfig, JSON.stringify(config, null, 2), 'utf8');
}

export function publicLlmConfig(config: LlmConfig): Record<string, unknown> {
  return {
    enabled: config.enabled ?? false,
    provider: config.provider ?? 'openai',
    baseUrl: config.baseUrl ?? '',
    apiKey: config.apiKey ? maskSecret(config.apiKey) : '',
    model: config.model ?? 'gpt-4o-mini',
    maxTokens: config.maxTokens ?? 2048,
    temperature: config.temperature ?? 0.3,
    hasApiKey: Boolean(config.apiKey),
  };
}

export async function testLlmConnection(config: LlmConfig): Promise<string> {
  const baseUrl = (config.baseUrl ?? '').replace(/\/$/, '');
  const apiKey = config.apiKey ?? '';
  const model = config.model ?? 'gpt-4o-mini';
  if (!baseUrl || !apiKey) throw new Error('请填写 API Base URL 和 API Key');

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      max_tokens: 16,
      messages: [{ role: 'user', content: '回复 OK' }],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`LLM 测试失败: ${response.status} ${body}`);
  }

  const data = (await response.json()) as { choices?: { message?: { content?: string } }[] };
  return data.choices?.[0]?.message?.content?.trim() ?? 'OK';
}
