import type { TaskPeriodStats } from '../models/types.js';
import type { Insight } from '../stats/insights.js';

/** 结构化分析报告（LLM 输出 / 规则兜底共用） */
export interface AnalysisReport {
  periodLabel: string;
  overview: {
    headline: string;
    grade: 'A' | 'B' | 'C' | 'D' | 'F';
    summary: string;
  };
  metricsInterpretation: string;
  wasteAnalysis: string;
  comparisonWithPrevious: string;
  strengths: string[];
  risks: string[];
  suggestions: Array<{
    priority: 'high' | 'medium' | 'low';
    action: string;
    reason: string;
  }>;
  nextPeriodFocus: string;
}

export const ANALYSIS_OUTPUT_SCHEMA = `{
  "periodLabel": "周期名称，如 2026年第22周",
  "overview": {
    "headline": "一句话结论（15字以内）",
    "grade": "A|B|C|D|F，综合效率等级",
    "summary": "2-3句概括本周期执行质量"
  },
  "metricsInterpretation": "解读 planned/completed/overdue/abandoned/neverDue 等指标含义，不重复罗列数字",
  "wasteAnalysis": "时间浪费来源：逾期、拖延、无截止、晚完成等",
  "comparisonWithPrevious": "与上一周期对比；若无对比数据写「无上一周期数据」",
  "strengths": ["做得好的点1", "点2"],
  "risks": ["需警惕的问题1", "问题2"],
  "suggestions": [
    { "priority": "high|medium|low", "action": "可执行建议", "reason": "为何建议" }
  ],
  "nextPeriodFocus": "下一周期应优先关注的 1 件事"
}`;

export function buildSystemPrompt(): string {
  return `你是个人待办效率分析师（GTD + 时间盒方法）。
仅根据用户提供的 JSON 统计数据发言，不得编造任务名称或数量。
输出必须是合法 JSON，严格符合下列 schema（不要 markdown 代码块）：
${ANALYSIS_OUTPUT_SCHEMA}

评分参考：完成率≥80%且无逾期→A；60-79%→B；40-59%→C；20-39%→D；<20%→F。
建议必须具体、可执行，每条 action 以动词开头。`;
}

export function buildUserPrompt(
  payload: Record<string, unknown>,
  periodLabel: string,
): string {
  return `请分析以下周期：${periodLabel}

统计数据（JSON）：
${JSON.stringify(payload, null, 2)}`;
}

export function parseLlmReport(raw: string, periodLabel: string): AnalysisReport | null {
  try {
    const parsed = JSON.parse(raw) as Partial<AnalysisReport>;
    return normalizeReport(parsed, periodLabel);
  } catch {
    return null;
  }
}

export function buildRulesReport(
  stats: TaskPeriodStats,
  previous: TaskPeriodStats | undefined,
  insights: Insight[],
  periodLabel: string,
  prefix?: string,
): AnalysisReport {
  const ratePct = Math.round(stats.completionRate * 100);
  const grade =
    ratePct >= 80 && stats.overdue === 0
      ? 'A'
      : ratePct >= 60
        ? 'B'
        : ratePct >= 40
          ? 'C'
          : ratePct >= 20
            ? 'D'
            : 'F';

  let comparison = '无上一周期数据。';
  if (previous) {
    const delta = Math.round((stats.completionRate - previous.completionRate) * 100);
    comparison = `完成率 ${ratePct}%（上周期 ${Math.round(previous.completionRate * 100)}%，${delta >= 0 ? '↑' : '↓'}${Math.abs(delta)}%）；计划数 ${stats.planned}（上周期 ${previous.planned}）。`;
  }

  const strengths: string[] = [];
  if (ratePct >= 70) strengths.push(`完成率 ${ratePct}%，执行节奏较好`);
  if (stats.overdue === 0 && stats.planned > 0) strengths.push('无逾期任务');
  if (stats.abandoned === 0 && stats.incomplete > 0) strengths.push('未出现长期搁置任务');
  if (strengths.length === 0) strengths.push('已记录并追踪待办，具备改进基础');

  const risks: string[] = [];
  if (stats.overdue > 0) risks.push(`${stats.overdue} 条任务已逾期`);
  if (stats.abandoned > 0) risks.push(`${stats.abandoned} 条任务超过 14 天未处理`);
  if (stats.neverDue > 0 && stats.planned > 0) {
    risks.push(`${stats.neverDue} 条无截止日期，执行优先级模糊`);
  }
  if (risks.length === 0) risks.push('暂无明显风险信号');

  const suggestions = insights.slice(0, 5).map((i, idx) => ({
    priority: (i.severity === 'critical' ? 'high' : i.severity === 'warning' ? 'medium' : 'low') as
      | 'high'
      | 'medium'
      | 'low',
    action: i.message,
    reason: idx === 0 ? '规则引擎检测' : '基于统计模式',
  }));

  return {
    periodLabel,
    overview: {
      headline: prefix ? '需关注执行效率' : ratePct >= 60 ? '整体可控' : '完成率偏低',
      grade,
      summary:
        (prefix ? `${prefix} ` : '') +
        `本周期计划 ${stats.planned} 项，完成 ${stats.completed} 项，完成率 ${ratePct}%。`,
    },
    metricsInterpretation: `共 ${stats.planned} 项进入本周期；${stats.incomplete} 项未完成；平均完成耗时 ${
      stats.avgCompletionHours != null ? `${Math.round(stats.avgCompletionHours * 10) / 10} 小时` : '暂无'
    }；${stats.lateCompleted} 项晚于截止完成。`,
    wasteAnalysis:
      stats.overdue > 0 || stats.abandoned > 0
        ? `主要浪费在逾期（${stats.overdue}）与长期搁置（${stats.abandoned}）。`
        : '暂无明显时间浪费信号。',
    comparisonWithPrevious: comparison,
    strengths,
    risks,
    suggestions,
    nextPeriodFocus:
      stats.overdue > 0
        ? '优先清空逾期任务'
        : stats.neverDue > stats.planned * 0.3
          ? '为新任务设置明确截止日期'
          : '保持当前节奏并控制每日新增待办数量',
  };
}

function normalizeReport(parsed: Partial<AnalysisReport>, periodLabel: string): AnalysisReport {
  const rawGrade = parsed.overview?.grade;
  const grade: AnalysisReport['overview']['grade'] =
    rawGrade === 'A' || rawGrade === 'B' || rawGrade === 'C' || rawGrade === 'D' || rawGrade === 'F'
      ? rawGrade
      : 'C';

  return {
    periodLabel: parsed.periodLabel ?? periodLabel,
    overview: {
      headline: parsed.overview?.headline ?? '周期分析',
      grade,
      summary: parsed.overview?.summary ?? '',
    },
    metricsInterpretation: parsed.metricsInterpretation ?? '',
    wasteAnalysis: parsed.wasteAnalysis ?? '',
    comparisonWithPrevious: parsed.comparisonWithPrevious ?? '无上一周期数据。',
    strengths: parsed.strengths?.length ? parsed.strengths : ['—'],
    risks: parsed.risks?.length ? parsed.risks : ['—'],
    suggestions: parsed.suggestions?.length
      ? parsed.suggestions.map((s) => ({
          priority: s.priority ?? 'medium',
          action: s.action ?? '',
          reason: s.reason ?? '',
        }))
      : [],
    nextPeriodFocus: parsed.nextPeriodFocus ?? '',
  };
}

export function formatPeriodLabel(
  period: string,
  year: number,
  week?: number,
  month?: number,
): string {
  if (period === 'month' && month != null) return `${year}年${month}月`;
  if (period === 'year') return `${year}年`;
  if (period === 'week' && week != null) return `${year}年第${week}周`;
  return `${year}年`;
}
