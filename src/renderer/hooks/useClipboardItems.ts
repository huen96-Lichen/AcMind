import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { ClipboardItem, ClipboardContentType } from '../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

export type ClipboardFilter = 'all' | ClipboardContentType;

interface UseClipboardItemsReturn {
  items: ClipboardItem[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  filter: ClipboardFilter;
  setFilter: (filter: ClipboardFilter) => void;
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  watching: boolean;
  paused: boolean;
  toggleWatching: () => Promise<void>;
  togglePause: () => Promise<void>;
  copyItem: (id: string) => Promise<boolean>;
  deleteItem: (id: string) => Promise<boolean>;
  pinItem: (id: string) => Promise<boolean>;
  unpinItem: (id: string) => Promise<boolean>;
  saveToInbox: (id: string) => Promise<{ success: boolean; alreadySaved?: boolean }>;
  clearHistory: () => Promise<boolean>;
}

// ─── Hook ────────────────────────────────────────────────────────────────────

export function useClipboardItems(): UseClipboardItemsReturn {
  const [allItems, setAllItems] = useState<ClipboardItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<ClipboardFilter>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [watching, setWatching] = useState(true);
  const [paused, setPaused] = useState(false);
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
      const result = await window.acmind.clipboard.listItems({ limit: 200 });
      if (result.success) {
        setAllItems(result.items);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  // ── Load status ──

  const loadStatus = useCallback(async () => {
    if (!window.acmind) return;
    try {
      const status = await window.acmind.clipboard.getStatus();
      setWatching(status.enabled);
      const p = await window.acmind.clipboard.isPaused();
      setPaused(p);
    } catch {
      // ignore
    }
  }, []);

  // ── Initial load ──

  useEffect(() => {
    void loadItems();
    void loadStatus();
  }, [loadItems, loadStatus]);

  // ── Listen for clipboard.itemsChanged events ──

  useEffect(() => {
    if (!window.acmind) return;
    const unsubscribe = window.acmind.clipboard.onItemsChanged(() => {
      void loadItems();
      void loadStatus();
    });
    return unsubscribe;
  }, [loadItems, loadStatus]);

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
        void loadItems();
      } else {
        try {
          const result = await window.acmind.clipboard.searchItems(q, filter !== 'all' ? filter : undefined);
          if (result.success) {
            setAllItems(result.items);
          }
          setError(null);
        } catch (err) {
          setError(err instanceof Error ? err.message : String(err));
        }
      }
    }, 300);
  }, [loadItems, filter]);

  // ── Filter items by type ──

  const items = useMemo(() => {
    if (filter === 'all') return allItems;
    return allItems.filter((item) => item.contentType === filter);
  }, [allItems, filter]);

  // ── Actions ──

  const toggleWatching = useCallback(async () => {
    if (!window.acmind) return;
    await window.acmind.clipboard.toggle(!watching);
    setWatching(!watching);
  }, [watching]);

  const togglePause = useCallback(async () => {
    if (!window.acmind) return;
    if (paused) {
      await window.acmind.clipboard.resume();
    } else {
      await window.acmind.clipboard.pause();
    }
    setPaused(!paused);
  }, [paused]);

  const copyItem = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.clipboard.copyItem(id);
      return result.success;
    } catch {
      return false;
    }
  }, []);

  const deleteItem = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.clipboard.deleteItem(id);
      if (result.success) {
        setAllItems((prev) => prev.filter((item) => item.id !== id));
      }
      return result.success;
    } catch {
      return false;
    }
  }, []);

  const pinItem = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.clipboard.pinItem(id);
      if (result.success) {
        setAllItems((prev) =>
          prev.map((item) => (item.id === id ? { ...item, isPinned: true } : item)),
        );
      }
      return result.success;
    } catch {
      return false;
    }
  }, []);

  const unpinItem = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.clipboard.unpinItem(id);
      if (result.success) {
        setAllItems((prev) =>
          prev.map((item) => (item.id === id ? { ...item, isPinned: false } : item)),
        );
      }
      return result.success;
    } catch {
      return false;
    }
  }, []);

  const saveToInbox = useCallback(async (id: string) => {
    try {
      const result = await window.acmind.clipboard.saveToInbox(id);
      if (result.success) {
        // Update local state to reflect saved status
        setAllItems((prev) =>
          prev.map((item) =>
            item.id === id ? { ...item, sourceItemId: result.sourceItem?.id ?? item.sourceItemId } : item,
          ),
        );
      }
      return { success: result.success, alreadySaved: result.alreadySaved };
    } catch {
      return { success: false };
    }
  }, []);

  const clearHistory = useCallback(async (): Promise<boolean> => {
    try {
      const result = await window.acmind.clipboard.clearHistory();
      if (result.success) {
        setAllItems((prev) => prev.filter((item) => item.isPinned));
      }
      return result.success;
    } catch {
      return false;
    }
  }, []);

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
    watching,
    paused,
    toggleWatching,
    togglePause,
    copyItem,
    deleteItem,
    pinItem,
    unpinItem,
    saveToInbox,
    clearHistory,
  };
}
