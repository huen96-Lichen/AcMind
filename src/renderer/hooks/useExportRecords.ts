import { useCallback, useEffect, useState } from 'react';
import type { ExportRecord } from '../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

interface UseExportRecordsReturn {
  records: ExportRecord[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  exportSingle: (distilledOutputId: string) => Promise<boolean>;
  exportBatch: (distilledOutputIds: string[]) => Promise<boolean>;
}

// ─── Hook ────────────────────────────────────────────────────────────────────

/**
 * Custom hook for managing export records.
 * Loads export history and provides export actions.
 */
export function useExportRecords(): UseExportRecordsReturn {
  const [records, setRecords] = useState<ExportRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadRecords = useCallback(async () => {
    if (!window.acmind) {
      setLoading(false);
      return;
    }
    try {
      setError(null);
      const result = await window.acmind.export.history();
      setRecords(result);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  // Initial load
  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  // Listen for records.changed events
  useEffect(() => {
    if (!window.acmind) return;
    const unsubscribe = window.acmind.onRecordsChanged(() => {
      void loadRecords();
    });
    return unsubscribe;
  }, [loadRecords]);

  const exportSingle = useCallback(
    async (distilledOutputId: string): Promise<boolean> => {
      try {
        setError(null);

        // V2.1: 优先走 pipeline retry
        const record = records.find((r) => r.distilledOutputId === distilledOutputId);
        if (record?.sourceItemId && window.acmind?.pipeline) {
          const result = await window.acmind.pipeline.retryExport(record.sourceItemId);
          if (result.success) {
            await loadRecords();
            return true;
          }
          // Pipeline retry failed, fall through to legacy export
        }

        // Fallback: legacy export.single
        await window.acmind.export.single(distilledOutputId);
        await loadRecords();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        setError(message);
        return false;
      }
    },
    [loadRecords, records],
  );

  const exportBatch = useCallback(
    async (distilledOutputIds: string[]): Promise<boolean> => {
      try {
        setError(null);

        // V2.1: 优先走 pipeline retry（逐条）
        if (window.acmind?.pipeline) {
          let allSucceeded = true;
          for (const id of distilledOutputIds) {
            const record = records.find((r) => r.distilledOutputId === id);
            if (record?.sourceItemId) {
              const result = await window.acmind.pipeline.retryExport(record.sourceItemId);
              if (!result.success) {
                allSucceeded = false;
                setError(result.error ?? '批量写入部分失败');
              }
            } else {
              // 无 sourceItemId，走 legacy
              try {
                await window.acmind.export.single(id);
              } catch {
                allSucceeded = false;
              }
            }
          }
          await loadRecords();
          return allSucceeded;
        }

        // Fallback: legacy export.batch
        await window.acmind.export.batch(distilledOutputIds);
        await loadRecords();
        return true;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        setError(message);
        return false;
      }
    },
    [loadRecords, records],
  );

  return {
    records,
    loading,
    error,
    refresh: loadRecords,
    exportSingle,
    exportBatch,
  };
}
