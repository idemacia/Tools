import { settingsStore } from '../store/settingsStore.js';
import {
  hasScheduledAnalysis,
  localParts,
  periodKey,
  previousMonthRef,
  previousWeekRef,
  previousYearRef,
  runPeriodAnalysis,
} from '../analytics/periodAnalysis.js';

const CHECK_INTERVAL_MS = 60_000;

export class AnalysisScheduler {
  private timer: ReturnType<typeof setInterval> | null = null;
  private running = false;
  /** 避免同一分钟内重复触发 */
  private lastTickKey = '';

  start(): void {
    this.stop();
    void this.tick();
    this.timer = setInterval(() => void this.tick(), CHECK_INTERVAL_MS);
    console.log('[analysis-scheduler] started');
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async tick(): Promise<void> {
    const settings = settingsStore.get();
    if (!settings.analysisScheduleEnabled || this.running) return;

    const now = localParts(new Date());
    const tickKey = `${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}`;
    if (tickKey === this.lastTickKey) return;
    this.lastTickKey = tickKey;

    // 仅在整点分钟触发（:00）
    if (now.minute !== 0) return;

    this.running = true;
    try {
      if (settings.weeklyAnalysisEnabled && now.weekday === settings.weeklyAnalysisWeekday) {
        if (now.hour === settings.weeklyAnalysisHour) {
          await this.runWeekly();
        }
      }

      if (settings.monthlyAnalysisEnabled && now.day === settings.monthlyAnalysisDay) {
        if (now.hour === settings.monthlyAnalysisHour) {
          await this.runMonthly();
        }
      }

      if (
        settings.yearlyAnalysisEnabled &&
        now.month === settings.yearlyAnalysisMonth &&
        now.day === settings.yearlyAnalysisDay
      ) {
        if (now.hour === settings.yearlyAnalysisHour) {
          await this.runYearly();
        }
      }
    } catch (err) {
      console.error('[analysis-scheduler] error:', err);
    } finally {
      this.running = false;
    }
  }

  private async runWeekly(): Promise<void> {
    const ref = previousWeekRef();
    const key = periodKey('week', ref.year, ref.week);
    if (hasScheduledAnalysis('week', key)) return;

    console.log(`[analysis-scheduler] weekly ${key}`);
    await runPeriodAnalysis({
      period: 'week',
      year: ref.year,
      week: ref.week,
      trigger: 'scheduled',
    });
  }

  private async runMonthly(): Promise<void> {
    const ref = previousMonthRef();
    const key = periodKey('month', ref.year, undefined, ref.month);
    if (hasScheduledAnalysis('month', key)) return;

    console.log(`[analysis-scheduler] monthly ${key}`);
    await runPeriodAnalysis({
      period: 'month',
      year: ref.year,
      month: ref.month,
      trigger: 'scheduled',
    });
  }

  private async runYearly(): Promise<void> {
    const year = previousYearRef();
    const key = periodKey('year', year);
    if (hasScheduledAnalysis('year', key)) return;

    console.log(`[analysis-scheduler] yearly ${key}`);
    await runPeriodAnalysis({
      period: 'year',
      year,
      trigger: 'scheduled',
    });
  }
}
