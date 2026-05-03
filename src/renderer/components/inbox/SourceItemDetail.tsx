import { useCallback, useEffect, useRef, useState } from 'react';
import type { AiOperation, SourceItem } from '../../../shared/types';
import { ScrollContainer } from '../shared/ScrollContainer';

// ─── Types ───────────────────────────────────────────────────────────────────

interface SourceItemDetailProps {
  item: SourceItem | null;
  onDelete: (id: string) => Promise<boolean>;
}

const DEFAULT_DISTILL_OPERATIONS: AiOperation[] = [
  'summarize',
];

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

function truncateHash(hash: string | undefined, maxLen: number): string {
  if (!hash) return '-';
  if (hash.length <= maxLen) return hash;
  return hash.slice(0, maxLen) + '...';
}

function getStatusLabel(status: SourceItem['status']): string {
  const map: Record<SourceItem['status'], string> = {
    inbox: '收件箱',
    distilling: '整理中',
    distilled: '已整理',
    exported: '已写入',
    archived: '已归档',
  };
  return map[status];
}

function getTypeLabel(type: SourceItem['type']): string {
  const map: Record<SourceItem['type'], string> = {
    text: '文本',
    image: '图片',
    url: '网页',
  };
  return map[type];
}

function getSourceLabel(source: SourceItem['source']): string {
  const map: Record<SourceItem['source'], string> = {
    clipboard: '剪贴板',
    screenshot: '截图',
    manual: '手动录入',
    vault_import: '资料库导入',
    audio: '语音录音',
  };
  return map[source];
}

function getFileExtension(path: string): string {
  const ext = path.split('.').pop()?.toUpperCase();
  return ext || 'FILE';
}

function getFileName(path: string): string {
  return path.split('/').pop() || path;
}

function getDirectory(path: string): string {
  const parts = path.split('/');
  parts.pop();
  const dir = parts.join('/');
  // Replace home directory with ~
  return dir.replace(/^\/Users\/[^/]+/, '~');
}

/**
 * Shorten path for display in metadata:
 * ~/PinMind/sources/2026-04-27/5f6c0f8d...1266.png
 */
function shortenPath(fullPath: string): string {
  let path = fullPath.replace(/^\/Users\/[^/]+/, '~');
  if (path.length > 52) {
    const parts = path.split('/');
    const filename = parts.pop() || '';
    const dir = parts.join('/');
    if (filename.length > 20) {
      const ext = filename.includes('.') ? '.' + filename.split('.').pop() : '';
      const name = filename.slice(0, 8);
      return `${dir}/${name}...${ext}`;
    }
  }
  return path;
}

// ─── Image Preview Sub-component ─────────────────────────────────────────────

function ImagePreview({ contentPath }: { contentPath: string }) {
  const [src, setSrc] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [showFullPath, setShowFullPath] = useState(false);
  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    setSrc(null);
    setLoading(true);
    setLoadError(false);

    const loadImage = async () => {
      try {
        const win = window as any;
        if (win.pinmind?.sourceItems?.readImage) {
          const result = await win.pinmind.sourceItems.readImage(contentPath);
          if (mountedRef.current && result) {
            setSrc(result);
            setLoading(false);
          }
        } else {
          if (mountedRef.current) {
            setSrc(`file://${contentPath}`);
            setLoading(false);
          }
        }
      } catch {
        if (mountedRef.current) {
          setLoadError(true);
          setLoading(false);
        }
      }
    };

    loadImage();

    return () => {
      mountedRef.current = false;
    };
  }, [contentPath]);

  return (
    <div className="pinmind-detail-image-section">
      {/* Image Preview Area */}
      <div className="pinmind-detail-image-preview-area">
        {loading && (
          <div className="pinmind-detail-image-loading">
            <span className="pinmind-detail-image-loading-spinner" />
            <span style={{ color: 'var(--pm-text-tertiary)', fontSize: 12 }}>加载中...</span>
          </div>
        )}
        {loadError && (
          <div className="pinmind-detail-image-error">
            <svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ color: 'var(--pm-text-tertiary)' }}>
              <rect x="3" y="3" width="22" height="22" rx="4" stroke="currentColor" strokeWidth="1.4" />
              <circle cx="10" cy="10.5" r="2" stroke="currentColor" strokeWidth="1.2" />
              <path d="M3 19L8 14L12 18L19 11L25 16" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            <span style={{ color: 'var(--pm-text-tertiary)', fontSize: 12, marginTop: 8 }}>图片加载失败</span>
          </div>
        )}
        {!loading && !loadError && src && (
          <img
            className="pinmind-detail-image-preview-img"
            src={src}
            alt="图片预览"
            onError={() => setLoadError(true)}
          />
        )}
      </div>

      {/* File Info (below preview) */}
      <div className="pinmind-detail-image-fileinfo">
        <div className="pinmind-detail-image-fileinfo-row">
          <span className="pinmind-detail-image-fileinfo-label">文件名</span>
          <span className="pinmind-detail-image-fileinfo-value font-mono">{getFileName(contentPath)}</span>
        </div>
        <div className="pinmind-detail-image-fileinfo-row">
          <span className="pinmind-detail-image-fileinfo-label">位置</span>
          <span className="pinmind-detail-image-fileinfo-value font-mono">{getDirectory(contentPath)}/</span>
        </div>
        <div className="pinmind-detail-image-fileinfo-row">
          <span className="pinmind-detail-image-fileinfo-label">完整路径</span>
          <span className="pinmind-detail-image-fileinfo-value">
            <button
              type="button"
              className="pinmind-detail-path-toggle"
              onClick={() => setShowFullPath(!showFullPath)}
            >
              {showFullPath ? '收起 ▲' : '点击展开 ▼'}
            </button>
            {showFullPath && (
              <span className="font-mono pinmind-detail-full-path">{contentPath}</span>
            )}
          </span>
        </div>
      </div>
    </div>
  );
}

// ─── SourceItemDetail ────────────────────────────────────────────────────────

/**
 * Detail panel for viewing a selected source item.
 * Image items show real image preview with file info.
 * Text items show content text as before.
 */
export function SourceItemDetail({ item, onDelete }: SourceItemDetailProps): JSX.Element {
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [distillStatus, setDistillStatus] = useState<'idle' | 'running' | 'done' | 'error'>('idle');
  const [distillMessage, setDistillMessage] = useState<string | null>(null);

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

  const handleDistill = useCallback(async () => {
    if (!item) return;

    setDistillStatus('running');
    setDistillMessage(null);

    try {
      const tasks = await window.pinmind.distill.run([item.id], DEFAULT_DISTILL_OPERATIONS);
      setDistillStatus('done');
      setDistillMessage(
        tasks.length > 0
          ? `已提交 ${tasks.length} 个整理任务，结果生成后可在整理页查看。`
          : '整理任务已提交。'
      );
    } catch (error) {
      setDistillStatus('error');
      setDistillMessage(error instanceof Error ? error.message : '提交整理任务失败，请稍后重试。');
    }
  }, [item]);

  // ── Empty state ──

  if (!item) {
    return (
      <div className="pinmind-inbox-detail pinmind-detail-empty">
        <div className="flex flex-col items-center justify-center h-full gap-3">
          <svg
            width="40"
            height="40"
            viewBox="0 0 40 40"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            style={{ color: 'var(--pm-text-tertiary)', opacity: 0.4 }}
          >
            <rect
              x="6"
              y="8"
              width="28"
              height="24"
              rx="4"
              stroke="currentColor"
              strokeWidth="1.5"
            />
            <path
              d="M6 14H34"
              stroke="currentColor"
              strokeWidth="1.5"
            />
            <path
              d="M14 8V6C14 4.89543 14.8954 4 16 4H24C25.1046 4 26 4.89543 26 6V8"
              stroke="currentColor"
              strokeWidth="1.5"
            />
            <path
              d="M16 20L18 22L24 18"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <p
            className="text-[13px]"
            style={{ color: 'var(--pm-text-tertiary)' }}
          >
            {'选择一条记录查看详情'}
          </p>
        </div>
      </div>
    );
  }

  // ── Detail view ──

  const contentText = item.previewText || item.ocrText || item.originalUrl || '';

  return (
    <div className="pinmind-inbox-detail">
      <ScrollContainer className="p-5">
        {/* Header */}
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-2">
            <h3
              className="text-[15px] font-semibold"
              style={{ color: 'var(--pm-text-primary)' }}
            >
              {'记录详情'}
            </h3>
            {item.type === 'image' && (
              <span className="pinmind-media-badge pinmind-media-badge-image">图片</span>
            )}
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => void handleDistill()}
              disabled={distillStatus === 'running'}
              className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
            >
              {distillStatus === 'running' ? '整理中...' : '开始整理'}
            </button>
            {!confirmDelete ? (
              <button
                type="button"
                onClick={() => setConfirmDelete(true)}
                className="pinmind-btn pinmind-btn-ghost pinmind-btn-danger motion-button text-[12px]"
              >
                {'删除'}
              </button>
            ) : (
              <div className="flex items-center gap-2">
                <span className="text-[11px]" style={{ color: 'var(--pm-status-danger)' }}>
                  {'确认删除？'}
                </span>
                <button
                  type="button"
                  onClick={handleDelete}
                  disabled={deleting}
                  className="pinmind-btn pinmind-btn-primary motion-button text-[12px]"
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
                  className="pinmind-btn pinmind-btn-ghost motion-button text-[12px]"
                >
                  {'取消'}
                </button>
              </div>
            )}
          </div>
        </div>

        {distillMessage && (
          <div
            className="mb-5 flex items-start justify-between gap-3 rounded-[8px] border px-3 py-2.5 text-[12px]"
            style={{
              borderColor:
                distillStatus === 'error'
                  ? 'var(--pm-status-danger)'
                  : distillStatus === 'done'
                    ? 'var(--pm-status-success)'
                    : 'var(--pm-border-subtle)',
              background:
                distillStatus === 'error'
                  ? 'rgba(201, 75, 75, 0.08)'
                  : distillStatus === 'done'
                    ? 'rgba(22, 163, 74, 0.08)'
                    : 'rgba(0,0,0,0.02)',
              color:
                distillStatus === 'error'
                  ? 'var(--pm-status-danger)'
                  : distillStatus === 'done'
                    ? 'var(--pm-status-success)'
                    : 'var(--pm-text-secondary)',
            }}
          >
            <span className="min-w-0 flex-1">{distillMessage}</span>
            <button
              type="button"
              className="shrink-0 text-[11px] opacity-70 hover:opacity-100"
              onClick={() => setDistillMessage(null)}
            >
              关闭
            </button>
          </div>
        )}

        {/* Content Section */}
        <div className="pinmind-detail-section mb-5">
          <h4 className="pinmind-field-label mb-2">
            {item.type === 'image' ? '内容预览' : '内容'}
          </h4>
          {item.type === 'image' ? (
            <ImagePreview contentPath={item.contentPath} />
          ) : (
            <div
              className="pinmind-detail-content-text"
              style={{ color: 'var(--pm-text-primary)' }}
            >
              {contentText || '无内容'}
            </div>
          )}
        </div>

        {/* Metadata */}
        <div className="pinmind-detail-section">
          <h4 className="pinmind-field-label mb-3">
            {'元数据'}
          </h4>
          <div className="pinmind-detail-meta-grid">
            <MetaRow label={'来源应用'} value={item.sourceApp || '-'} />
            <MetaRow label={'捕获方式'} value={getSourceLabel(item.source)} />
            <MetaRow label={'内容类型'} value={getTypeLabel(item.type)} />
            <MetaRow label={'文件格式'} value={item.type === 'image' ? getFileExtension(item.contentPath) : '-'} />
            <MetaRow label={'状态'} value={getStatusLabel(item.status)} />
            <MetaRow label={'捕获时间'} value={formatTimestamp(item.createdAt)} />
            <MetaRow
              label={'内容哈希'}
              value={truncateHash(item.contentHash, 16)}
              mono
            />
            {item.type === 'image' && (
              <MetaRow label={'文件路径'} value={shortenPath(item.contentPath)} mono />
            )}
          </div>
        </div>
      </ScrollContainer>
    </div>
  );
}

// ─── MetaRow ─────────────────────────────────────────────────────────────────

function MetaRow({
  label,
  value,
  mono,
}: {
  label: string;
  value: string;
  mono?: boolean;
}): JSX.Element {
  return (
    <div className="pinmind-detail-meta-row">
      <span className="pinmind-detail-meta-label">{label}</span>
      <span
        className={`pinmind-detail-meta-value ${mono ? 'font-mono' : ''}`}
        style={{ color: 'var(--pm-text-primary)' }}
      >
        {value}
      </span>
    </div>
  );
}
