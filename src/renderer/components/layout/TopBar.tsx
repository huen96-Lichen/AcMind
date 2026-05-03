import { Button, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import type { ShellSnapshot } from '../../hooks/useShellSnapshot';
import type { LayoutMode } from '../../hooks/useLayoutMode';

interface TopBarProps {
  snapshot: ShellSnapshot;
  onRefresh: () => void;
  onNavigate: (view: string, options?: { tab?: string }) => void;
  layoutMode: LayoutMode;
  activeView: string;
}

function viewTitle(view: string): string {
  const labels: Record<string, string> = {
    'daily-flow': '首页',
    'capture-inbox': '收集',
    distill: '整理',
    import: '资料库',
    ai: 'AI',
    settings: '设置',
    capture: '快速捕获',
    edit: '整理详情',
    errors: '错误回看',
    history: '处理历史',
    search: '搜索',
  };
  return labels[view] ?? 'AcMind';
}

export function TopBar({ snapshot, onRefresh, onNavigate, layoutMode, activeView }: TopBarProps): JSX.Element {
  const profile = snapshot.settings?.profile;
  const displayName = profile?.displayName;
  const isConfigured = !!displayName;
  const avatarInitial = displayName ? displayName[0] : '';
  const currentTier = snapshot.settings?.defaultTier ?? 'local_light';
  const enabledCurrentTierProviders = snapshot.settings?.providers?.filter(
    (provider) => provider.enabled && provider.tier === currentTier,
  ).length ?? 0;

  const tierLabels: Record<string, string> = {
    local_light: '本地',
    cloud_standard: '云端',
    cloud_advanced: '强力',
  };
  const currentTierLabel = tierLabels[currentTier] ?? '未配置';
  const isSmall = layoutMode === 'small';
  const isCompact = layoutMode === 'compact';

  return (
    <header
      className="acmind-topbar drag-region flex items-center justify-between"
      style={{ height: 'var(--pm-topbar-height, 56px)', background: 'var(--pm-bg-topbar)' }}
    >
      <div className="no-drag flex min-w-0 items-center gap-2">
        {(isSmall || isCompact) ? (
          <Button
            variant="icon"
            size="sm"
            onClick={() => window.dispatchEvent(new CustomEvent('acmind:toggle-sidebar'))}
            title="菜单"
          >
            <PinStackIcon name="settings" size={18} />
          </Button>
        ) : null}
        <span className="truncate text-[13px] font-semibold text-[color:var(--pm-text-primary)]">
          {viewTitle(activeView)}
        </span>
      </div>

      {!isSmall && !isCompact ? (
        <div className="no-drag flex min-w-0 flex-1 justify-center px-4">
          <button
            type="button"
            className="pm-ds-search-field w-full max-w-[480px]"
            onClick={() => onNavigate('search')}
            style={{ cursor: 'pointer' }}
          >
            <span className="pm-ds-search-icon" aria-hidden="true">
              <PinStackIcon name="search" size={14} />
            </span>
            <span className="truncate text-[13px] text-[color:var(--pm-text-tertiary)]">
              搜索内容、标签、来源
            </span>
            <span className="ml-auto text-[11px] text-[color:var(--pm-text-tertiary)]">⌘K</span>
          </button>
        </div>
      ) : null}

      <div className="no-drag flex items-center gap-1.5">
        {!isSmall ? (
          <StatusBadge
            tone={enabledCurrentTierProviders > 0 ? 'success' : 'warning'}
            label={enabledCurrentTierProviders > 0 ? currentTierLabel : '未配置'}
            onClick={() => onNavigate('ai')}
          />
        ) : null}

        <Button variant="icon" size="sm" onClick={() => onNavigate('settings')} title="设置">
          <PinStackIcon name="settings" size={16} />
        </Button>

        <button
          type="button"
          className="acmind-topbar-avatar motion-button"
          onClick={() => window.dispatchEvent(new CustomEvent('acmind:open-personal-space'))}
          title={isConfigured ? displayName : '个人空间'}
        >
          {isConfigured ? (
            <span className="acmind-topbar-avatar-letter">{avatarInitial}</span>
          ) : (
            <span className="acmind-topbar-avatar-logo">
              <PinStackIcon name="brand-acmind-logo" size={14} />
            </span>
          )}
          {!isConfigured ? <span className="acmind-topbar-avatar-badge" /> : null}
        </button>
      </div>
    </header>
  );
}
