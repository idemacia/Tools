import { getDb } from '../db/database.js';
import type { AppSettings } from '../models/types.js';
import { DEFAULT_SETTINGS } from '../models/types.js';

function bool(val: string | undefined, fallback: boolean): boolean {
  if (val == null) return fallback;
  return val === 'true';
}

function num(val: string | undefined, fallback: number, min?: number, max?: number): number {
  if (val == null) return fallback;
  let n = Number(val);
  if (Number.isNaN(n)) return fallback;
  if (min != null) n = Math.max(min, n);
  if (max != null) n = Math.min(max, n);
  return n;
}

export class SettingsStore {
  get(): AppSettings {
    const db = getDb();
    const rows = db.prepare('SELECT key, value FROM settings').all() as { key: string; value: string }[];
    const map = Object.fromEntries(rows.map((r) => [r.key, r.value]));
    return {
      reminderDelayHours: num(map.reminderDelayHours, DEFAULT_SETTINGS.reminderDelayHours, 0.1, 24),
      remindersEnabled: bool(map.remindersEnabled, DEFAULT_SETTINGS.remindersEnabled),
      showCompletedSection: bool(map.showCompletedSection, DEFAULT_SETTINGS.showCompletedSection),
      analysisScheduleEnabled: bool(map.analysisScheduleEnabled, DEFAULT_SETTINGS.analysisScheduleEnabled),
      analysisPushToDingTalk: bool(map.analysisPushToDingTalk, DEFAULT_SETTINGS.analysisPushToDingTalk),
      weeklyAnalysisEnabled: bool(map.weeklyAnalysisEnabled, DEFAULT_SETTINGS.weeklyAnalysisEnabled),
      weeklyAnalysisWeekday: num(map.weeklyAnalysisWeekday, DEFAULT_SETTINGS.weeklyAnalysisWeekday, 0, 6),
      weeklyAnalysisHour: num(map.weeklyAnalysisHour, DEFAULT_SETTINGS.weeklyAnalysisHour, 0, 23),
      monthlyAnalysisEnabled: bool(map.monthlyAnalysisEnabled, DEFAULT_SETTINGS.monthlyAnalysisEnabled),
      monthlyAnalysisDay: num(map.monthlyAnalysisDay, DEFAULT_SETTINGS.monthlyAnalysisDay, 1, 28),
      monthlyAnalysisHour: num(map.monthlyAnalysisHour, DEFAULT_SETTINGS.monthlyAnalysisHour, 0, 23),
      yearlyAnalysisEnabled: bool(map.yearlyAnalysisEnabled, DEFAULT_SETTINGS.yearlyAnalysisEnabled),
      yearlyAnalysisMonth: num(map.yearlyAnalysisMonth, DEFAULT_SETTINGS.yearlyAnalysisMonth, 1, 12),
      yearlyAnalysisDay: num(map.yearlyAnalysisDay, DEFAULT_SETTINGS.yearlyAnalysisDay, 1, 28),
      yearlyAnalysisHour: num(map.yearlyAnalysisHour, DEFAULT_SETTINGS.yearlyAnalysisHour, 0, 23),
    };
  }

  save(partial: Partial<AppSettings>): AppSettings {
    const current = this.get();
    const next = { ...current, ...partial };
    const db = getDb();
    const upsert = db.prepare(
      'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    );

    const entries: [string, string][] = [
      ['reminderDelayHours', String(Math.min(24, Math.max(0.1, next.reminderDelayHours)))],
      ['remindersEnabled', String(next.remindersEnabled)],
      ['showCompletedSection', String(next.showCompletedSection)],
      ['analysisScheduleEnabled', String(next.analysisScheduleEnabled)],
      ['analysisPushToDingTalk', String(next.analysisPushToDingTalk)],
      ['weeklyAnalysisEnabled', String(next.weeklyAnalysisEnabled)],
      ['weeklyAnalysisWeekday', String(next.weeklyAnalysisWeekday)],
      ['weeklyAnalysisHour', String(next.weeklyAnalysisHour)],
      ['monthlyAnalysisEnabled', String(next.monthlyAnalysisEnabled)],
      ['monthlyAnalysisDay', String(next.monthlyAnalysisDay)],
      ['monthlyAnalysisHour', String(next.monthlyAnalysisHour)],
      ['yearlyAnalysisEnabled', String(next.yearlyAnalysisEnabled)],
      ['yearlyAnalysisMonth', String(next.yearlyAnalysisMonth)],
      ['yearlyAnalysisDay', String(next.yearlyAnalysisDay)],
      ['yearlyAnalysisHour', String(next.yearlyAnalysisHour)],
    ];
    for (const [k, v] of entries) upsert.run(k, v);
    return next;
  }
}

export const settingsStore = new SettingsStore();
