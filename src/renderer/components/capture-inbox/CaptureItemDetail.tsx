import { useCallback, useEffect, useState } from 'react';
import type { CaptureItem, DistillLineageStatus } from '../../../shared/types';
import { ScrollContainer } from '../shared/ScrollContainer';

// ─── Types ───────────────────────────────────────────────────────────────────

interface CaptureItemDetailProps {
  item: CaptureItem | null;
  onUpdate: (id: string, patch: Partial<CaptureItem>) => Promise<CaptureItem>;
  onDelete: (id: string) => Promise<boolean>;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatTimestamp(timestamp: number): string {
  return new Date(timestamp * 1000).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

function getStatusLabel(status: CaptureItem['status']): string {
  const map: Record<CaptureItem['status'], string> = {
    pending: '待整理',
    distilling: '整理中',
    archived: '已归档',
    ignored: '已忽略',
    failed: '处理失败',
    transcribing: '正在转写',
    transcribed: '转写完成',
  };
  return map[status];
}

function getTypeLabel(type: CaptureItem['type']): string {
  const map: Record<CaptureItem['type'], string> = {
    text: '文本',
    link: '链接',
    image: '图片',
    audio: '语音',
  };
  return map[type];
}

function getStatusOptions(currentStatus: CaptureItem['status']): { value: CaptureItem['status']; label: string }[] {
  const all: { value: CaptureItem['status']; label: string }[] = [
    { value: 'pending', label: '待整理' },
    { value: 'archived', label: '已归档' },
    { value: 'ignored', label: '已忽略' },
    { value: 'failed', label: '处理失败' },
  ];
  return all.filter((opt) => opt.value !== currentStatus);
}

// ─── CaptureItemDetail ───────────────────────────────────────────────────────

/**
 * Distill progress section: shows task progress when CaptureItem is 'distilling'.
 */
function DistillProgressSection({ captureItemId }: { captureItemId: string }): JSX.Element {
  const [lineage, setLineage] = useState<DistillLineageStatus | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const load = async () => {
      try {
        const result = await window.acmind.sourceItems.getDistillStatus(captureItemId);
        if (!cancelled) setLineage(result);
      } catch {
        // Ignore errors, show nothing
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    // Auto-refresh every 3 seconds while distilling
    const interval = setInterval(() => { void load(); }, 3000);
    return () => { cancelled = true; clearInterval(interval); };
  }, [captureItemId]);

  if (loading && !lineage) {
    return (
      <div className="acmind-detail-section mb-4">
        <h4 className="acmind-field-label mb-2">整理进度</h4>
        <p className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>加载中...</p>
      </div>
    );
  }

  if (!lineage) return <></>;

  const totalTasks = lineage.aiTasks.length;
  const doneTasks = lineage.aiTasks.filter((t) => t.status === 'done').length;
  const failedTasks = lineage.aiTasks.filter((t) => t.status === 'failed').length;
  const runningTasks = lineage.aiTasks.filter((t) => t.status === 'running' || t.status === 'queued').length;
  const progress = totalTasks > 0 ? Math.round((doneTasks / totalTasks) * 100) : 0;

  return (
    <div className="acmind-detail-section mb-4">
      <h4 className="acmind-field-label mb-2">整理进度</h4>
      <div className="flex flex-col gap-2">
        {/* Progress bar */}
        <div
          className="h-2 rounded-full overflow-hidden"
          style={{ background: 'var(--pm-bg-subtle)' }}
        >
          <div
            className="h-full rounded-full transition-all duration-500"
            style={{
              width: `${progress}%`,
              background: failedTasks > 0 && doneTasks === 0
                ? 'var(--pm-status-danger)'
                : 'var(--pm-brand-primary)',
            }}
          />
        </div>
        <div className="flex items-center justify-between text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
          <span>{doneTasks}/{totalTasks} 任务完成</span>
          <span>{progress}%</span>
        </div>
        {/* Task breakdown */}
        <div className="grid grid-cols-3 gap-2 mt-1">
          <div className="rounded-lg px-2 py-1.5 text-center" style={{ background: 'rgba(59, 130, 246, 0.06)' }}>
            <div className="text-[13px] font-medium" style={{ color: 'var(--pm-status-info)' }}>{runningTasks}</div>
            <div className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>运行中</div>
          </div>
          <div className="rounded-lg px-2 py-1.5 text-center" style={{ background: 'rgba(34, 197, 94, 0.06)' }}>
            <div className="text-[13px] font-medium" style={{ color: 'var(--pm-status-success)' }}>{doneTasks}</div>
            <div className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>已完成</div>
          </div>
          <div className="rounded-lg px-2 py-1.5 text-center" style={{ background: 'rgba(239, 68, 68, 0.06)' }}>
            <div className="text-[13px] font-medium" style={{ color: 'var(--pm-status-danger)' }}>{failedTasks}</div>
            <div className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>失败</div>
          </div>
        </div>
        {/* SourceItem link */}
        {lineage.sourceItemId && (
          <p className="text-[10px] mt-1" style={{ color: 'var(--pm-text-tertiary)' }}>
            SourceItem: {lineage.sourceItemId.slice(0, 12)}...
          </p>
        )}
      </div>
    </div>
  );
}

/**
 * Detail panel for viewing and editing a selected capture item.
 */
export function CaptureItemDetail({ item, onUpdate, onDelete }: CaptureItemDetailProps): JSX.Element {
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [editingNote, setEditingNote] = useState(false);
  const [noteValue, setNoteValue] = useState('');
  const [savingNote, setSavingNote] = useState(false);
  const [copied, setCopied] = useState(false);
  const [imageDataUrl, setImageDataUrl] = useState<string | null>(null);
  const [imageError, setImageError] = useState<string | null>(null);

  // ── Load image when item changes ──

  useEffect(() => {
    if (!item || item.type !== 'image' || !item.filePath) {
      setImageDataUrl(null);
      setImageError(null);
      return;
    }

    let cancelled = false;
    (async () => {
      setImageError(null);
      setImageDataUrl(null);
      try {
        const result = await window.acmind.captureItems.readImage(item.filePath);
        if (cancelled) return;
        if (result.ok && result.dataUrl) {
          setImageDataUrl(result.dataUrl);
        } else {
          setImageError(result.error || '图片加载失败');
        }
      } catch (err) {
        if (cancelled) return;
        setImageError(err instanceof Error ? err.message : String(err));
      }
    })();

    return () => { cancelled = true; };
  }, [item]);

  const handleDelete = useCallback(async () => {
    if (!item) return;
    setDeleting(true);
    try {
      await onDelete(item.id);
    } finally {
      setDeleting(false);
      setConfirmDelete(false);
    }
  }, [item, onDelete]);

  const handleStatusChange = useCallback(
    async (newStatus: CaptureItem['status']) => {
      if (!item) return;
      await onUpdate(item.id, { status: newStatus });
    },
    [item, onUpdate],
  );

  const handleCopyRawText = useCallback(async () => {
    if (!item) return;
    const textToCopy = item.type === 'link' ? item.sourceUrl : item.rawText;
    if (!textToCopy) return;
    try {
      await navigator.clipboard.writeText(textToCopy);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback: select text
    }
  }, [item]);

  const handleSaveNote = useCallback(async () => {
    if (!item) return;
    setSavingNote(true);
    try {
      await onUpdate(item.id, { userNote: noteValue });
      setEditingNote(false);
    } finally {
      setSavingNote(false);
    }
  }, [item, noteValue, onUpdate]);

  const handleStartEditNote = useCallback(() => {
    if (!item) return;
    setNoteValue(item.userNote);
    setEditingNote(true);
  }, [item]);

  // ── Empty state ──

  if (!item) {
    return (
      <div className="acmind-capture-detail acmind-detail-empty">
        <div className="flex flex-col items-center justify-center h-full gap-3">
          <svg
            width="40"
            height="40"
            viewBox="0 0 40 40"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            style={{ color: 'var(--pm-text-tertiary)', opacity: 0.4 }}
          >
            <rect x="6" y="8" width="28" height="24" rx="4" stroke="currentColor" strokeWidth="1.5" />
            <path d="M6 14H34" stroke="currentColor" strokeWidth="1.5" />
            <path d="M14 8V6C14 4.89543 14.8954 4 16 4H24C25.1046 4 26 4.89543 26 6V8" stroke="currentColor" strokeWidth="1.5" />
            <path d="M16 20L18 22L24 18" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <p className="text-[13px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            选择一条碎片查看详情
          </p>
        </div>
      </div>
    );
  }

  const statusOptions = getStatusOptions(item.status);

  return (
    <div className="acmind-capture-detail">
      <ScrollContainer className="p-5">
        {/* Header */}
        <div className="flex items-center justify-between mb-5">
          <h3 className="text-[15px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
            碎片详情
          </h3>
          <div className="flex items-center gap-2">
            {!confirmDelete ? (
              <button
                type="button"
                onClick={() => setConfirmDelete(true)}
                className="acmind-btn acmind-btn-ghost acmind-btn-danger motion-button text-[12px]"
              >
                删除
              </button>
            ) : (
              <div className="flex items-center gap-2">
                <span className="text-[11px]" style={{ color: 'var(--pm-status-danger)' }}>
                  确认删除？
                </span>
                <button
                  type="button"
                  onClick={handleDelete}
                  disabled={deleting}
                  className="acmind-btn acmind-btn-primary motion-button text-[12px]"
                  style={{
                    background: 'var(--pm-status-danger)',
                    borderColor: 'var(--pm-status-danger)',
                    boxShadow: '0 4px 12px rgba(201, 75, 75, 0.16)',
                  }}
                >
                  {deleting ? '删除中...' : '确认'}
                </button>
                <button
                  type="button"
                  onClick={() => setConfirmDelete(false)}
                  className="acmind-btn acmind-btn-ghost motion-button text-[12px]"
                >
                  取消
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Title */}
        <div className="acmind-detail-section mb-4">
          <h4 className="acmind-field-label mb-2">标题</h4>
          <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
            {item.title || '未命名碎片'}
          </p>
        </div>

        {/* Content */}
        <div className="acmind-detail-section mb-4">
          <div className="flex items-center justify-between mb-2">
            <h4 className="acmind-field-label">
              {item.type === 'link' ? '链接地址' : item.type === 'image' ? '图片信息' : item.type === 'audio' ? '转写内容' : '原文内容'}
            </h4>
            {item.type !== 'image' && (item.rawText || item.sourceUrl) ? (
              <button
                type="button"
                onClick={handleCopyRawText}
                className="acmind-btn acmind-btn-ghost motion-button text-[11px] px-2 py-1"
                style={{ color: copied ? 'var(--pm-status-success)' : 'var(--pm-brand-primary)' }}
              >
                {copied ? '已复制 ✓' : '复制原文'}
              </button>
            ) : null}
          </div>
          {item.type === 'link' ? (
            <div>
              <a
                href={item.sourceUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-[13px] break-all underline"
                style={{ color: 'var(--pm-status-info)' }}
              >
                {item.sourceUrl || '无链接'}
              </a>
              {item.rawText ? (
                <div className="mt-3">
                  <p className="text-[11px] mb-1" style={{ color: 'var(--pm-text-tertiary)' }}>摘要</p>
                  <div
                    className="acmind-detail-content-text text-[13px]"
                    style={{ color: 'var(--pm-text-primary)' }}
                  >
                    {item.rawText}
                  </div>
                </div>
              ) : null}
            </div>
          ) : item.type === 'image' ? (
            <div className="acmind-detail-image-preview">
              {imageError ? (
                <div
                  className="flex flex-col items-center justify-center py-6 rounded-lg"
                  style={{
                    background: 'rgba(201, 75, 75, 0.06)',
                    border: '1px dashed rgba(201, 75, 75, 0.24)',
                  }}
                >
                  <svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ color: 'var(--pm-status-danger)', opacity: 0.6 }}>
                    <circle cx="14" cy="14" r="11" stroke="currentColor" strokeWidth="1.5" />
                    <path d="M14 9V15M14 18V18.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                  </svg>
                  <span className="text-[11px] mt-2" style={{ color: 'var(--pm-status-danger)' }}>
                    {imageError}
                  </span>
                </div>
              ) : imageDataUrl ? (
                <img
                  src={imageDataUrl}
                  alt={item.title || '图片碎片'}
                  className="w-full max-h-[320px] object-contain rounded-lg"
                  style={{ background: 'var(--pm-bg-subtle)' }}
                />
              ) : (
                <div className="flex items-center justify-center py-8" style={{ color: 'var(--pm-text-tertiary)' }}>
                  <span className="text-[12px]">加载图片中...</span>
                </div>
              )}
            </div>
          ) : item.type === 'audio' ? (
            <div className="flex flex-col gap-3">
              {/* Audio file info */}
              <div
                className="flex items-center gap-3 p-3 rounded-lg"
                style={{ background: 'var(--pm-bg-subtle)', border: '1px solid var(--pm-border)' }}
              >
                <span style={{ fontSize: '20px' }}>🎤</span>
                <div className="flex flex-col gap-1 min-w-0 flex-1">
                  <span className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
                    {item.filePath?.split('/').pop() || '语音录音'}
                  </span>
                  <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                    {item.filePath || '未知路径'}
                  </span>
                </div>
                {item.filePath && (
                  <button
                    type="button"
                    onClick={() => { void window.acmind.app.openPath(item.filePath); }}
                    className="acmind-btn acmind-btn-ghost motion-button text-[11px] px-2 py-1"
                    style={{ color: 'var(--pm-brand-primary)' }}
                  >
                    打开录音
                  </button>
                )}
              </div>
              {/* Transcript text */}
              {item.rawText ? (
                <div>
                  <p className="text-[11px] mb-1" style={{ color: 'var(--pm-text-tertiary)' }}>转写文本</p>
                  <div
                    className="acmind-detail-content-text text-[13px] whitespace-pre-wrap"
                    style={{ color: 'var(--pm-text-primary)' }}
                  >
                    {item.rawText}
                  </div>
                </div>
              ) : (
                <div
                  className="flex flex-col items-center justify-center py-4 rounded-lg"
                  style={{
                    background: 'rgba(59, 130, 246, 0.06)',
                    border: '1px dashed rgba(59, 130, 246, 0.24)',
                  }}
                >
                  <span className="text-[12px]" style={{ color: 'var(--pm-status-info)' }}>
                    {item.status === 'transcribing' ? '正在转写中...' : '等待转写'}
                  </span>
                  <span className="text-[11px] mt-1" style={{ color: 'var(--pm-text-tertiary)' }}>
                    转写完成后将自动整理为知识笔记
                  </span>
                </div>
              )}
              {/* Retry transcription button for failed items */}
              {item.status === 'failed' && item.filePath && (
                <button
                  type="button"
                  onClick={() => {
                    void window.acmind.voice.retryTranscription(item.id).then((result: { success: boolean; jobId?: string; error?: string; engineUnavailable?: boolean }) => {
                      if (result.engineUnavailable) {
                        alert('需要配置转写引擎');
                      }
                    });
                  }}
                  className="acmind-btn acmind-btn-ghost motion-button text-[12px]"
                  style={{ color: 'var(--pm-status-warning)' }}
                >
                  重试转写
                </button>
              )}
            </div>
          ) : (
            <div
              className="acmind-detail-content-text text-[13px] whitespace-pre-wrap"
              style={{ color: 'var(--pm-text-primary)' }}
            >
              {item.rawText || '无内容'}
            </div>
          )}
        </div>

        {/* User Note */}
        <div className="acmind-detail-section mb-4">
          <div className="flex items-center justify-between mb-2">
            <h4 className="acmind-field-label">备注</h4>
            {!editingNote ? (
              <button
                type="button"
                onClick={handleStartEditNote}
                className="acmind-btn acmind-btn-ghost motion-button text-[11px] px-2 py-1"
                style={{ color: 'var(--pm-brand-primary)' }}
              >
                编辑
              </button>
            ) : null}
          </div>
          {editingNote ? (
            <div className="flex flex-col gap-2">
              <textarea
                value={noteValue}
                onChange={(e) => setNoteValue(e.target.value)}
                placeholder="添加备注..."
                className="acmind-textarea text-[13px]"
                rows={3}
                autoFocus
              />
              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setEditingNote(false)}
                  className="acmind-btn acmind-btn-ghost motion-button text-[12px]"
                >
                  取消
                </button>
                <button
                  type="button"
                  onClick={handleSaveNote}
                  disabled={savingNote}
                  className="acmind-btn acmind-btn-primary motion-button text-[12px]"
                >
                  {savingNote ? '保存中...' : '保存'}
                </button>
              </div>
            </div>
          ) : (
            <p className="text-[13px]" style={{ color: item.userNote ? 'var(--pm-text-primary)' : 'var(--pm-text-tertiary)' }}>
              {item.userNote || '暂无备注'}
            </p>
          )}
        </div>

        {/* Status */}
        <div className="acmind-detail-section mb-4">
          <h4 className="acmind-field-label mb-2">状态</h4>
          <div className="flex items-center gap-2">
            <span
              className="text-[12px] px-2 py-1 rounded-md font-medium"
              style={{
                color: item.status === 'pending' ? 'var(--pm-status-warning)' : item.status === 'archived' ? 'var(--pm-status-success)' : item.status === 'failed' ? 'var(--pm-status-danger)' : 'var(--pm-text-tertiary)',
                background: `${item.status === 'pending' ? 'var(--pm-status-warning)' : item.status === 'archived' ? 'var(--pm-status-success)' : item.status === 'failed' ? 'var(--pm-status-danger)' : 'var(--pm-text-tertiary)'}15`,
              }}
            >
              {getStatusLabel(item.status)}
            </span>
            <div className="flex gap-1">
              {statusOptions.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => handleStatusChange(opt.value)}
                  className="acmind-btn acmind-btn-ghost motion-button text-[11px] px-2 py-1"
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Distill progress (only when distilling) */}
        {item.status === 'distilling' && <DistillProgressSection captureItemId={item.id} />}

        {/* Metadata */}
        <div className="acmind-detail-section">
          <h4 className="acmind-field-label mb-3">元数据</h4>
          <div className="acmind-detail-meta-grid">
            <MetaRow label="类型" value={getTypeLabel(item.type)} />
            <MetaRow label="状态" value={getStatusLabel(item.status)} />
            <MetaRow label="收集时间" value={formatTimestamp(item.capturedAt)} />
            <MetaRow label="更新时间" value={formatTimestamp(item.updatedAt)} />
            {item.sourceUrl ? <MetaRow label="来源链接" value={item.sourceUrl} /> : null}
            {item.filePath ? <MetaRow label="文件路径" value={item.filePath.split('/').pop() || '-'} /> : null}
          </div>
        </div>
      </ScrollContainer>
    </div>
  );
}

// ─── MetaRow ─────────────────────────────────────────────────────────────────

function MetaRow({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div className="acmind-detail-meta-row">
      <span className="acmind-detail-meta-label">{label}</span>
      <span className="acmind-detail-meta-value" style={{ color: 'var(--pm-text-primary)' }}>
        {value}
      </span>
    </div>
  );
}
