import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { AnalysisResult, TaskPeriodStats } from '../types';

type Period = 'week' | 'month' | 'year';

const PRIORITY_LABEL = { high: '高', medium: '中', low: '低' } as const;

export function StatsPanel() {
  const now = new Date();
  const [period, setPeriod] = useState<Period>('week');
  const [year, setYear] = useState(now.getFullYear());
  const [week, setWeek] = useState(getISOWeek(now));
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [statsLoading, setStatsLoading] = useState(false);
  const [analyzeLoading, setAnalyzeLoading] = useState(false);
  const [stats, setStats] = useState<TaskPeriodStats | null>(null);
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null);
  const [periodLabel, setPeriodLabel] = useState('');
  const [pushed, setPushed] = useState<boolean | null>(null);
  const [error, setError] = useState('');

  const analyzeBody = () => {
    const body: { period: Period; year: number; week?: number; month?: number } = { period, year };
    if (period === 'week') body.week = week;
    if (period === 'month') body.month = month;
    return body;
  };

  const loadStats = async () => {
    setStatsLoading(true);
    setError('');
    try {
      const body = analyzeBody();
      const res = await api.getStats(body.period, body.year, body.week, body.month);
      setStats(res.stats);
      setAnalysis(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setStatsLoading(false);
    }
  };

  const runAnalyze = async () => {
    setAnalyzeLoading(true);
    setError('');
    try {
      const res = await api.analyze(analyzeBody());
      setStats(res.stats);
      setAnalysis(res.analysis);
      setPeriodLabel(res.periodLabel);
      setPushed(res.pushed);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setAnalyzeLoading(false);
    }
  };

  useEffect(() => {
    void loadStats();
  }, [period, year, week, month]);

  const rate = stats ? Math.round(stats.completionRate * 100) : 0;
  const report = analysis?.report;

  return (
    <div className="flex-1 overflow-y-auto bg-detail-bg p-8">
      <div className="mb-4">
        <h2 className="text-xl font-semibold">统计分析</h2>
        <p className="mt-1 text-xs text-text-secondary">
          支持<strong>定时</strong>与<strong>手动</strong>两种方式：定时任务在设置中配置（默认周一/每月1日/每年1月1日 8:00 分析上一周期并推送钉钉）；此处可选手动运行并即时推送。
        </p>
      </div>

      <div className="mb-6 flex flex-wrap items-end gap-3">
        <label className="text-sm">
          <span className="mb-1 block text-xs text-text-secondary">周期</span>
          <select
            value={period}
            onChange={(e) => setPeriod(e.target.value as Period)}
            className="rounded-lg border border-black/10 px-3 py-1.5 text-sm"
          >
            <option value="week">周</option>
            <option value="month">月</option>
            <option value="year">年</option>
          </select>
        </label>
        <label className="text-sm">
          <span className="mb-1 block text-xs text-text-secondary">年份</span>
          <input
            type="number"
            value={year}
            onChange={(e) => setYear(Number(e.target.value))}
            className="w-24 rounded-lg border border-black/10 px-3 py-1.5 text-sm"
          />
        </label>
        {period === 'week' && (
          <label className="text-sm">
            <span className="mb-1 block text-xs text-text-secondary">ISO 周</span>
            <input
              type="number"
              min={1}
              max={53}
              value={week}
              onChange={(e) => setWeek(Number(e.target.value))}
              className="w-20 rounded-lg border border-black/10 px-3 py-1.5 text-sm"
            />
          </label>
        )}
        {period === 'month' && (
          <label className="text-sm">
            <span className="mb-1 block text-xs text-text-secondary">月份</span>
            <input
              type="number"
              min={1}
              max={12}
              value={month}
              onChange={(e) => setMonth(Number(e.target.value))}
              className="w-20 rounded-lg border border-black/10 px-3 py-1.5 text-sm"
            />
          </label>
        )}
        <button
          type="button"
          onClick={() => void loadStats()}
          disabled={statsLoading}
          className="rounded-lg bg-sidebar-active px-4 py-2 text-sm disabled:opacity-50"
        >
          {statsLoading ? '加载中…' : '刷新统计'}
        </button>
        <button
          type="button"
          onClick={() => void runAnalyze()}
          disabled={analyzeLoading}
          className="rounded-lg bg-accent px-4 py-2 text-sm text-white disabled:opacity-50"
        >
          {analyzeLoading ? 'AI 分析中…' : '运行 AI 分析'}
        </button>
      </div>

      {error && <p className="mb-4 text-sm text-overdue">{error}</p>}
      {pushed === true && (
        <p className="mb-4 text-sm text-complete">分析报告已推送到钉钉</p>
      )}
      {pushed === false && analysis && (
        <p className="mb-4 text-sm text-overdue">分析完成，但钉钉推送失败（请检查 robotCode 与 reminderUserIds）</p>
      )}

      {stats && (
        <div className="mb-8 grid grid-cols-2 gap-4 md:grid-cols-4">
          {[
            ['计划', stats.planned],
            ['完成', stats.completed],
            ['完成率', `${rate}%`],
            ['逾期', stats.overdue],
          ].map(([label, value]) => (
            <div key={String(label)} className="rounded-xl bg-sidebar-bg p-4">
              <div className="text-xs text-text-secondary">{label}</div>
              <div className="mt-1 text-2xl font-semibold">{value}</div>
            </div>
          ))}
        </div>
      )}

      {report && (
        <div className="space-y-5 rounded-xl border border-black/5 p-5">
          <div className="flex flex-wrap items-center gap-3">
            <span className="text-sm font-medium">{report.periodLabel || periodLabel}</span>
            <span className="rounded-full bg-sidebar-active px-2 py-0.5 text-xs">
              等级 {report.overview.grade}
            </span>
            <span className="text-xs text-text-secondary">
              {analysis?.source === 'llm' ? 'AI 生成' : '规则兜底'}
            </span>
          </div>

          <div>
            <div className="text-lg font-semibold">{report.overview.headline}</div>
            <p className="mt-2 text-sm leading-relaxed">{report.overview.summary}</p>
          </div>

          <Section title="指标解读" content={report.metricsInterpretation} />
          <Section title="时间浪费" content={report.wasteAnalysis} />
          <Section title="与上周期对比" content={report.comparisonWithPrevious} />

          {report.strengths.length > 0 && (
            <div>
              <div className="mb-2 text-xs font-medium text-text-secondary">优势</div>
              <ul className="list-inside list-disc space-y-1 text-sm">
                {report.strengths.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ul>
            </div>
          )}

          {report.risks.length > 0 && (
            <div>
              <div className="mb-2 text-xs font-medium text-text-secondary">风险</div>
              <ul className="list-inside list-disc space-y-1 text-sm">
                {report.risks.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ul>
            </div>
          )}

          {report.suggestions.length > 0 && (
            <div>
              <div className="mb-2 text-xs font-medium text-text-secondary">改进建议</div>
              <ul className="space-y-3 text-sm">
                {report.suggestions.map((s) => (
                  <li key={`${s.action}-${s.reason}`} className="rounded-lg bg-sidebar-bg p-3">
                    <div className="flex items-center gap-2">
                      <span className="rounded bg-black/5 px-1.5 py-0.5 text-xs">
                        {PRIORITY_LABEL[s.priority]}
                      </span>
                      <span className="font-medium">{s.action}</span>
                    </div>
                    <p className="mt-1 text-xs text-text-secondary">{s.reason}</p>
                  </li>
                ))}
              </ul>
            </div>
          )}

          <Section title="下周期重点" content={report.nextPeriodFocus} />
        </div>
      )}

      {!analysis && stats && !statsLoading && (
        <p className="text-sm text-text-secondary">
          统计已加载。点击「运行 AI 分析」手动生成报告并推送钉钉；或在设置中启用定时分析。
        </p>
      )}
    </div>
  );
}

function Section({ title, content }: { title: string; content: string }) {
  if (!content) return null;
  return (
    <div>
      <div className="mb-1 text-xs font-medium text-text-secondary">{title}</div>
      <p className="text-sm leading-relaxed">{content}</p>
    </div>
  );
}

function getISOWeek(date: Date): number {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
}
