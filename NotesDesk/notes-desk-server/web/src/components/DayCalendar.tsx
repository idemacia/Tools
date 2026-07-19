import { useEffect, useMemo, useState } from 'react';
import { api } from '../api/client';

const WEEKDAYS = ['一', '二', '三', '四', '五', '六', '日'];

type DayMarks = {
  created: Record<string, number>;
  incomplete: Record<string, number>;
  completed: Record<string, number>;
};

const EMPTY_MARKS: DayMarks = { created: {}, incomplete: {}, completed: {} };

function todayStr(): string {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Shanghai' });
}

function parseDay(dateStr: string): { y: number; m: number; d: number } | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return null;
  const [y, m, d] = dateStr.split('-').map(Number);
  return { y: y!, m: m!, d: d! };
}

function formatDay(y: number, m: number, d: number): string {
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

function monthKey(y: number, m: number): string {
  return `${y}-${String(m).padStart(2, '0')}`;
}

function daysInMonth(y: number, m: number): number {
  return new Date(y, m, 0).getDate();
}

/** Monday-first weekday index for the 1st of month (0=Mon … 6=Sun). */
function startWeekdayMon(y: number, m: number): number {
  const sun0 = new Date(y, m - 1, 1).getDay();
  return (sun0 + 6) % 7;
}

function dayTitle(marks: DayMarks, day: string): string | undefined {
  const parts: string[] = [];
  const c = marks.created[day] ?? 0;
  const i = marks.incomplete[day] ?? 0;
  const d = marks.completed[day] ?? 0;
  if (c) parts.push(`新建 ${c}`);
  if (i) parts.push(`未完成 ${i}`);
  if (d) parts.push(`已完成 ${d}`);
  return parts.length ? parts.join(' · ') : undefined;
}

interface Props {
  selected: string;
  onSelect: (dateStr: string) => void;
  onToday: () => void;
  onClear: () => void;
  /** 任务列表变化时用于刷新色点 */
  refreshToken?: number | string;
}

export function DayCalendar({ selected, onSelect, onToday, onClear, refreshToken }: Props) {
  const today = todayStr();
  const initial = parseDay(selected) ?? parseDay(today)!;
  const [cursor, setCursor] = useState({ y: initial.y, m: initial.m });
  const [marks, setMarks] = useState<DayMarks>(EMPTY_MARKS);

  useEffect(() => {
    const p = parseDay(selected || today);
    if (p) setCursor({ y: p.y, m: p.m });
  }, [selected, today]);

  useEffect(() => {
    const month = monthKey(cursor.y, cursor.m);
    let cancelled = false;
    void api
      .calendarDays(month)
      .then((res) => {
        if (!cancelled) {
          setMarks({
            created: res.created ?? {},
            incomplete: res.incomplete ?? {},
            completed: res.completed ?? {},
          });
        }
      })
      .catch(() => {
        if (!cancelled) setMarks(EMPTY_MARKS);
      });
    return () => {
      cancelled = true;
    };
  }, [cursor.y, cursor.m, refreshToken]);

  const cells = useMemo(() => {
    const total = daysInMonth(cursor.y, cursor.m);
    const pad = startWeekdayMon(cursor.y, cursor.m);
    const out: Array<{ key: string; label: string; dateStr: string | null }> = [];
    for (let i = 0; i < pad; i++) {
      out.push({ key: `e-${i}`, label: '', dateStr: null });
    }
    for (let d = 1; d <= total; d++) {
      const dateStr = formatDay(cursor.y, cursor.m, d);
      out.push({ key: dateStr, label: String(d), dateStr });
    }
    return out;
  }, [cursor.y, cursor.m]);

  const shiftMonth = (delta: number) => {
    setCursor((c) => {
      const dt = new Date(c.y, c.m - 1 + delta, 1);
      return { y: dt.getFullYear(), m: dt.getMonth() + 1 };
    });
  };

  return (
    <div className="rounded-lg border border-black/10 bg-white p-2">
      <div className="mb-1.5 flex items-center gap-1">
        <button
          type="button"
          className="rounded px-1.5 py-0.5 text-xs hover:bg-black/5"
          onClick={() => shiftMonth(-1)}
          aria-label="上一月"
        >
          ‹
        </button>
        <span className="min-w-0 flex-1 text-center text-xs font-medium tabular-nums">
          {cursor.y}年{cursor.m}月
        </span>
        <button
          type="button"
          className="rounded px-1.5 py-0.5 text-xs hover:bg-black/5"
          onClick={() => shiftMonth(1)}
          aria-label="下一月"
        >
          ›
        </button>
        <button type="button" className="rounded px-1.5 py-0.5 text-xs text-accent" onClick={onToday}>
          今天
        </button>
        {selected && (
          <button type="button" className="rounded px-1.5 py-0.5 text-xs text-text-secondary" onClick={onClear}>
            清除
          </button>
        )}
      </div>
      <div className="grid grid-cols-7 gap-0.5 text-center">
        {WEEKDAYS.map((w) => (
          <div key={w} className="py-0.5 text-[10px] text-text-secondary">
            {w}
          </div>
        ))}
        {cells.map((cell) => {
          if (!cell.dateStr) {
            return <div key={cell.key} className="h-8" />;
          }
          const isSelected = cell.dateStr === selected;
          const isToday = cell.dateStr === today;
          const nCreated = marks.created[cell.dateStr] ?? 0;
          const nIncomplete = marks.incomplete[cell.dateStr] ?? 0;
          const nCompleted = marks.completed[cell.dateStr] ?? 0;
          const hasAny = nCreated > 0 || nIncomplete > 0 || nCompleted > 0;
          return (
            <button
              key={cell.key}
              type="button"
              onClick={() => onSelect(cell.dateStr!)}
              title={dayTitle(marks, cell.dateStr)}
              className={`relative flex h-8 flex-col items-center justify-center rounded text-xs tabular-nums transition-colors ${
                isSelected
                  ? 'bg-accent font-semibold text-white'
                  : isToday
                    ? 'bg-accent/15 font-medium text-accent hover:bg-accent/25'
                    : 'hover:bg-black/5'
              }`}
            >
              <span className="leading-none">{cell.label}</span>
              <span className="mt-0.5 flex h-1.5 items-center justify-center gap-0.5">
                {nCreated > 0 && <span className="h-1 w-1 rounded-full bg-[#ffcc00]" aria-hidden />}
                {nIncomplete > 0 && <span className="h-1 w-1 rounded-full bg-[#ff3b30]" aria-hidden />}
                {nCompleted > 0 && <span className="h-1 w-1 rounded-full bg-[#34c759]" aria-hidden />}
                {!hasAny && <span className="h-1 w-1" aria-hidden />}
              </span>
            </button>
          );
        })}
      </div>
      <p className="mt-1.5 px-0.5 text-[10px] text-text-secondary">
        <span className="inline-flex items-center gap-1">
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-[#ffcc00]" />
          新建
        </span>
        <span className="mx-1.5 inline-flex items-center gap-1">
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-[#ff3b30]" />
          未完成
        </span>
        <span className="inline-flex items-center gap-1">
          <span className="inline-block h-1.5 w-1.5 rounded-full bg-[#34c759]" />
          已完成
        </span>
      </p>
    </div>
  );
}
