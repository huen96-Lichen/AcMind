import { useCallback, useEffect, useState } from 'react';
import type { ErrorRecord, ErrorStatus } from '../../shared/types';

export interface UseErrorRecordsReturn {
  records: ErrorRecord[];
  openCount: number;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  resolve: (errorId: string) => Promise<boolean>;
  dismiss: (errorId: string) => Promise<boolean>;
  clearResolved: () => Promise<number>;
}

export function useErrorRecords(
  filter?: { status?: ErrorStatus; errorType?: string; limit?: number },
): UseErrorRecordsReturn {
  const [records, setRecords] = useState<ErrorRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadRecords = useCallback(async () => {
    if (!window.pinmind?.errors) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const items = await window.pinmind.errors.list({
        status: filter?.status,
        errorType: filter?.errorType,
        limit: filter?.limit ?? 100,
      });
      setRecords(items);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, [filter?.status, filter?.errorType, filter?.limit]);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  const resolve = useCallback(async (errorId: string): Promise<boolean> => {
    if (!window.pinmind?.errors) return false;
    const ok = await window.pinmind.errors.resolve(errorId);
    if (ok) void loadRecords();
    return ok;
  }, [loadRecords]);

  const dismiss = useCallback(async (errorId: string): Promise<boolean> => {
    if (!window.pinmind?.errors) return false;
    const ok = await window.pinmind.errors.dismiss(errorId);
    if (ok) void loadRecords();
    return ok;
  }, [loadRecords]);

  const clearResolved = useCallback(async (): Promise<number> => {
    if (!window.pinmind?.errors) return 0;
    const count = await window.pinmind.errors.clearResolved();
    if (count > 0) void loadRecords();
    return count;
  }, [loadRecords]);

  const openCount = records.filter((r) => r.status === 'open').length;

  return {
    records,
    openCount,
    loading,
    error,
    refresh: loadRecords,
    resolve,
    dismiss,
    clearResolved,
  };
}
