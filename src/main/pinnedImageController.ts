/**
 * PinnedImageController — 贴图浮窗管理器
 *
 * 管理钉在桌面的截图浮窗，每个浮窗独立、可移动、可关闭。
 * 参考 CapsuleController 的 alwaysOnTop + frameless 模式。
 */

import { app, BrowserWindow, screen, ipcMain, nativeImage, clipboard } from 'electron';
import { join } from 'path';
import { existsSync } from 'fs';
import { storage } from './storage';
import { logger } from './logger';
import { PinnedImage, IPC_CHANNELS } from '../shared/types';
import { randomUUID } from 'crypto';

const isDev = !app.isPackaged;

// 每个贴图窗口的引用
interface PinnedWindowEntry {
  window: BrowserWindow;
  pinnedImage: PinnedImage;
}

class PinnedImageController {
  private windows = new Map<string, PinnedWindowEntry>();

  constructor() {
    // 监听来自贴图窗口的 IPC
    ipcMain.on('pinned-image:close', (_event, id: string) => {
      this.closePinnedImage(id);
    });

    ipcMain.on('pinned-image:save-to-inbox', (_event, id: string) => {
      this.saveToInbox(id);
    });

    ipcMain.on('pinned-image:copy', (_event, id: string) => {
      this.copyToClipboard(id);
    });
  }

  /**
   * 钉一张图片到桌面
   */
  pinImage(filePath: string, sourceItemId?: string): PinnedImage | null {
    if (!existsSync(filePath)) {
      logger.warn('error', 'pinnedImageController', 'pinImage', 'File not found', { filePath });
      return null;
    }

    // 读取图片尺寸
    const image = nativeImage.createFromPath(filePath);
    const size = image.getSize();

    // 限制初始尺寸
    const maxWidth = 600;
    const maxHeight = 500;
    let width = size.width;
    let height = size.height;
    if (width > maxWidth) {
      const ratio = maxWidth / width;
      width = maxWidth;
      height = Math.round(height * ratio);
    }
    if (height > maxHeight) {
      const ratio = maxHeight / height;
      height = maxHeight;
      width = Math.round(width * ratio);
    }

    // 居中放置
    const primaryDisplay = screen.getPrimaryDisplay();
    const { width: screenW, height: screenH } = primaryDisplay.workAreaSize;
    const x = Math.round((screenW - width) / 2);
    const y = Math.round((screenH - height) / 2);

    const pinnedImage: PinnedImage = {
      id: randomUUID(),
      filePath,
      x,
      y,
      width,
      height,
      sourceItemId,
      createdAt: Date.now(),
    };

    this.createWindow(pinnedImage);
    this.notifyChanged();
    return pinnedImage;
  }

  /**
   * 创建贴图窗口
   */
  private createWindow(pinned: PinnedImage): void {
    const preload = join(__dirname, '../preload/index.js');

    const win = new BrowserWindow({
      x: pinned.x,
      y: pinned.y,
      width: pinned.width,
      height: pinned.height,
      frame: false,
      transparent: true,
      alwaysOnTop: true,
      skipTaskbar: true,
      hasShadow: true,
      resizable: true,
      movable: true,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      backgroundColor: '#00000000',
      webPreferences: {
        preload,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
      },
    });

    // 加载贴图页面
    const encodedId = encodeURIComponent(pinned.id);
    if (isDev && process.env.ELECTRON_RENDERER_URL) {
      win.loadURL(`${process.env.ELECTRON_RENDERER_URL}/pinned-image.html?id=${encodedId}`);
    } else {
      win.loadFile(join(__dirname, '../renderer/pinned-image.html'), {
        search: `?id=${encodedId}`,
      });
    }

    // 窗口关闭时清理
    win.on('closed', () => {
      this.windows.delete(pinned.id);
      this.notifyChanged();
    });

    this.windows.set(pinned.id, { window: win, pinnedImage: pinned });
  }

  /**
   * 关闭贴图窗口
   */
  closePinnedImage(id: string): void {
    const entry = this.windows.get(id);
    if (entry && !entry.window.isDestroyed()) {
      entry.window.close();
    }
    this.windows.delete(id);
    this.notifyChanged();
  }

  /**
   * 关闭所有贴图
   */
  closeAll(): void {
    for (const [, entry] of this.windows) {
      if (!entry.window.isDestroyed()) {
        entry.window.close();
      }
    }
    this.windows.clear();
    this.notifyChanged();
  }

  /**
   * 保存贴图到 Inbox
   */
  saveToInbox(id: string): { success: boolean; error?: string } {
    const entry = this.windows.get(id);
    if (!entry) return { success: false, error: 'Pinned image not found' };

    const { pinnedImage } = entry;

    // 检查是否已保存
    if (pinnedImage.sourceItemId) {
      const existing = storage.getSourceItem(pinnedImage.sourceItemId);
      if (existing) {
        return { success: true };
      }
    }

    try {
      const sourceItem = {
        id: randomUUID(),
        type: 'image' as const,
        source: 'screenshot' as const,
        contentPath: pinnedImage.filePath,
        previewText: '贴图 · ' + new Date(pinnedImage.createdAt).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' }),
        status: 'inbox' as const,
        createdAt: Math.floor(Date.now() / 1000),
      };
      storage.insertSourceItem(sourceItem);

      // 更新 pinned image 的 sourceItemId
      pinnedImage.sourceItemId = sourceItem.id;
      entry.pinnedImage = pinnedImage;

      // 通知主窗口
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed() && win !== entry.window) {
          win.webContents.send(IPC_CHANNELS.RECORDS_CHANGED, { action: 'pinned_saved', id: sourceItem.id, timestamp: Date.now() });
        }
      }

      return { success: true };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  }

  /**
   * 复制贴图到剪贴板
   */
  copyToClipboard(id: string): void {
    const entry = this.windows.get(id);
    if (!entry) return;

    const image = nativeImage.createFromPath(entry.pinnedImage.filePath);
    clipboard.writeImage(image);
  }

  /**
   * 获取所有贴图
   */
  listPinnedImages(): PinnedImage[] {
    return Array.from(this.windows.values()).map(e => e.pinnedImage);
  }

  /**
   * 获取单个贴图信息
   */
  getPinnedImage(id: string): PinnedImage | null {
    return this.windows.get(id)?.pinnedImage ?? null;
  }

  /**
   * 通知渲染进程贴图列表变化
   */
  private notifyChanged(): void {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.CAPTURE_PINNED_CHANGED, { timestamp: Date.now() });
      }
    }
  }
}

export const pinnedImageController = new PinnedImageController();
