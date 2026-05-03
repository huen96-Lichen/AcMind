// AcMind Voice Watch Service
// Phase 10: 监听本地/iCloud文件夹，自动导入新增音频文件
//
// 职责：
// 1. 监听配置的文件夹新增音频文件
// 2. 延迟处理（等待 iCloud 同步完成）
// 3. 文件去重（file_fingerprint）
// 4. 通过 captureService 创建 audio CaptureRecord → SourceItem + CaptureItem
// 5. 提交转写任务

import { watch, type FSWatcher, statSync, existsSync, readdirSync } from 'node:fs';
import path from 'node:path';
import type { AppSettings } from '../../../shared/types';
import { settings } from '../../settings';
import { logger } from '../../logger';
import { audioTranscriptionService } from './audioTranscriptionService';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PendingFile {
  filePath: string;
  fileName: string;
  detectedAt: number;
  timer: ReturnType<typeof setTimeout>;
}

interface ImportedFileRecord {
  filePath: string;
  fileSize: number;
  mtimeMs: number;
  importedAt: number;
}

export type VoiceWatchStatus = 'stopped' | 'watching' | 'error';

export interface VoiceWatchState {
  status: VoiceWatchStatus;
  watchPath: string | null;
  error: string | null;
  importedCount: number;
  pendingCount: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const SUPPORTED_EXTENSIONS = new Set(['.m4a', '.mp3', '.wav', '.aac', '.flac', '.ogg', '.webm']);

// ---------------------------------------------------------------------------
// VoiceWatchService
// ---------------------------------------------------------------------------

class VoiceWatchService {
  private watcher: FSWatcher | null = null;
  private pendingFiles = new Map<string, PendingFile>();
  private importedFiles = new Map<string, ImportedFileRecord>();
  private status: VoiceWatchStatus = 'stopped';
  private watchPath: string | null = null;
  private error: string | null = null;
  private importedCount = 0;
  private initialized = false;
  // Lazy reference to captureService to avoid circular dependency
  private _captureService: { captureAudio(filePath: string, title?: string): { id: string; captureItemId?: string } } | null = null;

  /**
   * Set the captureService reference (called from captureService.init)
   */
  setCaptureService(cs: { captureAudio(filePath: string, title?: string): { id: string; captureItemId?: string } }): void {
    this._captureService = cs;
  }

  /**
   * 初始化：从设置中恢复监听状态
   */
  init(): void {
    if (this.initialized) return;
    this.initialized = true;

    const currentSettings = settings.load();
    if (currentSettings.voiceWatchEnabled && currentSettings.voiceWatchFolderPath) {
      this.startWatching(currentSettings.voiceWatchFolderPath);
    }

    logger.info('app', 'voiceWatchService', 'init', 'Voice watch service initialized', {
      enabled: currentSettings.voiceWatchEnabled,
      watchPath: currentSettings.voiceWatchFolderPath,
    });
  }

  /**
   * 停止服务
   */
  stop(): void {
    this.stopWatching();
    this.initialized = false;
    logger.info('app', 'voiceWatchService', 'stop', 'Voice watch service stopped');
  }

  /**
   * 获取当前监听状态
   */
  getState(): VoiceWatchState {
    return {
      status: this.status,
      watchPath: this.watchPath,
      error: this.error,
      importedCount: this.importedCount,
      pendingCount: this.pendingFiles.size,
    };
  }

  /**
   * 开始监听文件夹
   */
  startWatching(folderPath: string): { success: boolean; error?: string } {
    // 停止现有监听
    this.stopWatching();

    // 校验文件夹
    if (!existsSync(folderPath)) {
      this.status = 'error';
      this.error = `文件夹不存在: ${folderPath}`;
      logger.warn('error', 'voiceWatchService', 'startWatching', 'Folder does not exist', { folderPath });
      return { success: false, error: this.error };
    }

    try {
      readdirSync(folderPath);
    } catch (err) {
      this.status = 'error';
      this.error = `文件夹不可读: ${folderPath}`;
      logger.warn('error', 'voiceWatchService', 'startWatching', 'Folder not readable', { folderPath, error: String(err) });
      return { success: false, error: this.error };
    }

    try {
      this.watcher = watch(folderPath, { persistent: false }, (eventType, filename) => {
        if (eventType === 'rename' && filename) {
          this.handleNewFile(folderPath, filename);
        }
      });

      this.watcher.on('error', (err) => {
        this.status = 'error';
        this.error = `监听异常: ${err.message}`;
        logger.error('error', 'voiceWatchService', 'watcher', 'Watcher error', { error: err.message });
      });

      this.watchPath = folderPath;
      this.status = 'watching';
      this.error = null;

      logger.info('app', 'voiceWatchService', 'startWatching', 'Started watching folder', { folderPath });
      return { success: true };
    } catch (err) {
      this.status = 'error';
      this.error = `启动监听失败: ${err instanceof Error ? err.message : String(err)}`;
      logger.error('error', 'voiceWatchService', 'startWatching', 'Failed to start watcher', { error: this.error });
      return { success: false, error: this.error };
    }
  }

  /**
   * 停止监听
   */
  stopWatching(): void {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }

    // 清理所有待处理的定时器
    for (const pending of this.pendingFiles.values()) {
      clearTimeout(pending.timer);
    }
    this.pendingFiles.clear();

    this.status = 'stopped';
    this.watchPath = null;
    this.error = null;
  }

  /**
   * 手动导入音频文件
   */
  async importAudioFile(
    filePath: string,
    title?: string,
  ): Promise<{ success: boolean; originalId?: string; captureItemId?: string; error?: string }> {
    return this.doImport(filePath, 'manual', title);
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  /**
   * 处理文件夹中的新文件事件
   */
  private handleNewFile(folderPath: string, filename: string): void {
    const filePath = path.join(folderPath, filename);
    const ext = path.extname(filename).toLowerCase();

    // 只处理支持的音频格式
    if (!SUPPORTED_EXTENSIONS.has(ext)) {
      return;
    }

    // Phase 10: voiceAutoImportEnabled 控制是否自动导入
    // 当关闭时，仅记录检测到的文件但不自动导入
    const currentSettings = settings.load();
    if (!currentSettings.voiceAutoImportEnabled) {
      logger.info('app', 'voiceWatchService', 'handleNewFile', 'Auto-import disabled, skipping', {
        filePath,
      });
      return;
    }

    // 检查是否已在待处理队列中
    if (this.pendingFiles.has(filePath)) {
      return;
    }

    // 检查是否已导入过
    if (currentSettings.voiceDedupEnabled && this.isAlreadyImported(filePath)) {
      logger.debug('app', 'voiceWatchService', 'handleNewFile', 'Skipping duplicate file', { filePath });
      return;
    }

    // 延迟处理，等待 iCloud 同步完成
    const delayMs = currentSettings.voiceImportDelayMs ?? 3000;
    const timer = setTimeout(() => {
      this.processPendingFile(filePath);
    }, delayMs);

    this.pendingFiles.set(filePath, {
      filePath,
      fileName: filename,
      detectedAt: Date.now(),
      timer,
    });

    logger.debug('app', 'voiceWatchService', 'handleNewFile', 'New audio file detected, pending import', {
      filePath,
      delayMs,
    });
  }

  /**
   * 处理延迟后的待导入文件
   */
  private async processPendingFile(filePath: string): Promise<void> {
    const pending = this.pendingFiles.get(filePath);
    if (!pending) return;

    this.pendingFiles.delete(filePath);

    // 检查文件是否仍然存在
    if (!existsSync(filePath)) {
      logger.debug('app', 'voiceWatchService', 'processPendingFile', 'File disappeared before import', { filePath });
      return;
    }

    // 检查文件是否可读且大小稳定
    try {
      const stats1 = statSync(filePath);
      if (stats1.size === 0) {
        logger.debug('app', 'voiceWatchService', 'processPendingFile', 'File is empty, skipping', { filePath });
        return;
      }

      // 等待一小段时间后再次检查文件大小是否稳定（iCloud 同步中）
      await new Promise((resolve) => setTimeout(resolve, 1000));
      if (!existsSync(filePath)) return;
      const stats2 = statSync(filePath);
      if (stats1.size !== stats2.size) {
        // 文件大小还在变化，重新排队
        const delayMs = settings.load().voiceImportDelayMs ?? 3000;
        const timer = setTimeout(() => {
          this.processPendingFile(filePath);
        }, delayMs);
        this.pendingFiles.set(filePath, { ...pending, timer });
        logger.debug('app', 'voiceWatchService', 'processPendingFile', 'File size still changing, re-queuing', { filePath });
        return;
      }
    } catch (err) {
      logger.warn('error', 'voiceWatchService', 'processPendingFile', 'Cannot stat file', { filePath, error: String(err) });
      return;
    }

    // 执行导入
    const result = await this.doImport(filePath, 'watch_folder');
    if (result.success) {
      logger.info('app', 'voiceWatchService', 'processPendingFile', 'Auto-imported audio from watch folder', {
        filePath,
        originalId: result.originalId,
      });
    } else {
      logger.warn('error', 'voiceWatchService', 'processPendingFile', 'Failed to auto-import audio', {
        filePath,
        error: result.error,
      });
    }
  }

  /**
   * 执行音频文件导入的核心逻辑
   */
  private async doImport(
    filePath: string,
    importedFrom: 'manual' | 'watch_folder',
    title?: string,
  ): Promise<{ success: boolean; originalId?: string; captureItemId?: string; error?: string }> {
    // 校验文件
    if (!existsSync(filePath)) {
      return { success: false, error: '文件不存在' };
    }

    const ext = path.extname(filePath).toLowerCase();
    if (!SUPPORTED_EXTENSIONS.has(ext)) {
      return { success: false, error: `不支持的音频格式: ${ext}` };
    }

    let fileSize: number;
    try {
      const stats = statSync(filePath);
      fileSize = stats.size;
      if (fileSize === 0) {
        return { success: false, error: '文件为空' };
      }
    } catch (err) {
      return { success: false, error: `无法读取文件: ${err instanceof Error ? err.message : String(err)}` };
    }

    // 去重检查
    const currentSettings = settings.load();
    const fingerprint = `${filePath}:${fileSize}`;
    if (currentSettings.voiceDedupEnabled && importedFrom === 'watch_folder') {
      if (this.importedFiles.has(fingerprint)) {
        logger.debug('app', 'voiceWatchService', 'doImport', 'Duplicate file skipped', { filePath, fingerprint });
        return { success: false, error: '文件已导入过' };
      }
    }

    // 通过 captureService 创建记录
    if (!this._captureService) {
      return { success: false, error: 'captureService 未初始化' };
    }

    try {
      const sourceItem = this._captureService.captureAudio(
        filePath,
        title || path.basename(filePath, ext),
      );

      // 记录已导入
      this.importedFiles.set(fingerprint, {
        filePath,
        fileSize,
        mtimeMs: Date.now(),
        importedAt: Date.now(),
      });
      this.importedCount++;

      // 提交转写任务（使用 captureItemId）
      const captureItemId = (sourceItem as Record<string, unknown>).captureItemId as string | undefined;
      if (captureItemId) {
        const transcriptionResult = await audioTranscriptionService.submitTranscriptionJob(captureItemId, filePath);
        if (!transcriptionResult.success) {
          logger.warn('error', 'voiceWatchService', 'doImport', 'Transcription job submission failed', {
            captureItemId,
            error: transcriptionResult.error,
          });
        }
      }

      return { success: true, originalId: sourceItem.id, captureItemId: sourceItem.captureItemId };
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      logger.error('error', 'voiceWatchService', 'doImport', 'Failed to import audio', { filePath, error: errorMsg });
      return { success: false, error: errorMsg };
    }
  }

  /**
   * 检查文件是否已导入（基于文件路径和大小的简单指纹）
   */
  private isAlreadyImported(filePath: string): boolean {
    try {
      const stats = statSync(filePath);
      const fingerprint = `${filePath}:${stats.size}`;
      return this.importedFiles.has(fingerprint);
    } catch {
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const voiceWatchService = new VoiceWatchService();
