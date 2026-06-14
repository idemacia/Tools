import { getDb } from '../db/database.js';
import { getTaskStore } from '../ingest/ingestHandler.js';
import {
  dailyStats,
  weeklyStats,
  monthlyStats,
  yearlyStats,
} from '../stats/periodStats.js';
import { TIMEZONE } from '../config/paths.js';
import { analyzeWithLlm, type AnalysisResult } from './llmAnalyzer.js';
import { formatPeriodLabel } from './analysisTemplate.js';
import { formatReportForDingTalk } from './formatReportForDingTalk.js';
import { sendDingTalkText } from '../reminder/dingtalkNotifier.js';
import { settingsStore } from '../store/settingsStore.js';
import type { TaskPeriodStats } from '../models/types.js';

export type AnalysisPeriod = 'week' | 'month' | 'year';

export interface RunAnalysisOptions {
  period: AnalysisPeriod;
  year: number;
  week?: number;
  month?: number;
  trigger: 'manual' | 'scheduled';
  pushDingTalk?: boolean;
}

export interface RunAnalysisResult {
  stats: TaskPeriodStats;
  analysis: AnalysisResult;
  periodLabel: string;
  periodKey: string;
  pushed: boolean;
}

export function resolvePrevious(
  period: AnalysisPeriod,
  year: number,
  week?: number,
  month?: number,
): TaskPeriodStats | undefined {
  const store = getTaskStore();
  if (period === 'week' && week != null) {
    const prevWeek = week > 1 ? week - 1 : 52;
    const prevYear = week > 1 ? year : year - 1;
    return weeklyStats(store, prevYear, prevWeek);
  }
  if (period === 'month' && month != null) {
    const prevMonth = month > 1 ? month - 1 : 12;
    const prevYear = month > 1 ? year : year - 1;
    return monthlyStats(store, prevYear, prevMonth);
  }
  if (period === 'year') {
    return yearlyStats(store, year - 1);
  }
  return undefined;
}

export function computeStats(
  period: AnalysisPeriod,
  year: number,
  week?: number,
  month?: number,
): TaskPeriodStats {
  const store = getTaskStore();
  if (period === 'month' && month != null) return monthlyStats(store, year, month);
  if (period === 'year') return yearlyStats(store, year);
  return weeklyStats(store, year, week ?? 1);
}

export function periodKey(period: AnalysisPeriod, year: number, week?: number, month?: number): string {
  if (period === 'week' && week != null) return `${year}-W${week}`;
  if (period === 'month' && month != null) return `${year}-${String(month).padStart(2, '0')}`;
  return String(year);
}

export function hasScheduledAnalysis(period: AnalysisPeriod, key: string): boolean {
  const row = getDb()
    .prepare('SELECT 1 FROM analysis_cache WHERE period_type = ? AND period_key = ?')
    .get(period, key);
  return !!row;
}

export function saveAnalysisCache(period: AnalysisPeriod, key: string, analysis: AnalysisResult): void {
  getDb()
    .prepare(
      `INSERT INTO analysis_cache (period_type, period_key, content, created_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(period_type, period_key) DO UPDATE SET content = excluded.content, created_at = excluded.created_at`,
    )
    .run(period, key, JSON.stringify(analysis), new Date().toISOString());
}

export async function runPeriodAnalysis(opts: RunAnalysisOptions): Promise<RunAnalysisResult> {
  const stats = computeStats(opts.period, opts.year, opts.week, opts.month);
  const previous = resolvePrevious(opts.period, opts.year, opts.week, opts.month);
  const periodLabel = formatPeriodLabel(opts.period, opts.year, opts.week, opts.month);
  const key = periodKey(opts.period, opts.year, opts.week, opts.month);

  const analysis = await analyzeWithLlm(stats, previous, periodLabel);
  saveAnalysisCache(opts.period, key, analysis);

  const settings = settingsStore.get();
  const shouldPush =
    opts.pushDingTalk ??
    (settings.analysisPushToDingTalk !== false);

  let pushed = false;
  if (shouldPush) {
    const text = formatReportForDingTalk(analysis.report, analysis.source);
    pushed = await sendDingTalkText(text);
    if (pushed) {
      console.log(`[analysis] pushed to DingTalk (${opts.trigger}) ${periodLabel}`);
    }
  }

  return { stats, analysis, periodLabel, periodKey: key, pushed };
}

/** 定时任务：上一周 / 上一月 / 上一年 */
export function previousWeekRef(now = new Date()): { year: number; week: number } {
  const d = new Date(now);
  d.setDate(d.getDate() - 7);
  return { year: isoWeekYear(d), week: isoWeek(d) };
}

export function previousMonthRef(now = new Date()): { year: number; month: number } {
  const parts = localParts(now);
  let year = parts.year;
  let month = parts.month - 1;
  if (month < 1) {
    month = 12;
    year -= 1;
  }
  return { year, month };
}

export function previousYearRef(now = new Date()): number {
  return localParts(now).year - 1;
}

export function localParts(date: Date): {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  weekday: number;
} {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    weekday: 'short',
    hour12: false,
  });
  const parts = fmt.formatToParts(date);
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? 0);
  const wdMap: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  const wd = parts.find((p) => p.type === 'weekday')?.value ?? 'Mon';
  return {
    year: get('year'),
    month: get('month'),
    day: get('day'),
    hour: get('hour'),
    minute: get('minute'),
    weekday: wdMap[wd] ?? 1,
  };
}

function isoWeek(date: Date): number {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
}

function isoWeekYear(date: Date): number {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  return d.getUTCFullYear();
}

export { dailyStats };
