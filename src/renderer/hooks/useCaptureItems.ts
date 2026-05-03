import { useCallback, useEffect, useMemo, useState } from 'react';
import type { CaptureItem, CaptureItemStatus } from '../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

export type CaptureInboxFilter = 'all' | 'today' | 'pending' | 'archived' | 'failed';

interface UseCaptureItemsReturn {
  items: CaptureItem[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  filter: CaptureInboxFilter;
  setFilter: (filter: CaptureInboxFilter) => void;
  selectedItem: CaptureItem | null;
  setSelectedItem: (item: CaptureItem | null) => void;
  createItem: (data: {
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
  updateItem: (id: string, patch: Partial<CaptureItem>) => Promise<CaptureItem>;
  deleteItem: (id: string) => Promise<boolean>;
  exportMarkdown: (ids: string[]) => Promise<string[]>;
}

// ─── Hook ────────────────────────────────────────────────────────────────────

/**
 * Custom hook for managing capture items in the Capture Inbox page.
 * Handles loading, filtering, selection, CRUD, and real-time updates.
 */
export function useCaptureItems(): UseCaptureItemsReturn {
  const [allItems, setAllItems] = useState<CaptureItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<CaptureInboxFilter>('all');
  const [selectedItem, setSelectedItem] = useState<CaptureItem | null>(null);

  // ── Load items from backend ──

  const loadItems = useCallback(async () => {
    if (!window.acmind) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const items = await window.acmind.captureItems.list({});
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

  // ── Listen for captureItems.changed events ──

  useEffect(() => {
    if (!window.acmind) return;
    const unsubscribe = window.acmind.onCaptureItemsChanged(() => {
      void loadItems();
    });
    return unsubscribe;
  }, [loadItems]);

  // ── Filter items ──

  const items = useMemo(() => {
    if (filter === 'all') return allItems;

    if (filter === 'today') {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayStartSec = Math.floor(todayStart.getTime() / 1000);
      return allItems.filter((item) => item.capturedAt >= todayStartSec);
    }

    const statusMap: Record<string, CaptureItemStatus> = {
      pending: 'pending',
      archived: 'archived',
      failed: 'failed',
    };
    const targetStatus = statusMap[filter];
    if (targetStatus) {
      return allItems.filter((item) => item.status === targetStatus);
    }

    return allItems;
  }, [allItems, filter]);

  // ── Create item ──

  const createItem = useCallback(
    async (data: {
      type: CaptureItem['type'];
      title?: string;
      rawText?: string;
      sourceUrl?: string;
      filePath?: string;
      userNote?: string;
      imageBase64?: string;
      imageMimeType?: string;
      imageOriginalName?: string;
    }): Promise<CaptureItem> => {
      const item = await window.acmind.captureItems.create(data);
      // The captureItems.changed event will trigger a refresh
      return item;
    },
    [],
  );

  // ── Update item ──

  const updateItem = useCallback(
    async (id: string, patch: Partial<CaptureItem>): Promise<CaptureItem> => {
      const updated = await window.acmind.captureItems.update(id, patch);
      // Update selected item if it matches
      if (selectedItem?.id === id) {
        setSelectedItem(updated);
      }
      // The captureItems.changed event will trigger a refresh
      return updated;
    },
    [selectedItem],
  );

  // ── Delete item ──

  const deleteItem = useCallback(
    async (id: string): Promise<boolean> => {
      const result = await window.acmind.captureItems.delete(id);
      if (selectedItem?.id === id) {
        setSelectedItem(null);
      }
      // The captureItems.changed event will trigger a refresh
      return result;
    },
    [selectedItem],
  );

  // ── Export Markdown ──

  const exportMarkdown = useCallback(
    async (ids: string[]): Promise<string[]> => {
      return await window.acmind.captureItems.exportMarkdown(ids);
    },
    [],
  );

  return {
    items,
    loading,
    error,
    refresh: loadItems,
    filter,
    setFilter,
    selectedItem,
    setSelectedItem,
    createItem,
    updateItem,
    deleteItem,
    exportMarkdown,
  };
}
