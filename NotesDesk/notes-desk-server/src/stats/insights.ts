import type { TaskPeriodStats } from '../models/types.js';

export interface Insight {
  id: string;
  severity: 'info' | 'warning' | 'critical';
  message: string;
}

export function ruleBasedInsights(
  stats: TaskPeriodStats,
  previous?: TaskPeriodStats,
): Insight[] {
  const insights: Insight[] = [];
  const rate = stats.completionRate;
  const ratePct = Math.round(rate * 100);

  if (rate < 0.5 && stats.planned >= 5) {
    insights.push({
      id: 'R01',
      severity: 'warning',
      message: `计划偏多，本周期仅完成 ${ratePct}%，建议每天不超过 3 条新待办。`,
    });
  }

  if (stats.overdue >= 3) {
    insights.push({
      id: 'R02',
      severity: 'critical',
      message: `有 ${stats.overdue} 条逾期任务，优先处理最早截止的几条。`,
    });
  }

  if (previous && previous.completionRate - rate >= 0.15) {
    const delta = Math.round((rate - previous.completionRate) * 100);
    insights.push({
      id: 'R03',
      severity: 'warning',
      message: `完成率较上周期下降 ${Math.abs(delta)}%，检查是否截止设得过于密集。`,
    });
  }

  if (stats.planned > 0 && stats.neverDue / stats.planned > 0.3) {
    const pct = Math.round((stats.neverDue / stats.planned) * 100);
    insights.push({
      id: 'R04',
      severity: 'info',
      message: `${pct}% 任务无截止日期，习惯用「截止 m/d …」提高可执行性。`,
    });
  }

  if (stats.completed > 0 && stats.lateCompleted / stats.completed > 0.4) {
    insights.push({
      id: 'R05',
      severity: 'warning',
      message: '四成任务晚于截止才完成，建议预留 buffer 或调整截止时刻。',
    });
  }

  if (stats.abandoned >= 2) {
    insights.push({
      id: 'R06',
      severity: 'warning',
      message: `${stats.abandoned} 条任务创建超过 14 天仍未动，考虑完成或删除。`,
    });
  }

  if (insights.length === 0 && stats.planned > 0) {
    insights.push({
      id: 'R00',
      severity: 'info',
      message: `本周期完成率 ${ratePct}%，继续保持或适当提高计划质量。`,
    });
  }

  return insights;
}
