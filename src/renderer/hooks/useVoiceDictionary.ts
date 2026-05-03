/**
 * useVoiceDictionary — 语音词典管理 hook
 */

import { useState, useCallback, useEffect } from 'react';
import type { VoiceDictionaryEntry } from '../../shared/types';

interface UseVoiceDictionaryResult {
  entries: VoiceDictionaryEntry[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  add: (phrase: string, note?: string) => Promise<boolean>;
  remove: (id: string) => Promise<boolean>;
  toggle: (id: string, enabled: boolean) => Promise<boolean>;
}

export function useVoiceDictionary(): UseVoiceDictionaryResult {
  const [entries, setEntries] = useState<VoiceDictionaryEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await window.acmind.voiceDictionary.list();
      if (res.success) {
        setEntries(res.entries);
      } else {
        setError('Failed to load dictionary');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  const add = useCallback(async (phrase: string, note?: string): Promise<boolean> => {
    try {
      const res = await window.acmind.voiceDictionary.add(phrase, note);
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
      const res = await window.acmind.voiceDictionary.delete(id);
      if (res.success) {
        await refresh();
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }, [refresh]);

  const toggle = useCallback(async (id: string, enabled: boolean): Promise<boolean> => {
    try {
      const res = await window.acmind.voiceDictionary.toggle(id, enabled);
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

  return { entries, loading, error, refresh, add, remove, toggle };
}
