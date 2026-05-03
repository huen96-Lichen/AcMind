/**
 * useVaultSearch — Obsidian Vault 关键词搜索 hook
 */

import { useState, useCallback } from 'react';
import type { VaultSearchResult } from '../../shared/types';

interface UseVaultSearchResult {
  results: VaultSearchResult[];
  loading: boolean;
  error: string | null;
  search: (keyword: string, options?: { folderPath?: string; limit?: number }) => Promise<void>;
  clear: () => void;
}

export function useVaultSearch(): UseVaultSearchResult {
  const [results, setResults] = useState<VaultSearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const search = useCallback(async (keyword: string, options?: { folderPath?: string; limit?: number }) => {
    if (!keyword.trim()) {
      setResults([]);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await window.acmind.vaultSearch.search(keyword, options);
      if (res.success) {
        setResults(res.results);
      } else {
        setError(res.error || 'Search failed');
        setResults([]);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setResults([]);
    } finally {
      setLoading(false);
    }
  }, []);

  const clear = useCallback(() => {
    setResults([]);
    setError(null);
  }, []);

  return { results, loading, error, search, clear };
}
