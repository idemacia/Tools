import { loadLlmConfig } from '../config/llmConfig.js';
import type { TaskPeriodStats } from '../models/types.js';
import { statsPayloadForLlm } from '../stats/periodStats.js';
import { ruleBasedInsights, type Insight } from '../stats/insights.js';
import {
  buildRulesReport,
  buildSystemPrompt,
  buildUserPrompt,
  parseLlmReport,
  type AnalysisReport,
} from './analysisTemplate.js';

export interface AnalysisResult {
  source: 'llm' | 'rules';
  report: AnalysisReport;
  /** 兼容旧 UI 的扁平字段 */
  summary: string;
  wasteAnalysis: string;
  suggestions: string[];
  insights: Insight[];
  raw?: string;
}

export async function analyzeWithLlm(
  stats: TaskPeriodStats,
  previous?: TaskPeriodStats,
  periodLabel = '本周期',
): Promise<AnalysisResult> {
  const config = loadLlmConfig();
  const insights = ruleBasedInsights(stats, previous);

  if (!config.enabled || !config.apiKey || !config.baseUrl) {
    return toResult(buildRulesReport(stats, previous, insights, periodLabel), 'rules', insights);
  }

  const baseUrl = config.baseUrl.replace(/\/$/, '');
  const payload = statsPayloadForLlm(stats, previous);
  const systemPrompt = buildSystemPrompt();
  const userPrompt = buildUserPrompt(payload, periodLabel);

  try {
    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.apiKey}`,
      },
      body: JSON.stringify({
        model: config.model ?? 'gpt-4o-mini',
        max_tokens: config.maxTokens ?? 2048,
        temperature: config.temperature ?? 0.3,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      console.error('[llm] analyze failed:', response.status, body);
      return toResult(
        buildRulesReport(stats, previous, insights, periodLabel, 'LLM 调用失败，已使用规则分析。'),
        'rules',
        insights,
      );
    }

    const data = (await response.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    const content = data.choices?.[0]?.message?.content ?? '';
    const report = parseLlmReport(content, periodLabel);
    if (!report) {
      return toResult(
        buildRulesReport(stats, previous, insights, periodLabel, 'LLM 返回格式异常，已使用规则分析。'),
        'rules',
        insights,
        content,
      );
    }

    return toResult(report, 'llm', insights, content);
  } catch (err) {
    console.error('[llm] analyze error:', err);
    return toResult(
      buildRulesReport(stats, previous, insights, periodLabel, 'LLM 不可用，已使用规则分析。'),
      'rules',
      insights,
    );
  }
}

function toResult(
  report: AnalysisReport,
  source: 'llm' | 'rules',
  insights: Insight[],
  raw?: string,
): AnalysisResult {
  return {
    source,
    report,
    summary: report.overview.summary,
    wasteAnalysis: report.wasteAnalysis,
    suggestions: report.suggestions.map((s) => s.action),
    insights,
    raw,
  };
}
