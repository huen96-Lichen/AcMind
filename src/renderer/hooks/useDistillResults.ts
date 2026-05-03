import { useCallback, useEffect, useState } from 'react';
import type { DistilledOutput } from '../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

interface UseDistillResultsReturn {
  outputs: DistilledOutput[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  accept: (outputId: string) => Promise<boolean>;
  reject: (outputId: string) => Promise<boolean>;
}

// ─── Hook ────────────────────────────────────────────────────────────────────

/**
 * Custom hook for managing distilled outputs.
 * Loads outputs awaiting review and provides accept/reject actions.
 */
export function useDistillResults(): UseDistillResultsReturn {
  const [outputs, setOutputs] = useState<DistilledOutput[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadOutputs = useCallback(async () => {
    if (!window.pinmind) {
      setLoading(false);
      return;
    }
    try {
      setError(null);
      const result = await window.pinmind.distilledOutputs.list({ reviewStatus: 'pending' });
      setOutputs(result);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    void loadOutputs();
  }, [loadOutputs]);

  // Listen for records.changed events
  useEffect(() => {
    if (!window.pinmind) return;
    const unsubscribe = window.pinmind.onRecordsChanged(() => {
      void loadOutputs();
    });
    return unsubscribe;
  }, [loadOutputs]);

  const accept = useCallback(
    async (outputId: string): Promise<boolean> => {
      try {
        setError(null);
        await window.pinmind.distilledOutputs.review(outputId, 'approve');
        await loadOutputs();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        setError(message);
        return false;
      }
    },
    [loadOutputs],
  );

  const reject = useCallback(
    async (outputId: string): Promise<boolean> => {
      try {
        setError(null);
        await window.pinmind.distilledOutputs.review(outputId, 'discard');
        await loadOutputs();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        setError(message);
        return false;
      }
    },
    [loadOutputs],
  );

  return {
    outputs,
    loading,
    error,
    refresh: loadOutputs,
    accept,
    reject,
  };
}
