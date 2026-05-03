import { useCallback, useEffect, useState } from 'react';
import { useDistillResults } from '../../hooks/useDistillResults';
import { DistillResultCard } from './DistillResultCard';
import { ScrollContainer } from '../shared/ScrollContainer';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  Input,
  LoadingState,
} from '../../design-system/components';
import type { DistilledOutput, SourceItem } from '../../../shared/types';
import { DEFAULT_DISTILLED_TYPE } from '../../../shared/markdownSpec';

// ─── Types ───────────────────────────────────────────────────────────────────

interface DistillReviewPanelProps {
  onRefresh?: () => void;
}

// ─── Component ───────────────────────────────────────────────────────────────

export function DistillReviewPanel({ onRefresh }: DistillReviewPanelProps): JSX.Element {
  const { outputs, loading, error, refresh, accept, reject } = useDistillResults();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editData, setEditData] = useState<Partial<DistilledOutput>>({});
  const [sourceItems, setSourceItems] = useState<Map<string, SourceItem>>(new Map());
  const [actionMessage, setActionMessage] = useState<string | null>(null);

  const loadSourceItem = useCallback(async (sourceItemId: string) => {
    if (sourceItems.has(sourceItemId)) return;
    try {
      const item = await window.pinmind.sourceItems.get(sourceItemId);
      if (item) {
        setSourceItems((prev) => {
          if (prev.has(sourceItemId)) {
            return prev;
          }
          return new Map(prev).set(sourceItemId, item);
        });
      }
    } catch {
      // Source item may have been deleted
    }
  }, [sourceItems]);

  useEffect(() => {
    if (loading || outputs.length === 0) {
      return;
    }

    const missingSourceItemIds = outputs
      .map((output) => output.sourceItemId)
      .filter((sourceItemId, index, ids) => ids.indexOf(sourceItemId) === index && !sourceItems.has(sourceItemId));

    if (missingSourceItemIds.length === 0) {
      return;
    }

    missingSourceItemIds.forEach((sourceItemId) => {
      void loadSourceItem(sourceItemId);
    });
  }, [loading, outputs, sourceItems, loadSourceItem]);

  const handleEdit = (output: DistilledOutput) => {
    setEditingId(output.id);
    setEditData({
      suggestedTitle: output.suggestedTitle,
      summary: output.summary,
      category: output.category,
      tags: output.tags,
      documentType: output.documentType ?? DEFAULT_DISTILLED_TYPE,
      contentMarkdown: output.contentMarkdown,
      valueScore: output.valueScore,
      cleanSuggestion: output.cleanSuggestion,
    });
  };

  const handleSaveEdit = async () => {
    if (!editingId) return;
    try {
      await window.pinmind.distilledOutputs.review(editingId, 'edit', editData);
      setEditingId(null);
      setEditData({});
      await refresh();
      onRefresh?.();
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : '保存编辑失败，请稍后重试。');
    }
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditData({});
  };

  const handleAccept = async (outputId: string) => {
    await accept(outputId);
    onRefresh?.();
  };

  const handleAcceptAndExport = async (outputId: string) => {
    const ok = await accept(outputId);
    if (!ok) {
      setActionMessage('接受失败，请稍后重试。');
      return;
    }

    try {
      // V2.1: 优先走 pipeline retry（自动整理 + 写入 Obsidian）
      const output = outputs.find((o) => o.id === outputId);
      if (output?.sourceItemId && window.pinmind?.pipeline) {
        const result = await window.pinmind.pipeline.retryExport(output.sourceItemId);
        if (result.success) {
          setActionMessage('已写入 Obsidian。');
          onRefresh?.();
          window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'export' }));
          return;
        }
        // Pipeline retry failed, fall through to legacy export
      }

      // Fallback: legacy export.single
      await window.pinmind.export.single(outputId);
      setActionMessage('已写入 Obsidian。');
      onRefresh?.();
      window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'export' }));
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : '写入 Obsidian 失败，请先检查知识库设置。');
      onRefresh?.();
    }
  };

  const handleReject = async (outputId: string) => {
    await reject(outputId);
    onRefresh?.();
  };

  return (
    <ScrollContainer>
      <div className="p-4">
        {loading ? (
          <LoadingState title="正在加载结果..." description="请稍候" />
        ) : error ? (
          <ErrorState
            title="加载结果失败"
            reason={error}
            suggestion="请稍后重试"
          />
        ) : outputs.length === 0 ? (
          <EmptyState
            title="暂无可审阅结果"
            description="先运行批量整理，生成可审阅的 AI 结果。"
            action={{
              label: '去整理',
              onClick: () => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'distill' })),
            }}
          />
        ) : (
          <div className="flex flex-col gap-4">
            {actionMessage ? (
              <Card variant="base" padding={12}>
                <p className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>
                  {actionMessage}
                </p>
              </Card>
            ) : null}
            {outputs.map((output) => {
              const sourceItem = sourceItems.get(output.sourceItemId);
              const isEditing = editingId === output.id;

              return (
                <Card key={output.id} variant="base" padding={0} className="flex flex-row overflow-hidden">
                  {/* Original content (left) */}
                  <div className="flex-1 min-w-0 p-4">
                    <h5
                      className="text-[11px] font-semibold uppercase tracking-wider mb-2"
                      style={{ color: 'var(--pm-text-tertiary)' }}
                    >
                      原文
                    </h5>
                    {sourceItem ? (
                      <div>
                        <p
                          className="text-[12px] leading-relaxed"
                          style={{
                            color: 'var(--pm-text-secondary)',
                            display: '-webkit-box',
                            WebkitLineClamp: 8,
                            WebkitBoxOrient: 'vertical',
                            overflow: 'hidden',
                            whiteSpace: 'pre-wrap',
                            wordBreak: 'break-word',
                          }}
                        >
                          {sourceItem.previewText ?? '（暂无预览内容）'}
                        </p>
                        <div className="mt-2 flex items-center gap-2">
                          <span className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                            {sourceItem.sourceApp ?? sourceItem.source}
                          </span>
                          <span className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                            {sourceItem.type}
                          </span>
                        </div>
                      </div>
                    ) : (
                      <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                        正在加载原文...
                      </span>
                    )}
                  </div>

                  {/* Divider */}
                  <div
                    className="w-px self-stretch flex-shrink-0"
                    style={{ background: 'var(--pm-border-subtle)' }}
                  />

                  {/* Distilled result (right) */}
                  <div className="flex-1 min-w-0 p-4">
                    <h5
                      className="text-[11px] font-semibold uppercase tracking-wider mb-2"
                      style={{ color: 'var(--pm-text-tertiary)' }}
                    >
                      整理结果
                    </h5>
                    {isEditing ? (
                      <div className="flex flex-col gap-2">
                        <Input
                          placeholder="标题"
                          value={editData.suggestedTitle ?? ''}
                          onChange={(e) =>
                            setEditData((prev) => ({ ...prev, suggestedTitle: e.target.value }))
                          }
                        />
                        <textarea
                          className="pm-ds-input w-full"
                          style={{ height: 80, resize: 'vertical' }}
                          placeholder="摘要"
                          value={editData.summary ?? ''}
                          onChange={(e) =>
                            setEditData((prev) => ({ ...prev, summary: e.target.value }))
                          }
                        />
                        <Input
                          placeholder="分类"
                          value={editData.category ?? ''}
                          onChange={(e) =>
                            setEditData((prev) => ({ ...prev, category: e.target.value }))
                          }
                        />
                        <Input
                          placeholder="标签，用英文逗号分隔"
                          value={(editData.tags ?? []).join(', ')}
                          onChange={(e) =>
                            setEditData((prev) => ({
                              ...prev,
                              tags: e.target.value
                                .split(',')
                                .map((tag) => tag.trim())
                                .filter(Boolean),
                            }))
                          }
                        />
                        <textarea
                          className="pm-ds-input w-full font-mono"
                          style={{ height: 180, resize: 'vertical' }}
                          placeholder="正文 Markdown（不含 frontmatter）"
                          value={editData.contentMarkdown ?? ''}
                          onChange={(e) =>
                            setEditData((prev) => ({ ...prev, contentMarkdown: e.target.value }))
                          }
                        />
                        <div className="flex gap-2">
                          <Button
                            variant="secondary"
                            size="sm"
                            onClick={handleCancelEdit}
                          >
                            取消
                          </Button>
                          <Button
                            variant="primary"
                            size="sm"
                            onClick={handleSaveEdit}
                          >
                            保存
                          </Button>
                        </div>
                      </div>
                    ) : (
                      <DistillResultCard
                        output={output}
                        sourceItem={sourceItem}
                        onAccept={handleAccept}
                        onAcceptAndExport={handleAcceptAndExport}
                        onReject={handleReject}
                        onEdit={handleEdit}
                      />
                    )}
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </ScrollContainer>
  );
}
