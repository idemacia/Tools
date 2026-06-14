import { settingsStore } from '../store/settingsStore.js';
import { TaskStore } from '../store/taskStore.js';
import { sendReminder } from './dingtalkNotifier.js';

const CHECK_INTERVAL_MS = 60_000;

export class ReminderScheduler {
  private timer: ReturnType<typeof setInterval> | null = null;
  private checking = false;
  private store: TaskStore;

  constructor(store?: TaskStore) {
    this.store = store ?? new TaskStore();
  }

  start(): void {
    this.stop();
    void this.check();
    this.timer = setInterval(() => void this.check(), CHECK_INTERVAL_MS);
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async check(): Promise<void> {
    const settings = settingsStore.get();
    if (!settings.remindersEnabled || this.checking) return;
    this.checking = true;
    try {
      const tasks = this.store.tasksNeedingReminder(settings.reminderDelayHours);
      for (const task of tasks) {
        const sent = await sendReminder(task, settings.reminderDelayHours);
        if (sent) this.store.markReminded(task.id);
      }
    } finally {
      this.checking = false;
    }
  }
}
