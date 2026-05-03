import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../shared/ScrollContainer';
import type { ShellSnapshot } from '../../hooks/useShellSnapshot';
import acmindLogoMark from '../../../assets/icon/brand/acmind-logo-mark@64.png';

interface NavItem {
  view: string;
  icon: string;
  label: string;
}

interface SidebarProps {
  activeView: string;
  onNavigate: (view: string) => void;
  snapshot: ShellSnapshot;
}

const NAV_ITEMS: NavItem[] = [
  { view: 'dashboard', icon: 'ai-workspace', label: '工作台' },
  { view: 'capture-inbox', icon: 'sb-inbox', label: '收集' },
  { view: 'clipboard', icon: 'duplicate', label: '剪贴板' },
  { view: 'shelf', icon: 'filled-file-import', label: 'Shelf' },
  { view: 'capture', icon: 'capture', label: '截图' },
  { view: 'distill', icon: 'sb-ai-process', label: '整理' },
  { view: 'review', icon: 'edit', label: '确认' },
  { view: 'export', icon: 'sb-results', label: '入库' },
  { view: 'projects', icon: 'filled-projects', label: '项目' },
  { view: 'knowledge-cards', icon: 'ai-workspace', label: '知识库' },
  { view: 'datasets', icon: 'sb-ai-process', label: '数据集' },
  { view: 'utilities', icon: 'line-file-import', label: '工具箱' },
  { view: 'task-queue', icon: 'sb-settings', label: '任务' },
  { view: 'automation', icon: 'cloud-advanced', label: '自动化' },
  { view: 'ai', icon: 'cloud-advanced', label: 'AI' },
  { view: 'settings', icon: 'sb-settings', label: '设置' },
];

export function Sidebar({ activeView, onNavigate, snapshot }: SidebarProps): JSX.Element {
  const settings = snapshot.settings;

  return (
    <aside
      className="flex min-h-0 w-[var(--pm-sidebar-width)] shrink-0 flex-col"
      style={{ background: 'var(--pm-bg-sidebar)', borderRight: '1px solid var(--border-light)' }}
    >
      <div className="flex shrink-0 items-center gap-2.5 px-5" style={{ height: 68 }}>
        <div
          className="flex shrink-0 items-center justify-center rounded-[10px]"
          style={{
            width: 28,
            height: 28,
            background: 'linear-gradient(180deg, #FFF1E6 0%, #FFE6D1 100%)',
            border: '1px solid color-mix(in srgb, var(--primary) 18%, transparent)',
          }}
        >
          <img src={acmindLogoMark} alt="" style={{ width: 18, height: 18 }} draggable={false} />
        </div>
        <span style={{ fontSize: 18, fontWeight: 700, color: 'var(--primary)', letterSpacing: '-0.02em', lineHeight: 1 }}>
          AcMind
        </span>
      </div>

      <ScrollContainer className="flex min-h-0 flex-1 flex-col px-3 pt-2 pb-2">
        <nav className="flex flex-col gap-[4px]">
          {NAV_ITEMS.map((item) => (
            <NavButton
              key={item.view}
              item={item}
              active={activeView === item.view}
              onClick={() => onNavigate(item.view)}
            />
          ))}
        </nav>
      </ScrollContainer>

      <div className="shrink-0 px-3 pb-4 pt-2">
        <button
          type="button"
          className="acmind-user-card flex w-full items-center gap-2.5 text-left"
          onClick={() => window.dispatchEvent(new CustomEvent('acmind:open-personal-space'))}
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[color:var(--pm-brand-soft)] text-[12px] font-semibold text-[color:var(--pm-brand)]">
            {settings?.profile?.displayName ? settings.profile.displayName[0] : '?'}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
              {settings?.profile?.displayName || '设置你的空间'}
            </p>
            <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
              {settings?.profile?.workspaceName || 'AcMind'}
            </p>
          </div>
        </button>
      </div>
    </aside>
  );
}

function NavButton({
  item,
  active,
  onClick,
}: {
  item: NavItem;
  active: boolean;
  onClick: () => void;
}): JSX.Element {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`acmind-sidebar-item motion-button w-full text-left ${active ? 'is-active' : ''}`}
      style={{ height: 42, padding: '0 12px', fontSize: 14, fontWeight: 500, gap: 10, borderRadius: 12, border: 'none' }}
    >
      <span className="flex min-w-0 items-center gap-[10px]">
        <PinStackIcon name={item.icon as any} size={18} className={active ? 'is-active' : ''} />
        <span className="min-w-0 flex-1 truncate">{item.label}</span>
      </span>
    </button>
  );
}
