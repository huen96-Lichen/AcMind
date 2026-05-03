import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  EmptyState,
  LoadingState,
  PageHeader,
  PageShell,
  Section,
  StatusBadge,
} from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { useShellSnapshot } from '../../hooks/useShellSnapshot';
import type { ProviderConfig } from '../../../shared/types';

const TIER_LABELS: Record<string, string> = {
  local_light: '本地',
  cloud_standard: '云端',
  cloud_advanced: '强力',
};

const TIER_TONES: Record<string, 'success' | 'info' | 'primary'> = {
  local_light: 'success',
  cloud_standard: 'info',
  cloud_advanced: 'primary',
};

interface RecentTask {
  id: string;
  title: string;
  status: string;
  time: string;
}

export function AIPage(): JSX.Element {
  const snapshot = useShellSnapshot();
  const [recentTasks, setRecentTasks] = useState<RecentTask[]>([]);
  const [loadingTasks, setLoadingTasks] = useState(true);

  const settings = snapshot.settings;
  const currentTier = settings?.defaultTier ?? 'local_light';
  const providers = settings?.providers ?? [];

  useEffect(() => {
    async function loadRecentTasks() {
      try {
        const items = await window.pinmind.sourceItems.list({ limit: 10 });
        setRecentTasks(
          items.map((item) => ({
            id: item.id,
            title: item.title || item.previewText || '未命名',
            status: item.status,
            time: formatTime(item.createdAt),
          })),
        );
      } catch {
        // ignore
      } finally {
        setLoadingTasks(false);
      }
    }
    void loadRecentTasks();
  }, []);

  const handleNavigateToSettings = useCallback(() => {
    window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'settings', tab: 'ai-models' } }));
  }, []);

  if (snapshot.loading) {
    return (
      <PageShell>
        <LoadingState title="正在加载" description="正在读取模型配置。" />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <div className="px-6 pt-5">
        <PageHeader
          title="AI"
          description="模型与处理方式"
        />
      </div>

      <div className="px-6 pb-6 flex flex-col gap-5">
        <Section title="当前模式" compact>
          <div className="grid grid-cols-3 gap-2">
            {(['local_light', 'cloud_standard', 'cloud_advanced'] as const).map((tier) => {
              const isActive = currentTier === tier;
              const hasEnabled = providers.some((p) => p.tier === tier && p.enabled);
              return (
                <button
                  key={tier}
                  type="button"
                  className={`flex flex-col items-center gap-1.5 rounded-[12px] border p-3 transition-all ${
                    isActive
                      ? 'border-[color:var(--pm-brand)] bg-[color:var(--pm-brand-soft)]'
                      : 'border-[color:var(--pm-border-subtle)] bg-white/50'
                  }`}
                  onClick={handleNavigateToSettings}
                >
                  <span
                    className="text-[13px] font-medium"
                    style={{ color: isActive ? 'var(--pm-brand)' : 'var(--pm-text-secondary)' }}
                  >
                    {TIER_LABELS[tier]}
                  </span>
                  {isActive && (
                    <span className="text-[10px] font-medium" style={{ color: 'var(--pm-brand)' }}>
                      当前
                    </span>
                  )}
                  {!isActive && hasEnabled && (
                    <span className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                      已配置
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </Section>

        <Section title="模型来源" compact>
          {providers.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="brand-cloud" size={24} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="还没有可用模型"
              description="请先配置"
              action={{ label: '新增模型', onClick: handleNavigateToSettings }}
            />
          ) : (
            <div className="flex flex-col gap-2">
              {providers.map((provider) => (
                <ProviderRow key={provider.id} provider={provider} />
              ))}
            </div>
          )}
          <div className="mt-3">
            <Button variant="secondary" size="sm" onClick={handleNavigateToSettings}>
              新增模型
            </Button>
          </div>
        </Section>

        <Section title="最近处理" compact>
          {loadingTasks ? (
            <div className="py-4">
              <LoadingState title="正在加载" description="正在读取处理记录。" />
            </div>
          ) : recentTasks.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="ai-workspace" size={24} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="还没有处理记录"
              description="收集内容后会出现在这里"
            />
          ) : (
            <div className="flex flex-col gap-1.5">
              {recentTasks.map((task) => (
                <div
                  key={task.id}
                  className="flex items-center gap-3 rounded-[10px] px-3 py-2"
                  style={{ background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.5))' }}
                >
                  <StatusBadge
                    tone={statusTone(task.status)}
                    label={statusLabel(task.status)}
                  />
                  <span
                    className="flex-1 min-w-0 truncate text-[13px]"
                    style={{ color: 'var(--pm-text-primary)' }}
                  >
                    {task.title}
                  </span>
                  <span
                    className="shrink-0 text-[11px]"
                    style={{ color: 'var(--pm-text-tertiary)' }}
                  >
                    {task.time}
                  </span>
                </div>
              ))}
            </div>
          )}
        </Section>
      </div>
    </PageShell>
  );
}

function ProviderRow({ provider }: { provider: ProviderConfig }): JSX.Element {
  const statusTone = provider.enabled ? 'success' : 'neutral';
  const statusLabel = provider.enabled ? '可用' : '不可用';
  const providerLabel = provider.type === 'ollama' ? 'Ollama' : provider.type === 'openai_compatible' ? 'OpenAI' : provider.type;

  return (
    <div
      className="flex items-center gap-3 rounded-[10px] px-3 py-2"
      style={{ background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.5))' }}
    >
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span
            className="text-[13px] font-medium truncate"
            style={{ color: 'var(--pm-text-primary)' }}
          >
            {provider.name}
          </span>
          <span
            className="text-[11px] shrink-0"
            style={{ color: 'var(--pm-text-tertiary)' }}
          >
            {provider.modelId}
          </span>
        </div>
        <span
          className="text-[11px]"
          style={{ color: 'var(--pm-text-tertiary)' }}
        >
          {providerLabel} · {TIER_LABELS[provider.tier]}
        </span>
      </div>
      <StatusBadge tone={statusTone} label={statusLabel} />
    </div>
  );
}

function statusTone(status: string): 'success' | 'warning' | 'danger' | 'neutral' {
  if (status === 'exported' || status === 'distilled') return 'success';
  if (status === 'distilling') return 'warning';
  return 'neutral';
}

function statusLabel(status: string): string {
  if (status === 'exported') return '已入库';
  if (status === 'distilled') return '已整理';
  if (status === 'distilling') return '整理中';
  if (status === 'archived') return '已归档';
  return '待整理';
}

function formatTime(ts: number): string {
  const d = new Date(ts * 1000);
  return d.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}
