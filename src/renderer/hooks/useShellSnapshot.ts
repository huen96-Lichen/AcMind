import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AppSettings, PermissionStatusSnapshot, SourceItem, StorageStats, VaultConfig } from '../../shared/types';

export interface ShellSnapshot {
  settings: AppSettings | null;
  storageStats: StorageStats | null;
  clipboard: { running: boolean; enabled: boolean } | null;
  permissions: PermissionStatusSnapshot | null;
  vault: VaultConfig | null;
  recentItems: SourceItem[];
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
}

/** Check if the Electron preload bridge is available */
function isBridgeAvailable(): boolean {
  return typeof window !== 'undefined' && window.pinmind != null;
}

export function useShellSnapshot(): ShellSnapshot {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [storageStats, setStorageStats] = useState<StorageStats | null>(null);
  const [clipboard, setClipboard] = useState<{ running: boolean; enabled: boolean } | null>(null);
  const [permissions, setPermissions] = useState<PermissionStatusSnapshot | null>(null);
  const [vault, setVault] = useState<VaultConfig | null>(null);
  const [recentItems, setRecentItems] = useState<SourceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!isBridgeAvailable()) {
      setError('Electron bridge not available');
      setLoading(false);
      return;
    }
    try {
      setError(null);
      const [nextSettings, nextStats, nextClipboard, nextPermissions, nextVault, nextItems] = await Promise.all([
        window.pinmind.settings.get(),
        window.pinmind.storage.getStats(),
        window.pinmind.clipboard.getStatus(),
        window.pinmind.permissions.getStatus('renderer-query'),
        window.pinmind.vault.getConfig(),
        window.pinmind.sourceItems.list({ limit: 6 }),
      ]);

      setSettings(nextSettings);
      setStorageStats(nextStats);
      setClipboard(nextClipboard);
      setPermissions(nextPermissions);
      setVault(nextVault);
      setRecentItems(nextItems);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    if (!isBridgeAvailable()) return;
    const unsubscribe = window.pinmind.onRecordsChanged(() => {
      void refresh();
    });
    return unsubscribe;
  }, [refresh]);

  useEffect(() => {
    if (!isBridgeAvailable()) return;
    const unsubscribe = window.pinmind.permissions.onStatusUpdated((snapshot) => {
      setPermissions(snapshot);
    });
    return unsubscribe;
  }, []);

  return useMemo(
    () => ({
      settings,
      storageStats,
      clipboard,
      permissions,
      vault,
      recentItems,
      loading,
      error,
      refresh,
    }),
    [settings, storageStats, clipboard, permissions, vault, recentItems, loading, error, refresh],
  );
}
