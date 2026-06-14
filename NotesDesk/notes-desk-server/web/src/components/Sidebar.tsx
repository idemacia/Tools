import type { ViewMode } from '../types';

const items: { id: ViewMode; label: string }[] = [
  { id: 'today', label: '今日' },
  { id: 'incomplete', label: '未完成' },
  { id: 'completed', label: '已完成' },
  { id: 'stats', label: '统计' },
  { id: 'settings', label: '设置' },
];

interface Props {
  view: ViewMode;
  onChange: (v: ViewMode) => void;
  bridge: boolean;
  incompleteCount: number;
}

export function Sidebar({ view, onChange, bridge, incompleteCount }: Props) {
  return (
    <aside className="flex h-full w-60 shrink-0 flex-col bg-sidebar-bg border-r border-black/5">
      <div className="px-4 py-5">
        <h1 className="text-lg font-semibold tracking-tight">NotesDesk</h1>
        <p className="mt-1 text-xs text-text-secondary">
          钉钉 {bridge ? '已连接' : '未连接'}
        </p>
      </div>
      <nav className="flex-1 space-y-0.5 px-2">
        {items.map((item) => {
          const active = view === item.id;
          const label =
            item.id === 'incomplete' && incompleteCount > 0
              ? `${item.label} (${incompleteCount})`
              : item.label;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onChange(item.id)}
              className={`w-full rounded-lg px-3 py-2 text-left text-sm transition-colors ${
                active ? 'bg-sidebar-active font-medium' : 'hover:bg-black/5'
              }`}
            >
              {label}
            </button>
          );
        })}
      </nav>
    </aside>
  );
}
