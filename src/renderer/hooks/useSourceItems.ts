import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SourceItem, SourceItemType } from '../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

export type InboxFilter = 'all' | 'text' | 'image' | 'screenshot';

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
}

// ─── Hook ────────────────────────────────────────────────────────────────────

/**
 * Custom hook for managing source items in the Inbox page.
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
    if (!window.pinmind) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const items = await window.pinmind.sourceItems.list({});
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
    if (!window.pinmind) return;
    const unsubscribe = window.pinmind.onRecordsChanged(() => {
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
          const items = await window.pinmind.sourceItems.list({});
          setAllItems(items);
          setError(null);
        } catch (err) {
          setError(err instanceof Error ? err.message : String(err));
        }
      } else {
        try {
          const results = await window.pinmind.sourceItems.search(q);
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
    return allItems.filter((item) => item.type === (filter as SourceItemType));
  }, [allItems, filter]);

  // ── Delete item ──

  const deleteItem = useCallback(
    async (id: string): Promise<boolean> => {
      try {
        await window.pinmind.sourceItems.delete(id);
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
  };
}
