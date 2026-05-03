import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../shared/ScrollContainer';
import type { ShellSnapshot } from '../../hooks/useShellSnapshot';
import pinmindLogoMark from '../../../assets/icon/brand/pinmind-logo-mark@64.png';

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
  { view: 'daily-flow', icon: 'ai-workspace', label: '首页' },
  { view: 'capture-inbox', icon: 'sb-inbox', label: '收集' },
  { view: 'distill', icon: 'sb-ai-process', label: '整理' },
  { view: 'import', icon: 'sb-results', label: '资料库' },
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
          <img src={pinmindLogoMark} alt="" style={{ width: 18, height: 18 }} draggable={false} />
        </div>
        <span style={{ fontSize: 18, fontWeight: 700, color: 'var(--primary)', letterSpacing: '-0.02em', lineHeight: 1 }}>
          PinMind
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
          className="pinmind-user-card flex w-full items-center gap-2.5 text-left"
          onClick={() => window.dispatchEvent(new CustomEvent('pinmind:open-personal-space'))}
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[color:var(--pm-brand-soft)] text-[12px] font-semibold text-[color:var(--pm-brand)]">
            {settings?.profile?.displayName ? settings.profile.displayName[0] : '?'}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
              {settings?.profile?.displayName || '设置你的空间'}
            </p>
            <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
              {settings?.profile?.workspaceName || '我的第二大脑'}
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
      className={`pinmind-sidebar-item motion-button w-full text-left ${active ? 'is-active' : ''}`}
      style={{ height: 42, padding: '0 12px', fontSize: 14, fontWeight: 500, gap: 10, borderRadius: 12, border: 'none' }}
    >
      <span className="flex min-w-0 items-center gap-[10px]">
        <PinStackIcon name={item.icon as any} size={18} className={active ? 'is-active' : ''} />
        <span className="min-w-0 flex-1 truncate">{item.label}</span>
      </span>
    </button>
  );
}
