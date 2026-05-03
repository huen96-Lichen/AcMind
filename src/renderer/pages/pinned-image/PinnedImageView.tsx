/**
 * PinnedImageView — 贴图浮窗渲染内容
 *
 * 在独立 BrowserWindow 中渲染，显示钉在桌面的截图。
 * 支持：移动窗口、关闭、保存到 Inbox、复制到剪贴板。
 */

import { useState, useEffect, useCallback } from 'react';
import { PinStackIcon } from '../../design-system/icons';
import { Button } from '../../design-system/components';
import type { PinnedImage } from '../../../shared/types';

export function PinnedImageView(): JSX.Element {
  const [pinnedImage, setPinnedImage] = useState<PinnedImage | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  // 从 URL 参数获取 pinned image ID
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const id = params.get('id');
    if (!id) return;

    // 通过 IPC 获取 pinned image 信息
    window.acmind.capture.listPinnedImages().then((result) => {
      if (result.success && result.pinnedImages) {
        const found = result.pinnedImages.find((p: PinnedImage) => p.id === id);
        if (found) setPinnedImage(found);
      }
    });
  }, []);

  const handleClose = useCallback(() => {
    if (!pinnedImage) return;
    // 通过 preload 发送关闭消息
    const { ipcRenderer } = window.require('electron');
    ipcRenderer.send('pinned-image:close', pinnedImage.id);
  }, [pinnedImage]);

  const handleSaveToInbox = useCallback(async () => {
    if (!pinnedImage) return;
    setBusy('save');
    try {
      const result = await window.acmind.capture.saveToInbox(pinnedImage.id);
      if (result.success) {
        // 可以选择关闭窗口或保持打开
      }
    } finally {
      setBusy(null);
    }
  }, [pinnedImage]);

  const handleCopy = useCallback(() => {
    if (!pinnedImage) return;
    const { ipcRenderer } = window.require('electron');
    ipcRenderer.send('pinned-image:copy', pinnedImage.id);
  }, [pinnedImage]);

  if (!pinnedImage) {
    return (
      <div className="flex h-screen w-screen items-center justify-center bg-transparent">
        <span className="text-[12px] text-white/60">加载中...</span>
      </div>
    );
  }

  return (
    <div className="group relative h-screen w-screen overflow-hidden bg-transparent">
      {/* 图片 */}
      <img
        src={`file://${pinnedImage.filePath}`}
        alt="贴图"
        className="h-full w-full object-contain"
        draggable={false}
      />

      {/* 悬浮操作栏 - 鼠标悬停时显示 */}
      <div className="absolute bottom-0 left-0 right-0 flex items-center justify-center gap-1 bg-black/50 p-2 opacity-0 transition-opacity group-hover:opacity-100">
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name="duplicate" size={14} />}
          onClick={() => void handleCopy()}
          title="复制到剪贴板"
          className="text-white hover:text-white"
        >
          复制
        </Button>
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name="filled-inbox" size={14} />}
          busy={busy === 'save'}
          onClick={() => void handleSaveToInbox()}
          title="保存到收集箱"
          className="text-white hover:text-white"
        >
          收集箱
        </Button>
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name="close" size={14} />}
          onClick={handleClose}
          title="关闭贴图"
          className="text-white hover:text-white"
        >
          关闭
        </Button>
      </div>
    </div>
  );
}
