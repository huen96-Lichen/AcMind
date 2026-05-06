import { randomUUID } from 'node:crypto';
import { execFile } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, unlinkSync, existsSync, copyFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { promisify } from 'node:util';
import { BrowserWindow, shell, systemPreferences, screen, nativeImage, clipboard } from 'electron';
import type { SourceItem, SourceItemStatus, SourceItemType, SourceItemSource, CaptureRecord, CaptureItem, PinItem, ClipboardItem, ClipboardContentType, AssetFile } from '../shared/types';
import { IPC_CHANNELS } from '../shared/types';
import { storage } from './storage';
import { logger } from './logger';
import { errorService } from './errorService';
import { clipboardWatcher } from './clipboardWatcher';
import type { ClipboardContent } from './clipboardWatcher';
import { getClipboardSourceApp } from './sourceApp';
import { settings } from './settings';
import { captureRegistry } from './services/capture';
import type { CaptureInput } from './services/capture';
import { taskQueue } from './services/aiHub/taskQueue';
import { voiceWatchService } from './services/capture/voiceWatchService';
import { audioTranscriptionService } from './services/capture/audioTranscriptionService';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SourceItemFilter {
  type?: SourceItemType;
  source?: SourceItemSource;
  status?: SourceItemStatus;
  limit?: number;
  offset?: number;
}

export interface SourceItemContentResult {
  type: SourceItemType;
  text?: string;
  dataUrl?: string;
}

export interface RecordsChangedEvent {
  action: 'created' | 'updated' | 'deleted';
  id: string;
  timestamp: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const RECORDS_CHANGED_CHANNEL = 'records.changed';
const execFileAsync = promisify(execFile);
// ---------------------------------------------------------------------------
// CaptureService
// ---------------------------------------------------------------------------

class CaptureService {
  private initialized = false;

  /**
   * Initialize the capture service. Starts the clipboard watcher.
   */
  init(): void {
    if (this.initialized) {
      return;
    }

    const currentSettings = settings.load();

    // Start clipboard watcher with content handler
    clipboardWatcher.start(this.handleNewClipboardContent.bind(this));

    // Respect autoCapture and backgroundClipboard settings
    if (!currentSettings.autoCapture || !currentSettings.backgroundClipboard) {
      clipboardWatcher.setEnabled(false);
    }

    // Phase 10: Initialize voice watch service
    voiceWatchService.setCaptureService(this);
    voiceWatchService.init();

    this.initialized = true;

    logger.info('app', 'captureService', 'init', 'Capture service initialized', {
      autoCapture: currentSettings.autoCapture,
      pollIntervalMs: currentSettings.pollIntervalMs,
    });
  }

  /**
   * Stop the capture service and all watchers.
   */
  stop(): void {
    clipboardWatcher.stop();
    voiceWatchService.stop();
    this.initialized = false;

    logger.info('app', 'captureService', 'stop', 'Capture service stopped');
  }

  /**
   * Trigger a screenshot capture and save it as a SourceItem.
   */
  async captureScreenshot(): Promise<boolean> {
    logger.info('app', 'captureService', 'captureScreenshot', 'Screenshot capture requested');

    try {
      if (process.platform === 'darwin') {
        const mediaStatus = systemPreferences.getMediaAccessStatus('screen');
        if (mediaStatus === 'denied' || mediaStatus === 'restricted') {
          logger.warn('error', 'captureService', 'captureScreenshot', 'Screen recording permission is not granted', {
            mediaStatus,
          });
          return false;
        }
      }

      const storageRoot = settings.getStorageRoot();
      const id = randomUUID();
      const now = Math.floor(Date.now() / 1000);
      const dateDir = new Date().toISOString().slice(0, 10);
      const sourcesDir = path.join(storageRoot, 'sources', dateDir);
      mkdirSync(sourcesDir, { recursive: true });

      const contentPath = path.join(sourcesDir, `${id}.png`);
      if (process.platform === 'darwin') {
        await execFileAsync('/usr/sbin/screencapture', ['-x', contentPath]);
      } else {
        logger.warn('app', 'captureService', 'captureScreenshot', 'Using fallback screen capture path on non-macOS platform');
        const { desktopCapturer } = await import('electron');
        const sources = await desktopCapturer.getSources({
          types: ['screen'],
          thumbnailSize: { width: 1920, height: 1080 },
          fetchWindowIcons: false,
        });
        const fallbackSource = sources[0];
        if (!fallbackSource) {
          logger.warn('error', 'captureService', 'captureScreenshot', 'No screen source available');
          return false;
        }
        writeFileSync(contentPath, fallbackSource.thumbnail.toPNG());
      }

      const pngBuffer = readFileSync(contentPath);
      if (pngBuffer.length === 0) {
        logger.warn('error', 'captureService', 'captureScreenshot', 'Captured screenshot buffer is empty');
        return false;
      }

      const sourceItem: SourceItem = {
        id,
        type: 'image',
        source: 'screenshot',
        contentPath,
        previewText: `屏幕截图 · ${new Date(now).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`,
        sourceApp: 'AcMind',
        createdAt: now,
        status: 'inbox',
      };

      storage.insertSourceItem(sourceItem);
      this.emitRecordsChanged({ action: 'created', id, timestamp: now });

      // Phase 4: Also create PinItem so screenshot enters Pin Pool
      const pin: PinItem = {
        id: randomUUID(),
        captureItemId: '',
        originalId: id,
        sourceType: 'screenshot',
        title: `屏幕截图 · ${new Date(now * 1000).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`,
        previewText: '',
        rawFilePath: contentPath,
        status: 'pinned',
        createdAt: now,
        pinnedAt: now,
        updatedAt: now,
      };
      storage.insertPinItem(pin);
      this.emitPinPoolChanged('created', pin.id);

      logger.info('app', 'captureService', 'captureScreenshot', 'Screenshot captured and stored', {
        id,
        contentPath,
        pinId: pin.id,
        sourceName: 'screen',
      });

      return true;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'captureService', 'captureScreenshot', 'Failed to capture screenshot', {
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'capture',
        error,
        userMessage: '截图捕获失败，请检查屏幕录制权限或重试。',
        retryable: false,
      });
      return false;
    }
  }

  /**
   * Capture a region screenshot by taking a full screen capture and cropping with nativeImage.
   * Returns the cropped image path, or null on failure.
   */
  async captureRegionScreenshot(bounds: { x: number; y: number; width: number; height: number }): Promise<string | null> {
    logger.info('app', 'captureService', 'captureRegionScreenshot', 'Region screenshot requested', { bounds });

    try {
      if (process.platform === 'darwin') {
        const mediaStatus = systemPreferences.getMediaAccessStatus('screen');
        if (mediaStatus === 'denied' || mediaStatus === 'restricted') {
          logger.warn('error', 'captureService', 'captureRegionScreenshot', 'Screen recording permission is not granted');
          return null;
        }
      }

      const storageRoot = settings.getStorageRoot();
      const id = randomUUID();
      const now = Math.floor(Date.now() / 1000);
      const dateDir = new Date().toISOString().slice(0, 10);
      const sourcesDir = path.join(storageRoot, 'sources', dateDir);
      mkdirSync(sourcesDir, { recursive: true });

      // Step 1: Full screen capture to temp file
      const tempPath = path.join(sourcesDir, `_region_temp_${id}.png`);
      if (process.platform === 'darwin') {
        await execFileAsync('/usr/sbin/screencapture', ['-x', tempPath]);
      } else {
        const { desktopCapturer } = await import('electron');
        const sources = await desktopCapturer.getSources({
          types: ['screen'],
          thumbnailSize: { width: 3840, height: 2160 },
          fetchWindowIcons: false,
        });
        if (!sources[0]) {
          logger.warn('error', 'captureService', 'captureRegionScreenshot', 'No screen source available');
          return null;
        }
        writeFileSync(tempPath, sources[0].thumbnail.toPNG());
      }

      // Step 2: Crop with nativeImage
      const fullImage = nativeImage.createFromPath(tempPath);
      const fullSize = fullImage.getSize();

      // Scale bounds from CSS pixels to device pixels
      const primaryDisplay = screen.getPrimaryDisplay();
      const scaleFactor = primaryDisplay.scaleFactor || 1;
      const cropBounds = {
        x: Math.round(bounds.x * scaleFactor),
        y: Math.round(bounds.y * scaleFactor),
        width: Math.round(bounds.width * scaleFactor),
        height: Math.round(bounds.height * scaleFactor),
      };

      // Clamp to image dimensions
      cropBounds.x = Math.max(0, Math.min(cropBounds.x, fullSize.width - 1));
      cropBounds.y = Math.max(0, Math.min(cropBounds.y, fullSize.height - 1));
      cropBounds.width = Math.min(cropBounds.width, fullSize.width - cropBounds.x);
      cropBounds.height = Math.min(cropBounds.height, fullSize.height - cropBounds.y);

      const croppedImage = fullImage.crop(cropBounds);
      const contentPath = path.join(sourcesDir, `${id}.png`);
      writeFileSync(contentPath, croppedImage.toPNG());

      // Cleanup temp file
      try { unlinkSync(tempPath); } catch { /* ignore */ }

      const pngBuffer = readFileSync(contentPath);
      if (pngBuffer.length === 0) {
        logger.warn('error', 'captureService', 'captureRegionScreenshot', 'Cropped screenshot buffer is empty');
        return null;
      }

      // Step 3: Create SourceItem
      const sourceItem: SourceItem = {
        id,
        type: 'image',
        source: 'screenshot',
        contentPath,
        previewText: `区域截图 · ${new Date(now * 1000).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`,
        sourceApp: 'AcMind',
        createdAt: now,
        status: 'inbox',
      };
      storage.insertSourceItem(sourceItem);
      this.emitRecordsChanged({ action: 'created', id, timestamp: now });

      // Step 4: Create PinItem
      const pin: PinItem = {
        id: randomUUID(),
        captureItemId: '',
        originalId: id,
        sourceType: 'screenshot',
        title: `区域截图 · ${new Date(now * 1000).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`,
        previewText: '',
        rawFilePath: contentPath,
        status: 'pinned',
        createdAt: now,
        pinnedAt: now,
        updatedAt: now,
      };
      storage.insertPinItem(pin);
      this.emitPinPoolChanged('created', pin.id);

      logger.info('app', 'captureService', 'captureRegionScreenshot', 'Region screenshot captured', {
        id, contentPath, pinId: pin.id, bounds: cropBounds,
      });

      return contentPath;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'captureService', 'captureRegionScreenshot', 'Failed to capture region screenshot', { error: errorMsg });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'capture',
        error,
        userMessage: '区域截图失败，请检查屏幕录制权限或重试。',
        retryable: false,
      });
      return null;
    }
  }

  /**
   * Copy an image file to clipboard.
   */
  async copyImageToClipboard(imagePath: string): Promise<boolean> {
    try {
      const image = nativeImage.createFromPath(imagePath);
      clipboard.writeImage(image);
      return true;
    } catch (error) {
      logger.error('error', 'captureService', 'copyImageToClipboard', 'Failed to copy image to clipboard', {
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }

  /**
   * Save a text note as a SourceItem. Used by onboarding and quick capture flows.
   * Now uses the unified CaptureAdapter architecture internally.
   */
  captureText(text: string, sourceApp = 'AcMind'): SourceItem {
    const trimmed = text.trim();
    if (!trimmed) {
      throw new Error('Text content is empty');
    }

    // Use the unified CaptureAdapter to produce a CaptureRecord
    const captureRecord = captureRegistry.capture({
      sourceType: 'manual_text',
      text: trimmed,
      sourceApp,
    });

    // Convert CaptureRecord to SourceItem (legacy bridge)
    return this.captureRecordToSourceItem(captureRecord);
  }

  /**
   * Import an audio file as a CaptureRecord.
   * Phase 10: Creates audio CaptureRecord, converts to SourceItem + CaptureItem,
   * and submits transcription job.
   */
  captureAudio(filePath: string, title?: string, sourceApp = 'AcMind'): SourceItem {
    const captureRecord = captureRegistry.capture({
      sourceType: 'audio',
      filePath,
      title,
      sourceApp,
    });

    const sourceItem = this.captureRecordToSourceItem(captureRecord);

    // Phase 10: Auto-submit transcription job if captureItemId was created
    if (sourceItem.captureItemId) {
      const rawFilePath = (sourceItem.metadata as Record<string, unknown>)?.raw_file_path as string || filePath;
      audioTranscriptionService.submitTranscriptionJob(sourceItem.captureItemId, rawFilePath).catch((err) => {
        logger.error('error', 'captureService', 'captureAudio', 'Auto transcription submission failed', {
          captureItemId: sourceItem.captureItemId,
          error: String(err),
        });
      });
    }

    return sourceItem;
  }

  /**
   * Convert a CaptureRecord to a SourceItem.
   * This bridges the new CaptureAdapter architecture with the existing SourceItem-based storage.
   */
  private captureRecordToSourceItem(record: CaptureRecord): SourceItem {
    const id = randomUUID();
    const now = Math.floor(Date.now() / 1000);
    const storageRoot = settings.getStorageRoot();
    const dateDir = new Date().toISOString().slice(0, 10);
    const sourcesDir = path.join(storageRoot, 'sources', dateDir);
    mkdirSync(sourcesDir, { recursive: true });

    let contentPath = '';
    let previewText = record.preview_text;
    let type: SourceItem['type'] = 'text';
    let source: SourceItem['source'] = 'manual';

    // Map source_type to legacy fields
    switch (record.source_type) {
      case 'manual_text':
      case 'clipboard_text':
        type = 'text';
        source = record.source_type === 'clipboard_text' ? 'clipboard' : 'manual';
        break;
      case 'screenshot':
      case 'image':
        type = 'image';
        source = record.source_type === 'screenshot' ? 'screenshot' : 'manual';
        break;
      case 'webpage':
        type = 'url';
        source = 'manual';
        break;
      case 'audio':
        type = 'text';
        source = 'audio';
        break;
      default:
        type = 'text';
        source = 'manual';
    }

    // Store content
    if (record.raw_text) {
      contentPath = path.join(sourcesDir, `${id}.txt`);
      writeFileSync(contentPath, record.raw_text, 'utf8');
      if (!previewText) {
        previewText = record.raw_text.length > 200 ? `${record.raw_text.slice(0, 200)}...` : record.raw_text;
      }
    } else if (record.raw_file_path && existsSync(record.raw_file_path)) {
      const ext = path.extname(record.raw_file_path) || '.bin';
      contentPath = path.join(sourcesDir, `${id}${ext}`);
      copyFileSync(record.raw_file_path, contentPath);
      if (!previewText) {
        previewText = record.title || `文件: ${path.basename(record.raw_file_path)}`;
      }
    } else if (record.raw_url) {
      contentPath = path.join(sourcesDir, `${id}.txt`);
      writeFileSync(contentPath, record.raw_url, 'utf8');
      if (!previewText) {
        previewText = record.raw_url;
      }
    }

    const sourceItem: SourceItem = {
      id,
      type,
      source,
      contentPath,
      previewText: previewText || '',
      sourceApp: record.source_app,
      originalUrl: record.raw_url,
      createdAt: now,
      status: 'inbox',
      title: record.title,
      originalId: record.original_id,
      metadata: record.metadata,
    };

    // Phase 10: For audio records, also create a CaptureItem so the
    // transcription pipeline has a captureItemId to work with.
    if (record.source_type === 'audio') {
      const captureItemId = randomUUID();
      const captureItem: CaptureItem = {
        id: captureItemId,
        type: 'audio',
        status: 'pending',
        title: record.title || path.basename(record.raw_file_path || 'audio'),
        rawText: '',
        sourceUrl: '',
        filePath: record.raw_file_path || '',
        userNote: '',
        capturedAt: now,
        updatedAt: now,
      };
      storage.insertCaptureItem(captureItem);
      sourceItem.captureItemId = captureItemId;

      // Notify renderer of new CaptureItem
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send('captureItems.changed', { action: 'created', id: captureItemId, timestamp: now });
        }
      }
    }

    storage.insertSourceItem(sourceItem);
    this.emitRecordsChanged({ action: 'created', id, timestamp: now });
    return sourceItem;
  }

  /**
   * Get source items with optional filtering.
   */
  getSourceItems(filter?: SourceItemFilter): SourceItem[] {
    return storage.getSourceItems(filter);
  }

  /**
   * Get a single source item by ID.
   */
  getSourceItem(id: string): SourceItem | null {
    return storage.getSourceItem(id);
  }

  /**
   * Read the content of a source item from disk.
   * Returns text content or a base64 data URL for images.
   */
  getSourceItemContent(id: string): SourceItemContentResult | null {
    const item = storage.getSourceItem(id);
    if (!item) {
      return null;
    }

    let contentPath = item.contentPath;
    if (!contentPath || !existsSync(contentPath)) {
      // Fallback: look for associated asset files
      const assets = storage.listAssetFilesBySourceItem(id);
      const fallback = assets.find(a => a.localPath && existsSync(a.localPath));
      if (fallback?.localPath) {
        contentPath = fallback.localPath;
      } else {
        logger.warn('app', 'captureService', 'getSourceItemContent', 'Content file not found', {
          id,
          contentPath,
        });
        return null;
      }
    }

    try {
      if (item.type === 'text') {
        const text = readFileSync(contentPath, 'utf8');
        return { type: 'text', text };
      }

      if (item.type === 'image') {
        const buffer = readFileSync(contentPath);
        const base64 = buffer.toString('base64');
        const dataUrl = `data:image/png;base64,${base64}`;
        return { type: 'image', dataUrl };
      }

      // URL type: read the text file containing the URL
      if (item.type === 'url') {
        const text = readFileSync(contentPath, 'utf8');
        return { type: 'url', text };
      }

      return null;
    } catch (error) {
      logger.error('error', 'captureService', 'getSourceItemContent', 'Failed to read content file', {
        id,
        contentPath,
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }

  /**
   * Delete a source item: remove from database and move content file to trash.
   */
  deleteSourceItem(id: string): void {
    const item = storage.getSourceItem(id);
    if (!item) {
      throw new Error(`SourceItem not found: ${id}`);
    }

    const tasks = storage.getAiTasks({ sourceItemId: id });
    const cancellableTasks = tasks.filter((task) => task.status === 'queued' || task.status === 'failed');
    if (cancellableTasks.length > 0) {
      const cancelledInMemory = new Set(taskQueue.cancelBySourceItem(id));
      for (const task of cancellableTasks) {
        storage.updateAiTask(task.id, {
          status: 'cancelled',
          finishedAt: Date.now(),
          error: cancelledInMemory.has(task.id) ? task.error : task.error ?? '删除 SourceItem 前取消排队任务',
        });
      }
    }

    const runningTasks = storage.getAiTasks({ sourceItemId: id }).filter((task) => task.status === 'running');
    if (runningTasks.length > 0) {
      throw new Error('当前内容仍有正在运行的任务，请等待当前模型调用结束后再删除');
    }

    // Move content file to trash if it exists
    if (item.contentPath && existsSync(item.contentPath)) {
      try {
        shell.trashItem(item.contentPath).catch(() => {
          // If trash fails, try to delete directly
          try {
            unlinkSync(item.contentPath);
          } catch {
            logger.warn('app', 'captureService', 'deleteSourceItem', 'Failed to delete content file', {
              contentPath: item.contentPath,
            });
          }
        });
      } catch {
        // Ignore trash errors
      }
    }

    // Remove from database
    storage.deleteSourceItem(id);

    logger.info('app', 'captureService', 'deleteSourceItem', `SourceItem deleted: ${id}`);

    // Notify renderer
    this.emitRecordsChanged({ action: 'deleted', id, timestamp: Date.now() });
  }

  /**
   * Search source items by query string.
   */
  searchSourceItems(query: string): SourceItem[] {
    return storage.searchSourceItems(query);
  }

  /**
   * List recent screenshot captures (Phase 2A).
   * Returns SourceItems of type 'image' with source 'screenshot'.
   */
  listRecentCaptures(limit = 50): SourceItem[] {
    return storage.getSourceItems({
      type: 'image',
      source: 'screenshot',
      status: 'inbox',
      limit,
    });
  }

  /**
   * Get clipboard watcher running status.
   */
  getClipboardStatus(): { running: boolean; enabled: boolean } {
    return {
      running: clipboardWatcher.isRunning(),
      enabled: clipboardWatcher.isEnabled(),
    };
  }

  /**
   * Toggle clipboard capture on/off.
   */
  toggleClipboard(enabled: boolean): void {
    clipboardWatcher.setEnabled(enabled);
  }

  /**
   * Tell the clipboard watcher to skip the next N clipboard changes.
   */
  ignoreNextCopy(count = 1): void {
    clipboardWatcher.ignoreNextCopy(count);
  }

  /**
   * Temporarily pause clipboard capture without stopping the poll timer.
   */
  pauseClipboard(): void {
    clipboardWatcher.pause();
  }

  /**
   * Resume clipboard capture after a pause.
   */
  resumeClipboard(): void {
    clipboardWatcher.resume();
  }

  /**
   * Check if clipboard capture is paused.
   */
  isClipboardPaused(): boolean {
    return clipboardWatcher.isPaused();
  }

  // -------------------------------------------------------------------------
  // Private: handle new clipboard content
  // -------------------------------------------------------------------------

  private async handleNewClipboardContent(content: ClipboardContent): Promise<void> {
    try {
      const sourceApp = (await getClipboardSourceApp()) ?? undefined;

      // Use the unified CaptureAdapter to produce a CaptureRecord
      let captureRecord: CaptureRecord;
      let imageFilePath = '';  // track image file path for AssetFile creation
      if (content.type === 'text' && content.text) {
        captureRecord = captureRegistry.capture({
          sourceType: 'clipboard_text',
          text: content.text,
          sourceApp,
          contentHash: content.contentHash,
        });
      } else if (content.type === 'image' && content.image) {
        // For clipboard images, save to file first, then use image adapter
        const storageRoot = settings.getStorageRoot();
        const imageId = randomUUID();
        const dateDir = new Date().toISOString().slice(0, 10);
        const sourcesDir = path.join(storageRoot, 'sources', dateDir);
        mkdirSync(sourcesDir, { recursive: true });
        imageFilePath = path.join(sourcesDir, `${imageId}.png`);
        const pngBuffer = content.image.toPNG();
        writeFileSync(imageFilePath, pngBuffer);

        captureRecord = captureRegistry.capture({
          sourceType: 'image',
          filePath: imageFilePath,
          sourceApp,
        });
      } else {
        logger.warn('app', 'captureService', 'handleNewContent', 'Unsupported clipboard content type', {
          type: content.type,
        });
        return;
      }

      // Content-level dedup: check if a SourceItem with the same originalId already exists
      const existingItem = storage.getSourceItems({}).find(
        (item) => item.originalId === captureRecord.original_id,
      );
      if (existingItem) {
        logger.info('app', 'captureService', 'handleNewContent', 'Duplicate clipboard content skipped (SourceItem exists)', {
          originalId: captureRecord.original_id,
          existingItemId: existingItem.id,
        });
        return;
      }

      // Create SourceItem via the unified bridge (clipboard → sourceItems)
      const sourceItem = this.captureRecordToSourceItem(captureRecord);

      // Also create a ClipboardItem for the Clipboard history page
      const rawText = content.type === 'text' ? (content.text || '') : '';
      const isUrl = content.type === 'text' && /^https?:\/\/[^\s]+$/i.test(rawText.trim());
      const clipboardContentType: ClipboardContentType = content.type === 'image' ? 'image' : isUrl ? 'url' : 'text';

      // For image items, create an AssetFile so the file path is preserved
      const now = Math.floor(Date.now() / 1000);
      let clipboardAssetFileIds: string[] | undefined;
      if (content.type === 'image' && content.image && imageFilePath) {
        const assetFile: AssetFile = {
          id: randomUUID(),
          kind: 'image',
          originalName: path.basename(imageFilePath),
          localPath: imageFilePath,
          createdAt: now * 1000,
        };
        storage.insertAssetFile(assetFile);
        clipboardAssetFileIds = [assetFile.id];
      }

      const clipboardItem: ClipboardItem = {
        id: randomUUID(),
        contentType: clipboardContentType,
        text: content.type === 'text' ? rawText : undefined,
        assetFileIds: clipboardAssetFileIds,
        sourceApp,
        isPinned: false,
        createdAt: now * 1000,
      };
      storage.insertClipboardItem(clipboardItem);

      // Notify renderer of changes
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.CLIPBOARD_ITEMS_CHANGED, { timestamp: now });
        }
      }

      logger.info('app', 'captureService', 'handleNewContent', `Clipboard ${content.type} → SourceItem + ClipboardItem`, {
        sourceItemId: sourceItem.id,
        clipboardItemId: clipboardItem.id,
        originalId: captureRecord.original_id,
        sourceApp,
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'captureService', 'handleNewContent', 'Failed to process clipboard content', {
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'clipboard_capture',
        outputId: content.contentHash,
        error,
        userMessage: '剪贴板内容捕获失败，请稍后重试。',
      });
    }
  }

  // -------------------------------------------------------------------------
  // File import and URL save
  // -------------------------------------------------------------------------

  /**
   * Import a file as a SourceItem.
   * Copies the file into the storage sources directory and creates a SourceItem record.
   */
  async importFile(filePath: string): Promise<SourceItem> {
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }

    const stat = statSync(filePath);
    const fileName = path.basename(filePath);
    const ext = path.extname(filePath).toLowerCase();

    // Simple MIME type detection based on extension
    const mimeType = this.getMimeType(ext);

    const id = randomUUID();
    const now = Math.floor(Date.now() / 1000);
    const storageRoot = settings.getStorageRoot();
    const dateDir = new Date().toISOString().slice(0, 10);
    const sourcesDir = path.join(storageRoot, 'sources', dateDir);
    mkdirSync(sourcesDir, { recursive: true });

    const contentPath = path.join(sourcesDir, `${id}${ext}`);
    copyFileSync(filePath, contentPath);

    const fileSize = stat.size;
    const fileSizeStr = fileSize > 1024 * 1024
      ? `${(fileSize / (1024 * 1024)).toFixed(1)} MB`
      : `${(fileSize / 1024).toFixed(1)} KB`;

    const sourceItem: SourceItem = {
      id,
      type: 'file',
      source: 'file_import',
      contentPath,
      title: fileName,
      previewText: `${fileName} (${fileSizeStr})`,
      sourceApp: 'AcMind',
      createdAt: now,
      status: 'inbox',
      metadata: {
        fileSize,
        mimeType,
        originalFileName: fileName,
      },
    };

    storage.insertSourceItem(sourceItem);
    this.emitRecordsChanged({ action: 'created', id, timestamp: now });

    logger.info('app', 'captureService', 'importFile', 'File imported as SourceItem', {
      id,
      filePath,
      fileName,
      fileSize,
      mimeType,
    });

    return sourceItem;
  }

  /**
   * Save a URL as a SourceItem.
   * Creates a SourceItem with type='webpage' and source='url_paste'.
   */
  async saveUrl(url: string): Promise<SourceItem> {
    const trimmed = url.trim();
    if (!trimmed || !/^https?:\/\/[^\s]+$/i.test(trimmed)) {
      throw new Error(`Invalid URL: ${trimmed}`);
    }

    const id = randomUUID();
    const now = Math.floor(Date.now() / 1000);
    const storageRoot = settings.getStorageRoot();
    const dateDir = new Date().toISOString().slice(0, 10);
    const sourcesDir = path.join(storageRoot, 'sources', dateDir);
    mkdirSync(sourcesDir, { recursive: true });

    // Save URL to a text file
    const contentPath = path.join(sourcesDir, `${id}.txt`);
    writeFileSync(contentPath, trimmed, 'utf8');

    // Extract domain for title
    let title = trimmed;
    try {
      const parsed = new URL(trimmed);
      title = parsed.hostname;
    } catch {
      // Use raw URL as title if parsing fails
    }

    const sourceItem: SourceItem = {
      id,
      type: 'webpage',
      source: 'url_paste',
      contentPath,
      title,
      previewText: trimmed,
      originalUrl: trimmed,
      sourceApp: 'AcMind',
      createdAt: now,
      status: 'inbox',
    };

    storage.insertSourceItem(sourceItem);
    this.emitRecordsChanged({ action: 'created', id, timestamp: now });

    logger.info('app', 'captureService', 'saveUrl', 'URL saved as SourceItem', {
      id,
      url: trimmed,
      title,
    });

    return sourceItem;
  }

  /**
   * Simple MIME type detection based on file extension.
   */
  private getMimeType(ext: string): string {
    const mimeMap: Record<string, string> = {
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      '.md': 'text/markdown',
      '.csv': 'text/csv',
      '.json': 'application/json',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
      '.mp3': 'audio/mpeg',
      '.mp4': 'video/mp4',
      '.wav': 'audio/wav',
      '.zip': 'application/zip',
    };
    return mimeMap[ext] || 'application/octet-stream';
  }

  // -------------------------------------------------------------------------
  // Private: emit records.changed event to all renderer windows
  // -------------------------------------------------------------------------

  private emitRecordsChanged(event: RecordsChangedEvent): void {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed() && win.webContents && !win.webContents.isDestroyed()) {
        win.webContents.send(RECORDS_CHANGED_CHANNEL, event);
      }
    }
  }

  private emitPinPoolChanged(action: 'created' | 'updated' | 'deleted', id: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed() && win.webContents && !win.webContents.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.PIN_POOL_CHANGED, { action, id, timestamp });
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const captureService = new CaptureService();
