/**
 * useKnowledgeCards — 知识卡片 CRUD hook
 */

import { useState, useCallback, useEffect } from 'react';
import type { KnowledgeCard } from '../../shared/types';

interface UseKnowledgeCardsResult {
  cards: KnowledgeCard[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
}

export function useKnowledgeCards(): UseKnowledgeCardsResult {
  const [cards, setCards] = useState<KnowledgeCard[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await window.acmind.knowledgeCards.list({ limit: 200 });
      setCards(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { cards, loading, error, refresh };
}
