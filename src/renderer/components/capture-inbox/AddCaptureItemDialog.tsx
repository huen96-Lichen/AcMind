import { useCallback, useRef, useState } from 'react';
import type { CaptureItem } from '../../../shared/types';
import { PinStackIcon } from '../../design-system/icons';

// ─── Types ───────────────────────────────────────────────────────────────────

interface AddCaptureItemDialogProps {
  open: boolean;
  onClose: () => void;
  onCreate: (data: {
    type: CaptureItem['type'];
    title?: string;
    rawText?: string;
    sourceUrl?: string;
    filePath?: string;
    userNote?: string;
    imageBase64?: string;
    imageMimeType?: string;
    imageOriginalName?: string;
  }) => Promise<CaptureItem>;
  /** Called after a webpage is successfully collected via the full pipeline */
  onWebpageCollected?: () => void;
}

type DialogTab = 'text' | 'link' | 'image';
type LinkMode = 'fetch' | 'paste';

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Convert a File/Blob to base64 string (without the data:... prefix) */
function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result as string;
      // Strip "data:<mime>;base64," prefix
      const base64 = dataUrl.split(',')[1];
      resolve(base64);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

// ─── AddCaptureItemDialog ───────────────────────────────────────────────────

/**
 * Modal dialog for adding a new capture item.
 * Supports text, link (fetch/paste), and image (paste/drag) types.
 *
 * V2.1 Phase 7.4: Link tab now supports two modes:
 * - 自动抓取: URL → markitdown/webParser → pipeline → Obsidian
 * - 粘贴正文: URL + user-pasted text → pipeline → Obsidian
 */
export function AddCaptureItemDialog({ open, onClose, onCreate, onWebpageCollected }: AddCaptureItemDialogProps): JSX.Element | null {
  const [tab, setTab] = useState<DialogTab>('text');
  const [title, setTitle] = useState('');
  const [rawText, setRawText] = useState('');
  const [sourceUrl, setSourceUrl] = useState('');
  const [userNote, setUserNote] = useState('');
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [linkMode, setLinkMode] = useState<LinkMode>('fetch');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const resetForm = useCallback(() => {
    setTitle('');
    setRawText('');
    setSourceUrl('');
    setUserNote('');
    setImageFile(null);
    setImagePreview(null);
    setError(null);
    setTab('text');
    setLinkMode('fetch');
  }, []);

  const handleClose = useCallback(() => {
    resetForm();
    onClose();
  }, [resetForm, onClose]);

  const handleSubmit = useCallback(async () => {
    setError(null);
    setSubmitting(true);
    try {
      if (tab === 'text' && !rawText.trim()) {
        setError('请输入文本内容');
        setSubmitting(false);
        return;
      }
      if (tab === 'link' && !sourceUrl.trim()) {
        setError('请输入链接地址');
        setSubmitting(false);
        return;
      }
      if (tab === 'image' && !imageFile) {
        setError('请选择或粘贴图片');
        setSubmitting(false);
        return;
      }

      // ── Link tab: use collectWebpage for full pipeline ──
      if (tab === 'link') {
        try {
          const result = await window.pinmind.capture.collectWebpage({
            url: sourceUrl.trim(),
            title: title.trim() || undefined,
            rawText: linkMode === 'paste' ? rawText.trim() || undefined : undefined,
            fetchContent: linkMode === 'fetch',
          });

          if (!result.success) {
            setError(result.error || '网页收集失败');
            setSubmitting(false);
            return;
          }

          // Success — notify parent and close
          onWebpageCollected?.();
          handleClose();
          return;
        } catch (err) {
          setError(err instanceof Error ? err.message : String(err));
          setSubmitting(false);
          return;
        }
      }

      // ── Text / Image tab: use existing onCreate callback ──
      const createData: Parameters<typeof onCreate>[0] = {
        type: tab,
        title: title.trim() || undefined,
        rawText: rawText.trim() || undefined,
        sourceUrl: sourceUrl.trim() || undefined,
        userNote: userNote.trim() || undefined,
      };

      if (tab === 'image' && imageFile) {
        // Always send base64 — works for paste, drag, and file picker
        const base64 = await fileToBase64(imageFile);
        createData.imageBase64 = base64;
        createData.imageMimeType = imageFile.type || 'image/png';
        createData.imageOriginalName = imageFile.name || 'screenshot.png';

        // Also send real file path if available (Electron enhanced File object)
        // Main process will prefer base64, but can fall back to path copy
        const electronPath = (imageFile as File & { path?: string }).path;
        if (electronPath) {
          createData.filePath = electronPath;
        }
      }

      await onCreate(createData);
      handleClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  }, [tab, title, rawText, sourceUrl, userNote, imageFile, linkMode, onCreate, onWebpageCollected, handleClose]);

  const handleImageSelect = useCallback(() => {
    fileInputRef.current?.click();
  }, []);

  const handleFileChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      setError('请选择图片文件');
      return;
    }
    setImageFile(file);
    setError(null);
    // Create preview
    const reader = new FileReader();
    reader.onload = (ev) => {
      setImagePreview(ev.target?.result as string);
    };
    reader.readAsDataURL(file);
  }, []);

  const handlePaste = useCallback((e: React.ClipboardEvent) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    for (const item of items) {
      if (item.type.startsWith('image/')) {
        e.preventDefault();
        const file = item.getAsFile();
        if (file) {
          setImageFile(file);
          setTab('image');
          setError(null);
          const reader = new FileReader();
          reader.onload = (ev) => {
            setImagePreview(ev.target?.result as string);
          };
          reader.readAsDataURL(file);
        }
        return;
      }
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer.files[0];
    if (!file || !file.type.startsWith('image/')) {
      setError('请拖入图片文件');
      return;
    }
    setImageFile(file);
    setTab('image');
    setError(null);
    const reader = new FileReader();
    reader.onload = (ev) => {
      setImagePreview(ev.target?.result as string);
    };
    reader.readAsDataURL(file);
  }, []);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
  }, []);

  if (!open) return null;

  const tabs: { key: DialogTab; label: string; icon: JSX.Element }[] = [
    { key: 'text', label: '文本', icon: <PinStackIcon name="text" size={13} /> },
    { key: 'link', label: '链接', icon: <PinStackIcon name="duplicate" size={13} /> },
    { key: 'image', label: '图片', icon: <PinStackIcon name="image" size={13} /> },
  ];

  // Determine submit button label
  const submitLabel = submitting
    ? (tab === 'link' ? (linkMode === 'fetch' ? '抓取中...' : '收集中...') : '添加中...')
    : (tab === 'link' ? '收集网页' : '添加碎片');

  return (
    <div className="pinmind-dialog-overlay" onClick={handleClose}>
      <div
        className="pinmind-dialog motion-popover"
        onClick={(e) => e.stopPropagation()}
        onPaste={handlePaste}
        onDrop={handleDrop}
        onDragOver={handleDragOver}
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-[15px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
            新增碎片
          </h3>
          <button
            type="button"
            onClick={handleClose}
            className="pinmind-btn pinmind-btn-ghost motion-button text-[16px] w-7 h-7 flex items-center justify-center rounded-full"
            style={{ color: 'var(--pm-text-tertiary)' }}
          >
            ×
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 mb-4 p-1 rounded-lg" style={{ background: 'var(--pm-bg-subtle)' }}>
          {tabs.map((t) => (
            <button
              key={t.key}
              type="button"
              onClick={() => { setTab(t.key); setError(null); }}
              className={`motion-button flex-1 text-[12px] py-1.5 px-3 rounded-md font-medium transition-all ${
                tab === t.key
                  ? 'bg-[var(--pm-bg-elevated)] shadow-sm'
                  : 'text-[var(--pm-text-tertiary)] hover:text-[var(--pm-text-secondary)]'
              }`}
              style={tab === t.key ? { color: 'var(--pm-text-primary)' } : undefined}
            >
              <span className="mr-1">{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {/* Form */}
        <div className="flex flex-col gap-3">
          {/* Title */}
          <div>
            <label className="pinmind-field-label block mb-1">标题（可选）</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder={tab === 'link' ? '网页标题（抓取时自动填充）' : '碎片标题'}
              className="pinmind-input text-[13px] w-full"
            />
          </div>

          {/* Text content */}
          {tab === 'text' && (
            <div>
              <label className="pinmind-field-label block mb-1">文本内容 *</label>
              <textarea
                value={rawText}
                onChange={(e) => setRawText(e.target.value)}
                placeholder="输入或粘贴文本内容..."
                className="pinmind-textarea text-[13px] w-full"
                rows={5}
                autoFocus
              />
            </div>
          )}

          {/* Link content — V2.1 Phase 7.4: two modes */}
          {tab === 'link' && (
            <>
              {/* Mode toggle */}
              <div className="flex gap-1 p-0.5 rounded-md" style={{ background: 'var(--pm-bg-subtle)' }}>
                <button
                  type="button"
                  onClick={() => setLinkMode('fetch')}
                  className={`motion-button flex-1 text-[11px] py-1 px-2 rounded font-medium transition-all ${
                    linkMode === 'fetch'
                      ? 'bg-[var(--pm-bg-elevated)] shadow-sm'
                      : 'text-[var(--pm-text-tertiary)] hover:text-[var(--pm-text-secondary)]'
                  }`}
                  style={linkMode === 'fetch' ? { color: 'var(--pm-text-primary)' } : undefined}
                >
                  🌐 自动抓取
                </button>
                <button
                  type="button"
                  onClick={() => setLinkMode('paste')}
                  className={`motion-button flex-1 text-[11px] py-1 px-2 rounded font-medium transition-all ${
                    linkMode === 'paste'
                      ? 'bg-[var(--pm-bg-elevated)] shadow-sm'
                      : 'text-[var(--pm-text-tertiary)] hover:text-[var(--pm-text-secondary)]'
                  }`}
                  style={linkMode === 'paste' ? { color: 'var(--pm-text-primary)' } : undefined}
                >
                  📋 粘贴正文
                </button>
              </div>

              <div>
                <label className="pinmind-field-label block mb-1">链接地址 *</label>
                <input
                  type="url"
                  value={sourceUrl}
                  onChange={(e) => setSourceUrl(e.target.value)}
                  placeholder="https://..."
                  className="pinmind-input text-[13px] w-full"
                  autoFocus
                />
                {linkMode === 'fetch' && (
                  <p className="text-[11px] mt-1" style={{ color: 'var(--pm-text-tertiary)' }}>
                    系统将自动抓取网页正文并整理为笔记
                  </p>
                )}
              </div>

              {/* Paste mode: show textarea for user-pasted content */}
              {linkMode === 'paste' && (
                <div>
                  <label className="pinmind-field-label block mb-1">网页正文</label>
                  <textarea
                    value={rawText}
                    onChange={(e) => setRawText(e.target.value)}
                    placeholder="粘贴网页正文内容..."
                    className="pinmind-textarea text-[13px] w-full"
                    rows={4}
                  />
                </div>
              )}
            </>
          )}

          {/* Image content */}
          {tab === 'image' && (
            <div>
              <label className="pinmind-field-label block mb-1">图片 *</label>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                className="hidden"
              />
              {imagePreview ? (
                <div className="relative rounded-lg overflow-hidden border border-[var(--pm-border-subtle)]">
                  <img
                    src={imagePreview}
                    alt="预览"
                    className="w-full max-h-[200px] object-contain"
                    style={{ background: 'var(--pm-bg-subtle)' }}
                  />
                  <button
                    type="button"
                    onClick={() => { setImageFile(null); setImagePreview(null); }}
                    className="absolute top-2 right-2 w-6 h-6 rounded-full bg-black/40 text-white flex items-center justify-center text-[12px] hover:bg-black/60 transition-colors"
                  >
                    ×
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={handleImageSelect}
                  className="w-full py-8 rounded-lg border-2 border-dashed border-[var(--pm-border-default)] hover:border-[var(--pm-brand-primary)] transition-colors flex flex-col items-center gap-2"
                  style={{ background: 'var(--pm-bg-subtle)' }}
                >
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ color: 'var(--pm-text-tertiary)' }}>
                    <path d="M12 5V19M5 12H19" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                  </svg>
                  <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                    点击选择图片，或粘贴 / 拖入图片
                  </span>
                </button>
              )}
            </div>
          )}

          {/* User Note */}
          <div>
            <label className="pinmind-field-label block mb-1">备注（可选）</label>
            <input
              type="text"
              value={userNote}
              onChange={(e) => setUserNote(e.target.value)}
              placeholder="添加备注..."
              className="pinmind-input text-[13px] w-full"
            />
          </div>

          {/* Error */}
          {error && (
            <div
              className="text-[12px] p-2.5 rounded-lg"
              style={{
                background: 'rgba(201, 75, 75, 0.08)',
                color: 'var(--pm-status-danger)',
                border: '1px solid rgba(201, 75, 75, 0.16)',
              }}
            >
              {error}
            </div>
          )}

          {/* Actions */}
          <div className="flex justify-end gap-2 mt-2">
            <button
              type="button"
              onClick={handleClose}
              className="pinmind-btn pinmind-btn-ghost motion-button text-[13px]"
            >
              取消
            </button>
            <button
              type="button"
              onClick={handleSubmit}
              disabled={submitting}
              className="pinmind-btn pinmind-btn-primary motion-button text-[13px]"
            >
              {submitLabel}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
