import type { AnalysisReport } from './analysisTemplate.js';

const PRIORITY_LABEL = { high: '高', medium: '中', low: '低' } as const;

/** 格式化为钉钉文本消息（控制在约 1800 字以内） */
export function formatReportForDingTalk(report: AnalysisReport, source: 'llm' | 'rules'): string {
  const lines: string[] = [
    `【NotesDesk 周期分析】${report.periodLabel}`,
    `等级 ${report.overview.grade} | ${report.overview.headline}`,
    `来源：${source === 'llm' ? 'AI 分析' : '规则兜底'}`,
    '',
    report.overview.summary,
    '',
    `📈 指标：${truncate(report.metricsInterpretation, 200)}`,
    `⏱ 浪费：${truncate(report.wasteAnalysis, 200)}`,
    `📉 对比：${truncate(report.comparisonWithPrevious, 200)}`,
  ];

  if (report.strengths.length) {
    lines.push('', '✅ 优势');
    for (const s of report.strengths.slice(0, 3)) lines.push(`· ${s}`);
  }

  if (report.risks.length) {
    lines.push('', '⚠️ 风险');
    for (const r of report.risks.slice(0, 3)) lines.push(`· ${r}`);
  }

  if (report.suggestions.length) {
    lines.push('', '💡 建议');
    report.suggestions.slice(0, 5).forEach((s, i) => {
      lines.push(`${i + 1}. [${PRIORITY_LABEL[s.priority]}] ${s.action}`);
    });
  }

  if (report.nextPeriodFocus) {
    lines.push('', `🎯 下周期重点：${report.nextPeriodFocus}`);
  }

  let text = lines.join('\n');
  if (text.length > 1800) text = text.slice(0, 1797) + '…';
  return text;
}

function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + '…';
}
