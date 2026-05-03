import { useCallback, useEffect, useRef, useState } from 'react';
import type { CaptureItem, DistilledOutput, SourceItem } from '../../../shared/types';
import { ErrorState, LoadingState, PageShell } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { ImagePreview } from '../../components/shared/ImagePreview';
import { useToast } from '../../components/shared/ToastViewport';
import { DEFAULT_DISTILLED_TYPE } from '../../../shared/markdownSpec';

// ─── EditPage ───────────────────────────────────────────────────────────────

interface EditPageProps {
  itemId?: string;
}

export function EditPage({ itemId }: EditPageProps): JSX.Element {
  const { addToast } = useToast();

  // ── Item state ──
  const [item, setItem] = useState<CaptureItem | null>(null);
  const [sourceItem, setSourceItem] = useState<SourceItem | null>(null);
  const [captureItemId, setCaptureItemId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ── Distilled output state ──
  const [distilledOutput, setDistilledOutput] = useState<DistilledOutput | null>(null);
  const [distilledLoading, setDistilledLoading] = useState(true);
  const [savingDistilled, setSavingDistilled] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [exportStatus, setExportStatus] = useState<'none' | 'success' | 'failed'>('none');
  const [exportRecordId, setExportRecordId] = useState<string | null>(null);

  // ── UI state ──
  const [editingTitle, setEditingTitle] = useState(false);
  const [editingContent, setEditingContent] = useState(false);
  const [showSource, setShowSource] = useState(false);
  const [showExportPreview, setShowExportPreview] = useState(false);
  const [titleDraft, setTitleDraft] = useState('');
  const [contentDraft, setContentDraft] = useState('');
  const [userNote, setUserNote] = useState('');
  const [summaryDraft, setSummaryDraft] = useState('');
  const [categoryDraft, setCategoryDraft] = useState('');
  const [markdownDraft, setMarkdownDraft] = useState('');
  const [tags, setTags] = useState<string[]>([]);
  const [newTagInput, setNewTagInput] = useState('');

  const titleInputRef = useRef<HTMLInputElement>(null);
  const distilledOutputRef = useRef<DistilledOutput | null>(null);

  // ── Load item ──
  const loadItem = useCallback(async () => {
    if (!itemId) {
      setLoading(false);
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const directSource = await window.pinmind.sourceItems.get(itemId);
      const captureBridge = directSource?.captureItemId
        ? await window.pinmind.captureItems.get(directSource.captureItemId)
        : null;
      const captureFallback = directSource ? null : await window.pinmind.captureItems.get(itemId);
      const resolvedCapture = captureBridge ?? captureFallback;
      let resolvedSource = directSource;

      if (!resolvedSource && resolvedCapture) {
        resolvedSource = await window.pinmind.sourceItems.getByCaptureItemId(resolvedCapture.id);
        if (!resolvedSource) {
          resolvedSource = await window.pinmind.sourceItems.ensureFromCapture(resolvedCapture.id);
        }
      }

      if (!resolvedSource && !resolvedCapture) {
        setError('未找到该碎片或源条目');
        setItem(null);
        setSourceItem(null);
        setCaptureItemId(null);
      } else {
        const syntheticCapture: CaptureItem | null = resolvedCapture ?? (resolvedSource
          ? {
              id: resolvedSource.captureItemId ?? resolvedSource.id,
              type: resolvedSource.type === 'url' ? 'link' : resolvedSource.type,
              title: resolvedSource.title ?? '无标题',
              rawText: resolvedSource.previewText ?? resolvedSource.originalUrl ?? '',
              sourceUrl: resolvedSource.originalUrl ?? '',
              filePath: resolvedSource.contentPath,
              userNote: '',
              status: resolvedSource.status === 'distilled' ? 'archived' : resolvedSource.status === 'exported' ? 'archived' : 'pending',
              updatedAt: resolvedSource.createdAt,
              capturedAt: resolvedSource.createdAt,
            }
          : null);

        setItem(syntheticCapture);
        setSourceItem(resolvedSource);
        setCaptureItemId(resolvedCapture?.id ?? resolvedSource?.captureItemId ?? null);

        if (syntheticCapture) {
          setTitleDraft(syntheticCapture.title);
          setContentDraft(syntheticCapture.rawText);
          setUserNote(syntheticCapture.userNote ?? '');
          setTags(parseTagsFromUserNote(syntheticCapture.userNote ?? ''));
        } else {
          setTitleDraft(resolvedSource?.title ?? '');
          setContentDraft(resolvedSource?.previewText ?? resolvedSource?.originalUrl ?? '');
          setUserNote('');
          setTags([]);
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载碎片失败');
      setItem(null);
      setSourceItem(null);
      setCaptureItemId(null);
    } finally {
      setLoading(false);
    }
  }, [itemId]);

  // ── Load distilled output ──
  // NOTE: titleDraft is intentionally NOT in the dependency array.
  const loadDistilledOutput = useCallback(async () => {
    const lookupId = sourceItem?.id ?? itemId;
    if (!lookupId) {
      setDistilledLoading(false);
      return;
    }
    setDistilledLoading(true);
    try {
      const results = await window.pinmind.distilledOutputs.list({ sourceItemId: lookupId });
      const summarizeResult = results.find((r) => r.operation === 'summarize' || r.contentMarkdown);
      const nextOutput = summarizeResult ?? (results.length > 0 ? results[0] : null);
      setDistilledOutput(nextOutput);
      if (nextOutput) {
        setTitleDraft((prev) => {
          if (distilledOutputRef.current?.id !== nextOutput.id) {
            return nextOutput.suggestedTitle ?? prev;
          }
          return prev;
        });
        setSummaryDraft(nextOutput.summary ?? '');
        setCategoryDraft(nextOutput.category ?? '');
        setMarkdownDraft(nextOutput.contentMarkdown ?? '');
        if (nextOutput.tags?.length) {
          setTags(nextOutput.tags);
        }
        distilledOutputRef.current = nextOutput;
      }
    } catch {
      setDistilledOutput(null);
    } finally {
      setDistilledLoading(false);
    }
  }, [itemId, sourceItem?.id]);

  useEffect(() => { void loadItem(); }, [loadItem]);
  useEffect(() => { void loadDistilledOutput(); }, [loadDistilledOutput]);

  useEffect(() => {
    if (editingTitle && titleInputRef.current) {
      titleInputRef.current.focus();
      titleInputRef.current.select();
    }
  }, [editingTitle]);

  // ── Helpers ──

  function parseTagsFromUserNote(note: string): string[] {
    if (!note) return [];
    const tagMatch = note.match(/tags:\s*(.+)/i);
    if (tagMatch) {
      return tagMatch[1].split(',').map((t) => t.trim()).filter(Boolean);
    }
    const parts = note.split(',').map((t) => t.trim()).filter(Boolean);
    if (parts.every((p) => p.length <= 30 && !p.includes('\n'))) {
      return parts;
    }
    return [];
  }

  function buildUserNoteWithTags(existingNote: string, updatedTags: string[]): string {
    let cleaned = existingNote.replace(/tags:\s*.*/i, '').trim();
    if (updatedTags.length > 0) {
      const tagLine = `tags: ${updatedTags.join(', ')}`;
      cleaned = cleaned ? `${cleaned}\n${tagLine}` : tagLine;
    }
    return cleaned;
  }

  function generateMarkdown(): string {
    if (markdownDraft.trim()) {
      return markdownDraft;
    }
    if (distilledOutput?.contentMarkdown?.trim()) {
      return distilledOutput.contentMarkdown;
    }
    if (!item) return '';
    const lines: string[] = [];
    lines.push(`# ${titleDraft || item.title || '无标题'}`);
    lines.push('');
    if (item.sourceUrl) {
      lines.push(`> 来源: ${item.sourceUrl}`);
      lines.push('');
    }
    if (summaryDraft) {
      lines.push(`## 摘要`);
      lines.push('');
      lines.push(summaryDraft);
      lines.push('');
    }
    if (item.rawText) {
      lines.push(item.rawText);
    }
    if (tags.length > 0) {
      lines.push('');
      lines.push(`标签: ${tags.map((t) => `#${t}`).join(' ')}`);
    }
    return lines.join('\n');
  }

  // ── Actions ──

  const handleBack = useCallback(() => {
    window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'capture-inbox' }));
  }, []);

  const handleDistill = useCallback(async () => {
    const targetId = sourceItem?.id ?? captureItemId ?? item?.id;
    if (!targetId) return;
    try {
      if (sourceItem) {
        await window.pinmind.distill.run([targetId], ['summarize']);
      } else {
        await window.pinmind.distill.bridgeAndRun(targetId, ['summarize']);
      }
      addToast('整理任务已提交', 'success');
      // Reload distilled output after a short delay
      setTimeout(() => { void loadDistilledOutput(); }, 2000);
    } catch (err) {
      addToast(err instanceof Error ? err.message : '整理失败', 'error');
    }
  }, [sourceItem, captureItemId, item, addToast, loadDistilledOutput]);

  const handleToggleEditContent = useCallback(async () => {
    if (editingContent) {
      if (item && captureItemId) {
        try {
          const updated = await window.pinmind.captureItems.update(captureItemId, {
            rawText: contentDraft,
          });
          setItem(updated);
          addToast('内容已保存', 'success');
        } catch (err) {
          addToast(err instanceof Error ? err.message : '保存内容失败', 'error');
          return;
        }
      }
      setEditingContent(false);
    } else {
      setContentDraft(item?.rawText ?? '');
      setEditingContent(true);
    }
  }, [editingContent, item, contentDraft, captureItemId, addToast]);

  const handleSaveDistilledOutput = useCallback(async (): Promise<DistilledOutput | null> => {
    if (!distilledOutput) {
      addToast('没有可保存的整理结果', 'warning');
      return null;
    }

    setSavingDistilled(true);
    try {
      const updated = await window.pinmind.distilledOutputs.review(distilledOutput.id, 'edit', {
        suggestedTitle: titleDraft.trim() || distilledOutput.suggestedTitle,
        summary: summaryDraft.trim() || distilledOutput.summary,
        category: categoryDraft.trim() || distilledOutput.category,
        tags,
        documentType: distilledOutput.documentType ?? DEFAULT_DISTILLED_TYPE,
        contentMarkdown: markdownDraft.trim() || distilledOutput.contentMarkdown,
      });
      setDistilledOutput(updated);
      setSummaryDraft(updated.summary ?? '');
      setCategoryDraft(updated.category ?? '');
      setMarkdownDraft(updated.contentMarkdown ?? '');
      addToast('审阅结果已保存', 'success');
      return updated;
    } catch (err) {
      addToast(err instanceof Error ? err.message : '保存失败', 'error');
      return null;
    } finally {
      setSavingDistilled(false);
    }
  }, [distilledOutput, titleDraft, summaryDraft, categoryDraft, tags, markdownDraft, addToast]);

  const handleExport = useCallback(async () => {
    if (!distilledOutput) {
      addToast('请先完成整理并审阅', 'warning');
      return;
    }
    setExporting(true);
    try {
      const appSettings = await window.pinmind.settings.get();
      const vaultPath = appSettings?.vault?.vaultPath;
      if (!vaultPath) {
        addToast('写入路径未设置，请先在设置中配置 Obsidian Vault 路径', 'warning');
        return;
      }

      // V2.1: 优先走 pipeline retry（自动重新整理 + 写入）
      if (sourceItem?.id && window.pinmind?.pipeline) {
        const result = await window.pinmind.pipeline.retryExport(sourceItem.id);
        if (result.success) {
          addToast(`已写入 Obsidian: ${result.relativePath ?? ''}`, 'success');
          setShowExportPreview(false);
          setExportStatus('success');
          setExportRecordId(result.exportRecord?.id ?? null);
          return;
        }
        // Pipeline retry failed, fall through to legacy export
      }

      // Fallback: legacy export.single
      const exportableOutput = distilledOutput.reviewStatus === 'pending'
        ? await handleSaveDistilledOutput()
        : distilledOutput;
      if (!exportableOutput) return;

      const record = await window.pinmind.export.single(exportableOutput.id);

      switch (record.status) {
        case 'success':
          addToast(`已输出到 Obsidian: ${record.relativeFilePath}`, 'success');
          setShowExportPreview(false);
          setExportStatus('success');
          setExportRecordId(record.id);
          break;
        case 'conflict':
          addToast(`文件已存在，已跳过: ${record.relativeFilePath}`, 'warning');
          setExportStatus('success');
          setExportRecordId(record.id);
          break;
        case 'failed': {
          const errMsg = record.error || '未知写入错误';
          if (errMsg.includes('Vault path does not exist')) {
            addToast('写入路径不存在，请检查设置中的 Vault 路径是否正确', 'error');
          } else if (errMsg.includes('EACCES') || errMsg.includes('permission')) {
            addToast('文件写入失败：没有写入权限，请检查目录权限', 'error');
          } else {
            addToast(`写入失败: ${errMsg}`, 'error');
          }
          setExportStatus('failed');
          setExportRecordId(record.id);
          break;
        }
        default:
          addToast(`写入返回未知状态: ${record.status}`, 'warning');
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : '输出到 Obsidian 失败';
      addToast(msg, 'error');
    } finally {
      setExporting(false);
    }
  }, [distilledOutput, sourceItem, handleSaveDistilledOutput, addToast]);

  const handleCopyMarkdown = useCallback(async () => {
    const md = generateMarkdown();
    if (!md) {
      addToast('没有可复制的内容', 'warning');
      return;
    }
    try {
      await navigator.clipboard.writeText(md);
      addToast('Markdown 已复制到剪贴板', 'success');
    } catch {
      addToast('复制失败，请手动复制', 'error');
    }
  }, [generateMarkdown, addToast]);

  const handleOpenInBrowser = useCallback(() => {
    if (item?.sourceUrl) {
      window.open(item.sourceUrl, '_blank');
    }
  }, [item]);

  const handleOpenInObsidian = useCallback(async () => {
    if (!exportRecordId) {
      addToast('暂无输出记录', 'warning');
      return;
    }
    try {
      await window.pinmind.export.revealInVault(exportRecordId);
    } catch (err) {
      addToast(err instanceof Error ? err.message : '打开失败', 'error');
    }
  }, [exportRecordId, addToast]);

  const handleToggleEditTitle = useCallback(async () => {
    if (editingTitle) {
      if (item && titleDraft !== item.title && captureItemId) {
        try {
          const updated = await window.pinmind.captureItems.update(captureItemId, {
            title: titleDraft,
          });
          setItem(updated);
          addToast('标题已更新', 'success');
        } catch (err) {
          addToast(err instanceof Error ? err.message : '更新标题失败', 'error');
          return;
        }
      }
      setEditingTitle(false);
    } else {
      setTitleDraft(item?.title ?? '');
      setEditingTitle(true);
    }
  }, [editingTitle, item, titleDraft, captureItemId, addToast]);

  const handleAddTag = useCallback(() => {
    const tag = newTagInput.trim();
    if (!tag) return;
    if (tags.includes(tag)) {
      addToast('标签已存在', 'warning');
      return;
    }
    setTags((prev) => [...prev, tag]);
    setNewTagInput('');
  }, [newTagInput, tags, addToast]);

  const handleRemoveTag = useCallback((tag: string) => {
    setTags((prev) => prev.filter((t) => t !== tag));
  }, []);

  // ── Derived values ──

  const captureTimeStr = item?.capturedAt
    ? new Date(item.capturedAt).toLocaleString('zh-CN', {
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit',
      })
    : '--';

  const sourceTypeLabel = item?.sourceUrl ? '网页文章' : item?.type === 'image' ? '图片' : '文本';

  let sourceDomain = '';
  if (item?.sourceUrl) {
    try { sourceDomain = new URL(item.sourceUrl).hostname; } catch { sourceDomain = item.sourceUrl; }
  }

  const reviewStatus = distilledOutput?.reviewStatus;
  const reviewStatusLabel = reviewStatus === 'accepted' ? '已确认'
    : reviewStatus === 'edited' ? '已编辑'
    : reviewStatus === 'rejected' ? '已拒绝'
    : '待审阅';
  const reviewStatusColor = reviewStatus === 'accepted' ? 'var(--pm-success)'
    : reviewStatus === 'edited' ? 'var(--pm-info)'
    : reviewStatus === 'rejected' ? 'var(--pm-danger)'
    : 'var(--pm-warning)';

  const markdownContent = generateMarkdown();
  const exportFilePath = distilledOutput?.category
    ? `${categoryDraft || distilledOutput.category}/${titleDraft || item?.title || '无标题'}.md`
    : `${titleDraft || item?.title || '无标题'}.md`;

  // ── Render: Loading ──
  if (loading) {
    return (
      <PageShell className="flex h-full items-center justify-center">
        <LoadingState title="正在加载内容" description="正在读取内容和整理结果。" />
      </PageShell>
    );
  }

  // ── Render: Error ──
  if (error) {
    return (
      <PageShell className="flex h-full items-center justify-center">
        <ErrorState
          title="加载内容失败"
          reason={error}
          suggestion="请重试加载，或返回收集箱检查该条目是否仍然存在。"
          action={{ label: '重试', onClick: () => void loadItem() }}
        />
      </PageShell>
    );
  }

  // ── Render: No itemId ──
  if (!itemId || !item) {
    return (
      <PageShell className="flex h-full items-center justify-center">
        <ErrorState
          title="未找到该碎片"
          reason="该条目可能已被删除，或当前路由参数无效。"
          suggestion="返回收集箱，重新选择一条内容。"
          action={{ label: '返回收集箱', onClick: handleBack }}
        />
      </PageShell>
    );
  }

  return (
    <PageShell className="flex h-full flex-col overflow-hidden p-0">
      {/* ── Header ── */}
      <div className="shrink-0 border-b border-[color:var(--pm-border-subtle)] bg-gradient-to-b from-white/88 to-[rgba(255,249,241,0.78)] backdrop-blur-[8px]">
        {/* Row 1: Back + Title */}
        <div className="flex items-center gap-2.5 px-4 pt-3 pb-1.5">
          <button type="button" onClick={handleBack} className="pinmind-btn pinmind-btn-ghost motion-button flex items-center gap-1.5 text-[13px]">
            <PinStackIcon name="arrow-left" size={14} />
            返回
          </button>
          <div className="mx-1.5 h-4 w-px bg-[color:var(--pm-border-subtle)]" />
          <div className="flex items-center gap-2 min-w-0 flex-1">
            {editingTitle ? (
              <input
                ref={titleInputRef}
                type="text"
                value={titleDraft}
                onChange={(e) => setTitleDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') void handleToggleEditTitle();
                  if (e.key === 'Escape') { setEditingTitle(false); setTitleDraft(item.title); }
                }}
                onBlur={() => void handleToggleEditTitle()}
                className="flex-1 min-w-0 text-[15px] font-semibold tracking-tight text-[color:var(--pm-text-primary)] bg-white/80 border border-[color:var(--pm-border-subtle)] rounded-[var(--radius-control)] px-2 py-1 outline-none focus:border-[color:var(--pm-brand-primary)]"
              />
            ) : (
              <h1 className="truncate text-[17px] font-[650] tracking-tight text-[color:var(--pm-text-primary)]">
                {titleDraft || item.title || '无标题'}
              </h1>
            )}
            <button type="button" onClick={() => void handleToggleEditTitle()} className="shrink-0 text-[color:var(--pm-text-tertiary)] hover:text-[color:var(--pm-text-secondary)] transition-colors" title="编辑标题">
              <PinStackIcon name="edit" size={14} />
            </button>
          </div>
          {/* Review status badge */}
          {distilledOutput && (
            <span className="shrink-0 inline-flex items-center gap-1 rounded-full border px-2.5 py-1 text-[11px] font-medium" style={{ color: reviewStatusColor, borderColor: reviewStatusColor, background: `${reviewStatusColor}11` }}>
              {reviewStatusLabel}
            </span>
          )}
        </div>

        {/* Row 2: Meta + Actions */}
        <div className="flex items-center justify-between gap-2 px-4 pb-2.5">
          <div className="flex flex-wrap items-center gap-1.5 text-[11px] text-[color:var(--pm-text-tertiary)]">
            <span>{sourceTypeLabel}</span>
            {item.sourceUrl && <span>· {sourceDomain}</span>}
            <span>· {captureTimeStr}</span>
            {tags.length > 0 && <span>· {tags.length} 标签</span>}
          </div>
          <div className="flex items-center gap-1.5">
            {!distilledOutput && (
              <button type="button" onClick={() => void handleDistill()} className="pinmind-btn pinmind-btn-secondary motion-button text-[12px] flex items-center gap-1.5">
                <PinStackIcon name="spark" size={13} />
                整理
              </button>
            )}
            <button
              type="button"
              onClick={() => setShowSource((v) => !v)}
              className={`pinmind-btn motion-button text-[12px] flex items-center gap-1.5 ${showSource ? 'pinmind-btn-primary' : 'pinmind-btn-ghost'}`}
            >
              <PinStackIcon name="save" size={13} />
              原文
            </button>
            <button
              type="button"
              onClick={() => setShowExportPreview((v) => !v)}
              className={`pinmind-btn motion-button text-[12px] flex items-center gap-1.5 ${showExportPreview ? 'pinmind-btn-primary' : 'pinmind-btn-ghost'}`}
            >
              <PinStackIcon name="launcher" size={13} />
              输出预览
            </button>
            {exportStatus === 'success' ? (
              /* 已成功输出：主按钮为"打开 Obsidian 文件" */
              <button
                type="button"
                onClick={() => void handleOpenInObsidian()}
                className="pinmind-btn pinmind-btn-primary motion-button text-[12px] flex items-center gap-1.5"
              >
                <PinStackIcon name="panel" size={13} />
                打开 Obsidian 文件
              </button>
            ) : exportStatus === 'failed' ? (
              /* 输出失败：主按钮为"重试写入 Obsidian" */
              <button
                type="button"
                onClick={() => void handleExport()}
                disabled={exporting}
                className="pinmind-btn pinmind-btn-primary motion-button text-[12px] flex items-center gap-1.5"
              >
                <PinStackIcon name="refresh" size={13} />
                {exporting ? '写入中...' : '重试写入 Obsidian'}
              </button>
            ) : (
              /* 未写入：写入 Obsidian 降级为次级操作 */
              <button
                type="button"
                onClick={() => void handleExport()}
                disabled={exporting}
                className="pinmind-btn pinmind-btn-secondary motion-button text-[12px] flex items-center gap-1.5"
              >
                <PinStackIcon name="check" size={13} />
                {exporting ? '写入中...' : '写入 Obsidian'}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* ── Main Content: Two-Column ── */}
      <div className="flex-1 min-h-0 flex">
        {/* ── Left Panel: Source (collapsible) ── */}
        {showSource && (
          <div className="w-[340px] shrink-0 flex flex-col min-h-0 border-r border-[color:var(--pm-border-subtle)]">
            <div className="shrink-0 px-3 py-2 border-b border-[color:var(--pm-border-subtle)] bg-[rgba(251,247,240,0.5)]">
              <h2 className="text-[12px] font-semibold text-[color:var(--pm-text-primary)]">原始内容</h2>
            </div>
            <ScrollContainer className="flex-1 min-h-0">
              <div className="p-3 flex flex-col gap-3">
                {editingContent ? (
                  <textarea
                    value={contentDraft}
                    onChange={(e) => setContentDraft(e.target.value)}
                    className="rounded-[var(--radius-control)] border border-[color:var(--pm-brand-primary)] bg-white/80 p-3 text-[13px] leading-[1.65] text-[color:var(--pm-text-secondary)] whitespace-pre-wrap break-words min-h-[180px] resize-y outline-none focus:ring-1 focus:ring-[color:var(--pm-brand-primary)]"
                  />
                ) : item.type === 'image' && item.filePath ? (
                  <ImagePreview filePath={item.filePath} title={item.title} maxHeight={360} />
                ) : (
                  <div className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-white/60 p-3 text-[13px] leading-[1.65] text-[color:var(--pm-text-secondary)] whitespace-pre-wrap break-words select-text">
                    {item.rawText || '(无内容)'}
                  </div>
                )}
                <div className="flex gap-2">
                  <button type="button" onClick={() => void handleToggleEditContent()} className={`pinmind-btn motion-button text-[12px] flex items-center gap-1.5 ${editingContent ? 'pinmind-btn-primary' : 'pinmind-btn-secondary'}`}>
                    <PinStackIcon name="edit" size={12} />
                    {editingContent ? '完成编辑' : '编辑内容'}
                  </button>
                  {item.sourceUrl && (
                    <button type="button" onClick={handleOpenInBrowser} className="pinmind-btn pinmind-btn-ghost motion-button text-[12px] flex items-center gap-1.5" style={{ color: 'var(--pm-brand-primary)' }}>
                      <PinStackIcon name="arrow-right" size={12} /> 在浏览器中打开
                    </button>
                  )}
                </div>
                {/* Source meta */}
                <div className="flex flex-col gap-1.5 text-[11px]">
                  <MetaRow label="来源类型" value={sourceTypeLabel} />
                  {item.sourceUrl && <MetaRow label="域名" value={sourceDomain} />}
                  <MetaRow label="抓取时间" value={captureTimeStr} />
                  {item.sourceUrl && <MetaRow label="链接" value={item.sourceUrl} />}
                </div>
                {/* User note */}
                <div className="flex flex-col gap-1.5">
                  <h3 className="text-[11px] font-semibold text-[color:var(--pm-text-tertiary)] tracking-[0.08em] uppercase">备注</h3>
                  <textarea
                    value={userNote}
                    onChange={(e) => setUserNote(e.target.value)}
                    placeholder="添加备注..."
                    className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-white/60 p-3 text-[13px] leading-[1.65] text-[color:var(--pm-text-secondary)] min-h-[60px] resize-y outline-none focus:border-[color:var(--pm-brand-primary)] transition-colors"
                  />
                </div>
              </div>
            </ScrollContainer>
          </div>
        )}

        {/* ── Right Panel: Review Editor ── */}
        <div className="flex-1 min-h-0 flex flex-col">
          <ScrollContainer className="flex-1 min-h-0">
            <div className="max-w-[680px] mx-auto p-4 flex flex-col gap-4">
              {distilledLoading ? (
                <div className="flex items-center justify-center py-16">
                  <div className="flex flex-col items-center gap-3">
                    <PinStackIcon name="refresh" size={20} className="animate-spin" />
                    <span className="text-[13px] text-[color:var(--pm-text-tertiary)]">加载整理结果...</span>
                  </div>
                </div>
              ) : !distilledOutput ? (
                <div className="flex flex-col items-center justify-center py-16 gap-4">
                  <PinStackIcon name="spark" size={36} style={{ color: 'var(--pm-text-tertiary)' }} />
                  <p className="text-[14px] text-[color:var(--pm-text-tertiary)]">尚未整理</p>
                  <p className="text-[12px] text-[color:var(--pm-text-tertiary)] text-center max-w-[260px]">
                    点击上方「整理」按钮，AI 将自动生成摘要、标题和标签建议
                  </p>
                  <button type="button" onClick={() => void handleDistill()} className="pinmind-btn pinmind-btn-secondary motion-button text-[13px] flex items-center gap-1.5">
                    <PinStackIcon name="spark" size={14} />
                    开始整理
                  </button>
                </div>
              ) : (
                <>
                  {/* ── Summary ── */}
                  <SectionBlock title="摘要">
                    <textarea
                      value={summaryDraft}
                      onChange={(e) => setSummaryDraft(e.target.value)}
                      className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-white/60 p-3 text-[14px] leading-[1.7] text-[color:var(--pm-text-primary)] min-h-[80px] resize-y outline-none focus:border-[color:var(--pm-brand-primary)]"
                      placeholder="AI 摘要"
                    />
                  </SectionBlock>

                  {/* ── Title ── */}
                  <SectionBlock title="标题">
                    <input
                      value={titleDraft}
                      onChange={(e) => setTitleDraft(e.target.value)}
                      className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-[color:var(--pm-brand-soft)] px-3 py-2 text-[14px] font-medium text-[color:var(--pm-text-primary)] outline-none focus:border-[color:var(--pm-brand-primary)]"
                      placeholder="标题"
                    />
                  </SectionBlock>

                  {/* ── Category ── */}
                  <SectionBlock title="归档分类">
                    <input
                      value={categoryDraft}
                      onChange={(e) => setCategoryDraft(e.target.value)}
                      className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-white/60 px-3 py-2 text-[13px] text-[color:var(--pm-text-primary)] outline-none focus:border-[color:var(--pm-brand-primary)]"
                      placeholder="00_Inbox/PinMind"
                    />
                  </SectionBlock>

                  {/* ── Tags ── */}
                  <SectionBlock title="标签">
                    <div className="flex flex-wrap gap-2 mb-2">
                      {tags.length > 0 ? (
                        tags.map((tag) => (
                          <span key={tag} className="inline-flex items-center gap-1 rounded-[999px] border border-[color:var(--pm-brand-border)] bg-[color:var(--pm-brand-soft)] px-3 py-1.5 text-[12px] font-medium text-[color:var(--pm-brand-text)]">
                            #{tag}
                            <button type="button" onClick={() => handleRemoveTag(tag)} className="ml-0.5 hover:text-[color:var(--pm-status-danger)] transition-colors" title="移除">&times;</button>
                          </span>
                        ))
                      ) : (
                        <span className="text-[12px] text-[color:var(--pm-text-tertiary)]">暂无标签</span>
                      )}
                    </div>
                    {distilledOutput.tags && distilledOutput.tags.length > 0 && (
                      <div className="mb-2">
                        <p className="text-[11px] text-[color:var(--pm-text-tertiary)] mb-1.5">AI 建议（点击添加）</p>
                        <div className="flex flex-wrap gap-1.5">
                          {distilledOutput.tags.filter((t) => !tags.includes(t)).map((tag) => (
                            <button key={tag} type="button" onClick={() => setTags((prev) => [...prev, tag])} className="inline-flex items-center rounded-[999px] border border-dashed border-[color:var(--pm-border-subtle)] px-3 py-1.5 text-[12px] text-[color:var(--pm-text-tertiary)] hover:border-[color:var(--pm-brand-primary)] hover:text-[color:var(--pm-brand-primary)] transition-colors cursor-pointer">
                              + #{tag}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                    <div className="flex items-center gap-2">
                      <input type="text" value={newTagInput} onChange={(e) => setNewTagInput(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') handleAddTag(); }} placeholder="添加标签..." className="flex-1 min-w-0 rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-white/60 px-3 py-1.5 text-[12px] text-[color:var(--pm-text-secondary)] outline-none focus:border-[color:var(--pm-brand-primary)]" />
                      <button type="button" onClick={handleAddTag} disabled={!newTagInput.trim()} className="pinmind-btn pinmind-btn-ghost motion-button text-[12px] px-2 disabled:opacity-40">添加</button>
                    </div>
                  </SectionBlock>

                  {/* ── Content Markdown ── */}
                  <SectionBlock title="正文 Markdown">
                    <textarea
                      value={markdownDraft}
                      onChange={(e) => setMarkdownDraft(e.target.value)}
                      className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.02)] p-3 font-mono text-[12px] leading-[1.55] text-[color:var(--pm-text-secondary)] min-h-[240px] resize-y outline-none focus:border-[color:var(--pm-brand-primary)]"
                      placeholder="正文 Markdown"
                    />
                  </SectionBlock>

                  {/* ── Confidence ── */}
                  {distilledOutput.confidence != null && (
                    <SectionBlock title="置信度">
                      <div className="flex items-center gap-2">
                        <div className="h-2 flex-1 rounded-full bg-[color:var(--pm-border-subtle)] overflow-hidden">
                          <div className="h-full rounded-full bg-[color:var(--pm-brand-primary)] transition-all" style={{ width: `${Math.round(distilledOutput.confidence * 100)}%` }} />
                        </div>
                        <span className="text-[12px] font-medium text-[color:var(--pm-text-secondary)]">{Math.round(distilledOutput.confidence * 100)}%</span>
                      </div>
                    </SectionBlock>
                  )}

                  {/* ── Save button ── */}
                  <div className="flex items-center gap-2 pt-2">
                    <button type="button" onClick={() => void handleSaveDistilledOutput()} disabled={savingDistilled} className="pinmind-btn pinmind-btn-primary motion-button text-[13px] flex items-center gap-1.5">
                      <PinStackIcon name="check" size={14} />
                      {savingDistilled ? '保存中...' : '保存审阅结果'}
                    </button>
                    <button type="button" onClick={() => void handleCopyMarkdown()} className="pinmind-btn pinmind-btn-ghost motion-button text-[13px] flex items-center gap-1.5">
                      <PinStackIcon name="copy" size={14} />
                      复制 Markdown
                    </button>
                  </div>
                </>
              )}
            </div>
          </ScrollContainer>
        </div>

        {/* ── Export Preview Panel (collapsible right) ── */}
        {showExportPreview && (
          <div className="w-[340px] shrink-0 flex flex-col min-h-0 border-l border-[color:var(--pm-border-subtle)]">
            <div className="shrink-0 px-3 py-2 border-b border-[color:var(--pm-border-subtle)] bg-[rgba(251,247,240,0.5)]">
              <h2 className="text-[12px] font-semibold text-[color:var(--pm-text-primary)]">输出预览</h2>
            </div>
            <ScrollContainer className="flex-1 min-h-0">
              <div className="p-3 flex flex-col gap-3">
                <div className="flex flex-col gap-1">
                  <span className="text-[11px] font-semibold text-[color:var(--pm-text-tertiary)]">文件路径</span>
                  <div className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-white/80 px-3 py-2 text-[12px] text-[color:var(--pm-text-secondary)] break-all select-text">
                    {exportFilePath}
                  </div>
                </div>
                <div className="flex flex-col gap-1">
                  <span className="text-[11px] font-semibold text-[color:var(--pm-text-tertiary)]">Markdown 内容</span>
                  <div className="rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.02)] p-3 font-mono text-[11px] leading-[1.5] text-[color:var(--pm-text-secondary)] whitespace-pre-wrap break-all select-text max-h-[500px] overflow-y-auto">
                    {markdownContent}
                  </div>
                </div>
                <div className="flex items-center gap-2 rounded-[var(--radius-control)] border border-[color:var(--pm-border-subtle)] bg-[color:var(--pm-bg-subtle)] px-3 py-2">
                  <PinStackIcon name="text" size={12} />
                  <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">{item.rawText.length} 字</span>
                </div>
              </div>
            </ScrollContainer>
          </div>
        )}
      </div>
    </PageShell>
  );
}

// ─── Helper Components ──────────────────────────────────────────────────────

function MetaRow({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div className="flex items-baseline gap-2">
      <span className="text-[11px] font-medium text-[color:var(--pm-text-tertiary)] min-w-[56px] shrink-0">{label}</span>
      <span className="text-[12px] text-[color:var(--pm-text-primary)] select-text break-all">{value}</span>
    </div>
  );
}

function SectionBlock({ title, children }: { title: string; children: React.ReactNode }): JSX.Element {
  return (
    <div className="flex flex-col gap-1.5">
      <h3 className="text-[11px] font-semibold text-[color:var(--pm-text-tertiary)] tracking-[0.06em] uppercase">{title}</h3>
      {children}
    </div>
  );
}
