import { useCallback, useEffect, useState } from 'react';
import type { PinItem } from '../../shared/types';

export function usePinPool(): {
  pins: PinItem[];
  selectedPin: PinItem | null;
  setSelectedPin: (pin: PinItem | null) => void;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  createFromText: (text: string, title?: string) => Promise<PinItem>;
  prefilter: (id: string) => Promise<void>;
  promoteToInbox: (id: string) => Promise<void>;
  ignore: (id: string) => Promise<void>;
  deletePin: (id: string) => Promise<void>;
} {
  const [pins, setPins] = useState<PinItem[]>([]);
  const [selectedPin, setSelectedPin] = useState<PinItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const items = await window.acmind.pinPool.list({ limit: 100 });
      setPins(items);
      setSelectedPin((current) => current ? items.find((item) => item.id === current.id) ?? null : items[0] ?? null);
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
    return window.acmind.onPinPoolChanged(() => {
      void refresh();
    });
  }, [refresh]);

  const prefilter = useCallback(async (id: string) => {
    await window.acmind.pinPool.prefilter(id);
    await refresh();
  }, [refresh]);

  const promoteToInbox = useCallback(async (id: string) => {
    await window.acmind.pinPool.promoteToInbox(id);
    await refresh();
  }, [refresh]);

  const ignore = useCallback(async (id: string) => {
    await window.acmind.pinPool.ignore(id);
    await refresh();
  }, [refresh]);

  const createFromText = useCallback(async (text: string, title?: string) => {
    const pin = await window.acmind.pinPool.createFromText(text, title);
    await refresh();
    return pin;
  }, [refresh]);

  const deletePin = useCallback(async (id: string) => {
    await window.acmind.pinPool.delete(id);
    await refresh();
  }, [refresh]);

  return { pins, selectedPin, setSelectedPin, loading, error, refresh, createFromText, prefilter, promoteToInbox, ignore, deletePin };
}
