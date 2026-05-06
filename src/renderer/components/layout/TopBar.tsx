import { Button, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
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
    'daily-flow': '工作台',
    'capture-inbox': '整理',
    distill: '整理',
    'staging-pool': '暂存池',
    'knowledge-cards': '知识库',
    import: '资料库',
    ai: 'AI',
    settings: '设置',
    capture: '快速捕获',
    edit: '整理详情',
    errors: '错误回看',
    history: '处理历史',
    search: '搜索',
    'agent-chat': 'Agent 对话',
    'agent-tasks': '定时任务',
    'auto-tools': '自动工具',
    workbench: '工作台',
    schedule: '日程表',
    agent: 'Agent',
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
            <AcMindIcon name="settings" size={18} />
          </Button>
        ) : null}
        <span className="truncate text-[13px] font-semibold text-[color:var(--pm-text-primary)]">
          {viewTitle(activeView)}
        </span>
      </div>

      {!isSmall && !isCompact ? (
        <div className="no-drag flex min-w-0 flex-1 justify-center px-4">
          <div className="flex w-full max-w-[560px] items-center gap-2">
            <button
              type="button"
              className="pm-ds-search-field min-w-0 flex-1"
              onClick={() => {
                // 搜索归位到 Agent：唤起 Agent 并准备搜索
                window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'agent' } }));
                // 延迟后触发搜索焦点事件（Agent 页面加载需要时间）
                setTimeout(() => {
                  window.dispatchEvent(new CustomEvent('acmind:focus-search'));
                }, 100);
              }}
              style={{ cursor: 'pointer' }}
            >
              <span className="pm-ds-search-icon" aria-hidden="true">
                <AcMindIcon name="search" size={14} />
              </span>
              <span className="truncate text-[13px] text-[color:var(--pm-text-tertiary)]">
                让 Agent 帮你搜索知识库…
              </span>
              <span className="ml-auto text-[11px] text-[color:var(--pm-text-tertiary)]">⌘K</span>
            </button>

            <Button
              variant="secondary"
              size="sm"
              leadingIcon={<AcMindIcon name="line-file-import" size={14} />}
              onClick={() => onNavigate('auto-tools')}
            >
              自动工具
            </Button>
          </div>
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
          <AcMindIcon name="settings" size={16} />
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
              <AcMindIcon name="brand-acmind-logo" size={14} />
            </span>
          )}
          {!isConfigured ? <span className="acmind-topbar-avatar-badge" /> : null}
        </button>
      </div>
    </header>
  );
}
