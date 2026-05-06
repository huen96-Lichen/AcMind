import { useEffect, useMemo, useRef, useState } from 'react';
import { Button, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import type { ProviderConfig } from '../../../shared/types';

interface AgentTopbarProps {
  currentProvider: ProviderConfig | null;
  currentSessionTitle: string;
  pendingCount: number;
  mockMode: boolean;
  providers: ProviderConfig[];
  onOpenHistory: () => void;
  onOpenTasks: () => void;
  onOpenKnowledgeBase: () => void;
  onOpenModelSettings: () => void;
  onSelectProvider: (providerId: string) => void;
}

function formatProviderLabel(provider: ProviderConfig | null): string {
  if (!provider) return '未绑定 Provider';
  return `${provider.name} · ${provider.modelId}`;
}

export function AgentTopbar({
  currentProvider,
  currentSessionTitle,
  pendingCount,
  mockMode,
  providers,
  onOpenHistory,
  onOpenTasks,
  onOpenKnowledgeBase,
  onOpenModelSettings,
  onSelectProvider,
}: AgentTopbarProps): JSX.Element {
  const [modelOpen, setModelOpen] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (!modelOpen) return;
      if (popoverRef.current?.contains(event.target as Node)) return;
      setModelOpen(false);
    };

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setModelOpen(false);
      }
    };

    window.addEventListener('mousedown', handleClickOutside);
    window.addEventListener('keydown', handleEscape);
    return () => {
      window.removeEventListener('mousedown', handleClickOutside);
      window.removeEventListener('keydown', handleEscape);
    };
  }, [modelOpen]);

  const providerSummary = useMemo(() => formatProviderLabel(currentProvider), [currentProvider]);

  return (
    <header className="relative flex h-[72px] items-center justify-between border-b border-[rgba(15,23,42,0.08)] bg-white/80 px-8 backdrop-blur-xl">
      <div className="min-w-0">
        <div className="flex items-center gap-3">
          <div className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-[color:var(--pm-primary-soft)] text-[color:var(--pm-primary)]">
            <AcMindIcon name="ai-workspace" size={18} />
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h1 className="truncate text-[20px] font-semibold tracking-[-0.02em] text-[color:var(--pm-text-primary)]">
                AcMind Agent
              </h1>
              {mockMode ? <StatusBadge tone="mock" label="Mock 模式" dot={false} /> : null}
            </div>
            <p className="mt-0.5 truncate text-[13px] leading-5 text-[color:var(--pm-text-secondary)]">
              你的桌面智能助手
            </p>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" onClick={onOpenHistory}>
          历史
        </Button>
        <Button variant="ghost" size="sm" onClick={onOpenTasks}>
          待处理 {pendingCount}
        </Button>

        <div className="relative" ref={popoverRef}>
          <Button variant="ghost" size="sm" onClick={() => setModelOpen((current) => !current)}>
            模型
          </Button>
          {modelOpen ? (
            <div className="absolute right-0 top-full z-40 mt-3 w-[360px] overflow-hidden rounded-[22px] border border-[rgba(15,23,42,0.08)] bg-white/94 shadow-[0_24px_72px_rgba(15,23,42,0.12)] backdrop-blur-2xl">
              <div className="border-b border-[rgba(15,23,42,0.06)] px-5 py-4">
                <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[color:var(--pm-text-tertiary)]">
                  模型状态
                </p>
                <div className="mt-2 space-y-2">
                  <div>
                    <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">Provider</p>
                    <p className="mt-0.5 text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                      {providerSummary}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">会话</p>
                    <p className="mt-0.5 truncate text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                      {currentSessionTitle || '未创建'}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">模式</p>
                    <p className="mt-0.5 text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                      {mockMode ? 'Mock 模式' : '真实模型'}
                    </p>
                  </div>
                </div>
              </div>

              <div className="max-h-[260px] overflow-y-auto p-3">
                <div className="px-2 pb-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-[color:var(--pm-text-tertiary)]">
                  可用 Provider
                </div>
                <div className="space-y-1">
                  {providers.length > 0 ? (
                    providers.map((provider) => {
                      const active = provider.id === currentProvider?.id;
                      return (
                        <button
                          key={provider.id}
                          type="button"
                          onClick={() => {
                            onSelectProvider(provider.id);
                            setModelOpen(false);
                          }}
                          className={`flex w-full items-start justify-between gap-3 rounded-[16px] border px-3 py-2 text-left transition-colors ${
                            active
                              ? 'border-[rgba(255,107,43,0.22)] bg-[color:var(--pm-primary-soft)]'
                              : 'border-transparent hover:bg-[rgba(17,24,39,0.04)]'
                          }`}
                        >
                          <div className="min-w-0">
                            <div className="truncate text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                              {provider.name}
                            </div>
                            <div className="truncate text-[12px] text-[color:var(--pm-text-secondary)]">
                              {provider.modelId}
                            </div>
                          </div>
                          {active ? (
                            <span className="rounded-full bg-[rgba(255,107,43,0.14)] px-2 py-0.5 text-[11px] font-medium text-[color:var(--pm-primary)]">
                              当前
                            </span>
                          ) : null}
                        </button>
                      );
                    })
                  ) : (
                    <div className="px-2 py-3 text-[12px] text-[color:var(--pm-text-tertiary)]">
                      还没有绑定 Provider
                    </div>
                  )}
                </div>
              </div>

              <div className="border-t border-[rgba(15,23,42,0.06)] p-3">
                <Button variant="secondary" size="sm" className="w-full" onClick={onOpenModelSettings}>
                  打开模型设置
                </Button>
              </div>
            </div>
          ) : null}
        </div>

        <Button variant="ghost" size="sm" onClick={onOpenKnowledgeBase}>
          知识库
        </Button>
      </div>
    </header>
  );
}
