import { useCallback, useEffect, useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { useToast } from '../../components/shared/ToastViewport';
import type { DistilledOutput, SourceItem } from '../../../shared/types';

// ─── Helpers ─────────────────────────────────────────────────────────────────

type ReviewTab = 'pending' | 'accepted' | 'rejected';

function relativeTime(ts: number): string {
  const diff = Date.now() / 1000 - ts;
  if (diff < 60) return '刚刚';
  if (diff < 3600) return `${Math.floor(diff / 60)}分钟前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}小时前`;
  return `${Math.floor(diff / 86400)}天前`;
}

const navigate = (view: string, options?: Record<string, string>) => {
  window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view, ...options } }));
};

const STATUS_BADGE_MAP: Record<string, { label: string; tone: 'warning' | 'success' | 'danger' | 'info' }> = {
  pending: { label: '待审核', tone: 'warning' },
  accepted: { label: '已确认', tone: 'success' },
  edited: { label: '已编辑', tone: 'info' },
  rejected: { label: '已拒绝', tone: 'danger' },
};

// ─── Component ───────────────────────────────────────────────────────────────

export function ReviewPage(): JSX.Element {
  const { addToast } = useToast();

  // ── State ──
  const [activeTab, setActiveTab] = useState<ReviewTab>('pending');
  const [pendingItems, setPendingItems] = useState<DistilledOutput[]>([]);
  const [acceptedItems, setAcceptedItems] = useState<DistilledOutput[]>([]);
  const [rejectedItems, setRejectedItems] = useState<DistilledOutput[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Editable fields for the selected item
  const [editTitle, setEditTitle] = useState('');
  const [editSummary, setEditSummary] = useState('');
  const [editTags, setEditTags] = useState('');

  // ── Derived ──
  const currentList = activeTab === 'pending' ? pendingItems : activeTab === 'accepted' ? acceptedItems : rejectedItems;
  const selectedItem = currentList.find((item) => item.id === selectedId) ?? null;

  // ── Data loading ──
  const loadAll = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const [pending, accepted, rejected] = await Promise.all([
        window.acmind.distilledOutputs.list({ reviewStatus: 'pending' }),
        window.acmind.distilledOutputs.list({ reviewStatus: 'accepted' }),
        window.acmind.distilledOutputs.list({ reviewStatus: 'rejected' }),
      ]);
      setPendingItems(pending);
      setAcceptedItems(accepted);
      setRejectedItems(rejected);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  // Subscribe to data changes
  useEffect(() => {
    const unsub = window.acmind.onRecordsChanged(() => {
      loadAll();
    });
    return unsub;
  }, [loadAll]);

  // Sync editable fields when selected item changes
  useEffect(() => {
    if (selectedItem) {
      setEditTitle(selectedItem.suggestedTitle ?? '');
      setEditSummary(selectedItem.summary ?? '');
      setEditTags((selectedItem.tags ?? []).join(', '));
    }
  }, [selectedItem?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Actions ──
  const handleReview = useCallback(
    async (outputId: string, action: 'approve' | 'discard') => {
      try {
        await window.acmind.distilledOutputs.review(outputId, action);
        addToast(action === 'approve' ? '已确认' : '已拒绝', 'success');
        if (selectedId === outputId) setSelectedId(null);
        await loadAll();
      } catch (e) {
        addToast(String(e), 'error');
      }
    },
    [addToast, loadAll, selectedId],
  );

  const handleEdit = useCallback(
    async (outputId: string) => {
      try {
        const tags = editTags
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean);
        await window.acmind.distilledOutputs.review(outputId, 'edit', {
          suggestedTitle: editTitle,
          summary: editSummary,
          tags,
          contentMarkdown: selectedItem?.contentMarkdown,
        });
        addToast('修改已保存', 'success');
        await loadAll();
      } catch (e) {
        addToast(String(e), 'error');
      }
    },
    [addToast, editTitle, editSummary, editTags, loadAll, selectedItem?.contentMarkdown],
  );

  const handleBatchApprove = useCallback(async () => {
    try {
      for (const item of pendingItems) {
        await window.acmind.distilledOutputs.review(item.id, 'approve');
      }
      addToast(`已确认 ${pendingItems.length} 条`, 'success');
      setSelectedId(null);
      await loadAll();
    } catch (e) {
      addToast(String(e), 'error');
    }
  }, [addToast, loadAll, pendingItems]);

  const handleBatchReject = useCallback(async () => {
    try {
      for (const item of pendingItems) {
        await window.acmind.distilledOutputs.review(item.id, 'discard');
      }
      addToast(`已拒绝 ${pendingItems.length} 条`, 'success');
      setSelectedId(null);
      await loadAll();
    } catch (e) {
      addToast(String(e), 'error');
    }
  }, [addToast, loadAll, pendingItems]);

  // ── Render ──
  if (loading) {
    return (
      <PageShell>
        <LoadingState title="加载中" description="正在获取审核列表..." />
      </PageShell>
    );
  }

  if (error) {
    return (
      <PageShell>
        <ErrorState
          title="加载失败"
          reason={error}
          suggestion="请检查连接后重试"
          action={{ label: '重试', onClick: loadAll }}
        />
      </PageShell>
    );
  }

  const tabs: { key: ReviewTab; label: string; count: number }[] = [
    { key: 'pending', label: '待审核', count: pendingItems.length },
    { key: 'accepted', label: '已确认', count: acceptedItems.length },
    { key: 'rejected', label: '已拒绝', count: rejectedItems.length },
  ];

  return (
    <PageShell style={{ display: 'flex', flexDirection: 'column', height: '100%', padding: 0 }}>
      {/* Header */}
      <div style={{ padding: '20px 24px 0 24px', flexShrink: 0 }}>
        <PageHeader
          title="人工确认"
          description="审核 AI 提炼结果，确认后可导出"
          actions={
            activeTab === 'pending' && pendingItems.length > 0 ? (
              <div style={{ display: 'flex', gap: 8 }}>
                <Button variant="primary" size="sm" onClick={handleBatchApprove}>
                  全部确认
                </Button>
                <Button variant="danger" size="sm" onClick={handleBatchReject}>
                  全部拒绝
                </Button>
              </div>
            ) : undefined
          }
        />
      </div>

      {/* Tab bar */}
      <div
        style={{
          display: 'flex',
          gap: 0,
          borderBottom: '1px solid var(--pm-border-subtle)',
          padding: '0 24px',
          marginTop: 16,
          flexShrink: 0,
        }}
      >
        {tabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => {
              setActiveTab(tab.key);
              setSelectedId(null);
            }}
            style={{
              padding: '8px 16px',
              fontSize: 13,
              fontWeight: activeTab === tab.key ? 600 : 400,
              color: activeTab === tab.key ? 'var(--pm-text-primary)' : 'var(--pm-text-tertiary)',
              borderBottom: activeTab === tab.key ? '2px solid var(--pm-brand-primary)' : '2px solid transparent',
              background: 'none',
              cursor: 'pointer',
              transition: 'color 0.15s, border-color 0.15s',
            }}
          >
            {tab.label}
            {tab.count > 0 && (
              <span
                style={{
                  marginLeft: 6,
                  fontSize: 11,
                  padding: '1px 6px',
                  borderRadius: 10,
                  background: activeTab === tab.key ? 'var(--pm-brand-soft)' : 'var(--pm-bg-surface-soft)',
                  color: activeTab === tab.key ? 'var(--pm-brand-primary)' : 'var(--pm-text-tertiary)',
                }}
              >
                {tab.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Main area: list + detail */}
      <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
        {/* Left panel */}
        <div
          style={{
            width: 320,
            flexShrink: 0,
            borderRight: '1px solid var(--pm-border-subtle)',
            overflowY: 'auto',
          }}
        >
          {currentList.length === 0 ? (
            <div style={{ padding: 32, textAlign: 'center', color: 'var(--pm-text-tertiary)', fontSize: 13 }}>
              暂无数据
            </div>
          ) : (
            currentList.map((item) => (
              <div
                key={item.id}
                onClick={() => setSelectedId(item.id)}
                style={{
                  padding: '12px 16px',
                  cursor: 'pointer',
                  borderBottom: '1px solid var(--pm-border-subtle)',
                  background: selectedId === item.id ? 'var(--pm-brand-soft)' : 'transparent',
                  transition: 'background 0.12s',
                }}
              >
                <div
                  style={{
                    fontSize: 13,
                    fontWeight: 500,
                    color: 'var(--pm-text-primary)',
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {item.suggestedTitle || '未命名'}
                </div>
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    marginTop: 4,
                    fontSize: 11,
                    color: 'var(--pm-text-tertiary)',
                  }}
                >
                  {item.operation && (
                    <span style={{ padding: '1px 5px', borderRadius: 4, background: 'var(--pm-bg-surface-soft)' }}>
                      {item.operation}
                    </span>
                  )}
                  <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {item.sourceItemId}
                  </span>
                  <span>{relativeTime(item.createdAt)}</span>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Right panel */}
        <ScrollContainer className="flex-1 min-h-0" bottomPadding={80}>
          {selectedItem ? (
            <div style={{ padding: 24, maxWidth: 680 }}>
              {/* Detail header */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
                <h2
                  style={{
                    fontSize: 18,
                    fontWeight: 600,
                    color: 'var(--pm-text-primary)',
                    margin: 0,
                    flex: 1,
                    minWidth: 0,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {selectedItem.suggestedTitle || '未命名'}
                </h2>
                {selectedItem.reviewStatus && STATUS_BADGE_MAP[selectedItem.reviewStatus] && (
                  <StatusBadge
                    tone={STATUS_BADGE_MAP[selectedItem.reviewStatus].tone}
                    label={STATUS_BADGE_MAP[selectedItem.reviewStatus].label}
                  />
                )}
              </div>

              {/* Source info */}
              <Card variant="grouped" style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, color: 'var(--pm-text-secondary)', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span>来源: {selectedItem.sourceItemId}</span>
                  <button
                    type="button"
                    onClick={() => navigate('source', { id: selectedItem.sourceItemId })}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: 'var(--pm-brand-primary)',
                      cursor: 'pointer',
                      fontSize: 12,
                      padding: 0,
                    }}
                  >
                    查看原文
                  </button>
                </div>
              </Card>

              {/* Editable fields */}
              <Section title="AI 提炼结果" compact>
                {/* Title */}
                <div style={{ marginBottom: 16 }}>
                  <label
                    style={{
                      display: 'block',
                      fontSize: 12,
                      fontWeight: 500,
                      color: 'var(--pm-text-secondary)',
                      marginBottom: 6,
                    }}
                  >
                    标题
                  </label>
                  <input
                    type="text"
                    value={editTitle}
                    onChange={(e) => setEditTitle(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      fontSize: 13,
                      border: '1px solid var(--pm-border-subtle)',
                      borderRadius: 8,
                      background: 'var(--pm-bg-surface-soft)',
                      color: 'var(--pm-text-primary)',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                {/* Summary */}
                <div style={{ marginBottom: 16 }}>
                  <label
                    style={{
                      display: 'block',
                      fontSize: 12,
                      fontWeight: 500,
                      color: 'var(--pm-text-secondary)',
                      marginBottom: 6,
                    }}
                  >
                    摘要
                  </label>
                  <textarea
                    value={editSummary}
                    onChange={(e) => setEditSummary(e.target.value)}
                    rows={4}
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      fontSize: 13,
                      border: '1px solid var(--pm-border-subtle)',
                      borderRadius: 8,
                      background: 'var(--pm-bg-surface-soft)',
                      color: 'var(--pm-text-primary)',
                      outline: 'none',
                      resize: 'vertical',
                      fontFamily: 'inherit',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                {/* Tags */}
                <div style={{ marginBottom: 16 }}>
                  <label
                    style={{
                      display: 'block',
                      fontSize: 12,
                      fontWeight: 500,
                      color: 'var(--pm-text-secondary)',
                      marginBottom: 6,
                    }}
                  >
                    标签（逗号分隔）
                  </label>
                  <input
                    type="text"
                    value={editTags}
                    onChange={(e) => setEditTags(e.target.value)}
                    placeholder="标签1, 标签2"
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      fontSize: 13,
                      border: '1px solid var(--pm-border-subtle)',
                      borderRadius: 8,
                      background: 'var(--pm-bg-surface-soft)',
                      color: 'var(--pm-text-primary)',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                {/* Markdown preview */}
                {selectedItem.contentMarkdown && (
                  <div style={{ marginBottom: 16 }}>
                    <label
                      style={{
                        display: 'block',
                        fontSize: 12,
                        fontWeight: 500,
                        color: 'var(--pm-text-secondary)',
                        marginBottom: 6,
                      }}
                    >
                      Markdown 内容
                    </label>
                    <pre
                      style={{
                        padding: '12px 16px',
                        fontSize: 12,
                        lineHeight: 1.6,
                        border: '1px solid var(--pm-border-subtle)',
                        borderRadius: 8,
                        background: 'var(--pm-bg-surface-soft)',
                        color: 'var(--pm-text-primary)',
                        whiteSpace: 'pre-wrap',
                        wordBreak: 'break-word',
                        margin: 0,
                        maxHeight: 320,
                        overflowY: 'auto',
                      }}
                    >
                      {selectedItem.contentMarkdown}
                    </pre>
                  </div>
                )}

                {/* Confidence */}
                {selectedItem.confidence != null && (
                  <div style={{ marginBottom: 16 }}>
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        fontSize: 12,
                        color: 'var(--pm-text-secondary)',
                        marginBottom: 6,
                      }}
                    >
                      <span>置信度</span>
                      <span>{Math.round(selectedItem.confidence * 100)}%</span>
                    </div>
                    <div
                      style={{
                        height: 4,
                        borderRadius: 2,
                        background: 'var(--pm-bg-surface-soft)',
                        overflow: 'hidden',
                      }}
                    >
                      <div
                        style={{
                          height: '100%',
                          width: `${selectedItem.confidence * 100}%`,
                          borderRadius: 2,
                          background:
                            selectedItem.confidence >= 0.8
                              ? 'var(--pm-status-success)'
                              : selectedItem.confidence >= 0.5
                                ? 'var(--pm-status-warning)'
                                : 'var(--pm-status-danger)',
                          transition: 'width 0.3s',
                        }}
                      />
                    </div>
                  </div>
                )}
              </Section>

              {/* Action buttons */}
              <div style={{ display: 'flex', gap: 8, marginTop: 20, flexWrap: 'wrap' }}>
                {selectedItem.reviewStatus === 'pending' && (
                  <>
                    <Button variant="primary" onClick={() => handleReview(selectedItem.id, 'approve')}>
                      确认
                    </Button>
                    <Button variant="danger" onClick={() => handleReview(selectedItem.id, 'discard')}>
                      拒绝
                    </Button>
                  </>
                )}
                <Button variant="secondary" onClick={() => handleEdit(selectedItem.id)}>
                  保存修改
                </Button>
                <Button variant="secondary" onClick={() => navigate('export')}>
                  发送到导出
                </Button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', padding: 32 }}>
              <EmptyState
                icon={<PinStackIcon name="empty-inbox" size={28} />}
                title="选择一条记录"
                description="从左侧列表选择要查看的提炼结果"
              />
            </div>
          )}
        </ScrollContainer>
      </div>
    </PageShell>
  );
}
