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

export interface AnalysisResult {
  source: 'llm' | 'rules';
  report: AnalysisReport;
  summary: string;
  wasteAnalysis: string;
  suggestions: string[];
}

export type ViewMode = 'today' | 'incomplete' | 'completed' | 'stats' | 'settings';

export interface DingTalkConfigForm {
  clientId: string;
  clientSecret: string;
  robotCode: string;
  reminderUserIds: string;
  hasClientSecret?: boolean;
}

export interface LlmConfigForm {
  enabled: boolean;
  provider: string;
  baseUrl: string;
  apiKey: string;
  model: string;
  maxTokens: number;
  temperature: number;
  hasApiKey?: boolean;
}

export interface AppSettings {
  reminderDelayHours: number;
  remindersEnabled: boolean;
  showCompletedSection: boolean;
  analysisScheduleEnabled: boolean;
  analysisPushToDingTalk: boolean;
  weeklyAnalysisEnabled: boolean;
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
