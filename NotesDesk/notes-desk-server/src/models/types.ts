export type MessageSource = 'dingtalk' | 'feishu' | 'manual';

export interface DeskTask {
  id: string;
  text: string;
  createdAt: string;
  dueDate: string | null;
  completedAt: string | null;
  remindedAt: string | null;
  source: MessageSource;
  dingtalkMessageId: string | null;
  dingtalkStaffId: string | null;
  updatedAt: string;
}

export interface TaskRow {
  id: string;
  text: string;
  created_at: string;
  due_date: string | null;
  completed_at: string | null;
  reminded_at: string | null;
  source: string;
  dingtalk_msg_id: string | null;
  dingtalk_staff_id: string | null;
  updated_at: string;
}

export function rowToTask(row: TaskRow): DeskTask {
  return {
    id: row.id,
    text: row.text,
    createdAt: row.created_at,
    dueDate: row.due_date,
    completedAt: row.completed_at,
    remindedAt: row.reminded_at,
    source: row.source as MessageSource,
    dingtalkMessageId: row.dingtalk_msg_id,
    dingtalkStaffId: row.dingtalk_staff_id,
    updatedAt: row.updated_at,
  };
}

export function taskToRow(task: DeskTask): TaskRow {
  return {
    id: task.id,
    text: task.text,
    created_at: task.createdAt,
    due_date: task.dueDate,
    completed_at: task.completedAt,
    reminded_at: task.remindedAt,
    source: task.source,
    dingtalk_msg_id: task.dingtalkMessageId,
    dingtalk_staff_id: task.dingtalkStaffId,
    updated_at: task.updatedAt,
  };
}

export function isCompleted(task: DeskTask): boolean {
  return task.completedAt != null;
}

export function isOverdue(task: DeskTask, now = new Date()): boolean {
  if (isCompleted(task) || !task.dueDate) return false;
  return new Date(task.dueDate) < now;
}

export function reminderTriggerDate(task: DeskTask, delayHours: number): Date {
  const base = task.dueDate ? new Date(task.dueDate) : new Date(task.createdAt);
  return new Date(base.getTime() + delayHours * 3600 * 1000);
}

export function shouldRemind(task: DeskTask, delayHours: number, now = new Date()): boolean {
  if (isCompleted(task) || task.remindedAt) return false;
  return now >= reminderTriggerDate(task, delayHours);
}

export interface IngestPayload {
  id?: string;
  text: string;
  source?: string;
  senderName?: string | null;
  senderStaffId?: string | null;
  receivedAt?: string;
}

export type TaskIngestAction =
  | { type: 'create'; task: DeskTask }
  | { type: 'complete'; taskId: string; text: string }
  | { type: 'list'; summary: string }
  | { type: 'noop'; reason: string };

export interface TaskPeriodStats {
  periodStart: string;
  periodEnd: string;
  planned: number;
  completed: number;
  incomplete: number;
  overdue: number;
  lateCompleted: number;
  completionRate: number;
  avgCompletionHours: number | null;
  abandoned: number;
  neverDue: number;
}

export interface DingTalkConfig {
  clientId?: string;
  clientSecret?: string;
  appKey?: string;
  appSecret?: string;
  robotCode?: string;
  reminderUserIds?: string[];
  debug?: boolean;
}

export interface LlmConfig {
  enabled?: boolean;
  provider?: string;
  baseUrl?: string;
  apiKey?: string;
  model?: string;
  maxTokens?: number;
  temperature?: number;
}

export interface AppSettings {
  reminderDelayHours: number;
  remindersEnabled: boolean;
  showCompletedSection: boolean;
  /** 启用周/月/年定时 AI 分析 */
  analysisScheduleEnabled: boolean;
  /** 分析完成后推送钉钉（手动 + 定时） */
  analysisPushToDingTalk: boolean;
  weeklyAnalysisEnabled: boolean;
  /** 0=周日 … 1=周一 … 6=周六 */
  weeklyAnalysisWeekday: number;
  weeklyAnalysisHour: number;
  monthlyAnalysisEnabled: boolean;
  monthlyAnalysisDay: number;
  monthlyAnalysisHour: number;
  yearlyAnalysisEnabled: boolean;
  yearlyAnalysisMonth: number;
  yearlyAnalysisDay: number;
  yearlyAnalysisHour: number;
}

export const DEFAULT_SETTINGS: AppSettings = {
  reminderDelayHours: 1.0,
  remindersEnabled: true,
  showCompletedSection: true,
  analysisScheduleEnabled: true,
  analysisPushToDingTalk: true,
  weeklyAnalysisEnabled: true,
  weeklyAnalysisWeekday: 1,
  weeklyAnalysisHour: 8,
  monthlyAnalysisEnabled: true,
  monthlyAnalysisDay: 1,
  monthlyAnalysisHour: 8,
  yearlyAnalysisEnabled: true,
  yearlyAnalysisMonth: 1,
  yearlyAnalysisDay: 1,
  yearlyAnalysisHour: 8,
};
