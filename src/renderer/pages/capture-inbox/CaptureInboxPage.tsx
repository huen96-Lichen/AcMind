import { useCallback, useEffect, useState } from 'react';
import { Button, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon, type PinStackIconName } from '../../design-system/icons';
import { AddCaptureItemDialog } from '../../components/capture-inbox/AddCaptureItemDialog';
import { CaptureItemDetail } from '../../components/capture-inbox/CaptureItemDetail';
import { useToast } from '../../components/shared/ToastViewport';
import type { SourceItem, CaptureItem } from '../../../shared/types';

const STATUS_LABELS: Record<string, string> = {
  inbox: '待整理',
  distilling: '整理中',
  distilled: '已整理',
  exported: '已入库',
  archived: '已归档',
};

const STATUS_TONES: Record<string, 'success' | 'warning' | 'danger' | 'neutral' | 'processing'> = {
  inbox: 'warning',
  distilling: 'processing',
  distilled: 'success',
  exported: 'success',
  archived: 'neutral',
};

export function CaptureInboxPage(): JSX.Element {
  const { addToast } = useToast();
  const [items, setItems] = useState<SourceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [selectedItem, setSelectedItem] = useState<SourceItem | null>(null);

  const loadItems = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await window.acmind.sourceItems.list({});
      setItems(result);
    } catch (err) {
      setError('加载失败，请稍后重试。');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadItems();
  }, [loadItems]);

  useEffect(() => {
    const unsubscribe = window.acmind.onRecordsChanged(() => {
      void loadItems();
    });
    return unsubscribe;
  }, [loadItems]);

  const handleCreateCaptureItem = useCallback(async (data: Parameters<NonNullable<React.ComponentProps<typeof AddCaptureItemDialog>['onCreate']>>[0]) => {
    const result = await window.acmind.capture.record({
      sourceType: data.type === 'text' ? 'manual_text' : data.type === 'image' ? 'image' : 'unknown_file',
      text: data.rawText,
      filePath: data.filePath,
      url: data.sourceUrl,
      title: data.title,
    });
    if (result.success) {
      addToast('已收集', 'success');
      void loadItems();
    }
    return { id: result.sourceItemId, type: data.type, status: 'inbox' } as unknown as CaptureItem;
  }, [loadItems, addToast]);

  const handleDelete = useCallback(async (id: string) => {
    try {
      await window.acmind.sourceItems.delete(id);
      addToast('已删除', 'success');
      void loadItems();
      if (selectedItem?.id === id) {
        setSelectedItem(null);
      }
    } catch {
      addToast('删除失败', 'error');
    }
  }, [loadItems, addToast, selectedItem]);

  const handleCollect = useCallback(async (type: 'clipboard' | 'file' | 'screenshot' | 'audio') => {
    try {
      if (type === 'clipboard') {
        await window.acmind.capture.collectClipboard();
        addToast('已从剪贴板收集', 'success');
      } else if (type === 'file') {
        await window.acmind.capture.collectFile({ filePath: '' });
      } else if (type === 'screenshot') {
        await window.acmind.capture.takeScreenshot();
        addToast('截图已收集', 'success');
      } else if (type === 'audio') {
        addToast('录音功能开发中', 'info');
      }
      void loadItems();
    } catch {
      addToast('收集失败', 'error');
    }
  }, [loadItems, addToast]);

  const formatTime = (ts: number) => {
    const diff = Math.floor((Date.now() / 1000 - ts));
    if (diff < 60) return '刚刚';
    if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} 小时前`;
    return new Date(ts * 1000).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
  };

  if (loading) {
    return (
      <PageShell>
        <div className="px-6 pt-5">
          <PageHeader title="收集" description="把内容放进来" />
        </div>
        <div className="flex items-center justify-center" style={{ minHeight: 400 }}>
          <LoadingState title="正在加载" description="正在读取收集内容。" />
        </div>
      </PageShell>
    );
  }

  if (error) {
    return (
      <PageShell>
        <div className="px-6 pt-5">
          <PageHeader title="收集" description="把内容放进来" />
        </div>
        <ErrorState
          title="加载失败"
          reason={error}
          suggestion="请稍后重试。"
          action={{ label: '重新加载', onClick: () => void loadItems() }}
        />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <div className="px-6 pt-5">
        <PageHeader
          title="收集"
          description="把内容放进来"
          actions={
            <Button
              variant="primary"
              size="sm"
              leadingIcon={<PinStackIcon name="act-quick-capture" size={14} />}
              onClick={() => setDialogOpen(true)}
            >
              新建
            </Button>
          }
        />
      </div>

      <div className="px-6 pb-6 flex flex-col gap-4">
        <Section title="收集方式" compact>
          <div className="grid grid-cols-4 gap-2">
            {([
              { type: 'clipboard' as const, label: '粘贴内容', icon: 'filled-clipboard' as PinStackIconName },
              { type: 'file' as const, label: '导入文件', icon: 'filled-file-import' as PinStackIconName },
              { type: 'screenshot' as const, label: '截图', icon: 'capture' as PinStackIconName },
              { type: 'audio' as const, label: '录音', icon: 'record' as PinStackIconName },
            ]).map((action) => (
              <button
                key={action.type}
                type="button"
                className="flex flex-col items-center gap-1.5 rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-white/50 p-3 transition-all hover:border-[color:var(--pm-brand)] hover:bg-[color:var(--pm-brand-soft)]"
                onClick={() => void handleCollect(action.type)}
              >
                <PinStackIcon name={action.icon} size={20} style={{ color: 'var(--pm-text-secondary)' }} />
                <span className="text-[12px] font-medium" style={{ color: 'var(--pm-text-secondary)' }}>
                  {action.label}
                </span>
              </button>
            ))}
          </div>
        </Section>

        <Section title="最近收集" compact>
          {items.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="filled-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="还没有内容"
              description="粘贴或导入开始"
            />
          ) : (
            <div className="flex flex-col gap-1.5">
              {items.map((item) => (
                <div
                  key={item.id}
                  className="flex items-center gap-3 rounded-[10px] px-3 py-2.5 cursor-pointer"
                  style={{ background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.5))' }}
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
                  <StatusBadge
                    tone={STATUS_TONES[item.status] ?? 'neutral'}
                    label={STATUS_LABELS[item.status] ?? item.status}
                  />
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={(e) => { e.stopPropagation(); setSelectedItem(item); }}
                    >
                      查看
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={(e) => { e.stopPropagation(); void handleDelete(item.id); }}
                    >
                      删除
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </Section>
      </div>

      <AddCaptureItemDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onCreate={(data) => handleCreateCaptureItem(data)}
      />

      {selectedItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
          <div className="w-full max-w-lg rounded-[16px] bg-white shadow-xl overflow-hidden">
            <div className="flex items-center justify-between px-4 py-3 border-b border-[color:var(--pm-border-subtle)]">
              <h3 className="text-[14px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
                内容详情
              </h3>
              <Button variant="ghost" size="sm" onClick={() => setSelectedItem(null)}>
                关闭
              </Button>
            </div>
            <div className="p-4">
              <CaptureItemDetail
                item={selectedItem as unknown as CaptureItem}
                onUpdate={async (id, patch) => {
                  await window.acmind.sourceItems.delete(id);
                  return selectedItem as unknown as CaptureItem;
                }}
                onDelete={async (id) => {
                  await handleDelete(id);
                  return true;
                }}
              />
            </div>
          </div>
        </div>
      )}
    </PageShell>
  );
}
