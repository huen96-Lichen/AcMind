/**
 * useCaptures — Capture 模块数据 Hook
 *
 * 管理最近截图列表、已钉图片列表、截图操作。
 */

import { useState, useEffect, useCallback } from 'react';
import type { SourceItem, PinnedImage, OcrResult } from '../../shared/types';

interface UseCapturesResult {
  recentCaptures: SourceItem[];
  pinnedImages: PinnedImage[];
  loading: boolean;
  error: string | null;
  // 截图操作
  takeScreenshot: () => Promise<boolean>;
  pinImage: (filePath: string, sourceItemId?: string) => Promise<PinnedImage | null>;
  // 贴图操作
  closePinnedImage: (id: string) => Promise<void>;
  savePinnedToInbox: (id: string) => Promise<boolean>;
  // OCR
  ocrExtract: (imagePath: string, language?: string) => Promise<OcrResult>;
  ocrSaveToInbox: (text: string, sourceImagePath?: string) => Promise<boolean>;
  // 刷新
  refresh: () => Promise<void>;
}

export function useCaptures(): UseCapturesResult {
  const [recentCaptures, setRecentCaptures] = useState<SourceItem[]>([]);
  const [pinnedImages, setPinnedImages] = useState<PinnedImage[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const [recentResult, pinnedResult] = await Promise.all([
        window.acmind.capture.listRecentCaptures(50),
        window.acmind.capture.listPinnedImages(),
      ]);
      if (recentResult.success) {
        setRecentCaptures(recentResult.items ?? []);
      }
      if (pinnedResult.success) {
        setPinnedImages(pinnedResult.pinnedImages ?? []);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  // 初始加载
  useEffect(() => {
    void refresh();
  }, [refresh]);

  // 监听截图变化事件
  useEffect(() => {
    const unsubItems = window.acmind.capture.onItemsChanged(() => {
      void refresh();
    });
    const unsubPinned = window.acmind.capture.onPinnedChanged(() => {
      void refresh();
    });
    return () => {
      unsubItems();
      unsubPinned();
    };
  }, [refresh]);

  const takeScreenshot = useCallback(async (): Promise<boolean> => {
    try {
      const result = await window.acmind.capture.screenshot();
      if (result) {
        await refresh();
      }
      return result;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return false;
    }
  }, [refresh]);

  const pinImage = useCallback(async (filePath: string, sourceItemId?: string): Promise<PinnedImage | null> => {
    try {
      const result = await window.acmind.capture.pinImage(filePath, sourceItemId);
      if (result.success && result.pinnedImage) {
        await refresh();
        return result.pinnedImage;
      }
      return null;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return null;
    }
  }, [refresh]);

  const closePinnedImage = useCallback(async (id: string): Promise<void> => {
    try {
      await window.acmind.capture.closePinnedImage(id);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, [refresh]);

  const savePinnedToInbox = useCallback(async (id: string): Promise<boolean> => {
    try {
      const result = await window.acmind.capture.saveToInbox(id);
      if (result.success) {
        await refresh();
        return true;
      }
      return false;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return false;
    }
  }, [refresh]);

  const ocrExtract = useCallback(async (imagePath: string, language?: string): Promise<OcrResult> => {
    try {
      const result = await window.acmind.capture.ocrExtract(imagePath, language);
      return result;
    } catch (err) {
      return { text: '', error: err instanceof Error ? err.message : String(err) };
    }
  }, []);

  const ocrSaveToInbox = useCallback(async (text: string, sourceImagePath?: string): Promise<boolean> => {
    try {
      const result = await window.acmind.capture.ocrSaveToInbox(text, sourceImagePath);
      return result.success;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return false;
    }
  }, []);

  return {
    recentCaptures,
    pinnedImages,
    loading,
    error,
    takeScreenshot,
    pinImage,
    closePinnedImage,
    savePinnedToInbox,
    ocrExtract,
    ocrSaveToInbox,
    refresh,
  };
}
