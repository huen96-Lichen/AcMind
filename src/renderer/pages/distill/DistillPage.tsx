import { useCallback, useEffect, useState } from 'react';
import { Button, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { useToast } from '../../components/shared/ToastViewport';
import type { SourceItem } from '../../../shared/types';

type OrganizeTab = 'pending' | 'confirming' | 'done';

const TABS: { key: OrganizeTab; label: string }[] = [
  { key: 'pending', label: '待整理' },
  { key: 'confirming', label: '待确认' },
  { key: 'done', label: '已完成' },
];

const STATUS_MAP: Record<OrganizeTab, string[]> = {
  pending: ['inbox'],
  confirming: ['distilled'],
  done: ['exported'],
};

export function DistillPage(): JSX.Element {
  const { addToast } = useToast();
  const [activeTab, setActiveTab] = useState<OrganizeTab>('confirming');
  const [items, setItems] = useState<SourceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedItem, setSelectedItem] = useState<SourceItem | null>(null);

  const loadItems = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const allItems = await window.pinmind.sourceItems.list({});
      const statuses = STATUS_MAP[activeTab];
      const filtered = allItems.filter((item) => statuses.includes(item.status));
      setItems(filtered);
      if (filtered.length > 0 && !selectedItem) {
        setSelectedItem(filtered[0]);
      } else if (filtered.length === 0) {
        setSelectedItem(null);
      }
    } catch (err) {
      setError('加载失败，请稍后重试。');
    } finally {
      setLoading(false);
    }
  }, [activeTab]);

  useEffect(() => {
    void loadItems();
  }, [loadItems]);

  useEffect(() => {
    const unsubscribe = window.pinmind.onRecordsChanged(() => {
      void loadItems();
    });
    return unsubscribe;
  }, [loadItems]);

  const handleDistill = async (item: SourceItem) => {
    try {
      addToast('整理任务已提交', 'success');
      void loadItems();
    } catch {
      addToast('整理失败', 'error');
    }
  };

  const handleConfirmExport = async (item: SourceItem) => {
    try {
      const outputs = await window.pinmind.distilledOutputs.list({ sourceItemId: item.id });
      const preferredOutput =
        outputs.find((output) => output.operation === 'summarize' || Boolean(output.contentMarkdown)) ??
        outputs[0] ??
        null;

      if (!preferredOutput) {
        throw new Error('未找到可入库的蒸馏结果');
      }

      await window.pinmind.export.single(preferredOutput.id);
      addToast('已入库', 'success');
      void loadItems();
    } catch (error) {
      addToast(error instanceof Error ? error.message : '入库失败', 'error');
    }
  };

  const handleSkip = async (item: SourceItem) => {
    try {
      await window.pinmind.sourceItems.delete(item.id);
      addToast('已跳过', 'success');
      void loadItems();
    } catch {
      addToast('操作失败', 'error');
    }
  };

  const handleRetry = async (item: SourceItem) => {
    try {
      addToast('已提交重新整理', 'success');
      void loadItems();
    } catch {
      addToast('操作失败', 'error');
    }
  };

  const formatTime = (ts: number) => {
    const diff = Math.floor((Date.now() / 1000 - ts));
    if (diff < 60) return '刚刚';
    if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} 小时前`;
    return new Date(ts * 1000).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
  };

  return (
    <PageShell className="flex h-full flex-col overflow-hidden">
      <div className="px-6 pt-5">
        <PageHeader title="整理" description="确认 AI 整理结果" />
      </div>

      <div className="px-6 pb-2">
        <div className="flex gap-1">
          {TABS.map((tab) => (
            <Button
              key={tab.key}
              variant={activeTab === tab.key ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => { setActiveTab(tab.key); setSelectedItem(null); }}
            >
              {tab.label}
            </Button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center flex-1">
          <LoadingState title="正在加载" description="正在读取整理内容。" />
        </div>
      ) : error ? (
        <ErrorState
          title="加载失败"
          reason={error}
          suggestion="请稍后重试。"
          action={{ label: '重新加载', onClick: () => void loadItems() }}
        />
      ) : items.length === 0 ? (
        <div className="flex items-center justify-center flex-1 px-6">
          <EmptyState
            icon={<PinStackIcon name="sb-ai-process" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title={emptyTitle(activeTab)}
            description={emptyDesc(activeTab)}
            action={activeTab === 'pending' ? {
              label: '去收集',
              onClick: () => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'capture-inbox' } })),
            } : undefined}
          />
        </div>
      ) : (
        <div className="flex min-h-0 flex-1 px-6 pb-4 gap-4">
          <div className="flex flex-col min-w-0 w-[35%] shrink-0 gap-1.5 overflow-auto">
            {items.map((item) => (
              <button
                key={item.id}
                type="button"
                className={`flex items-center gap-3 rounded-[10px] px-3 py-2.5 text-left transition-all ${
                  selectedItem?.id === item.id
                    ? 'bg-[color:var(--pm-brand-soft)] border border-[color:var(--pm-brand)]'
                    : 'bg-[color:var(--pm-bg-surface-soft,rgba(255,255,255,0.5))] border border-transparent hover:border-[color:var(--pm-border-light)]'
                }`}
                onClick={() => setSelectedItem(item)}
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
                    {item.title || item.previewText || '未命名内容'}
                  </p>
                  <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                    {formatTime(item.createdAt)}
                  </p>
                </div>
              </button>
            ))}
          </div>

          <div className="flex min-w-0 flex-1 flex-col rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-white/50 overflow-hidden">
            {selectedItem ? (
              <>
                <div className="shrink-0 px-4 py-3 border-b border-[color:var(--pm-border-subtle)]">
                  <div className="flex items-center justify-between">
                    <h3 className="text-[14px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
                      {selectedItem.title || '未命名内容'}
                    </h3>
                    <StatusBadge
                      tone={statusTone(selectedItem.status)}
                      label={statusLabel(selectedItem.status)}
                    />
                  </div>
                </div>
                <div className="flex-1 min-h-0 overflow-auto p-4">
                  <p className="text-[13px] leading-relaxed" style={{ color: 'var(--pm-text-secondary)' }}>
                    {selectedItem.previewText || '暂无内容'}
                  </p>
                </div>
                <div className="shrink-0 px-4 py-3 border-t border-[color:var(--pm-border-subtle)] flex items-center gap-2">
                  {activeTab === 'pending' && (
                    <Button variant="primary" size="sm" onClick={() => void handleDistill(selectedItem)}>
                      开始整理
                    </Button>
                  )}
                  {activeTab === 'confirming' && (
                    <>
                      <Button variant="primary" size="sm" onClick={() => void handleConfirmExport(selectedItem)}>
                        确认并入库
                      </Button>
                      <Button variant="secondary" size="sm" onClick={() => void handleDistill(selectedItem)}>
                        重新整理
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => void handleSkip(selectedItem)}>
                        跳过
                      </Button>
                    </>
                  )}
                </div>
              </>
            ) : (
              <div className="flex items-center justify-center flex-1">
                <EmptyState
                  icon={<PinStackIcon name="sb-ai-process" size={24} style={{ color: 'var(--pm-text-tertiary)' }} />}
                  title="选择一条内容"
                  description="在左侧列表中选择查看详情"
                />
              </div>
            )}
          </div>
        </div>
      )}
    </PageShell>
  );
}

function emptyTitle(tab: OrganizeTab): string {
  if (tab === 'pending') return '还没有待整理内容';
  if (tab === 'confirming') return '还没有整理结果';
  return '还没有已完成内容';
}

function emptyDesc(tab: OrganizeTab): string {
  if (tab === 'pending') return '先收集一条内容';
  if (tab === 'confirming') return '先整理一条内容';
  return '确认后会出现在这里';
}

function statusTone(status: string): 'success' | 'warning' | 'danger' | 'neutral' | 'processing' {
  if (status === 'distilled' || status === 'exported') return 'success';
  if (status === 'distilling') return 'processing';
  if (status === 'inbox') return 'warning';
  return 'neutral';
}

function statusLabel(status: string): string {
  if (status === 'inbox') return '待整理';
  if (status === 'distilling') return '整理中';
  if (status === 'distilled') return '待确认';
  if (status === 'exported') return '已入库';
  if (status === 'archived') return '已归档';
  return status;
}
