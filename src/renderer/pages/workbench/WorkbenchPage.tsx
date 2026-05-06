/**
 * WorkbenchPage — 工作台
 *
 * 只负责 Obsidian 相关和知识沉淀相关流程。
 * 核心心智：收集 → 暂存 → 整理 → 确认 → 入库 Obsidian
 *
 * 内部 Tab：总览 / 快速入库 / 暂存区 / 整理中 / 待确认 / 知识库 / 处理日志
 */

import { useState, useCallback, useEffect, useMemo } from 'react';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  LoadingState,
  PageHeader,
  PageShell,
  Section,
  StatusBadge,
} from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { useSourceItems } from '../../hooks/useSourceItems';
import { useKnowledgeCards } from '../../hooks/useKnowledgeCards';
import { useProcessingHistory, type ProcessingHistoryItem } from '../../hooks/useProcessingHistory';
import type { SourceItem, KnowledgeCard } from '../../../shared/types';

// ─── Tab 定义 ─────────────────────────────────────────────────────

type WorkbenchTab = 'overview' | 'quick-import' | 'staging' | 'processing' | 'review' | 'knowledge' | 'logs';

const TABS: Array<{ key: WorkbenchTab; label: string; icon: string }> = [
  { key: 'overview', label: '总览', icon: 'filled-home' },
  { key: 'quick-import', label: '快速入库', icon: 'sb-inbox' },
  { key: 'staging', label: '暂存区', icon: 'sb-inbox' },
  { key: 'processing', label: '整理中', icon: 'sb-ai-process' },
  { key: 'review', label: '待确认', icon: 'sb-results' },
  { key: 'knowledge', label: '知识库', icon: 'sb-obsidian' },
  { key: 'logs', label: '处理日志', icon: 'sb-settings' },
];

const STATUS_CONFIG: Record<string, { label: string; tone: 'info' | 'warning' | 'success' | 'neutral' | 'danger' }> = {
  inbox: { label: '待整理', tone: 'info' },
  distilling: { label: '整理中', tone: 'warning' },
  distilled: { label: '已整理', tone: 'success' },
  exported: { label: '已入库', tone: 'success' },
  archived: { label: '已归档', tone: 'neutral' },
  error: { label: '失败', tone: 'danger' },
};

const SOURCE_LABELS: Record<string, string> = {
  manual: '手动输入',
  clipboard: '剪贴板',
  screenshot: '截图',
  vault_import: 'Vault',
  audio: '音频',
  url_paste: 'URL',
};

// ─── Main Component ───────────────────────────────────────────────

export function WorkbenchPage(): JSX.Element {
  const [activeTab, setActiveTab] = useState<WorkbenchTab>(() => {
    const tab = new URLSearchParams(window.location.search).get('tab');
    return isWorkbenchTab(tab) ? tab : 'overview';
  });

  useEffect(() => {
    const syncTabFromUrl = () => {
      const tab = new URLSearchParams(window.location.search).get('tab');
      if (isWorkbenchTab(tab)) setActiveTab(tab);
    };
    window.addEventListener('popstate', syncTabFromUrl);
    return () => window.removeEventListener('popstate', syncTabFromUrl);
  }, []);

  const handleTabChange = (tab: WorkbenchTab) => {
    setActiveTab(tab);
    const url = new URL(window.location.href);
    url.searchParams.set('tab', tab);
    window.history.replaceState({}, '', url.toString());
  };

  return (
    <PageShell>
      <PageHeader
        title="工作台"
        description="Obsidian 入库和知识沉淀 — 收集 · 暂存 · 整理 · 确认 · 入库"
      />

      {/* Tab Navigation */}
      <div className="flex items-center gap-1 px-6 pt-2">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            className={`flex items-center gap-1.5 rounded-[8px] px-3 py-1.5 text-[13px] font-medium transition-colors ${
              activeTab === tab.key
                ? 'bg-[color:var(--pm-brand)] text-white'
                : 'text-[color:var(--text-muted)] hover:bg-[color:var(--pm-bg-subtle)]'
            }`}
            onClick={() => handleTabChange(tab.key)}
          >
            <AcMindIcon name={tab.icon as any} size={14} />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <ScrollContainer className="px-6 py-4">
        {activeTab === 'overview' && <OverviewTab />}
        {activeTab === 'quick-import' && <QuickImportTab />}
        {activeTab === 'staging' && <StagingTab />}
        {activeTab === 'processing' && <ProcessingTab />}
        {activeTab === 'review' && <ReviewTab />}
        {activeTab === 'knowledge' && <KnowledgeTab />}
        {activeTab === 'logs' && <LogsTab />}
      </ScrollContainer>
    </PageShell>
  );
}

function isWorkbenchTab(tab: string | null): tab is WorkbenchTab {
  return tab === 'overview' || tab === 'quick-import' || tab === 'staging' || tab === 'processing' || tab === 'review' || tab === 'knowledge' || tab === 'logs';
}

// ─── 3.1 总览 Tab ─────────────────────────────────────────────────

function OverviewTab(): JSX.Element {
  const { items, loading, error, refresh } = useSourceItems();
  const { cards: knowledgeItems, loading: knowledgeLoading, error: knowledgeError, refresh: refreshKnowledge } = useKnowledgeCards();

  const stats = useMemo(() => {
    const pending = items.filter((i) => i.status === 'inbox').length;
    const processing = items.filter((i) => i.status === 'distilling').length;
    const review = items.filter((i) => i.status === 'distilled').length;
    const exported = items.filter((i) => i.status === 'exported').length;
    return { pending, processing, review, exported };
  }, [items]);

  const recentItems = useMemo(() => {
    return [...items].sort((a, b) => b.createdAt - a.createdAt).slice(0, 5);
  }, [items]);

  const recentKnowledge = useMemo(() => {
    return [...knowledgeItems].sort((a, b) => b.createdAt - a.updatedAt).slice(0, 5);
  }, [knowledgeItems]);

  const navigate = (view: string, tab?: string) => {
    window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view, tab } }));
  };

  if (loading || knowledgeLoading) {
    return <LoadingState title="加载中" description="正在读取工作台数据..." />;
  }

  if (error || knowledgeError) {
    return <ErrorState title="加载失败" reason={error || knowledgeError || '未知错误'} suggestion="请检查网络连接或稍后重试" action={{ label: '重试', onClick: () => { refresh(); refreshKnowledge(); } }} />;
  }

  return (
    <div className="flex flex-col gap-5">
      {/* 统计卡片 */}
      <Section title="整体状态" compact>
        <div className="grid grid-cols-4 gap-3">
          <StatCard value={stats.pending} label="待处理" tone="warning" />
          <StatCard value={stats.processing} label="整理中" tone="info" />
          <StatCard value={stats.review} label="待确认" tone="brand" />
          <StatCard value={stats.exported} label="已入库" tone="success" />
        </div>
      </Section>

      {/* 主按钮 */}
      <div className="flex gap-2">
        <Button variant="primary" onClick={() => navigate('agent')}>
          <AcMindIcon name="sb-ai-process" size={14} className="mr-1.5" />
          让 Agent 整理
        </Button>
        {stats.review > 0 && (
          <Button variant="secondary" onClick={() => navigate('workbench', 'review')}>
            查看待确认 ({stats.review})
          </Button>
        )}
      </div>

      {/* 最近收集 */}
      <Section title="最近收集" compact>
        {recentItems.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="sb-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="还没有收集内容"
            description="使用 Agent 或快捷方式收集内容"
            action={{ label: '去收集', onClick: () => navigate('agent') }}
          />
        ) : (
          <div className="flex flex-col gap-2">
            {recentItems.map((item) => (
              <SourceItemRow key={item.id} item={item} onClick={() => navigate('workbench', 'staging')} />
            ))}
          </div>
        )}
      </Section>

      {/* 最近入库 */}
      <Section title="最近入库" compact>
        {recentKnowledge.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="sb-obsidian" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="还没有入库内容"
            description="整理并确认后的内容会显示在这里"
          />
        ) : (
          <div className="flex flex-col gap-2">
            {recentKnowledge.map((item) => (
              <KnowledgeItemRow key={item.id} item={item} onClick={() => navigate('workbench', 'knowledge')} />
            ))}
          </div>
        )}
      </Section>
    </div>
  );
}

function StatCard({ value, label, tone }: { value: number; label: string; tone: 'warning' | 'info' | 'brand' | 'success' }): JSX.Element {
  const toneColors = {
    warning: 'var(--pm-warning)',
    info: 'var(--pm-info)',
    brand: 'var(--pm-brand)',
    success: 'var(--pm-success)',
  };
  return (
    <Card variant="base" className="pm-ds-metric-card">
      <div className="pm-ds-metric-value" style={{ color: toneColors[tone] }}>{value}</div>
      <div className="pm-ds-metric-label">{label}</div>
    </Card>
  );
}

// ─── 3.2 快速入库 Tab ─────────────────────────────────────────────

function QuickImportTab(): JSX.Element {
  const { refresh } = useSourceItems();
  const [textInput, setTextInput] = useState('');
  const [urlInput, setUrlInput] = useState('');
  const [submitting, setSubmitting] = useState<'text' | 'url' | 'file' | 'clipboard' | null>(null);
  const [toast, setToast] = useState<{ message: string; tone: 'success' | 'error' } | null>(null);

  const showToast = useCallback((message: string, tone: 'success' | 'error') => {
    setToast({ message, tone });
    setTimeout(() => setToast(null), 3000);
  }, []);

  const handleTextSubmit = useCallback(async () => {
    const text = textInput.trim();
    if (!text || submitting) return;
    setSubmitting('text');
    try {
      await window.acmind.sourceItems.createText(text);
      setTextInput('');
      showToast('文本已收集', 'success');
      refresh();
    } catch (err) {
      console.error('文本收集失败:', err);
      showToast('文本收集失败，请重试', 'error');
    } finally {
      setSubmitting(null);
    }
  }, [textInput, submitting, refresh, showToast]);

  const handleUrlSubmit = useCallback(async () => {
    const url = urlInput.trim();
    if (!url || submitting) return;
    setSubmitting('url');
    try {
      await window.acmind.sourceItems.saveUrl(url);
      setUrlInput('');
      showToast('URL 已收集', 'success');
      refresh();
    } catch (err) {
      console.error('URL 收集失败:', err);
      showToast('URL 收集失败，请重试', 'error');
    } finally {
      setSubmitting(null);
    }
  }, [urlInput, submitting, refresh, showToast]);

  const handleFileImport = useCallback(async () => {
    if (submitting) return;
    setSubmitting('file');
    try {
      await window.acmind.capture.collectFile({ filePath: '' });
      showToast('文件导入成功', 'success');
      refresh();
    } catch (err) {
      console.error('文件导入失败:', err);
      showToast('文件导入失败，请重试', 'error');
    } finally {
      setSubmitting(null);
    }
  }, [submitting, refresh, showToast]);

  const handleClipboardCollect = useCallback(async () => {
    if (submitting) return;
    setSubmitting('clipboard');
    try {
      await window.acmind.capture.collectClipboard();
      showToast('剪贴板内容已收集', 'success');
      refresh();
    } catch (err) {
      console.error('剪贴板收集失败:', err);
      showToast('剪贴板收集失败，请重试', 'error');
    } finally {
      setSubmitting(null);
    }
  }, [submitting, refresh, showToast]);

  return (
    <div className="flex flex-col gap-5">
      {/* Toast 提示 */}
      {toast && (
        <div
          className="fixed top-4 right-4 z-50 rounded-[10px] px-4 py-2.5 text-[13px] font-medium shadow-lg transition-opacity"
          style={{
            backgroundColor: toast.tone === 'success' ? 'var(--pm-success-soft)' : 'var(--pm-danger-soft)',
            color: toast.tone === 'success' ? 'var(--pm-success)' : 'var(--pm-danger)',
            border: `1px solid ${toast.tone === 'success' ? 'var(--pm-success)' : 'var(--pm-danger)'}`,
          }}
        >
          {toast.message}
        </div>
      )}

      {/* 文本输入 */}
      <Section title="文本收集" compact>
        <Card variant="base" className="flex flex-col gap-3">
          <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
            输入文本内容，快速收集到暂存区
          </p>
          <div className="flex gap-2">
            <textarea
              value={textInput}
              onChange={(e) => setTextInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  void handleTextSubmit();
                }
              }}
              placeholder="输入要收集的文本内容..."
              rows={3}
              className="flex-1 resize-none rounded-[8px] border border-[color:var(--border-light)] bg-white/70 px-3 py-2 text-[13px] outline-none focus:border-[color:var(--pm-brand)]"
            />
          </div>
          <div className="flex justify-end">
            <Button
              size="sm"
              variant="primary"
              onClick={() => void handleTextSubmit()}
              disabled={!textInput.trim() || submitting === 'text'}
            >
              {submitting === 'text' ? '收集中...' : '收集文本'}
            </Button>
          </div>
        </Card>
      </Section>

      {/* URL 输入 */}
      <Section title="URL 收集" compact>
        <Card variant="base" className="flex flex-col gap-3">
          <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
            输入网页链接，自动抓取内容并收集
          </p>
          <div className="flex gap-2">
            <input
              type="url"
              value={urlInput}
              onChange={(e) => setUrlInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  void handleUrlSubmit();
                }
              }}
              placeholder="https://example.com/article"
              className="flex-1 rounded-[8px] border border-[color:var(--border-light)] bg-white/70 px-3 py-2 text-[13px] outline-none focus:border-[color:var(--pm-brand)]"
            />
            <Button
              size="sm"
              variant="primary"
              onClick={() => void handleUrlSubmit()}
              disabled={!urlInput.trim() || submitting === 'url'}
            >
              {submitting === 'url' ? '收集中...' : '收集'}
            </Button>
          </div>
        </Card>
      </Section>

      {/* 快捷操作 */}
      <Section title="快捷操作" compact>
        <div className="grid grid-cols-2 gap-3">
          {([
            { type: 'file' as const, label: '导入文件', icon: 'filled-file-import', desc: '从本地选择文件导入' },
            { type: 'clipboard' as const, label: '粘贴内容', icon: 'filled-clipboard', desc: '从剪贴板收集内容' },
          ]).map((action) => (
            <button
              key={action.type}
              type="button"
              className="flex items-center gap-3 rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-white/50 p-4 text-left transition-all hover:border-[color:var(--pm-brand)] hover:bg-[color:var(--pm-brand-soft)] disabled:opacity-50"
              disabled={submitting === action.type}
              onClick={() => {
                if (action.type === 'file') void handleFileImport();
                else void handleClipboardCollect();
              }}
            >
              <AcMindIcon name={action.icon as any} size={20} style={{ color: 'var(--pm-text-secondary)' }} />
              <div className="min-w-0 flex-1">
                <p className="text-[13px] font-medium" style={{ color: 'var(--text-title)' }}>
                  {submitting === action.type ? '处理中...' : action.label}
                </p>
                <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
                  {action.desc}
                </p>
              </div>
            </button>
          ))}
        </div>
      </Section>
    </div>
  );
}

// ─── 3.3 暂存区 Tab ───────────────────────────────────────────────

function StagingTab(): JSX.Element {
  const { items, loading, error, refresh, selectedItem, setSelectedItem, deleteItem } = useSourceItems();
  const [distillingIds, setDistillingIds] = useState<Set<string>>(new Set());

  const inboxItems = useMemo(() => {
    return items.filter((i) => i.status === 'inbox').sort((a, b) => b.createdAt - a.createdAt);
  }, [items]);

  const handleSendToDistill = useCallback(async (item: SourceItem) => {
    setDistillingIds((prev) => new Set(prev).add(item.id));
    try {
      await window.acmind.sourceItems.update(item.id, { status: 'distilling' });
      await window.acmind.distill.run([item.id], ['summarize']);
      refresh();
    } catch (err) {
      console.error('送入整理失败:', err);
    } finally {
      setDistillingIds((prev) => {
        const next = new Set(prev);
        next.delete(item.id);
        return next;
      });
    }
  }, [refresh]);

  const handleDelete = useCallback(async (item: SourceItem) => {
    if (confirm('确定要删除这条内容吗？')) {
      await deleteItem(item.id);
      if (selectedItem?.id === item.id) setSelectedItem(null);
    }
  }, [deleteItem, selectedItem, setSelectedItem]);

  if (loading) return <LoadingState title="加载中" description="正在读取暂存内容..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请检查网络连接或稍后重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <div className="grid min-h-0 grid-cols-[minmax(0,1fr)_340px] gap-4">
      <div className="flex flex-col gap-2 overflow-auto" style={{ maxHeight: 'calc(100vh - 220px)' }}>
        {inboxItems.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="sb-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="暂存池为空"
            description="所有收集的原始内容都会先进入这里"
          />
        ) : (
          inboxItems.map((item) => (
            <Card
              key={item.id}
              variant="interactive"
              className={selectedItem?.id === item.id ? 'ring-2 ring-[color:var(--pm-brand)]' : ''}
              onClick={() => setSelectedItem(item)}
            >
              <div className="flex items-start gap-3">
                <AcMindIcon name={getTypeIcon(item) as any} size={16} style={{ color: 'var(--text-muted)' }} />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                    {item.title || '未命名'}
                  </p>
                  <p className="mt-1 line-clamp-2 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                    {item.previewText || '暂无预览'}
                  </p>
                  <div className="mt-1.5 flex items-center gap-2">
                    <span className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
                      {formatRelativeTime(item.createdAt)}
                    </span>
                    <StatusBadge tone="info" label={SOURCE_LABELS[item.source] ?? item.source} dot={false} />
                  </div>
                </div>
              </div>
            </Card>
          ))
        )}
      </div>

      {/* Detail Panel */}
      <Section title="详情" compact>
        {selectedItem ? (
          <StagingDetailPanel
            item={selectedItem}
            onSendToDistill={() => handleSendToDistill(selectedItem)}
            onDelete={() => handleDelete(selectedItem)}
            isDistilling={distillingIds.has(selectedItem.id)}
          />
        ) : (
          <EmptyState title="选择一条内容" description="查看详情和操作" />
        )}
      </Section>
    </div>
  );
}

function StagingDetailPanel({
  item,
  onSendToDistill,
  onDelete,
  isDistilling,
}: {
  item: SourceItem;
  onSendToDistill: () => void;
  onDelete: () => void;
  isDistilling: boolean;
}): JSX.Element {
  const [contentText, setContentText] = useState<string | null>(null);
  const [loadingContent, setLoadingContent] = useState(false);

  useEffect(() => {
    setLoadingContent(true);
    window.acmind.sourceItems.getContent(item.id)
      .then((content) => setContentText(content?.text ?? null))
      .finally(() => setLoadingContent(false));
  }, [item.id]);

  return (
    <Card variant="base" className="flex flex-col gap-3">
      <div>
        <p className="text-[15px] font-semibold" style={{ color: 'var(--text-title)' }}>
          {item.title || '未命名'}
        </p>
        <div className="mt-1 flex items-center gap-2">
          <AcMindIcon name={getTypeIcon(item) as any} size={13} style={{ color: 'var(--text-muted)' }} />
          <span className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
            {item.type} · {SOURCE_LABELS[item.source] ?? item.source}
          </span>
        </div>
      </div>

      <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] p-3">
        <p className="mb-1 text-[11px] font-medium" style={{ color: 'var(--text-muted)' }}>内容预览</p>
        {loadingContent ? (
          <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>加载中...</p>
        ) : (
          <p className="max-h-[200px] overflow-auto whitespace-pre-wrap text-[13px]" style={{ color: 'var(--text-body)' }}>
            {contentText || item.previewText || '暂无文本内容'}
          </p>
        )}
      </div>

      <div className="flex flex-wrap gap-2">
        <Button size="sm" variant="primary" onClick={onSendToDistill} disabled={isDistilling}>
          {isDistilling ? '整理中...' : '送入整理'}
        </Button>
        <Button size="sm" variant="ghost" onClick={onDelete}>
          删除
        </Button>
      </div>
    </Card>
  );
}

// ─── 3.3 整理中 Tab ───────────────────────────────────────────────

function ProcessingTab(): JSX.Element {
  const { items, loading, error, refresh } = useSourceItems();

  const processingItems = useMemo(() => {
    return items.filter((i) => i.status === 'distilling').sort((a, b) => b.createdAt - a.createdAt);
  }, [items]);

  if (loading) return <LoadingState title="加载中" description="正在读取整理任务..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请检查网络连接或稍后重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <div className="flex flex-col gap-5">
      {/* 整理中 */}
      <Section title={`整理中 (${processingItems.length})`} compact>
        {processingItems.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="sb-ai-process" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="没有正在整理的内容"
            description="从暂存池送入内容后开始整理"
          />
        ) : (
          <div className="flex flex-col gap-2">
            {processingItems.map((item) => (
              <Card key={item.id} variant="base" className="p-3">
                <div className="flex items-center gap-3">
                  <div className="h-4 w-4 animate-spin rounded-full border-2 border-[color:var(--pm-brand)] border-t-transparent" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[14px] font-medium">{item.title || '未命名'}</p>
                    <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
                      {formatRelativeTime(item.createdAt)} · AI 正在处理...
                    </p>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </Section>
    </div>
  );
}

// ─── 3.4 待确认 Tab ───────────────────────────────────────────────

function ReviewTab(): JSX.Element {
  const { items, loading, error, refresh } = useSourceItems();
  const [selectedItem, setSelectedItem] = useState<SourceItem | null>(null);

  const reviewItems = useMemo(() => {
    return items.filter((i) => i.status === 'distilled').sort((a, b) => b.createdAt - a.createdAt);
  }, [items]);

  const handleConfirm = useCallback(async (item: SourceItem) => {
    try {
      // 使用 export.single 进行入库
      const outputs = await window.acmind.distilledOutputs.list({ sourceItemId: item.id });
      if (outputs.length > 0) {
        await window.acmind.export.single(outputs[0].id);
      }
      refresh();
      if (selectedItem?.id === item.id) setSelectedItem(null);
    } catch (err) {
      console.error('入库失败:', err);
    }
  }, [refresh, selectedItem]);

  const handleDelete = useCallback(async (item: SourceItem) => {
    if (confirm('确定要删除这条内容吗？')) {
      await window.acmind.sourceItems.delete(item.id);
      refresh();
      if (selectedItem?.id === item.id) setSelectedItem(null);
    }
  }, [refresh, selectedItem]);

  if (loading) return <LoadingState title="加载中" description="正在读取待确认内容..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请检查网络连接或稍后重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <div className="grid min-h-0 grid-cols-[minmax(0,1fr)_380px] gap-4">
      <div className="flex flex-col gap-2 overflow-auto" style={{ maxHeight: 'calc(100vh - 220px)' }}>
        {reviewItems.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="sb-results" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="没有待确认的内容"
            description="AI 整理完成的内容会显示在这里"
          />
        ) : (
          reviewItems.map((item) => (
            <Card
              key={item.id}
              variant="interactive"
              className={selectedItem?.id === item.id ? 'ring-2 ring-[color:var(--pm-brand)]' : ''}
              onClick={() => setSelectedItem(item)}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                    {item.title || '未命名'}
                  </p>
                  <p className="mt-1 line-clamp-2 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                    {item.previewText || '无预览'}
                  </p>
                </div>
                <span className="text-[11px] shrink-0" style={{ color: 'var(--text-muted)' }}>
                  {formatRelativeTime(item.createdAt)}
                </span>
              </div>
            </Card>
          ))
        )}
      </div>

      {/* Detail Panel */}
      <Section title="审阅详情" compact>
        {selectedItem ? (
          <ReviewDetailPanel
            item={selectedItem}
            onConfirm={() => handleConfirm(selectedItem)}
            onDelete={() => handleDelete(selectedItem)}
          />
        ) : (
          <EmptyState title="选择一条内容" description="查看 AI 整理结果并确认入库" />
        )}
      </Section>
    </div>
  );
}

function ReviewDetailPanel({
  item,
  onConfirm,
  onDelete,
}: {
  item: SourceItem;
  onConfirm: () => void;
  onDelete: () => void;
}): JSX.Element {
  return (
    <Card variant="base" className="flex flex-col gap-3">
      <div>
        <p className="text-[15px] font-semibold" style={{ color: 'var(--text-title)' }}>
          {item.title || '未命名'}
        </p>
      </div>

      <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] p-3">
        <p className="mb-1 text-[11px] font-medium" style={{ color: 'var(--text-muted)' }}>内容预览</p>
        <p className="text-[13px]" style={{ color: 'var(--text-body)' }}>{item.previewText || '无预览'}</p>
      </div>

      <div className="flex flex-wrap gap-2 pt-2">
        <Button size="sm" variant="primary" onClick={onConfirm}>
          确认入库
        </Button>
        <Button size="sm" variant="ghost" onClick={onDelete}>
          删除
        </Button>
      </div>
    </Card>
  );
}

// ─── 3.5 知识库 Tab ───────────────────────────────────────────────

function KnowledgeTab(): JSX.Element {
  const { cards, loading, error, refresh } = useKnowledgeCards();
  const [searchQuery, setSearchQuery] = useState('');

  const exportedCards = useMemo(() => {
    return cards
      .filter((c) => c.status === 'active')
      .filter((c) => {
        if (!searchQuery) return true;
        const q = searchQuery.toLowerCase();
        return (
          c.canonicalTitle?.toLowerCase().includes(q) ||
          c.summary?.toLowerCase().includes(q) ||
          c.tags?.some((t) => t.toLowerCase().includes(q))
        );
      })
      .sort((a, b) => b.updatedAt - a.updatedAt);
  }, [cards, searchQuery]);

  if (loading) return <LoadingState title="加载中" description="正在读取知识库..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请检查网络连接或稍后重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <div className="flex flex-col gap-4">
      {/* Search */}
      <div className="flex gap-2">
        <input
          type="text"
          placeholder="搜索知识库..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="flex-1 rounded-[8px] border border-[color:var(--border-light)] bg-white/70 px-3 py-2 text-[13px] outline-none"
        />
      </div>

      {/* Knowledge List */}
      <Section title={`已入库 (${exportedCards.length})`} compact>
        {exportedCards.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="sb-obsidian" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="知识库为空"
            description="确认入库的内容会显示在这里"
          />
        ) : (
          <div className="flex flex-col gap-2">
            {exportedCards.map((card) => (
              <Card key={card.id} variant="base" className="p-3">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                      {card.canonicalTitle || '未命名'}
                    </p>
                    <p className="mt-1 line-clamp-2 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                      {card.summary || '无摘要'}
                    </p>
                    {card.tags && card.tags.length > 0 && (
                      <div className="mt-2 flex flex-wrap gap-1">
                        {card.tags.slice(0, 3).map((tag) => (
                          <span key={tag} className="rounded-full px-2 py-0.5 text-[10px] bg-[color:var(--pm-success-soft)] text-[color:var(--pm-success)]">
                            {tag}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                  <div className="flex flex-col items-end gap-1 shrink-0">
                    <span className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
                      {new Date(card.updatedAt * 1000).toLocaleDateString('zh-CN')}
                    </span>
                    {card.category && (
                      <span className="text-[10px] truncate max-w-[120px]" style={{ color: 'var(--text-muted)' }}>
                        📁 {card.category}
                      </span>
                    )}
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </Section>
    </div>
  );
}

// ─── 3.7 处理日志 Tab ─────────────────────────────────────────────

function LogsTab(): JSX.Element {
  const { items, loading, error, refresh } = useProcessingHistory();

  if (loading) return <LoadingState title="加载中" description="正在读取日志..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请检查网络连接或稍后重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <Section title="操作日志" compact>
      {items.length === 0 ? (
        <EmptyState
          icon={<AcMindIcon name="sb-settings" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="暂无日志"
          description="系统操作记录会显示在这里"
        />
      ) : (
        <div className="flex flex-col gap-2">
          {items.slice(0, 50).map((record, index) => (
            <LogRow key={record.sourceItem.id ?? index} record={record} />
          ))}
        </div>
      )}
    </Section>
  );
}

function LogRow({ record }: { record: import('../../hooks/useProcessingHistory').ProcessingHistoryItem }): JSX.Element {
  const statusIcons: Record<string, string> = {
    success: 'status-success',
    error: 'status-error',
    pending: 'status-waiting',
    processing: 'status-processing',
  };

  const statusTone = record.statusTone;
  const statusLabel = record.currentStatus;

  return (
    <Card variant="base" className="p-2">
      <div className="flex items-center gap-3">
        <AcMindIcon name={statusIcons[record.statusTone === 'success' ? 'success' : record.statusTone === 'danger' ? 'error' : 'processing'] as any} size={14} style={{ color: `var(--pm-${statusTone})` }} />
        <div className="min-w-0 flex-1">
          <p className="text-[13px]">{record.title}</p>
          <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
            {formatRelativeTime(record.collectedAt)}
          </p>
        </div>
        <StatusBadge
          tone={statusTone}
          label={statusLabel}
          dot={false}
        />
      </div>
    </Card>
  );
}

// ─── Helpers ──────────────────────────────────────────────────────

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

function SourceItemRow({ item, onClick }: { item: SourceItem; onClick: () => void }): JSX.Element {
  return (
    <Card variant="interactive" className="p-3" onClick={onClick}>
      <div className="flex items-center gap-3">
        <AcMindIcon name={getTypeIcon(item) as any} size={16} style={{ color: 'var(--text-muted)' }} />
        <div className="min-w-0 flex-1">
          <p className="truncate text-[13px] font-medium">{item.title || '未命名'}</p>
          <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
            {formatRelativeTime(item.createdAt)} · {SOURCE_LABELS[item.source] ?? item.source}
          </p>
        </div>
        <StatusBadge tone={STATUS_CONFIG[item.status]?.tone ?? 'neutral'} label={STATUS_CONFIG[item.status]?.label ?? item.status} dot={false} />
      </div>
    </Card>
  );
}

function KnowledgeItemRow({ item, onClick }: { item: KnowledgeCard; onClick: () => void }): JSX.Element {
  return (
    <Card variant="interactive" className="p-3" onClick={onClick}>
      <div className="flex items-center gap-3">
        <AcMindIcon name="sb-obsidian" size={16} style={{ color: 'var(--pm-success)' }} />
        <div className="min-w-0 flex-1">
          <p className="truncate text-[13px] font-medium">{item.canonicalTitle || '未命名'}</p>
          <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
            {formatRelativeTime(item.updatedAt)}
          </p>
        </div>
        {item.category && (
          <span className="text-[10px] truncate max-w-[100px]" style={{ color: 'var(--text-muted)' }}>
            📁 {item.category}
          </span>
        )}
      </div>
    </Card>
  );
}
