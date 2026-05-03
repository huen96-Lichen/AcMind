import { useEffect, useRef, useState } from 'react';

interface ImagePreviewProps {
  filePath: string;
  title?: string;
  maxHeight?: number;
}

export function ImagePreview({ filePath, title, maxHeight = 420 }: ImagePreviewProps): JSX.Element {
  const [dataUrl, setDataUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    setDataUrl(null);
    setLoading(true);
    setError(null);

    (async () => {
      try {
        const result = await window.acmind.captureItems.readImage(filePath);
        if (!mountedRef.current) return;
        if (result.ok && result.dataUrl) {
          setDataUrl(result.dataUrl);
        } else {
          setError(result.error || '图片加载失败');
        }
      } catch (err) {
        if (!mountedRef.current) return;
        setError(err instanceof Error ? err.message : '图片加载失败');
      } finally {
        if (mountedRef.current) setLoading(false);
      }
    })();

    return () => { mountedRef.current = false; };
  }, [filePath]);

  if (loading) {
    return (
      <div className="flex min-h-[140px] items-center justify-center rounded-[12px] bg-[color:var(--pm-bg-subtle)]">
        <div className="flex flex-col items-center gap-2 text-[12px] text-[color:var(--pm-text-tertiary)]">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-[color:var(--pm-border-subtle)] border-t-[color:var(--pm-brand-primary)]" />
          加载中...
        </div>
      </div>
    );
  }

  if (error || !dataUrl) {
    return (
      <div className="flex min-h-[140px] items-center justify-center rounded-[12px] bg-[rgba(201,75,75,0.04)]">
        <div className="flex flex-col items-center gap-2 text-[12px] text-[color:var(--pm-text-tertiary)]">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <rect x="3" y="3" width="18" height="18" rx="3" stroke="currentColor" strokeWidth="1.4" />
            <circle cx="9" cy="9.5" r="1.5" stroke="currentColor" strokeWidth="1.2" />
            <path d="M3 17l4-4 3 3 5-5 6 5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span>{error || '找不到图片文件'}</span>
          {filePath && (
            <button
              type="button"
              className="text-[11px] text-[color:var(--pm-brand-primary)] hover:underline"
              onClick={() => window.acmind.app.openPath(filePath)}
            >
              打开原文件
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="overflow-hidden rounded-[12px] bg-[rgba(0,0,0,0.03)]">
        <img
          src={dataUrl}
          alt={title || '图片预览'}
          className="block w-full object-contain"
          style={{ maxHeight }}
          onError={() => setError('图片渲染失败')}
        />
      </div>
      <div className="flex items-center justify-between px-1">
        <span className="truncate text-[11px] text-[color:var(--pm-text-tertiary)]">
          {filePath.split('/').pop()}
        </span>
        <button
          type="button"
          className="shrink-0 text-[11px] text-[color:var(--pm-brand-primary)] hover:underline"
          onClick={() => window.acmind.app.openPath(filePath)}
        >
          打开原文件
        </button>
      </div>
    </div>
  );
}
