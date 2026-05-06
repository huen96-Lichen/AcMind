import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SourceItem, SourceItemType } from '../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

export type InboxFilter = 'all' | 'text' | 'image' | 'screenshot' | 'file' | 'webpage' | 'audio';

interface UseSourceItemsReturn {
  items: SourceItem[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  filter: InboxFilter;
  setFilter: (filter: InboxFilter) => void;
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  selectedItem: SourceItem | null;
  setSelectedItem: (item: SourceItem | null) => void;
  deleteItem: (id: string) => Promise<boolean>;
  deleteBatch: (ids: string[]) => Promise<boolean>;
  updateItem: (id: string, patch: Partial<SourceItem>) => Promise<boolean>;
  getContent: (id: string) => Promise<{ type: SourceItemType; text?: string; dataUrl?: string } | null>;
  importFile: (filePath: string) => Promise<SourceItem | null>;
  saveUrl: (url: string) => Promise<SourceItem | null>;
}

// ─── Hook ────────────────────────────────────────────────────────────────────

/**
 * Custom hook for managing source items in the Inbox / Staging Pool pages.
 * Handles loading, filtering, searching, selection, and real-time updates.
 */
export function useSourceItems(): UseSourceItemsReturn {
  const [allItems, setAllItems] = useState<SourceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<InboxFilter>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedItem, setSelectedItem] = useState<SourceItem | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const searchQueryRef = useRef('');

  // ── Load items from backend ──

  const loadItems = useCallback(async () => {
    if (!window.acmind) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const items = await window.acmind.sourceItems.list({});
      setAllItems(items);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  // ── Initial load ──

  useEffect(() => {
    void loadItems();
  }, [loadItems]);

  // ── Listen for records.changed events ──

  useEffect(() => {
    if (!window.acmind) return;
    const unsubscribe = window.acmind.onRecordsChanged(() => {
      void loadItems();
    });
    return unsubscribe;
  }, [loadItems]);

  // ── Debounced search ──

  const handleSearchChange = useCallback((query: string) => {
    searchQueryRef.current = query;
    setSearchQuery(query);

    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    debounceRef.current = setTimeout(async () => {
      const q = searchQueryRef.current.trim();
      if (!q) {
        // Reset to full list
        try {
          const items = await window.acmind.sourceItems.list({});
          setAllItems(items);
          setError(null);
        } catch (err) {
          setError(err instanceof Error ? err.message : String(err));
        }
      } else {
        try {
          const results = await window.acmind.sourceItems.search(q);
          setAllItems(results);
          setError(null);
        } catch (err) {
          setError(err instanceof Error ? err.message : String(err));
        }
      }
    }, 300);
  }, []);

  // ── Filter items by type ──

  const items = useMemo(() => {
    if (filter === 'all') return allItems;
    if (filter === 'screenshot') {
      return allItems.filter((item) => item.source === 'screenshot');
    }
    if (filter === 'webpage') {
      return allItems.filter((item) => item.type === 'url');
    }
    if (filter === 'audio') {
      return allItems.filter((item) => item.source === 'audio');
    }
    // 'file' — currently SourceItem.type doesn't have 'file', fallback: items with contentPath that are not text/image/url
    if (filter === 'file') {
      return allItems.filter((item) => item.source === 'vault_import');
    }
    return allItems.filter((item) => item.type === (filter as SourceItemType));
  }, [allItems, filter]);

  // ── Delete item ──

  const deleteItem = useCallback(
    async (id: string): Promise<boolean> => {
      try {
        await window.acmind.sourceItems.delete(id);
        if (selectedItem?.id === id) {
          setSelectedItem(null);
        }
        // The records.changed event will trigger a refresh
        return true;
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        return false;
      }
    },
    [selectedItem],
  );

  // ── Delete batch ──

  const deleteBatch = useCallback(
    async (ids: string[]): Promise<boolean> => {
      try {
        await window.acmind.sourceItems.deleteBatch(ids);
        if (selectedItem && ids.includes(selectedItem.id)) {
          setSelectedItem(null);
        }
        return true;
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        return false;
      }
    },
    [selectedItem],
  );

  // ── Update item ──

  const updateItem = useCallback(
    async (id: string, patch: Partial<SourceItem>): Promise<boolean> => {
      try {
        await window.acmind.sourceItems.update(id, patch);
        // records.changed event will trigger loadItems → state refresh
        return true;
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        return false;
      }
    },
    [],
  );

  // ── Get content ──

  const getContent = useCallback(
    async (id: string): Promise<{ type: SourceItemType; text?: string; dataUrl?: string } | null> => {
      try {
        return await window.acmind.sourceItems.getContent(id);
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        return null;
      }
    },
    [],
  );

  // ── Import file ──
  // NOTE: Uses window.acmind.parser.importFile which is the existing API.
  // This creates a source item from a file import.

  const importFile = useCallback(
    async (filePath: string): Promise<SourceItem | null> => {
      try {
        // parser.importFile triggers capture → bridge → sourceItem pipeline
        const result = await window.acmind.parser.importFile(filePath);
        // The pipeline will trigger onRecordsChanged → loadItems
        return result as SourceItem | null;
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        return null;
      }
    },
    [],
  );

  // ── Save URL ──

  const saveUrl = useCallback(
    async (url: string): Promise<SourceItem | null> => {
      try {
        const item = await window.acmind.sourceItems.saveUrl(url);
        await loadItems();
        return item;
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err));
        return null;
      }
    },
    [loadItems],
  );

  // ── Cleanup debounce on unmount ──

  useEffect(() => {
    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, []);

  return {
    items,
    loading,
    error,
    refresh: loadItems,
    filter,
    setFilter,
    searchQuery,
    setSearchQuery: handleSearchChange,
    selectedItem,
    setSelectedItem,
    deleteItem,
    deleteBatch,
    updateItem,
    getContent,
    importFile,
    saveUrl,
  };
}
