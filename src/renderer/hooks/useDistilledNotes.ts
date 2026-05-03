/**
 * useDistilledNotes — 蒸馏笔记 CRUD hook
 */

import { useState, useCallback, useEffect } from 'react';
import type { DistilledNote } from '../../shared/types';

interface UseDistilledNotesResult {
  notes: DistilledNote[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  create: (note: DistilledNote) => Promise<boolean>;
  update: (id: string, patch: Partial<DistilledNote>) => Promise<boolean>;
  remove: (id: string) => Promise<boolean>;
}

export function useDistilledNotes(): UseDistilledNotesResult {
  const [notes, setNotes] = useState<DistilledNote[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await window.acmind.distilledNotes.list({ limit: 200 });
      if (res.success) {
        setNotes(res.notes);
      } else {
        setError('Failed to load distilled notes');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  const create = useCallback(async (note: DistilledNote): Promise<boolean> => {
    try {
      const res = await window.acmind.distilledNotes.create(note);
      if (res.success) {
        await refresh();
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }, [refresh]);

  const update = useCallback(async (id: string, patch: Partial<DistilledNote>): Promise<boolean> => {
    try {
      const res = await window.acmind.distilledNotes.update(id, patch);
      if (res.success) {
        await refresh();
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }, [refresh]);

  const remove = useCallback(async (id: string): Promise<boolean> => {
    try {
      const res = await window.acmind.distilledNotes.delete(id);
      if (res.success) {
        await refresh();
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }, [refresh]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { notes, loading, error, refresh, create, update, remove };
}
