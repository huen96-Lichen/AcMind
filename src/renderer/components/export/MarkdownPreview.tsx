import { useEffect, useState } from 'react';
import { ScrollContainer } from '../shared/ScrollContainer';
import { EmptyState } from '../shared/EmptyState';

// ─── Types ───────────────────────────────────────────────────────────────────

interface MarkdownPreviewProps {
  outputId: string;
}

// ─── Component ───────────────────────────────────────────────────────────────

/**
 * Markdown preview panel.
 * Loads and renders markdown content with frontmatter section highlighted.
 */
export function MarkdownPreview({ outputId }: MarkdownPreviewProps): JSX.Element {
  const [content, setContent] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadPreview() {
      try {
        setError(null);
        setLoading(true);
        const result = await window.pinmind.template.preview(outputId);
        setContent(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
      } finally {
        setLoading(false);
      }
    }
    if (outputId) {
      void loadPreview();
    }
  }, [outputId]);

  if (loading) {
      return (
      <ScrollContainer>
        <div className="flex items-center justify-center py-8">
          <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            正在加载预览...
          </span>
        </div>
      </ScrollContainer>
    );
  }

  if (error) {
    return (
      <ScrollContainer>
        <div className="p-4">
          <div
            className="text-[12px] p-3 rounded-lg"
            style={{
              background: 'rgba(201, 75, 75, 0.08)',
              color: 'var(--pm-status-danger)',
              border: '1px solid rgba(201, 75, 75, 0.16)',
            }}
          >
            加载预览失败：{error}
          </div>
        </div>
      </ScrollContainer>
    );
  }

  if (!content) {
    return (
      <ScrollContainer>
        <div className="p-4">
          <EmptyState
            icon={'\u{1F4DD}'}
            title={'暂无预览内容'}
            description={'先选择一条内容，再查看 Markdown 预览。'}
          />
        </div>
      </ScrollContainer>
    );
  }

  // Split frontmatter from content
  const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  const frontmatter = frontmatterMatch ? frontmatterMatch[1] : null;
  const body = frontmatterMatch ? frontmatterMatch[2] : content;

  return (
    <ScrollContainer>
      <div className="p-4">
        <div
          className="rounded-lg overflow-hidden"
          style={{
            border: '1px solid color-mix(in srgb, var(--pm-border-subtle) 70%, transparent)',
            background: 'rgba(255, 255, 255, 0.6)',
          }}
        >
          {/* Frontmatter section */}
          {frontmatter && (
            <div
              className="p-3"
              style={{
                background: 'color-mix(in srgb, var(--pm-brand-soft) 30%, white 70%)',
                borderBottom: '1px solid color-mix(in srgb, var(--pm-border-subtle) 50%, transparent)',
              }}
            >
              <div
                className="text-[10px] font-semibold uppercase tracking-wider mb-1.5"
                style={{ color: 'var(--pm-brand-primary)' }}
              >
                前置信息
              </div>
              <pre
                className="text-[12px] leading-relaxed m-0"
                style={{
                  color: 'var(--pm-text-secondary)',
                  fontFamily: "'SF Mono', 'Fira Code', monospace",
                  whiteSpace: 'pre-wrap',
                  wordBreak: 'break-word',
                }}
              >
                {frontmatter}
              </pre>
            </div>
          )}

          {/* Markdown body */}
          <div className="p-4">
            <div
              className="text-[13px] leading-relaxed prose prose-sm max-w-none"
              style={{
                color: 'var(--pm-text-primary)',
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-word',
              }}
            >
              {body}
            </div>
          </div>
        </div>
      </div>
    </ScrollContainer>
  );
}
