import { useCallback, useEffect, useState } from 'react';
import { Button, EmptyState, LoadingState, PageHeader, PageShell, SearchField, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { SearchResultCard } from '../../components/search/SearchResultCard';
import type { SearchResult } from '../../components/search/SearchResultCard';

/* ===== Types ===== */

interface SearchStatus {
  initialized: boolean;
  ftsCount: number;
  searchable: boolean;
  lastRebuilt?: string;
}

/* ===== Helpers ===== */

function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}

/* ===== Main Component ===== */

export function SearchPage(): JSX.Element {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const [status, setStatus] = useState<SearchStatus | null>(null);
  const [rebuilding, setRebuilding] = useState(false);
  const debouncedQuery = useDebounce(query, 300);

  // Phase 12.2: 自动聚焦搜索输入框（从 TopBar 跳转过来时）
  useEffect(() => {
    const timer = window.setTimeout(() => {
      const searchInput = document.querySelector<HTMLInputElement>('.pm-ds-search-input');
      searchInput?.focus();
    }, 100);
    return () => window.clearTimeout(timer);
  }, []);

  // Load search module status on mount
  useEffect(() => {
    async function loadStatus(): Promise<void> {
      try {
        if (window.acmind?.search?.getStatus) {
          const s = await window.acmind.search.getStatus();
          setStatus(s);
        }
      } catch {
        // Search module may not be available
      }
    }
    void loadStatus();
  }, []);

  // Execute search when debounced query changes
  useEffect(() => {
    if (!debouncedQuery.trim()) {
      setResults([]);
      setSearched(false);
      return;
    }

    let cancelled = false;

    async function doSearch(): Promise<void> {
      setLoading(true);
      try {
        if (window.acmind?.search?.hybrid) {
          const res = await window.acmind.search.hybrid(debouncedQuery.trim());
          if (!cancelled) {
            setResults(Array.isArray(res) ? res : []);
            setSearched(true);
          }
        }
      } catch (err) {
        console.error('Search failed:', err);
        if (!cancelled) {
          setResults([]);
          setSearched(true);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    void doSearch();
    return () => { cancelled = true; };
  }, [debouncedQuery]);

  const handleRebuildIndex = useCallback(async () => {
    setRebuilding(true);
    try {
      if (window.acmind?.search?.rebuildFts) {
        await window.acmind.search.rebuildFts();
      }
      // Refresh status after rebuild
      if (window.acmind?.search?.getStatus) {
        const s = await window.acmind.search.getStatus();
        setStatus(s);
      }
    } catch (err) {
      console.error('Rebuild index failed:', err);
    } finally {
      setRebuilding(false);
    }
  }, []);

  const handleResultClick = useCallback((id: string) => {
    // Navigate to edit page with the item id
    window.dispatchEvent(
      new CustomEvent('acmind:navigate', { detail: { view: 'edit', itemId: id } }),
    );
  }, []);

  const handleViewExports = useCallback((id: string) => {
    window.dispatchEvent(
      new CustomEvent('acmind:navigate', { detail: { view: 'exports', sourceItemId: id } }),
    );
  }, []);

  return (
    <PageShell>
      <PageHeader
        eyebrow="知识检索"
        title="搜索"
        description="搜索收集内容、整理结果、标签和入库记录。"
        actions={<Button variant="ghost" leadingIcon={<PinStackIcon name="refresh" size={14} />} onClick={() => void handleRebuildIndex()} disabled={rebuilding}>{rebuilding ? '重建中...' : '重建索引'}</Button>}
        meta={status ? (
          <StatusBadge
            tone={status.searchable ? 'success' : status.initialized ? 'warning' : 'neutral'}
            label={status.searchable ? `已索引 ${status.ftsCount} 条` : status.initialized ? '索引为空' : '索引未初始化'}
          />
        ) : null}
      />

      <Section title="搜索入口" description="输入关键词后回车开始检索。">
        <div className="max-w-[760px]">
          <SearchField
            value={query}
            autoFocus
            placeholder="输入关键词搜索知识库..."
            onChange={(e) => setQuery(e.target.value)}
            onClear={() => setQuery('')}
            onSearch={(value) => setQuery(value)}
          />
        </div>
      </Section>

      <Section title="搜索结果" description={loading ? '正在搜索知识库内容。' : searched ? `找到 ${results.length} 条结果。` : '等待输入关键词。'}>
        <div className="rounded-[10px] border border-[color:var(--border-light)] bg-[color:var(--pm-bg-surface)]">
          <ScrollContainer className="min-h-[360px]">
            {!searched && !loading ? (
              <div className="flex min-h-[360px] items-center justify-center p-6">
                <EmptyState
                  icon={<PinStackIcon name="search" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
                  title="搜索资料库"
                  description="输入关键词，搜索收集内容、整理结果、标签和入库记录。"
                />
              </div>
            ) : null}

            {loading ? (
              <div className="flex min-h-[360px] items-center justify-center p-6">
                <LoadingState title="正在搜索知识库" description="正在读取全文索引并匹配结果。" />
              </div>
            ) : null}

            {searched && !loading && results.length === 0 ? (
              <div className="flex min-h-[360px] items-center justify-center p-6">
                <EmptyState
                  icon={<PinStackIcon name="empty-search" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
                  title="未找到相关结果"
                  description="尝试更换关键词，或重建索引后重试。"
                  action={{ label: '重建索引', onClick: () => void handleRebuildIndex() }}
                />
              </div>
            ) : null}

            {searched && !loading && results.length > 0 ? (
              <div className="flex flex-col gap-3 p-4">
                {results.map((result) => (
                  <SearchResultCard key={result.id} result={result} onClick={handleResultClick} onViewExports={handleViewExports} />
                ))}
              </div>
            ) : null}
          </ScrollContainer>
        </div>
      </Section>
    </PageShell>
  );
}
