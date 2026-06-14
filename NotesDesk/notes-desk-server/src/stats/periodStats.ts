import type { DeskTask, TaskPeriodStats } from '../models/types.js';
import { isCompleted, isOverdue } from '../models/types.js';
import type { TaskStore } from '../store/taskStore.js';
import { TIMEZONE } from '../config/paths.js';

function parseInTimeZone(iso: string): Date {
  return new Date(iso);
}

function startOfDayInTz(date: Date, timeZone: string): Date {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const y = Number(parts.find((p) => p.type === 'year')?.value);
  const m = Number(parts.find((p) => p.type === 'month')?.value);
  const d = Number(parts.find((p) => p.type === 'day')?.value);
  return new Date(Date.UTC(y, m - 1, d));
}

function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

function addMonths(date: Date, months: number): Date {
  const d = new Date(date);
  d.setUTCMonth(d.getUTCMonth() + months);
  return d;
}

function addYears(date: Date, years: number): Date {
  const d = new Date(date);
  d.setUTCFullYear(d.getUTCFullYear() + years);
  return d;
}

function getISOWeekStart(year: number, week: number): Date {
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const day = jan4.getUTCDay() || 7;
  const week1Monday = addDays(jan4, 1 - day);
  return addDays(week1Monday, (week - 1) * 7);
}

function extendedStats(tasks: DeskTask[], start: Date, end: Date, now: Date): Omit<TaskPeriodStats, 'periodStart' | 'periodEnd'> {
  const planned = tasks.length;
  const completed = tasks.filter((t) => isCompleted(t)).length;
  const incomplete = planned - completed;
  const overdue = tasks.filter((t) => isOverdue(t, now)).length;
  const lateCompleted = tasks.filter((t) => {
    if (!t.completedAt || !t.dueDate) return false;
    return new Date(t.completedAt) > new Date(t.dueDate);
  }).length;
  const completionRate = planned > 0 ? completed / planned : 0;

  const completionHours = tasks
    .filter((t) => t.completedAt)
    .map((t) => (new Date(t.completedAt!).getTime() - new Date(t.createdAt).getTime()) / 3600000);
  const avgCompletionHours =
    completionHours.length > 0
      ? completionHours.reduce((a, b) => a + b, 0) / completionHours.length
      : null;

  const abandonedDays = 14;
  const abandoned = tasks.filter((t) => {
    if (isCompleted(t)) return false;
    const age = (now.getTime() - new Date(t.createdAt).getTime()) / 86400000;
    return age > abandonedDays;
  }).length;

  const neverDue = tasks.filter((t) => !isCompleted(t) && !t.dueDate).length;

  return {
    planned,
    completed,
    incomplete,
    overdue,
    lateCompleted,
    completionRate,
    avgCompletionHours,
    abandoned,
    neverDue,
  };
}

function periodTasks(store: TaskStore, start: Date, end: Date): DeskTask[] {
  return store.allTasks().filter((task) => {
    const created = parseInTimeZone(task.createdAt);
    const createdIn = created >= start && created < end;
    const dueIn = task.dueDate
      ? parseInTimeZone(task.dueDate) >= start && parseInTimeZone(task.dueDate) < end
      : false;
    return createdIn || dueIn;
  });
}

function buildStats(store: TaskStore, start: Date, end: Date, now = new Date()): TaskPeriodStats {
  const tasks = periodTasks(store, start, end);
  const ext = extendedStats(tasks, start, end, now);
  return {
    periodStart: start.toISOString(),
    periodEnd: end.toISOString(),
    ...ext,
  };
}

export function dailyStats(store: TaskStore, day: Date, timeZone = TIMEZONE): TaskPeriodStats {
  const start = startOfDayInTz(day, timeZone);
  const end = addDays(start, 1);
  return buildStats(store, start, end);
}

export function weeklyStats(store: TaskStore, year: number, week: number): TaskPeriodStats {
  const start = getISOWeekStart(year, week);
  const end = addDays(start, 7);
  return buildStats(store, start, end);
}

export function monthlyStats(store: TaskStore, year: number, month: number): TaskPeriodStats {
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = addMonths(start, 1);
  return buildStats(store, start, end);
}

export function yearlyStats(store: TaskStore, year: number): TaskPeriodStats {
  const start = new Date(Date.UTC(year, 0, 1));
  const end = addYears(start, 1);
  return buildStats(store, start, end);
}

export function statsPayloadForLlm(stats: TaskPeriodStats, previous?: TaskPeriodStats): Record<string, unknown> {
  return {
    period: { start: stats.periodStart, end: stats.periodEnd },
    metrics: {
      planned: stats.planned,
      completed: stats.completed,
      incomplete: stats.incomplete,
      overdue: stats.overdue,
      lateCompleted: stats.lateCompleted,
      completionRate: Math.round(stats.completionRate * 1000) / 10,
      avgCompletionHours: stats.avgCompletionHours != null ? Math.round(stats.avgCompletionHours * 10) / 10 : null,
      abandoned: stats.abandoned,
      neverDue: stats.neverDue,
    },
    comparison: previous
      ? {
          completionRateDelta:
            Math.round((stats.completionRate - previous.completionRate) * 1000) / 10,
          plannedDelta: stats.planned - previous.planned,
        }
      : null,
  };
}
