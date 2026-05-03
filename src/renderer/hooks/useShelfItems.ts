import { useCallback, useEffect, useRef, useState } from 'react';
import type { ShelfItem } from '../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

interface UseShelfItemsReturn {
  items: ShelfItem[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  addFiles: (filePaths: string[], label?: string) => Promise<boolean>;
  addText: (text: string, label?: string) => Promise<boolean>;
  removeItem: (id: string) => Promise<boolean>;
  saveToInbox: (id: string) => Promise<{ success: boolean; alreadySaved?: boolean }>;
}

// ─── Hook ────────────────────────────────────────────────────────────────────

export function useShelfItems(): UseShelfItemsReturn {
  const [items, setItems] = useState<ShelfItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ── Load items from backend ──

  const loadItems = useCallback(async () => {
    if (!window.acmind) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const result = await window.acmind.shelf.listItems();
      if (result.success) {
        // Only show temporary items (not yet saved to inbox)
        setItems(result.items.filter(i => i.status === 'temporary'));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  // ── Initial load ──

  useEffect(() => {
    void loadItems();
  }, [loadItems]);

  // ── Listen for shelf.itemsChanged events ──

  useEffect(() => {
    if (!window.acmind) return;
    const unsubscribe = window.acmind.shelf.onItemsChanged(() => {
      void loadItems();
    });
    return unsubscribe;
  }, [loadItems]);

  // ── Actions ──

  const addFiles = useCallback(async (filePaths: string[], label?: string): Promise<boolean> => {
    try {
      const result = await window.acmind.shelf.addFiles(filePaths, label);
      if (result.success) {
        void loadItems();
      }
      return result.success;
    } catch {
      return false;
    }
  }, [loadItems]);

  const addText = useCallback(async (text: string, label?: string): Promise<boolean> => {
    try {
      const result = await window.acmind.shelf.addText(text, label);
      if (result.success) {
        void loadItems();
      }
      return result.success;
    } catch {
      return false;
    }
  }, [loadItems]);

  const removeItem = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.shelf.removeItem(id);
      if (result.success) {
        setItems(prev => prev.filter(item => item.id !== id));
      }
      return result.success;
    } catch {
      return false;
    }
  }, []);

  const saveToInbox = useCallback(async (id: string) => {
    try {
      const result = await window.acmind.shelf.saveToInbox(id);
      if (result.success) {
        // Remove from temporary list (it's now in inbox)
        setItems(prev => prev.filter(item => item.id !== id));
      }
      return { success: result.success, alreadySaved: result.alreadySaved };
    } catch {
      return { success: false };
    }
  }, []);

  return {
    items,
    loading,
    error,
    refresh: loadItems,
    addFiles,
    addText,
    removeItem,
    saveToInbox,
  };
}
