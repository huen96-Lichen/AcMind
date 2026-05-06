import { useCallback, useMemo, useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { useSourceItems } from '../../hooks/useSourceItems';
import type { SourceItem } from '../../../shared/types';

// ─── Constants ───────────────────────────────────────────────────────────────

type FilterTab = 'all' | 'text' | 'image' | 'screenshot' | 'file' | 'webpage' | 'audio';

const FILTER_TABS: { key: FilterTab; label: string }[] = [
  { key: 'all', label: '全部' },
  { key: 'text', label: '文本' },
  { key: 'image', label: '图片' },
  { key: 'screenshot', label: '截图' },
  { key: 'file', label: '文件' },
  { key: 'webpage', label: '网页' },
  { key: 'audio', label: '音频' },
];

const STATUS_CONFIG: Record<string, { label: string; tone: 'info' | 'warning' | 'success' | 'neutral' }> = {
  inbox: { label: '待整理', tone: 'info' },
  distilling: { label: '整理中', tone: 'warning' },
  distilled: { label: '已整理', tone: 'success' },
  exported: { label: '已入库', tone: 'success' },
  archived: { label: '已归档', tone: 'neutral' },
};

const SOURCE_LABELS: Record<string, string> = {
  manual: '手动输入',
  clipboard: '剪贴板',
  screenshot: '截图',
  vault_import: 'Vault',
  audio: '音频',
  url_paste: 'URL',
};

function getTypeIcon(item: SourceItem): string {
  if (item.source === 'screenshot') return 'capture';
  if (item.type === 'text') return 'filled-clipboard';
  if (item.type === 'image') return 'image';
  if (item.type === 'url') return 'filled-link';
  if (item.source === 'audio') return 'record';
  return 'filled-file-import';
}

function formatRelativeTime(ts: number): string {
  const diff = Math.floor(Date.now() / 1000 - ts);
  if (diff < 60) return '刚刚';
  if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} 小时前`;
  if (diff < 86400 * 30) return `${Math.floor(diff / 86400)} 天前`;
  return new Date(ts * 1000).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
}

function toast(message: string, type: 'success' | 'error' | 'info' = 'success') {
  window.dispatchEvent(new CustomEvent('acmind:toast', { detail: { message, type } }));
}

// ─── Component ───────────────────────────────────────────────────────────────

export function StagingPoolPage(): JSX.Element {
  const {
    items,
    loading,
    error,
    refresh,
    filter,
    setFilter,
    searchQuery,
    setSearchQuery,
    selectedItem,
    setSelectedItem,
    deleteItem,
    updateItem,
  } = useSourceItems();

  const [contentText, setContentText] = useState<string | null>(null);
  const [loadingContent, setLoadingContent] = useState(false);
  const [distillingIds, setDistillingIds] = useState<Set<string>>(new Set());

  // ── Filter counts ──
  const filterCounts = useMemo(() => {
    const counts: Record<string, number> = { all: items.length };
    for (const item of items) {
      if (item.type === 'text') counts.text = (counts.text || 0) + 1;
      if (item.type === 'image') counts.image = (counts.image || 0) + 1;
      if (item.source === 'screenshot') counts.screenshot = (counts.screenshot || 0) + 1;
      if (item.source === 'vault_import') counts.file = (counts.file || 0) + 1;
      if (item.type === 'url') counts.webpage = (counts.webpage || 0) + 1;
      if (item.source === 'audio') counts.audio = (counts.audio || 0) + 1;
    }
    return counts;
  }, [items]);

  // ── Sorted items (newest first) ──
  const sortedItems = useMemo(
    () => [...items].sort((a, b) => b.createdAt - a.createdAt),
    [items],
  );

  // ── Load content for detail panel ──
  const handleSelectItem = useCallback(async (item: SourceItem) => {
    setSelectedItem(item);
    setContentText(null);
    setLoadingContent(true);
    try {
      const content = await window.acmind.sourceItems.getContent(item.id);
      setContentText(content?.text ?? null);
    } catch {
      setContentText(null);
    } finally {
      setLoadingContent(false);
    }
  }, [setSelectedItem]);

  // ── Actions ──

  const handleCopyContent = useCallback(async () => {
    if (!selectedItem) return;
    const text = contentText || selectedItem.previewText || '';
    if (!text) {
      toast('没有可复制的内容', 'info');
      return;
    }
    try {
      await navigator.clipboard.writeText(text);
      toast('已复制到剪贴板');
    } catch {
      toast('复制失败', 'error');
    }
  }, [selectedItem, contentText]);

  const handleDelete = useCallback(async () => {
    if (!selectedItem) return;
    const ok = await deleteItem(selectedItem.id);
    if (ok) toast('已删除');
    else toast('删除失败', 'error');
  }, [selectedItem, deleteItem]);

  const handleOpenFile = useCallback(() => {
    if (!selectedItem?.contentPath) return;
    window.acmind.workbench.revealInFinder(selectedItem.contentPath);
  }, [selectedItem]);

  // ── Send single item to distill ──

  const handleSendToDistill = useCallback(async () => {
    if (!selectedItem) return;
    const id = selectedItem.id;
    setDistillingIds((prev) => new Set(prev).add(id));
    try {
      await window.acmind.sourceItems.update(id, { status: 'distilling' });
      await window.acmind.distill.run([id], ['summarize']);
      toast('已送入整理，完成后可在「整理」页面查看', 'success');
    } catch (err) {
      const msg = err instanceof Error ? err.message : '送入整理失败';
      toast(msg, 'error');
      try {
        await window.acmind.sourceItems.update(id, { status: 'inbox' });
      } catch { /* ignore */ }
    } finally {
      setDistillingIds((prev) => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
    }
  }, [selectedItem]);

  // ── Send all inbox items to distill ──

  const handleSendAllToDistill = useCallback(async () => {
    const inboxItems = items.filter((i) => i.status === 'inbox');
    if (inboxItems.length === 0) {
      toast('没有待整理的内容', 'info');
      return;
    }
    const ids = inboxItems.map((i) => i.id);
    setDistillingIds((prev) => new Set([...prev, ...ids]));
    for (const id of ids) {
      try {
        await window.acmind.sourceItems.update(id, { status: 'distilling' });
      } catch { /* continue */ }
    }
    try {
      await window.acmind.distill.run(ids, ['summarize']);
      toast(`已提交 ${ids.length} 条整理任务`, 'success');
    } catch (err) {
      const msg = err instanceof Error ? err.message : '批量整理失败';
      toast(msg, 'error');
      for (const id of ids) {
        try {
          await window.acmind.sourceItems.update(id, { status: 'inbox' });
        } catch { /* ignore */ }
      }
    } finally {
      setDistillingIds((prev) => {
        const next = new Set(prev);
        for (const id of ids) next.delete(id);
        return next;
      });
    }
  }, [items]);

  // ── Loading / Error states ──

  if (loading) {
    return (
      <PageShell>
        <ScrollContainer>
          <div className="flex items-center justify-center" style={{ minHeight: 420 }}>
            <LoadingState title="正在加载暂存池" description="正在读取内容列表。" />
          </div>
        </ScrollContainer>
      </PageShell>
    );
  }

  if (error) {
    return (
      <PageShell>
        <ScrollContainer>
          <ErrorState title="暂存池加载失败" reason={error} suggestion="请稍后重试。" action={{ label: '重新加载', onClick: () => void refresh() }} />
        </ScrollContainer>
      </PageShell>
    );
  }

  // ── Main layout ──

  return (
    <PageShell>
      <ScrollContainer>
        <PageHeader
          title="暂存池"
          description="所有收集的内容都在这里，等待整理"
          actions={
            <div className="flex items-center gap-2">
              {selectedItem && (
                <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="filled-delete" size={14} />} onClick={() => void handleDelete()}>
                  删除选中
                </Button>
              )}
              <Button variant="primary" size="sm" leadingIcon={<AcMindIcon name="sb-ai-process" size={14} />} onClick={() => void handleSendAllToDistill()} disabled={distillingIds.size > 0}>
                送入整理
              </Button>
            </div>
          }
        />

        {/* ── Filter tabs + Search ── */}
        <div className="flex items-center gap-4 px-6 pt-2">
          <div className="flex items-center gap-1">
            {FILTER_TABS.map((tab) => (
              <button
                key={tab.key}
                type="button"
                className={`rounded-[8px] px-3 py-1.5 text-[13px] font-medium transition-colors ${
                  filter === tab.key
                    ? 'bg-[color:var(--pm-brand)] text-white'
                    : 'text-[color:var(--text-muted)] hover:bg-[color:var(--pm-bg-subtle)]'
                }`}
                onClick={() => setFilter(tab.key)}
              >
                {tab.label}
                {filterCounts[tab.key] !== undefined && filterCounts[tab.key] > 0 ? (
                  <span className="ml-1 text-[11px] opacity-70">{filterCounts[tab.key]}</span>
                ) : null}
              </button>
            ))}
          </div>
          <div className="flex-1" />
          <div className="w-[220px]">
            <input
              type="text"
              placeholder="搜索标题或内容..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full rounded-[8px] border border-[color:var(--border-light)] bg-white/70 px-3 py-1.5 text-[13px] outline-none placeholder:text-[color:var(--text-muted)]"
            />
          </div>
        </div>

        {/* ── Main: List + Detail ── */}
        <div className="grid min-h-0 flex-1 grid-cols-[minmax(0,1fr)_340px] gap-4 px-6 py-4">
          {/* ── Left: Item list ── */}
          <div className="flex flex-col gap-2 overflow-auto" style={{ maxHeight: 'calc(100vh - 220px)' }}>
            {sortedItems.length === 0 ? (
              <EmptyState
                icon={<AcMindIcon name="filled-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
                title="还没有收集内容"
                description="你可以输入文本、粘贴剪贴板、导入文件或截图保存到这里。"
              />
            ) : (
              sortedItems.map((item) => {
                const statusCfg = STATUS_CONFIG[item.status] ?? { label: item.status, tone: 'neutral' as const };
                return (
                  <Card
                    key={item.id}
                    variant="interactive"
                    className={selectedItem?.id === item.id ? 'ring-2 ring-[color:var(--pm-brand)]' : ''}
                    onClick={() => void handleSelectItem(item)}
                  >
                    <div className="flex items-start gap-3">
                      <div className="mt-0.5 shrink-0">
                        <AcMindIcon name={getTypeIcon(item) as 'filled-clipboard'} size={16} style={{ color: 'var(--text-muted)' }} />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                            {item.title || '未命名'}
                          </p>
                          <span className="shrink-0 rounded-full px-2 py-0.5 text-[11px] bg-[color:var(--pm-bg-subtle)] text-[color:var(--text-muted)]">
                            {SOURCE_LABELS[item.source] ?? item.source}
                          </span>
                        </div>
                        <p className="mt-1 line-clamp-2 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                          {item.previewText || '暂无预览'}
                        </p>
                        <div className="mt-1.5 flex items-center gap-2">
                          <span className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
                            {formatRelativeTime(item.createdAt)}
                          </span>
                          <StatusBadge tone={statusCfg.tone} label={statusCfg.label} dot={false} />
                        </div>
                      </div>
                    </div>
                  </Card>
                );
              })
            )}
          </div>

          {/* ── Right: Detail panel ── */}
          <Section title="详情" compact>
            {selectedItem ? (
              <Card variant="base" className="flex flex-col gap-3">
                {/* Title & type */}
                <div>
                  <p className="text-[15px] font-semibold" style={{ color: 'var(--text-title)' }}>
                    {selectedItem.title || '未命名'}
                  </p>
                  <div className="mt-1 flex items-center gap-2">
                    <AcMindIcon name={getTypeIcon(selectedItem) as 'filled-clipboard'} size={13} style={{ color: 'var(--text-muted)' }} />
                    <span className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
                      {selectedItem.type} · {SOURCE_LABELS[selectedItem.source] ?? selectedItem.source}
                    </span>
                  </div>
                </div>

                {/* Meta info */}
                <div className="flex flex-col gap-1.5 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                  <div className="flex items-center gap-2">
                    <span className="w-14 shrink-0">来源</span>
                    <span>{SOURCE_LABELS[selectedItem.source] ?? selectedItem.source}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="w-14 shrink-0">创建时间</span>
                    <span>{new Date(selectedItem.createdAt * 1000).toLocaleString('zh-CN')}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="w-14 shrink-0">状态</span>
                    <StatusBadge
                      tone={STATUS_CONFIG[selectedItem.status]?.tone ?? 'neutral'}
                      label={STATUS_CONFIG[selectedItem.status]?.label ?? selectedItem.status}
                      dot={false}
                    />
                  </div>
                  {selectedItem.contentPath && (
                    <div className="flex items-center gap-2">
                      <span className="w-14 shrink-0">文件路径</span>
                      <span className="truncate">{selectedItem.contentPath}</span>
                    </div>
                  )}
                  {selectedItem.originalUrl && (
                    <div className="flex items-center gap-2">
                      <span className="w-14 shrink-0">URL</span>
                      <a href={selectedItem.originalUrl} target="_blank" rel="noopener noreferrer" className="truncate text-[color:var(--pm-brand)] hover:underline">
                        {selectedItem.originalUrl}
                      </a>
                    </div>
                  )}
                </div>

                {/* Content preview */}
                <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] p-3">
                  <p className="mb-1 text-[11px] font-medium" style={{ color: 'var(--text-muted)' }}>内容预览</p>
                  {loadingContent ? (
                    <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>加载中...</p>
                  ) : contentText ? (
                    <p className="max-h-[200px] overflow-auto whitespace-pre-wrap text-[13px]" style={{ color: 'var(--text-body)' }}>
                      {contentText}
                    </p>
                  ) : selectedItem.previewText ? (
                    <p className="max-h-[200px] overflow-auto whitespace-pre-wrap text-[13px]" style={{ color: 'var(--text-body)' }}>
                      {selectedItem.previewText}
                    </p>
                  ) : (
                    <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>暂无文本内容</p>
                  )}
                </div>

                {/* Actions */}
                <div className="flex flex-wrap gap-2">
                  <Button size="sm" variant="secondary" leadingIcon={<AcMindIcon name="copy" size={14} />} onClick={() => void handleCopyContent()}>
                    复制内容
                  </Button>
                  <Button size="sm" variant="ghost" leadingIcon={<AcMindIcon name="filled-delete" size={14} />} onClick={() => void handleDelete()}>
                    删除
                  </Button>
                  {selectedItem.status === 'inbox' && (
                    <Button
                      size="sm"
                      variant="primary"
                      leadingIcon={<AcMindIcon name="sb-ai-process" size={14} />}
                      onClick={() => void handleSendToDistill()}
                      disabled={distillingIds.has(selectedItem.id)}
                    >
                      {distillingIds.has(selectedItem.id) ? '整理中...' : '送入整理'}
                    </Button>
                  )}
                  {selectedItem.contentPath && (
                    <Button size="sm" variant="ghost" leadingIcon={<AcMindIcon name="filled-file-import" size={14} />} onClick={handleOpenFile}>
                      打开文件
                    </Button>
                  )}
                </div>
              </Card>
            ) : (
              <EmptyState title="选择一条内容" description="查看详情、内容预览和操作。" />
            )}
          </Section>
        </div>
      </ScrollContainer>
    </PageShell>
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function ScrollContainer({ children }: { children: React.ReactNode }): JSX.Element {
  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-auto">
      {children}
    </div>
  );
}
