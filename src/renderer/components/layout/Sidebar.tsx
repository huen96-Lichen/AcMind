import { AcMindIcon } from '../../design-system/icons';
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
  collapsed: boolean;
  onToggleCollapsed: () => void;
}

// 一级导航：Agent / 日程表 / 工作台 / 自动工具 / 设置
const NAV_ITEMS: NavItem[] = [
  { view: 'agent', icon: 'ai-process', label: 'Agent' },
  { view: 'schedule', icon: 'clock', label: '日程表' },
  { view: 'workbench', icon: 'filled-home', label: '工作台' },
  { view: 'auto-tools', icon: 'line-file-import', label: '自动工具' },
  { view: 'settings', icon: 'sb-settings', label: '设置' },
];

export function Sidebar({ activeView, onNavigate, snapshot, collapsed, onToggleCollapsed }: SidebarProps): JSX.Element {
  const settings = snapshot.settings;

  return (
    <aside
      className={`flex min-h-0 shrink-0 flex-col overflow-hidden transition-[width] duration-200 ease-out ${
        collapsed ? 'w-[72px]' : 'w-[var(--pm-sidebar-width)]'
      }`}
      style={{ background: 'var(--pm-bg-sidebar)', borderRight: '1px solid var(--border-light)' }}
    >
      <div className={`flex shrink-0 items-center ${collapsed ? 'justify-between px-2' : 'justify-between gap-2 px-4'} h-[64px]`}>
        <div className={`flex min-w-0 items-center ${collapsed ? 'justify-center' : 'gap-2.5'}`}>
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
          {!collapsed ? (
            <span style={{ fontSize: 18, fontWeight: 700, color: 'var(--primary)', letterSpacing: '-0.02em', lineHeight: 1 }}>
              AcMind
            </span>
          ) : null}
        </div>
        <button
          type="button"
          className="acmind-topbar-icon-btn"
          title={collapsed ? '展开导航' : '折叠导航'}
          aria-label={collapsed ? '展开导航' : '折叠导航'}
          onClick={onToggleCollapsed}
        >
          <AcMindIcon name={collapsed ? 'arrow-right' : 'arrow-left'} size={14} />
        </button>
      </div>

      <ScrollContainer className={`flex min-h-0 flex-1 flex-col pb-2 ${collapsed ? 'px-2 pt-1.5' : 'px-3 pt-2'}`}>
        <nav className={`flex flex-col gap-[4px] ${collapsed ? 'items-stretch' : ''}`}>
          {NAV_ITEMS.map((item) => (
            <NavButton
              key={item.view}
              item={item}
              active={activeView === item.view}
              onClick={() => onNavigate(item.view)}
              collapsed={collapsed}
            />
          ))}
        </nav>
      </ScrollContainer>

      <div className={`shrink-0 ${collapsed ? 'px-2 pb-3 pt-1.5' : 'px-3 pb-4 pt-2'}`}>
        {collapsed ? (
          <div className="flex flex-col gap-2">
            <button
              type="button"
              className="flex h-10 w-full items-center justify-center rounded-[14px] border border-[color:var(--border-light)] bg-white/82 text-[color:var(--pm-text-secondary)] shadow-[0_8px_18px_rgba(17,24,39,0.04)]"
              title={settings?.profile?.displayName || '设置你的空间'}
              onClick={() => window.dispatchEvent(new CustomEvent('acmind:open-personal-space'))}
            >
              <AcMindIcon name="filled-user" size={18} />
            </button>
            <button
              type="button"
              className="flex h-10 w-full items-center justify-center rounded-[14px] border border-[color:var(--border-light)] bg-white/82 text-[color:var(--pm-text-secondary)] shadow-[0_8px_18px_rgba(17,24,39,0.04)]"
              title="折叠/展开"
              aria-label="折叠/展开"
              onClick={onToggleCollapsed}
            >
              <AcMindIcon name="settings" size={18} />
            </button>
          </div>
        ) : (
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
        )}
      </div>
    </aside>
  );
}

function NavButton({
  item,
  active,
  onClick,
  collapsed,
}: {
  item: NavItem;
  active: boolean;
  onClick: () => void;
  collapsed: boolean;
}): JSX.Element {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`acmind-sidebar-item motion-button w-full text-left ${active ? 'is-active' : ''} ${
        collapsed ? 'justify-center' : ''
      }`}
      title={collapsed ? item.label : undefined}
      aria-label={item.label}
      style={{
        height: 44,
        padding: collapsed ? '0' : '0 14px',
        fontSize: 14,
        fontWeight: 500,
        gap: collapsed ? 0 : 10,
        borderRadius: 14,
        border: 'none',
        justifyContent: collapsed ? 'center' : 'space-between',
      }}
    >
      <span className={`flex min-w-0 items-center ${collapsed ? '' : 'gap-[10px]'}`}>
        <AcMindIcon name={item.icon as any} size={18} className={active ? 'is-active' : ''} />
        {!collapsed ? <span className="min-w-0 flex-1 truncate">{item.label}</span> : null}
      </span>
    </button>
  );
}
