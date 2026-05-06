import { randomUUID } from 'node:crypto';
import { mkdirSync, writeFileSync, unlinkSync, existsSync } from 'node:fs';
import path from 'node:path';
import { ipcMain, shell, dialog, BrowserWindow, clipboard, Notification } from 'electron';
import type {
  AppSettings,
  StorageStats,
  LogLevel,
  SourceItemListFilter,
  AiOperation,
  AiTier,
  DistilledOutput,
  ExportRecord,
  VaultConfig,
  PermissionCheckSource,
  PermissionSettingsTarget,
  PermissionStatusSnapshot,
  CaptureItem,
  CaptureItemListFilter,
  SourceItem,
  KnowledgeCard,
  KnowledgeEdge,
  DatasetSnapshot,
  TrainingRun,
  EvalRun,
  ModelVersion,
  ShelfItem,
  AIAction,
  SourceType,
  AiTaskStatus,
  PinnedImage,
  OcrResult,
  AssetFile,
  ProcessJob,
} from '../shared/types';
import { IPC_CHANNELS } from '../shared/types';
import type { HybridSearchOptions, SearchResult } from './services/search/types';
import { keywordSearch, embeddingService, vectorSearch } from './services/search';
import { documentImporter } from './services/parser';
import type { ImportResult } from './services/parser/types';
import { schedulerService } from './services/scheduler';
import type { CreateTaskParams, TaskExecutionResult } from './services/scheduler/types';
import { outputSpecService } from './services/outputSpec';
import { contentPipeline } from './services/pipeline';
import { contentStateMachine } from './services/pipeline';
import { inferFileKind } from '../shared/fileUtils';
import { storage } from './storage';
import { settings, resolveStorageRoot } from './settings';
import { DEFAULT_SETTINGS } from '../shared/defaultSettings';
import { logger } from './logger';
import { captureService } from './captureService';
import { aiActionRunner } from './services/aiHub/aiActionRunner';
import { aiProviderService } from './services/aiHub/aiProviderService';
import { vaultScanner } from './services/importer/vaultScanner';
import { voiceDictionaryStore } from './voice/dictionary';
import { asrProvider } from './voice/asr';
import { getRecorderAvailability } from './voice/recorder';
import { dictationCoordinator } from './voice/coordinator';
import { getDictationHistoryStore } from './voice/history';
import { clipboardWatcher } from './clipboardWatcher';
import { captureRegistry } from './services/capture';
import type { CaptureInput } from './services/capture';
import { errorService } from './errorService';
import type { PermissionCoordinator } from './permissionCoordinator';
import { voiceWatchService } from './services/capture/voiceWatchService';
import { audioTranscriptionService } from './services/capture/audioTranscriptionService';
import { pinnedImageController } from './pinnedImageController';
import { ocrService } from './ocrService';
import { shortcutManager } from './shortcutManager';

// ---------------------------------------------------------------------------
// IPC handler registration
// ---------------------------------------------------------------------------

export interface RegisterIpcHandlersDeps {
  permissionCoordinator: PermissionCoordinator;
  capsuleController?: { updateSettings: (settings: import('../shared/capsuleSettings').DesktopMuseCapsuleSettings) => void } | null;
  widgetController?: { show: () => void; hide: () => void; destroy: () => void; isVisible: () => boolean } | null;
}

export async function registerIpcHandlers(deps: RegisterIpcHandlersDeps): Promise<void> {
  /**
   * Helper: safely register a single IPC handler so that one failure
   * does NOT prevent subsequent handlers from being registered.
   */
  function safeHandle(channel: string, handler: Parameters<typeof ipcMain.handle>[1]): void {
    try {
      ipcMain.handle(channel, handler);
    } catch (error) {
      logger.error('error', 'ipc', 'register', `Failed to register IPC handler: ${channel}`, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  function emitRecordsChanged(action: 'created' | 'updated' | 'deleted', id: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.RECORDS_CHANGED, { action, id, timestamp });
      }
    }
  }

  function emitCaptureItemsChanged(action: 'created' | 'updated' | 'deleted', id: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, { action, id, timestamp });
      }
    }
  }

  function mergeProviderLists(...lists: Array<import('../shared/types').ProviderConfig[] | undefined>): import('../shared/types').ProviderConfig[] {
    const merged = new Map<string, import('../shared/types').ProviderConfig>();
    for (const list of lists) {
      for (const provider of list ?? []) {
        merged.set(provider.id, provider);
      }
    }
    return Array.from(merged.values());
  }

  function listProvidersFromAllSources(): import('../shared/types').ProviderConfig[] {
    const currentSettings = settings.load();
    return mergeProviderLists(currentSettings.providers, storage.getProviderConfigs());
  }

  function buildOpenAiCompatibleUrl(baseUrl: string, endpoint: 'chat/completions'): string {
    const normalizedBase = baseUrl.replace(/\/+$/, '');
    const baseWithVersion = normalizedBase.endsWith('/v1') ? normalizedBase : `${normalizedBase}/v1`;
    return `${baseWithVersion}/${endpoint}`;
  }

  function emitProvidersChanged(action: 'created' | 'updated' | 'deleted', id: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.PROVIDERS_CHANGED, { action, id, timestamp });
      }
    }
  }

  // -- Phase 1: settings.get -------------------------------------------------
  safeHandle(IPC_CHANNELS.SETTINGS_GET, async () => {
    return settings.load();
  });

  // -- Phase 1: settings.update ----------------------------------------------
  safeHandle(IPC_CHANNELS.SETTINGS_UPDATE, async (_event, patch: Partial<AppSettings>) => {
    try {
      const updated = settings.update(patch);
      // Sync capsule controller when capsule settings change
      if (patch.capsule && deps.capsuleController) {
        deps.capsuleController.updateSettings(updated.capsule);
      }
      if (patch.screenshotShortcut || patch.dashboardShortcut || patch.dictation) {
        shortcutManager.refresh(updated);
      }
      return updated;
    } catch (error) {
      logger.error('error', 'ipc', 'settings.update', 'Failed to update settings', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 1: app.getVersion -----------------------------------------------
  safeHandle(IPC_CHANNELS.APP_GET_VERSION, async () => {
    try {
      const { readFileSync } = await import('node:fs');
      const { resolve } = await import('node:path');
      const pkgPath = resolve(__dirname, '../../package.json');
      const pkg = JSON.parse(readFileSync(pkgPath, 'utf8')) as { version?: string };
      if (typeof pkg.version === 'string' && pkg.version.trim()) {
        return pkg.version.trim();
      }
    } catch {
      // Fall through
    }
    return '0.1.0';
  });

  // -- Phase 1: app.openStorageRoot ------------------------------------------
  safeHandle(IPC_CHANNELS.APP_OPEN_STORAGE_ROOT, async () => {
    try {
      const storageRoot = settings.getStorageRoot();
      const result = await shell.openPath(storageRoot);
      if (result) {
        throw new Error(result);
      }
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'app.openStorageRoot', 'Failed to open storage root', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 10: app.openPath -----------------------------------------------
  safeHandle(IPC_CHANNELS.APP_OPEN_PATH, async (_event, filePath: string) => {
    try {
      const result = await shell.openPath(filePath);
      if (result) {
        throw new Error(result);
      }
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'app.openPath', 'Failed to open path', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 1: storage.getStats --------------------------------------------
  safeHandle(IPC_CHANNELS.STORAGE_GET_STATS, async () => {
    try {
      return storage.getStorageStats();
    } catch (error) {
      logger.error('error', 'ipc', 'storage.getStats', 'Failed to get storage stats', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 1: logger.getLevel ---------------------------------------------
  safeHandle(IPC_CHANNELS.LOGGER_GET_LEVEL, async () => {
    return logger.getLevel();
  });

  // -- Phase 1: logger.setLevel ---------------------------------------------
  safeHandle(IPC_CHANNELS.LOGGER_SET_LEVEL, async (_event, level: LogLevel) => {
    try {
      logger.setLevel(level);
      return logger.getLevel();
    } catch (error) {
      logger.error('error', 'ipc', 'logger.setLevel', 'Failed to set log level', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: sourceItems.list --------------------------------------------
  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_LIST, async (_event, filter?: SourceItemListFilter) => {
    try {
      return captureService.getSourceItems(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.list', 'Failed to list source items', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: sourceItems.get ---------------------------------------------
  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_GET, async (_event, id: string) => {
    try {
      return captureService.getSourceItem(id);
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.get', 'Failed to get source item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: sourceItems.getContent --------------------------------------
  safeHandle('sourceItems.getContent', async (_event, id: string) => {
    try {
      return captureService.getSourceItemContent(id);
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.getContent', 'Failed to get source item content', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: sourceItems.delete ------------------------------------------
  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_DELETE, async (_event, id: string) => {
    try {
      captureService.deleteSourceItem(id);
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.delete', 'Failed to delete source item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: sourceItems.deleteBatch -----------------------------------
  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_DELETE_BATCH, async (_event, ids: string[]) => {
    const deleted: string[] = [];
    const failed: Array<{ id: string; error: string }> = [];

    try {
      for (const id of ids) {
        try {
          captureService.deleteSourceItem(id);
          deleted.push(id);
        } catch (error) {
          failed.push({
            id,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }
      return { deleted, failed };
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.deleteBatch', 'Failed to delete source items', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: sourceItems.search ------------------------------------------
  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_SEARCH, async (_event, query: string) => {
    try {
      return captureService.searchSourceItems(query);
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.search', 'Failed to search source items', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_CREATE_TEXT, async (_event, text: string) => {
    try {
      return captureService.captureText(text, 'AcMind 布置向导');
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.createText', 'Failed to create text source item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_ENSURE_FROM_CAPTURE, async (_event, captureItemId: string) => {
    try {
      const sourceItem = storage.createSourceItemFromCaptureItem(captureItemId);
      // Pure bridge: do NOT modify CaptureItem status.
      // CaptureItem status changes are managed exclusively by the distill flow.
      emitRecordsChanged('created', sourceItem.id);
      emitCaptureItemsChanged('updated', captureItemId);
      return sourceItem;
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.ensureFromCapture', 'Failed to bridge capture item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_GET_BY_CAPTURE_ITEM_ID, async (_event, captureItemId: string) => {
    try {
      return storage.getSourceItemByCaptureItemId(captureItemId);
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.getByCaptureItemId', 'Failed to get source item by capture item id', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_READ_IMAGE, async (_event, filePath: string) => {
    try {
      const { readFileSync, existsSync, statSync } = await import('node:fs');
      if (!filePath || !existsSync(filePath)) {
        return { ok: false, error: '图片文件不存在' };
      }
      const stat = statSync(filePath);
      if (stat.size > 10 * 1024 * 1024) {
        return { ok: false, error: '图片文件过大（超过 10MB）' };
      }
      const buffer = readFileSync(filePath);
      const base64 = buffer.toString('base64');
      const ext = path.extname(filePath).toLowerCase();
      const mimeMap: Record<string, string> = {
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.svg': 'image/svg+xml',
        '.bmp': 'image/bmp',
      };
      const mimeType = mimeMap[ext] || 'image/png';
      return { ok: true, dataUrl: `data:${mimeType};base64,${base64}` };
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.readImage', 'Failed to read image', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { ok: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_IMPORT_FILE, async (_event, filePath: string) => {
    try {
      const sourceItem = storage.importFileAsSourceItem(filePath);
      emitRecordsChanged('created', sourceItem.id);
      return sourceItem;
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.importFile', 'Failed to import file as source item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_SAVE_URL, async (_event, url: string) => {
    try {
      const sourceItem = storage.saveUrlAsSourceItem(url);
      emitRecordsChanged('created', sourceItem.id);
      return sourceItem;
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.saveUrl', 'Failed to save URL as source item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_UPDATE, async (_event, id: string, patch: Record<string, unknown>) => {
    try {
      storage.updateSourceItem(id, patch as Partial<import('../shared/types').SourceItem>);
      emitRecordsChanged('updated', id);
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.update', 'Failed to update source item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: capture.screenshot ------------------------------------------
  safeHandle('capture.screenshot', async () => {
    try {
      return await captureService.captureScreenshot();
    } catch (error) {
      logger.error('error', 'ipc', 'capture.screenshot', 'Failed to trigger screenshot', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: clipboard.getStatus -----------------------------------------
  safeHandle('clipboard.getStatus', async () => {
    try {
      return captureService.getClipboardStatus();
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.getStatus', 'Failed to get clipboard status', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 2: clipboard.toggle --------------------------------------------
  safeHandle('clipboard.toggle', async (_event, enabled: boolean) => {
    try {
      captureService.toggleClipboard(enabled);
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.toggle', 'Failed to toggle clipboard', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // =========================================================================
  // Phase 3: AI Console Backend
  // =========================================================================

  // -- Phase 3: providers.list ---------------------------------------------
  safeHandle('providers.list', async () => {
    try {
      return listProvidersFromAllSources();
    } catch (error) {
      logger.error('error', 'ipc', 'providers.list', 'Failed to list providers', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: providers.add ----------------------------------------------
  safeHandle('providers.add', async (_event, config: import('../shared/types').ProviderConfig) => {
    try {
      storage.upsertProviderConfig(config);
      const providers = mergeProviderLists(listProvidersFromAllSources(), [config]);
      settings.update({ providers });
      emitProvidersChanged('created', config.id);
      return config;
    } catch (error) {
      logger.error('error', 'ipc', 'providers.add', 'Failed to add provider', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: providers.update -------------------------------------------
  safeHandle('providers.update', async (_event, id: string, patch: Partial<import('../shared/types').ProviderConfig>) => {
    try {
      const currentProviders = listProvidersFromAllSources();
      const existing = currentProviders.find((p) => p.id === id);
      if (!existing) {
        throw new Error(`ProviderConfig not found: ${id}`);
      }
      const updated = { ...existing, ...patch, id };
      storage.upsertProviderConfig(updated);
      const providers = mergeProviderLists(currentProviders, storage.getProviderConfigs(), [updated]);
      settings.update({ providers });
      emitProvidersChanged('updated', id);
      return updated;
    } catch (error) {
      logger.error('error', 'ipc', 'providers.update', 'Failed to update provider', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: providers.delete -------------------------------------------
  safeHandle('providers.delete', async (_event, id: string) => {
    try {
      try {
        storage.deleteProviderConfig(id);
      } catch (deleteError) {
        logger.warn('ai', 'ipc', 'providers.delete', 'Provider was not present in provider_configs; removing from settings only', {
          id,
          error: deleteError instanceof Error ? deleteError.message : String(deleteError),
        });
      }
      settings.update({ providers: listProvidersFromAllSources().filter((provider) => provider.id !== id) });
      emitProvidersChanged('deleted', id);
    } catch (error) {
      logger.error('error', 'ipc', 'providers.delete', 'Failed to delete provider', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: providers.scanLocal ----------------------------------------
  safeHandle('providers.scanLocal', async () => {
    try {
      // Scan Ollama /api/tags for locally available models
      const currentSettings = settings.load();
      const ollamaBaseUrl = currentSettings.providers?.[0]?.baseUrl || 'http://localhost:11434';

      try {
        const response = await fetch(`${ollamaBaseUrl}/api/tags`, {
          signal: AbortSignal.timeout(5000),
        });
        if (!response.ok) {
          throw new Error(`Ollama returned HTTP ${response.status}`);
        }
        const data = (await response.json()) as { models?: Array<{ name: string; size?: number; modified_at?: string }> };
        const models = (data.models ?? []).map((m) => ({
          name: m.name,
          size: m.size ?? 0,
          modifiedAt: m.modified_at ?? '',
        }));
        logger.info('ai', 'ipc', 'providers.scanLocal', `Found ${models.length} local models`);
        return models;
      } catch (scanError) {
        logger.warn('ai', 'ipc', 'providers.scanLocal', 'Ollama scan failed', {
          error: scanError instanceof Error ? scanError.message : String(scanError),
        });
        return [];
      }
    } catch (error) {
      logger.error('error', 'ipc', 'providers.scanLocal', 'Failed to scan local models', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: providers.testConnection -----------------------------------
  safeHandle('providers.testConnection', async (_event, id: string) => {
    try {
      const providers = listProvidersFromAllSources();
      const provider = providers.find((p) => p.id === id);
      if (!provider) {
        throw new Error(`ProviderConfig not found: ${id}`);
      }

      const startedAt = Date.now();
      try {
        if (provider.type === 'ollama') {
          // Test Ollama connection
          const response = await fetch(`${provider.baseUrl}/api/tags`, {
            signal: AbortSignal.timeout(5000),
          });
          const latencyMs = Date.now() - startedAt;
          if (!response.ok) {
            return { ok: false, latencyMs, error: `HTTP ${response.status}` };
          }
          return { ok: true, latencyMs };
        } else {
          // Test the same chat-completions path used by real distillation.
          const headers: Record<string, string> = {
            'Content-Type': 'application/json',
          };
          if (provider.apiKey) {
            headers['Authorization'] = `Bearer ${provider.apiKey}`;
          }
          const response = await fetch(buildOpenAiCompatibleUrl(provider.baseUrl, 'chat/completions'), {
            method: 'POST',
            headers,
            body: JSON.stringify({
              model: provider.modelId,
              messages: [{ role: 'user', content: 'ping' }],
              max_tokens: 1,
              temperature: 0,
            }),
            signal: AbortSignal.timeout(10000),
          });
          const latencyMs = Date.now() - startedAt;
          if (!response.ok) {
            const body = await response.text().catch(() => '');
            return { ok: false, latencyMs, error: `HTTP ${response.status}${body ? `: ${body}` : ''}` };
          }
          return { ok: true, latencyMs };
        }
      } catch (connError) {
        const latencyMs = Date.now() - startedAt;
        return {
          ok: false,
          latencyMs,
          error: connError instanceof Error ? connError.message : String(connError),
        };
      }
    } catch (error) {
      logger.error('error', 'ipc', 'providers.testConnection', 'Failed to test connection', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: aiTasks.list -----------------------------------------------
  safeHandle('aiTasks.list', async (_event, filter?: { status?: string; sourceItemId?: string; limit?: number }) => {
    try {
      return storage.getAiTasks(filter as any);
    } catch (error) {
      logger.error('error', 'ipc', 'aiTasks.list', 'Failed to list AI tasks', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: aiTasks.cancel ---------------------------------------------
  safeHandle('aiTasks.cancel', async (_event, id: string) => {
    try {
      const { taskQueue } = await import('./services/aiHub/taskQueue');
      const success = taskQueue.cancel(id);
      if (success) {
        storage.updateAiTask(id, { status: 'cancelled' });
      }
      return success;
    } catch (error) {
      logger.error('error', 'ipc', 'aiTasks.cancel', 'Failed to cancel task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: aiTasks.retry ----------------------------------------------
  safeHandle('aiTasks.retry', async (_event, id: string) => {
    try {
      const { taskQueue } = await import('./services/aiHub/taskQueue');
      const success = taskQueue.retry(id);
      if (success) {
        storage.updateAiTask(id, { status: 'queued', error: undefined });
      }
      return storage.getAiTask(id);
    } catch (error) {
      logger.error('error', 'ipc', 'aiTasks.retry', 'Failed to retry task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: aiTasks.pause ---------------------------------------------
  safeHandle('aiTasks.pause', async () => {
    try {
      const { taskQueue } = await import('./services/aiHub/taskQueue');
      return taskQueue.pause();
    } catch (error) {
      logger.error('error', 'ipc', 'aiTasks.pause', 'Failed to pause task queue', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: aiTasks.resume --------------------------------------------
  safeHandle('aiTasks.resume', async () => {
    try {
      const { taskQueue } = await import('./services/aiHub/taskQueue');
      return taskQueue.resume();
    } catch (error) {
      logger.error('error', 'ipc', 'aiTasks.resume', 'Failed to resume task queue', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: aiTasks.isPaused ------------------------------------------
  safeHandle('aiTasks.isPaused', async () => {
    try {
      const { taskQueue } = await import('./services/aiHub/taskQueue');
      return taskQueue.isPaused();
    } catch (error) {
      logger.error('error', 'ipc', 'aiTasks.isPaused', 'Failed to get task queue state', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: distill.run ------------------------------------------------
  safeHandle('distill.run', async (_event, sourceItemIds: string[], operations: AiOperation[], tier?: AiTier) => {
    try {
      const { distillPipeline } = await import('./services/distiller/distillPipeline');
      return distillPipeline.distillBatch(sourceItemIds, operations, tier);
    } catch (error) {
      logger.error('error', 'ipc', 'distill.run', 'Failed to run batch distillation', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: distill.runSingle ------------------------------------------
  safeHandle('distill.runSingle', async (_event, sourceItemId: string, operation: AiOperation, tier?: AiTier) => {
    try {
      const { distillPipeline } = await import('./services/distiller/distillPipeline');
      return distillPipeline.distill(sourceItemId, operation, tier);
    } catch (error) {
      logger.error('error', 'ipc', 'distill.runSingle', 'Failed to run single distillation', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: distill.update ---------------------------------------------
  safeHandle('distill.update', async (_event, id: string, patch: Partial<DistilledOutput>) => {
    try {
      const updated = storage.updateDistilledOutput(id, patch);
      if (!updated) {
        throw new Error(`DistilledOutput not found: ${id}`);
      }
      return updated;
    } catch (error) {
      logger.error('error', 'ipc', 'distill.update', 'Failed to update distilled output', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: distill.listPending ----------------------------------------
  safeHandle('distill.listPending', async (_event, filter?: { sourceItemId?: string; limit?: number }) => {
    try {
      return storage.getDistilledOutputs(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'distill.listPending', 'Failed to list pending distilled outputs', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: distill.accept ---------------------------------------------
  safeHandle('distill.accept', async (_event, id: string) => {
    try {
      const result = storage.reviewDistilledOutput(id, 'approve');
      emitRecordsChanged('updated', result.output.id);
      return result.output;
    } catch (error) {
      logger.error('error', 'ipc', 'distill.accept', 'Failed to accept distilled output', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: distill.reject ---------------------------------------------
  safeHandle('distill.reject', async (_event, id: string) => {
    try {
      const result = storage.reviewDistilledOutput(id, 'discard');
      emitRecordsChanged('updated', result.output.id);
      return result.output;
    } catch (error) {
      logger.error('error', 'ipc', 'distill.reject', 'Failed to reject distilled output', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: logger.read ------------------------------------------------
  safeHandle('logger.read', async (_event, channel: string, limit?: number) => {
    try {
      const { readFileSync } = await import('node:fs');
      const { resolve } = await import('node:path');
      const currentSettings = settings.load();
      const logDir = resolve(currentSettings.storageRoot, 'logs');
      const logFile = resolve(logDir, `${channel}.log`);

      try {
        const content = readFileSync(logFile, 'utf8');
        const lines = content.trim().split('\n').filter(Boolean);
        const effectiveLimit = limit ?? 100;
        return lines.slice(-effectiveLimit);
      } catch {
        return [];
      }
    } catch (error) {
      logger.error('error', 'ipc', 'logger.read', 'Failed to read logs', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // =========================================================================
  // Phase 4: Real Distiller - Batch Processing
  // =========================================================================

  // -- Phase 4: distill.batch ----------------------------------------------
  safeHandle('distill.batch', async (_event, sourceItemIds: string[], operations: AiOperation[], tier?: AiTier) => {
    try {
      const { distillPipeline } = await import('./services/distiller/distillPipeline');
      const result = await distillPipeline.distillBatchAsync(sourceItemIds, operations, tier);
      return result.batchId;
    } catch (error) {
      logger.error('error', 'ipc', 'distill.batch', 'Failed to start batch distillation', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 4: distill.batchStatus ----------------------------------------
  safeHandle('distill.batchStatus', async (_event, batchId: string) => {
    try {
      const { distillPipeline } = await import('./services/distiller/distillPipeline');
      const status = distillPipeline.getBatchStatus(batchId);
      if (!status) {
        throw new Error(`Batch not found: ${batchId}`);
      }
      return status;
    } catch (error) {
      logger.error('error', 'ipc', 'distill.batchStatus', 'Failed to get batch status', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 4: distill.batchCancel ----------------------------------------
  safeHandle('distill.batchCancel', async (_event, batchId: string) => {
    try {
      const { distillPipeline } = await import('./services/distiller/distillPipeline');
      return distillPipeline.cancelBatch(batchId);
    } catch (error) {
      logger.error('error', 'ipc', 'distill.batchCancel', 'Failed to cancel batch', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 4: distilledOutputs.list --------------------------------------
  safeHandle('distilledOutputs.list', async (_event, filter?: { sourceItemId?: string; reviewStatus?: string; limit?: number }) => {
    try {
      return storage.getDistilledOutputs(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'distilledOutputs.list', 'Failed to list distilled outputs', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 4: distilledOutputs.review ------------------------------------
  safeHandle('distilledOutputs.review', async (_event, id: string, action: string, data?: Record<string, unknown>) => {
    try {
      if (action !== 'approve' && action !== 'edit' && action !== 'discard') {
        throw new Error(`Unknown review action: ${action}`);
      }

      const output = storage.getDistilledOutputs({}).find((o) => o.id === id);
      if (!output) {
        throw new Error(`DistilledOutput not found: ${id}`);
      }

      const result = storage.reviewDistilledOutput(
        id,
        action,
        action === 'edit'
          ? {
              suggestedTitle: (data?.suggestedTitle as string | undefined) ?? output.suggestedTitle,
              summary: (data?.summary as string | undefined) ?? output.summary,
              category: (data?.category as string | undefined) ?? output.category,
              tags: (data?.tags as string[] | undefined) ?? output.tags,
              documentType: (data?.documentType as DistilledOutput['documentType'] | undefined) ?? output.documentType,
              contentMarkdown: (data?.contentMarkdown as string | undefined) ?? output.contentMarkdown,
              valueScore: (data?.valueScore as number | undefined) ?? output.valueScore,
              cleanSuggestion: (data?.cleanSuggestion as DistilledOutput['cleanSuggestion'] | undefined) ?? output.cleanSuggestion,
            }
          : undefined,
      );

      logger.info('ai', 'ipc', 'distilledOutputs.review', `${action} distilled output: ${id}`);
      emitRecordsChanged('updated', result.output.id);
      return result.output;
    } catch (error) {
      logger.error('error', 'ipc', 'distilledOutputs.review', 'Failed to review distilled output', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // =========================================================================
  // Phase 5: Obsidian Exporter - Vault Configuration
  // =========================================================================

  // -- Phase 5: vault.getConfig --------------------------------------------
  safeHandle('vault.getConfig', async () => {
    try {
      return storage.getVaultConfig();
    } catch (error) {
      logger.error('error', 'ipc', 'vault.getConfig', 'Failed to get vault config', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: vault.updateConfig -----------------------------------------
  safeHandle('vault.updateConfig', async (_event, config: Partial<VaultConfig>) => {
    try {
      storage.updateVaultConfig(config);
      return storage.getVaultConfig();
    } catch (error) {
      logger.error('error', 'ipc', 'vault.updateConfig', 'Failed to update vault config', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: vault.validatePath -----------------------------------------
  safeHandle('vault.validatePath', async (_event, vaultPath: string) => {
    try {
      const { existsSync, statSync } = await import('node:fs');
      const { resolve } = await import('node:path');

      if (!vaultPath || !vaultPath.trim()) {
        return { valid: false, message: 'Vault path cannot be empty' };
      }

      const resolvedPath = resolve(vaultPath);

      if (!existsSync(resolvedPath)) {
        return { valid: false, message: `Path does not exist: ${vaultPath}` };
      }

      const stat = statSync(resolvedPath);
      if (!stat.isDirectory()) {
        return { valid: false, message: `Path is not a directory: ${vaultPath}` };
      }

      // Check for .obsidian folder (heuristic for Obsidian vault)
      const { existsSync: exists } = await import('node:fs');
      const hasObsidianFolder = exists(resolve(resolvedPath, '.obsidian'));

      return {
        valid: true,
        message: hasObsidianFolder
          ? 'Valid Obsidian vault detected'
          : 'Directory exists but no .obsidian folder found. It may still be a valid vault.',
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      return { valid: false, message: `Validation error: ${msg}` };
    }
  });

  // -- Phase 5: vault.pickFolder -------------------------------------------
  safeHandle('vault.pickFolder', async () => {
    try {
      const win = BrowserWindow.getFocusedWindow();
      const result = await dialog.showOpenDialog(win as any, {
        properties: ['openDirectory'],
        title: 'Select Obsidian Vault Folder',
      });

      if (result.canceled || result.filePaths.length === 0) {
        return '';
      }

      return result.filePaths[0];
    } catch (error) {
      logger.error('error', 'ipc', 'vault.pickFolder', 'Failed to pick folder', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // =========================================================================
  // Phase 5: Obsidian Exporter - Export Operations
  // =========================================================================

  // -- Phase 5: export.single ----------------------------------------------
  safeHandle('export.single', async (_event, distilledOutputId: string) => {
    try {
      const { obsidianExporter } = await import('./services/exporter/obsidianExporter');
      const record = obsidianExporter.exportSingle(distilledOutputId);
      emitRecordsChanged('created', record.id);
      return record;
    } catch (error) {
      logger.error('error', 'ipc', 'export.single', 'Failed to export single item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: export.batch -----------------------------------------------
  safeHandle('export.batch', async (_event, distilledOutputIds: string[]) => {
    try {
      const { obsidianExporter } = await import('./services/exporter/obsidianExporter');
      const records = obsidianExporter.exportBatch(distilledOutputIds);
      for (const record of records) {
        emitRecordsChanged('created', record.id);
      }
      return records;
    } catch (error) {
      logger.error('error', 'ipc', 'export.batch', 'Failed to batch export', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: export.openFile --------------------------------------------
  safeHandle('export.openFile', async (_event, recordId: string) => {
    try {
      const records = storage.getExportRecords({});
      const record = records.find((r) => r.id === recordId);
      if (!record) {
        throw new Error(`ExportRecord not found: ${recordId}`);
      }

      const { join } = await import('node:path');
      const filePath = join(record.vaultPath, record.relativeFilePath);
      const result = await shell.openPath(filePath);
      if (result) {
        throw new Error(result);
      }
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'export.openFile', 'Failed to open file', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: export.revealInVault ---------------------------------------
  safeHandle('export.revealInVault', async (_event, recordId: string) => {
    try {
      const records = storage.getExportRecords({});
      const record = records.find((r) => r.id === recordId);
      if (!record) {
        throw new Error(`ExportRecord not found: ${recordId}`);
      }

      const { join, dirname } = await import('node:path');
      const filePath = join(record.vaultPath, record.relativeFilePath);
      const result = await shell.openPath(dirname(filePath));
      if (result) {
        throw new Error(result);
      }
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'export.revealInVault', 'Failed to reveal in vault', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: export.history ---------------------------------------------
  safeHandle('export.history', async (_event, filter?: { sourceItemId?: string; status?: string; limit?: number }) => {
    try {
      return storage.getExportRecords(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'export.history', 'Failed to get export history', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: export.retry -----------------------------------------------
  safeHandle('export.retry', async (_event, recordId: string) => {
    try {
      const { obsidianExporter } = await import('./services/exporter/obsidianExporter');
      const record = obsidianExporter.retryExport(recordId);
      emitRecordsChanged('updated', record.id);
      return record;
    } catch (error) {
      logger.error('error', 'ipc', 'export.retry', 'Failed to retry export', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 5: template.preview -------------------------------------------
  safeHandle('template.preview', async (_event, distilledOutputId: string) => {
    try {
      const { obsidianExporter } = await import('./services/exporter/obsidianExporter');
      return obsidianExporter.preview(distilledOutputId);
    } catch (error) {
      logger.error('error', 'ipc', 'template.preview', 'Failed to generate template preview', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // =========================================================================
  // Phase 4.5: Knowledge / Dataset / Model Registry
  // =========================================================================

  safeHandle(IPC_CHANNELS.KNOWLEDGE_CARDS_LIST, async (_event, filter?: { status?: string; category?: string; tag?: string; limit?: number }) => {
    try {
      return storage.listKnowledgeCards(filter as any);
    } catch (error) {
      logger.error('error', 'ipc', 'knowledgeCards.list', 'Failed to list knowledge cards', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.KNOWLEDGE_CARDS_GET, async (_event, id: string) => {
    try {
      return storage.getKnowledgeCard(id);
    } catch (error) {
      logger.error('error', 'ipc', 'knowledgeCards.get', 'Failed to get knowledge card', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.KNOWLEDGE_CARDS_GET_BY_SOURCE_ITEM_ID, async (_event, sourceItemId: string) => {
    try {
      return storage.getKnowledgeCardBySourceItemId(sourceItemId);
    } catch (error) {
      logger.error('error', 'ipc', 'knowledgeCards.getBySourceItemId', 'Failed to get knowledge card by source item id', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.KNOWLEDGE_CARDS_UPSERT_FROM_REVIEW, async (_event, distilledOutputId: string, action: 'approve' | 'edit' | 'discard', patch?: Partial<DistilledOutput>) => {
    try {
      const output = storage.getDistilledOutputs({}).find((item) => item.id === distilledOutputId);
      if (!output) {
        throw new Error(`DistilledOutput not found: ${distilledOutputId}`);
      }
      return storage.upsertKnowledgeCardFromReview(output, action, patch);
    } catch (error) {
      logger.error('error', 'ipc', 'knowledgeCards.upsertFromReview', 'Failed to upsert knowledge card', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.GRAPH_GET, async (_event, filter?: { cardId?: string; includeSuggested?: boolean; category?: string; tag?: string; limit?: number }) => {
    try {
      return storage.getKnowledgeGraph(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'graph.get', 'Failed to get knowledge graph', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  /** @deprecated Use DATASETS_V2_CREATE instead */
  safeHandle(IPC_CHANNELS.DATASETS_CREATE_SNAPSHOT, async (_event, data: { name: string; description?: string; splitConfig?: Record<string, unknown> }) => {
    try {
      const { randomUUID } = await import('node:crypto');
      const now = Math.floor(Date.now() / 1000);
      const snapshot = storage.createDatasetSnapshot({
        id: randomUUID(),
        name: data.name,
        description: data.description,
        manifestPath: '',
        splitConfig: data.splitConfig ?? { trainRatio: 0.8, evalRatio: 0.2 },
        counts: { total: 0, train: 0, eval: 0 },
        status: 'draft',
        createdAt: now,
      });
      return snapshot;
    } catch (error) {
      logger.error('error', 'ipc', 'datasets.createSnapshot', 'Failed to create dataset snapshot', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.DATASETS_EXPORT_BUNDLE, async (_event, snapshotId: string) => {
    try {
      const snapshot = storage.getDatasetSnapshot(snapshotId);
      if (!snapshot) {
        throw new Error(`DatasetSnapshot not found: ${snapshotId}`);
      }

      const { mkdirSync, writeFileSync } = await import('node:fs');
      const storageRoot = settings.getStorageRoot();
      const bundleDir = path.join(storageRoot, 'datasets', snapshotId);
      mkdirSync(bundleDir, { recursive: true });

      const examples = storage.getTrainingExamples({ limit: 10000 });
      const splitIndex = Math.max(1, Math.floor(examples.length * 0.8));
      const train = examples.slice(0, splitIndex);
      const evalSet = examples.slice(splitIndex);

      const manifest = {
        ...snapshot,
        exportedAt: Date.now(),
        counts: {
          total: examples.length,
          train: train.length,
          eval: evalSet.length,
        },
      };

      writeFileSync(path.join(bundleDir, 'manifest.json'), JSON.stringify(manifest, null, 2), 'utf8');
      writeFileSync(
        path.join(bundleDir, 'train.jsonl'),
        train.map((item) => JSON.stringify(item)).join('\n'),
        'utf8',
      );
      writeFileSync(
        path.join(bundleDir, 'eval.jsonl'),
        evalSet.map((item) => JSON.stringify(item)).join('\n'),
        'utf8',
      );

      return { bundleDir, manifest };
    } catch (error) {
      logger.error('error', 'ipc', 'datasets.exportBundle', 'Failed to export dataset bundle', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.TRAINING_RUNS_IMPORT_RESULT, async (_event, result: {
    snapshotId: string;
    baseModel: string;
    manifestPath?: string;
    artifactPath?: string;
    metrics?: Record<string, unknown>;
    modelVersion?: {
      name: string;
      artifactPath: string;
      modelfilePath?: string;
      notes?: string;
    };
    evalMetrics?: Record<string, unknown>;
  }) => {
    try {
      const { randomUUID } = await import('node:crypto');
      const now = Math.floor(Date.now() / 1000);
      const runId = randomUUID();
      storage.createTrainingRun({
        id: runId,
        snapshotId: result.snapshotId,
        baseModel: result.baseModel,
        status: 'done',
        manifestPath: result.manifestPath,
        artifactPath: result.artifactPath,
        metrics: result.metrics ?? {},
        createdAt: now,
        finishedAt: now,
      });

      let modelVersion: ModelVersion | null = null;
      if (result.modelVersion) {
        const modelId = randomUUID();
        storage.createModelVersion({
          id: modelId,
          name: result.modelVersion.name,
          baseModel: result.baseModel,
          artifactPath: result.modelVersion.artifactPath,
          modelfilePath: result.modelVersion.modelfilePath,
          provider: 'ollama',
          status: 'candidate',
          notes: result.modelVersion.notes,
          createdAt: now,
          updatedAt: now,
        });
        modelVersion = storage.getModelVersion(modelId);
      }

      if (result.evalMetrics) {
        storage.createEvalRun({
          id: randomUUID(),
          snapshotId: result.snapshotId,
          trainingRunId: runId,
          modelVersionId: modelVersion?.id,
          metrics: result.evalMetrics,
          createdAt: now,
        });
      }

      return {
        trainingRun: storage.getTrainingRun(runId),
        modelVersion,
      };
    } catch (error) {
      logger.error('error', 'ipc', 'trainingRuns.importResult', 'Failed to import training result', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.TRAINING_RUNS_LIST, async () => {
    try {
      return storage.getTrainingRuns();
    } catch (error) {
      logger.error('error', 'ipc', 'trainingRuns.list', 'Failed to list training runs', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.MODEL_VERSIONS_LIST, async () => {
    try {
      return storage.listModelVersions();
    } catch (error) {
      logger.error('error', 'ipc', 'modelVersions.list', 'Failed to list model versions', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.MODEL_VERSIONS_ACTIVATE, async (_event, id: string) => {
    try {
      const version = storage.getModelVersion(id);
      if (!version) {
        throw new Error(`ModelVersion not found: ${id}`);
      }

      for (const current of storage.listModelVersions()) {
        if (current.id === id) {
          storage.updateModelVersion(current.id, { status: 'active' });
        } else if (current.status === 'active') {
          storage.updateModelVersion(current.id, { status: 'archived' });
        }
      }
      return storage.getModelVersion(id);
    } catch (error) {
      logger.error('error', 'ipc', 'modelVersions.activate', 'Failed to activate model version', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.MODEL_VERSIONS_ROLLBACK, async (_event, id: string) => {
    try {
      const version = storage.getModelVersion(id);
      if (!version) {
        throw new Error(`ModelVersion not found: ${id}`);
      }

      for (const current of storage.listModelVersions()) {
        if (current.id === id) {
          storage.updateModelVersion(current.id, { status: 'active' });
        } else if (current.status === 'active') {
          storage.updateModelVersion(current.id, { status: 'candidate' });
        }
      }
      return storage.getModelVersion(id);
    } catch (error) {
      logger.error('error', 'ipc', 'modelVersions.rollback', 'Failed to rollback model version', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 3: Push events - aiTasks.statusChanged ------------------------
  // This is set up during distillPipeline initialization in index.ts
  // The event is emitted from the taskQueue via distillPipeline

  // =========================================================================
  // Capture extensions (stubs - Phase 2+)
  // =========================================================================

  safeHandle('capture.takeFixedScreenshot', async () => { return false; });
  safeHandle('capture.takeRegionScreenshot', async () => {});
  safeHandle('capture.takeRegionScreenshotCopy', async () => {});
  safeHandle('capture.takeRegionScreenshotSave', async () => {});
  safeHandle('capture.takeRegionScreenshotSaveAs', async () => {});
  safeHandle('capture.takeRegionScreenshotPin', async () => {});
  safeHandle('capture.cancelRegionScreenshot', async () => {});
  safeHandle('capture.getSelectionSession', async () => { return null; });
  safeHandle('capture.getColorAtPosition', async () => { return '#000000'; });
  safeHandle('capture.ignoreNextCopy', async () => {});
  safeHandle('capture.getRecordingState', async () => { return { isRecording: false, startTime: null, sourceApp: null }; });
  safeHandle('capture.requestRecordingStop', async () => {});
  safeHandle('capture.getLauncherVisualState', async () => { return { state: 'idle', hubOpen: false, weakened: false }; });
  safeHandle('capture.launcherDragStart', async () => {});
  safeHandle('capture.launcherDragMove', async () => {});
  safeHandle('capture.launcherDragEnd', async () => {});
  safeHandle('capture.toggleHub', async () => {});
  safeHandle('capture.hideHub', async () => {});
  safeHandle('capture.reportHubHeight', async () => {});

  // =========================================================================
  // Permissions (stubs)
  // =========================================================================

  safeHandle('permissions.getStatus', async (_e, source: PermissionCheckSource) => {
    return deps.permissionCoordinator.getPermissionStatus(source);
  });
  safeHandle('permissions.refresh', async (_e, source: PermissionCheckSource) => {
    return deps.permissionCoordinator.getPermissionStatus(source);
  });
  safeHandle('permissions.openSettings', async (_e, target: PermissionSettingsTarget, traceId?: string) => {
    return deps.permissionCoordinator.openPermissionSettings(target, traceId);
  });

  // =========================================================================
  // Settings runtime (stub)
  // =========================================================================

  safeHandle('settings.runtime.get', async () => {
    const s = settings.load();
    return { captureSize: s.scopeMode, captureRatio: { id: 'free', label: 'Free', ratio: 0 }, scopeMode: s.scopeMode, scopedApps: s.scopedApps };
  });

  // =========================================================================
  // Records (stubs - Phase 6)
  // =========================================================================

  safeHandle('records.recent', async (_event, count?: number) => {
    const items = storage.getSourceItems({ limit: Math.max(1, Math.min(count ?? 10, 50)) });
    return items.map((item) => ({
      id: item.id,
      timestamp: item.createdAt,
      type: item.type,
      preview: item.previewText ?? item.originalUrl ?? path.basename(item.contentPath) ?? '',
      sourceApp: item.sourceApp ?? undefined,
      source: item.source,
      createdAt: item.createdAt,
    }));
  });

  safeHandle('records.touch', async (_event, id: string) => {
    const item = storage.getSourceItem(id);
    if (!item) {
      throw new Error(`SourceItem not found: ${id}`);
    }
    logger.info('app', 'ipc', 'records.touch', 'Record touched', { id });
    return true;
  });

  // =========================================================================
  // Cutout (stubs - Phase 6)
  // =========================================================================

  safeHandle('cutout.processFromRecord', async (_event, id: string) => {
    const item = storage.getSourceItem(id);
    if (!item) {
      throw new Error(`SourceItem not found: ${id}`);
    }
    const content = captureService.getSourceItemContent(id);
    if (!content || content.type !== 'image' || !content.dataUrl) {
      throw new Error('Selected record is not an image capture');
    }
    return {
      dataUrl: content.dataUrl,
      fileNameSuggestion: `${item.title ?? item.previewText ?? 'cutout'}.png`,
    };
  });

  safeHandle('cutout.saveAsRecord', async (_event, params: { dataUrl?: string; fileNameSuggestion?: string; recordId?: string }) => {
    if (!params?.dataUrl) {
      throw new Error('Missing cutout dataUrl');
    }

    const storageRoot = settings.getStorageRoot();
    const id = randomUUID();
    const now = Date.now();
    const dateDir = new Date().toISOString().slice(0, 10);
    const sourcesDir = path.join(storageRoot, 'sources', dateDir);
    mkdirSync(sourcesDir, { recursive: true });

    const contentPath = path.join(sourcesDir, `${id}.png`);
    const base64 = params.dataUrl.split(',')[1] ?? '';
    writeFileSync(contentPath, Buffer.from(base64, 'base64'));

    const sourceItem = {
      id,
      type: 'image' as const,
      source: 'manual' as const,
      contentPath,
      previewText: params.fileNameSuggestion ?? 'Cutout',
      createdAt: now,
      status: 'inbox' as const,
    };

    storage.insertSourceItem(sourceItem);
    logger.info('app', 'ipc', 'cutout.saveAsRecord', 'Cutout saved as source item', { id });
    return { recordId: id };
  });

  // =========================================================================
  // Phase 9: 外部处理服务深度接入
  // =========================================================================

  safeHandle(IPC_CHANNELS.VK_CHECK_HEALTH, async () => {
    try {
      const { vaultKeeperAdapter } = await import('./services/vaultkeeper');
      return await vaultKeeperAdapter.checkHealth();
    } catch (error) {
      logger.error('error', 'ipc', 'vk.checkHealth', 'Health check failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return {
        available: false,
        connection_method: 'unavailable',
        supported_job_types: [],
        error: error instanceof Error ? error.message : String(error),
        checked_at: Math.floor(Date.now() / 1000),
      };
    }
  });

  safeHandle(IPC_CHANNELS.VK_GET_JOB_STATUS, async (_event, jobId: string) => {
    try {
      const { vaultKeeperAdapter } = await import('./services/vaultkeeper');
      return await vaultKeeperAdapter.getJobStatus(jobId);
    } catch (error) {
      logger.error('error', 'ipc', 'vk.getJobStatus', 'Get job status failed', {
        jobId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.VK_CANCEL_JOB, async (_event, jobId: string) => {
    try {
      const { vaultKeeperAdapter } = await import('./services/vaultkeeper');
      return await vaultKeeperAdapter.cancelJob(jobId);
    } catch (error) {
      logger.error('error', 'ipc', 'vk.cancelJob', 'Cancel job failed', {
        jobId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.VK_RESUBMIT_JOB, async (_event, originalId: string) => {
    try {
      logger.info('app', 'ipc', 'vk.resubmitJob', 'Resubmit job requested', { originalId });
      const { processingJobService } = await import('./services/vaultkeeper');
      const { storage } = await import('./storage');
      const sourceItem = storage.getSourceItemByOriginalId(originalId);
      if (!sourceItem) {
        return { success: false, error: `找不到 original_id=${originalId} 对应的 SourceItem` };
      }
      // 构造一个最小 CaptureRecord 用于重新提交
      const captureRecord = {
        original_id: originalId,
        source_type: sourceItem.type,
        raw_text: sourceItem.previewText || '',
        raw_url: sourceItem.originalUrl || undefined,
        raw_file_path: sourceItem.contentPath || undefined,
        metadata: sourceItem.metadata || {},
      };
      const jobId = await processingJobService.submitJob(captureRecord as any, sourceItem.id);
      return { success: !!jobId, jobId, message: jobId ? '重新提交成功' : '不需要外部处理或提交失败' };
    } catch (error) {
      logger.error('error', 'ipc', 'vk.resubmitJob', 'Resubmit job failed', {
        originalId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.VK_MANUAL_INGEST, async (_event, jobId: string, originalId?: string) => {
    try {
      logger.info('app', 'ipc', 'vk.manualIngest', 'Manual ingest requested', { jobId, originalId });
      const { externalResultIngestionService } = await import('./services/vaultkeeper');
      return await externalResultIngestionService.manualIngest(jobId, originalId);
    } catch (error) {
      logger.error('error', 'ipc', 'vk.manualIngest', 'Manual ingest failed', {
        jobId,
        originalId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.VK_GET_RECENT_JOBS, async (_event, limit?: number) => {
    try {
      const vkErrorTypes = [
        'external_service_unavailable',
        'external_job_failed',
        'external_result_invalid',
        'external_result_ingest_failed',
      ];
      const errors = errorService.listRecords({ limit: limit ?? 20 });
      return errors.filter((e) => vkErrorTypes.includes(e.error_type));
    } catch (error) {
      logger.error('error', 'ipc', 'vk.getRecentJobs', 'Get recent jobs failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return [];
    }
  });

  safeHandle(IPC_CHANNELS.VK_GET_FAILED_JOBS, async () => {
    try {
      const vkFailedTypes = [
        'external_job_failed',
        'external_result_invalid',
        'external_result_ingest_failed',
      ];
      const errors = errorService.listRecords({ status: 'open' });
      return errors.filter((e) => vkFailedTypes.includes(e.error_type));
    } catch (error) {
      logger.error('error', 'ipc', 'vk.getFailedJobs', 'Get failed jobs failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return [];
    }
  });

  // 保留旧接口兼容
  safeHandle('vk.task.create', async (_event, params: unknown) => {
    const id = randomUUID();
    logger.info('app', 'ipc', 'vk.task.create', 'External task created (legacy)', { id, params: typeof params === 'object' ? params : String(params) });
    return { id };
  });

  // =========================================================================
  // Phase 6: External Import
  // =========================================================================

  safeHandle('import.scan', async (_event, params: { vaultPath: string; folderPath?: string; excludePatterns?: string[] }) => {
    try {
      const { vaultImporter } = await import('./services/importer/vaultImporter');
      return vaultImporter.scan(params.vaultPath, params);
    } catch (error) {
      logger.error('error', 'ipc', 'import.scan', 'Failed to scan vault', { error: error instanceof Error ? error.message : String(error) });
      throw error;
    }
  });

  safeHandle('import.start', async (_event, options: import('../shared/types').ImportOptions) => {
    try {
      const { vaultImporter } = await import('./services/importer/vaultImporter');
      const taskId = vaultImporter.startImport(options);
      return { id: taskId };
    } catch (error) {
      logger.error('error', 'ipc', 'import.start', 'Failed to start import', { error: error instanceof Error ? error.message : String(error) });
      throw error;
    }
  });

  safeHandle('import.status', async (_event, taskId: string) => {
    try {
      const { vaultImporter } = await import('./services/importer/vaultImporter');
      return vaultImporter.getTaskStatus(taskId);
    } catch (error) {
      logger.error('error', 'ipc', 'import.status', 'Failed to get import status', { error: error instanceof Error ? error.message : String(error) });
      throw error;
    }
  });

  safeHandle('import.cancel', async (_event, taskId: string) => {
    try {
      const { vaultImporter } = await import('./services/importer/vaultImporter');
      return vaultImporter.cancelImport(taskId);
    } catch (error) {
      logger.error('error', 'ipc', 'import.cancel', 'Failed to cancel import', { error: error instanceof Error ? error.message : String(error) });
      throw error;
    }
  });

  safeHandle('import.history', async (_event, limit?: number) => {
    try {
      const { vaultImporter } = await import('./services/importer/vaultImporter');
      return vaultImporter.getImportHistory(limit);
    } catch (error) {
      logger.error('error', 'ipc', 'import.history', 'Failed to get import history', { error: error instanceof Error ? error.message : String(error) });
      throw error;
    }
  });

  safeHandle('import.tasks.list', async (_event, filter?: { status?: string; limit?: number }) => {
    try {
      return storage.getImportTasks(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'import.tasks.list', 'Failed to list import tasks', { error: error instanceof Error ? error.message : String(error) });
      throw error;
    }
  });

  // =========================================================================
  // Capture Inbox v0.1
  // =========================================================================

  // -- captureItems.list ---------------------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_ITEMS_LIST, async (_event, filter?: CaptureItemListFilter) => {
    try {
      return storage.getCaptureItems(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'captureItems.list', 'Failed to list capture items', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- captureItems.get ----------------------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_ITEMS_GET, async (_event, id: string) => {
    try {
      return storage.getCaptureItem(id);
    } catch (error) {
      logger.error('error', 'ipc', 'captureItems.get', 'Failed to get capture item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- captureItems.create -------------------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_ITEMS_CREATE, async (_event, data: {
    type: CaptureItem['type'];
    title?: string;
    rawText?: string;
    sourceUrl?: string;
    filePath?: string;
    userNote?: string;
    imageBase64?: string;
    imageMimeType?: string;
    imageOriginalName?: string;
  }) => {
    try {
      const { randomUUID } = await import('node:crypto');
      const { mkdirSync, writeFileSync, existsSync, copyFileSync } = await import('node:fs');
      const now = Math.floor(Date.now() / 1000);
      const id = randomUUID();
      const storageRoot = settings.getStorageRoot();

      let resolvedFilePath = '';
      let resolvedTitle = data.title || '';
      let resolvedRawText = data.rawText || '';

      // Handle image type: save file to disk
      if (data.type === 'image') {
        const dateDir = new Date().toISOString().slice(0, 10);
        const captureDir = path.join(storageRoot, 'captures', dateDir);
        mkdirSync(captureDir, { recursive: true });

        let ext = '.png';

        if (data.imageBase64 && data.imageMimeType) {
          // Path A: base64 data from paste/drop (no real file path)
          const mimeToExt: Record<string, string> = {
            'image/png': '.png',
            'image/jpeg': '.jpg',
            'image/jpg': '.jpg',
            'image/gif': '.gif',
            'image/webp': '.webp',
            'image/svg+xml': '.svg',
            'image/bmp': '.bmp',
          };
          ext = mimeToExt[data.imageMimeType] || '.png';

          const destPath = path.join(captureDir, `${id}${ext}`);
          const buffer = Buffer.from(data.imageBase64, 'base64');
          writeFileSync(destPath, buffer);
          resolvedFilePath = destPath;

          logger.info('app', 'ipc', 'captureItems.create', `Image saved from base64: ${destPath}`, {
            size: buffer.length,
            mime: data.imageMimeType,
          });
        } else if (data.filePath && existsSync(data.filePath)) {
          // Path B: real file path from file picker (Electron enhanced File object)
          ext = path.extname(data.filePath) || '.png';
          const destPath = path.join(captureDir, `${id}${ext}`);
          copyFileSync(data.filePath, destPath);
          resolvedFilePath = destPath;

          logger.info('app', 'ipc', 'captureItems.create', `Image copied from disk: ${destPath}`);
        } else {
          // No valid image data — throw error, do NOT create DB record
          throw new Error('图片数据无效：未收到 base64 图片内容，且文件路径不存在或不可读');
        }

        if (!resolvedTitle) {
          const origName = data.imageOriginalName || '';
          resolvedTitle = origName
            ? origName.replace(/\.[^.]+$/, '') // strip extension
            : `图片碎片 ${new Date(now * 1000).toLocaleTimeString('zh-CN')}`;
        }
      }

      // Auto-generate title for text/link if not provided
      if (!resolvedTitle) {
        if (data.type === 'link') {
          resolvedTitle = data.sourceUrl || '未命名链接';
        } else {
          resolvedTitle = resolvedRawText.slice(0, 50) || '未命名碎片';
        }
      }

      const captureItem: CaptureItem = {
        id,
        type: data.type,
        status: 'pending',
        title: resolvedTitle,
        rawText: resolvedRawText,
        sourceUrl: data.sourceUrl || '',
        filePath: resolvedFilePath,
        userNote: data.userNote || '',
        capturedAt: now,
        updatedAt: now,
      };

      storage.insertCaptureItem(captureItem);

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, { action: 'created', id, timestamp: now });
        }
      }

      return captureItem;
    } catch (error) {
      logger.error('error', 'ipc', 'captureItems.create', 'Failed to create capture item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- captureItems.update -------------------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_ITEMS_UPDATE, async (_event, id: string, patch: Partial<CaptureItem>) => {
    try {
      storage.updateCaptureItem(id, patch);

      // Notify renderer
      const now = Math.floor(Date.now() / 1000);
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, { action: 'updated', id, timestamp: now });
        }
      }

      return storage.getCaptureItem(id);
    } catch (error) {
      logger.error('error', 'ipc', 'captureItems.update', 'Failed to update capture item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- captureItems.delete -------------------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_ITEMS_DELETE, async (_event, id: string) => {
    try {
      storage.deleteCaptureItem(id);

      // Notify renderer
      const now = Math.floor(Date.now() / 1000);
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, { action: 'deleted', id, timestamp: now });
        }
      }

      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'captureItems.delete', 'Failed to delete capture item', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- captureItems.exportMarkdown -----------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_ITEMS_EXPORT_MARKDOWN, async (_event, ids: string[]) => {
    try {
      void ids;
      throw new Error('Local Distill MVP 禁止直接导出 CaptureItem Markdown。请先执行蒸馏、审阅，再通过 export.single 生成 ExportRecord。');
    } catch (error) {
      logger.error('error', 'ipc', 'captureItems.exportMarkdown', 'Failed to export markdown', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- captureItems.readImage -----------------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_ITEMS_READ_IMAGE, async (_event, filePath: string) => {
    try {
      const { readFileSync, existsSync, statSync } = await import('node:fs');
      if (!filePath || !existsSync(filePath)) {
        return { ok: false, error: '图片文件不存在' };
      }
      const stat = statSync(filePath);
      // Limit to 10MB for safety
      if (stat.size > 10 * 1024 * 1024) {
        return { ok: false, error: '图片文件过大（超过 10MB）' };
      }
      const buffer = readFileSync(filePath);
      const base64 = buffer.toString('base64');
      // Detect mime from extension
      const ext = path.extname(filePath).toLowerCase();
      const mimeMap: Record<string, string> = {
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.svg': 'image/svg+xml',
        '.bmp': 'image/bmp',
      };
      const mimeType = mimeMap[ext] || 'image/png';
      return { ok: true, dataUrl: `data:${mimeType};base64,${base64}` };
    } catch (error) {
      logger.error('error', 'ipc', 'captureItems.readImage', 'Failed to read image', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { ok: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // =========================================================================
  // AI Distillation Workbench - Save Markdown
  // =========================================================================

  // -- workbench.saveMarkdown -----------------------------------------------
  safeHandle('workbench.saveMarkdown', async (_event, data: { content: string; filename?: string }) => {
    try {
      const { content, filename: userFilename } = data;

      if (!content || typeof content !== 'string') {
        return { success: false, error: '内容不能为空' };
      }

      // 生成文件名
      let filename = userFilename;
      if (!filename || !filename.trim()) {
        // 从内容第一行提取标题
        const firstLine = content.split('\n')[0].trim();
        if (firstLine) {
          // 去掉 Markdown 标题符号
          const cleaned = firstLine.replace(/^#+\s*/, '').trim();
          // 安全化文件名
          const safeName = cleaned
            .replace(/[\\/:*?"<>|#]/g, '-')
            .replace(/\s+/g, ' ')
            .slice(0, 80);
          if (safeName) {
            const dateStr = new Date().toISOString().replace(/[-T:.Z]/g, '').slice(0, 13);
            filename = `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}_${dateStr.slice(8, 12)}_${safeName}.md`;
          }
        }
        if (!filename) {
          const now = Math.floor(Date.now() / 1000);
          const { formatFilenameDate } = await import('../shared/outputSpec');
          filename = `${formatFilenameDate(now)}_未命名内容.md`;
        }
      } else if (!filename.endsWith('.md')) {
        filename = `${filename}.md`;
      }

      // 确定保存目录
      const vaultConfig = storage.getVaultConfig();
      let saveDir: string;

      if (vaultConfig.vaultPath) {
        saveDir = path.join(vaultConfig.vaultPath, '99_Inbox', 'AI蒸馏');
      } else {
        const storageRoot = settings.getStorageRoot();
        saveDir = path.join(storageRoot, 'outputs', 'distillations');
      }

      // 创建目录（递归）
      mkdirSync(saveDir, { recursive: true });

      // 处理文件名冲突 (xxx-2.md, xxx-3.md, ...)
      let filePath = path.join(saveDir, filename);
      let counter = 2;
      const baseName = filename.replace(/\.md$/, '');
      while (true) {
        try {
          const { existsSync } = await import('node:fs');
          if (!existsSync(filePath)) break;
          filePath = path.join(saveDir, `${baseName}-${counter}.md`);
          counter++;
        } catch {
          break;
        }
      }

      // 写入文件
      writeFileSync(filePath, content, 'utf8');

      const finalFilename = path.basename(filePath);
      logger.info('app', 'ipc', 'workbench.saveMarkdown', `Markdown saved: ${filePath}`);

      return { success: true, filePath, filename: finalFilename };
    } catch (error) {
      logger.error('error', 'ipc', 'workbench.saveMarkdown', 'Failed to save markdown', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // -- workbench.revealInFinder ---------------------------------------------
  safeHandle('workbench.revealInFinder', async (_event, filePath: string) => {
    try {
      if (!filePath || typeof filePath !== 'string') {
        throw new Error('文件路径不能为空');
      }

      const { dirname } = await import('node:path');
      const dir = dirname(filePath);
      const result = await shell.openPath(dir);
      if (result) {
        throw new Error(result);
      }
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'workbench.revealInFinder', 'Failed to reveal in Finder', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Workspace directory operations (PersonalSpace) -------------------------
  safeHandle(IPC_CHANNELS.WORKSPACE_SELECT_DIRECTORY, async () => {
    try {
      const win = BrowserWindow.getFocusedWindow();
      const result = await dialog.showOpenDialog(win as any, {
        properties: ['openDirectory'],
        title: '选择目录',
      });

      if (result.canceled || result.filePaths.length === 0) {
        return { success: false };
      }

      return { success: true, path: result.filePaths[0] };
    } catch (error) {
      logger.error('error', 'ipc', 'workspace.selectDirectory', 'Failed to select directory', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.WORKSPACE_OPEN_DIRECTORY, async (_event, dirPath: string) => {
    try {
      const result = await shell.openPath(dirPath);
      if (result) {
        throw new Error(result);
      }
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'workspace.openDirectory', 'Failed to open directory', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.WORKSPACE_TEST_WRITE, async (_event, dirPath: string) => {
    const testFile = path.join(dirPath, '.acmind_write_test');
    try {
      writeFileSync(testFile, 'AcMind write test', 'utf8');
      unlinkSync(testFile);
      return { success: true, path: dirPath };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'ipc', 'workspace.testWrite', 'Write test failed', {
        dirPath,
        error: msg,
      });
      return { success: false, error: `写入测试失败: ${msg}` };
    }
  });

  // =========================================================================
  // Distill Loop: Bridge + Distill + Lineage
  // =========================================================================

  // -- distill.bridgeAndRun: Single capture item → bridge → distill ----------
  safeHandle(IPC_CHANNELS.DISTILL_BRIDGE_AND_RUN, async (
    _event,
    captureItemId: string,
    operations?: AiOperation[],
    tier?: AiTier,
  ) => {
    try {
      // Step 1: Bridge CaptureItem → SourceItem (idempotent)
      const sourceItem = storage.createSourceItemFromCaptureItem(captureItemId);

      // Step 2: Update CaptureItem status to 'distilling'
      const captureItem = storage.getCaptureItem(captureItemId);
      if (captureItem && (captureItem.status === 'pending' || captureItem.status === 'archived')) {
        storage.updateCaptureItem(captureItemId, { status: 'distilling' });
        emitCaptureItemsChanged('updated', captureItemId);
      }

      // Step 3: Run distillation on the SourceItem
      const { distillPipeline } = await import('./services/distiller/distillPipeline');
      const ops = operations ?? (['summarize'] as AiOperation[]);
      const tasks = distillPipeline.distillBatch([sourceItem.id], ops, tier);

      // Notify renderer
      emitRecordsChanged('created', sourceItem.id);

      logger.info('app', 'ipc', 'distill.bridgeAndRun', `Bridged and distilled: ${captureItemId} → ${sourceItem.id}`, {
        taskCount: tasks.length,
      });

      return { sourceItem, tasks };
    } catch (error) {
      logger.error('error', 'ipc', 'distill.bridgeAndRun', 'Failed to bridge and distill', {
        captureItemId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- distill.bridgeAndRunBatch: Multiple capture items → bridge → distill --
  safeHandle(IPC_CHANNELS.DISTILL_BRIDGE_AND_RUN_BATCH, async (
    _event,
    captureItemIds: string[],
    operations?: AiOperation[],
    tier?: AiTier,
  ) => {
    try {
      const sourceItems: Array<{ id: string }> = [];
      for (const captureItemId of captureItemIds) {
        const sourceItem = storage.createSourceItemFromCaptureItem(captureItemId);
        sourceItems.push(sourceItem);

        // Update CaptureItem status
        const captureItem = storage.getCaptureItem(captureItemId);
        if (captureItem && (captureItem.status === 'pending' || captureItem.status === 'archived')) {
          storage.updateCaptureItem(captureItemId, { status: 'distilling' });
          emitCaptureItemsChanged('updated', captureItemId);
        }
      }

      const { distillPipeline } = await import('./services/distiller/distillPipeline');
      const ops = operations ?? (['summarize'] as AiOperation[]);
      const tasks = distillPipeline.distillBatch(sourceItems.map((s) => s.id), ops, tier);

      for (const si of sourceItems) {
        emitRecordsChanged('created', si.id);
      }

      logger.info('app', 'ipc', 'distill.bridgeAndRunBatch', `Bridged and distilled batch`, {
        captureItemCount: captureItemIds.length,
        taskCount: tasks.length,
      });

      return { sourceItems, tasks };
    } catch (error) {
      logger.error('error', 'ipc', 'distill.bridgeAndRunBatch', 'Failed to bridge and distill batch', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- export.getWithLineage: Single export record with SourceItem + DistilledOutput
  safeHandle(IPC_CHANNELS.EXPORT_GET_WITH_LINEAGE, async (_event, recordId: string) => {
    try {
      return storage.getExportRecordWithLineage(recordId);
    } catch (error) {
      logger.error('error', 'ipc', 'export.getWithLineage', 'Failed to get export record with lineage', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- export.recordsWithLineage: All export records with lineage data --------
  safeHandle(IPC_CHANNELS.EXPORT_RECORDS_WITH_LINEAGE, async (_event, filter?: { sourceItemId?: string; status?: string; limit?: number }) => {
    try {
      return storage.getExportRecordsWithLineage(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'export.recordsWithLineage', 'Failed to get export records with lineage', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- sourceItems.getDistillStatus: Full lineage status for a capture item ---
  safeHandle(IPC_CHANNELS.SOURCE_ITEMS_GET_DISTILL_STATUS, async (_event, captureItemId: string) => {
    try {
      return storage.getDistillLineageStatus(captureItemId);
    } catch (error) {
      logger.error('error', 'ipc', 'sourceItems.getDistillStatus', 'Failed to get distill status', {
        captureItemId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // ── Phase 1: Keyword Search ──────────────────────────────────────

  // Initialize search tables on first IPC call (lazy init)
  let searchInitialized = false;
  function ensureSearchInit(): void {
    if (searchInitialized) return;
    const db = storage.db;
    if (!db) return;
    try {
      keywordSearch.initTable(db);
      embeddingService.initTable(db);
      searchInitialized = true;
      logger.info('app', 'ipc', 'search', 'Search tables initialized (FTS5 + embeddings)');
    } catch (error) {
      logger.error('error', 'ipc', 'search', 'Failed to init search tables', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  // search.hybrid: Perform hybrid search (keyword + vector with RRF fusion)
  safeHandle(
    IPC_CHANNELS.SEARCH_HYBRID,
    async (
      _event,
      query: string,
      options: HybridSearchOptions = { query },
      embeddingConfig?: Record<string, unknown>,
    ): Promise<SearchResult[]> => {
      try {
        ensureSearchInit();
        const db = storage.db;
        if (!db) throw new Error('Database not initialized');

        const topK = options.topK ?? 20;
        const vectorWeight = options.vectorWeight ?? 0.6;
        const keywordWeight = options.keywordWeight ?? 0.4;

        // ── Keyword search (always available) ──
        const keywordResults = keywordSearch.search(db, query, topK * 2);

        // ── Vector search (if embeddings exist and provider available) ──
        let vectorResults: Array<{ itemType: string; itemId: string; score: number }> = [];
        const embeddingCount = embeddingService.count(db);

        if (embeddingCount > 0 && embeddingConfig) {
          try {
            // Find an embedding-capable provider from settings
            const currentSettings = settings.load();
            const provider = currentSettings.providers?.find(
              (p: { enabled: boolean; capabilities?: string[] }) =>
                p.enabled && p.capabilities?.includes('embedding'),
            );
            if (provider) {
              vectorResults = await vectorSearch.searchByQuery(
                db, provider, query, topK * 2,
                options.searchTargets?.length === 1
                  ? options.searchTargets[0] === 'source_items' ? 'source_item' : 'distilled_output'
                  : undefined,
              );
            }
          } catch (error) {
            logger.warn('search', 'ipc', 'search.hybrid', 'Vector search failed, falling back to keyword-only', {
              error: error instanceof Error ? error.message : String(error),
            });
          }
        }

        // ── Reciprocal Rank Fusion (RRF) ──
        const fusedScores = new Map<string, { score: number; vectorScore: number | null; keywordScore: number | null; source: SearchResult['source'] }>();

        // Add keyword results
        for (let i = 0; i < keywordResults.length; i++) {
          const r = keywordResults[i];
          const rrfScore = keywordWeight / (i + 1 + 60); // RRF with k=60
          const existing = fusedScores.get(r.itemId);
          if (existing) {
            existing.score += rrfScore;
            existing.keywordScore = r.score;
            existing.source = 'hybrid';
          } else {
            fusedScores.set(r.itemId, { score: rrfScore, vectorScore: null, keywordScore: r.score, source: 'keyword' });
          }
        }

        // Add vector results
        for (let i = 0; i < vectorResults.length; i++) {
          const r = vectorResults[i];
          const rrfScore = vectorWeight / (i + 1 + 60);
          const existing = fusedScores.get(r.itemId);
          if (existing) {
            existing.score += rrfScore;
            existing.vectorScore = r.score;
            existing.source = 'hybrid';
          } else {
            fusedScores.set(r.itemId, { score: rrfScore, vectorScore: r.score, keywordScore: null, source: 'vector' });
          }
        }

        // Sort by fused score and take top-K
        const sorted = [...fusedScores.entries()]
          .sort((a, b) => b[1].score - a[1].score)
          .slice(0, topK);

        // ── Build final results ──
        return sorted.map(([itemId, scores], index) => {
          // Determine item type from keyword results or vector results
          const keywordHit = keywordResults.find(r => r.itemId === itemId);
          const vectorHit = vectorResults.find(r => r.itemId === itemId);
          const itemType = keywordHit?.itemType ?? vectorHit?.itemType ?? 'source_item';
          const title = keywordHit?.title ?? '';

          // Resolve real createdAt
          let createdAt = 0;
          if (itemType === 'source_item') {
            const si = storage.getSourceItem(itemId);
            createdAt = si?.createdAt ?? 0;
          } else {
            const dos = storage.getDistilledOutputs({}).find(o => o.id === itemId);
            createdAt = dos?.createdAt ?? 0;
          }

          // Resolve associated ExportRecords
          let exportRecordIds: string[] = [];
          if (itemType === 'source_item') {
            exportRecordIds = storage.getExportRecords({ sourceItemId: itemId }).map(er => er.id);
          } else {
            exportRecordIds = storage.getExportRecords({ distilledOutputId: itemId }).map(er => er.id);
          }

          return {
            id: itemId,
            type: (itemType === 'source_item' ? 'source_item' : 'distilled_output') as SearchResult['type'],
            title,
            preview: keywordHit?.snippet ?? '',
            score: scores.score,
            vectorScore: scores.vectorScore,
            keywordScore: scores.keywordScore,
            rank: index + 1,
            source: scores.source,
            metadata: {
              createdAt,
              exportRecordIds,
              exportRecordCount: exportRecordIds.length,
            },
          };
        });
      } catch (error) {
        logger.error('error', 'ipc', 'search.hybrid', 'Search failed', {
          query,
          error: error instanceof Error ? error.message : String(error),
        });
        throw error;
      }
    },
  );

  // search.rebuildFts: Rebuild FTS index from existing data
  safeHandle(IPC_CHANNELS.SEARCH_REBUILD_FTS, async (_event) => {
    try {
      ensureSearchInit();
      const db = storage.db;
      if (!db) throw new Error('Database not initialized');

      // Fetch all source items
      const sourceItems = db
        .prepare('SELECT id, title, preview_text as content, tags, created_at FROM source_items')
        .all() as Array<Record<string, unknown>>;

      // Fetch all distilled outputs
      const distilledOutputs = db
        .prepare(
          'SELECT id, suggested_title as title, summary as content, tags, created_at FROM distilled_outputs WHERE review_status = ?',
        )
        .all('accepted') as Array<Record<string, unknown>>;

      keywordSearch.rebuildIndex(
        db,
        sourceItems as Parameters<typeof keywordSearch.rebuildIndex>[1],
        distilledOutputs as Parameters<typeof keywordSearch.rebuildIndex>[2],
      );

      return { sourceItems: sourceItems.length, distilledOutputs: distilledOutputs.length };
    } catch (error) {
      logger.error('error', 'ipc', 'search.rebuildFts', 'FTS rebuild failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // search.getStatus: Get search module status
  // Returns three-layer status: initialized / indexed / searchable
  safeHandle(IPC_CHANNELS.SEARCH_GET_STATUS, async (_event) => {
    try {
      const db = storage.db;
      if (!db) return { initialized: false, ftsCount: 0, searchable: false };

      ensureSearchInit();

      let ftsCount = 0;
      let tableExists = false;
      try {
        ftsCount = (
          db.prepare('SELECT COUNT(*) as count FROM search_fts').get() as { count: number }
        ).count;
        tableExists = true;
      } catch {
        // FTS table may not exist yet
      }

      return {
        initialized: searchInitialized,
        ftsCount,
        searchable: tableExists && ftsCount > 0,
      };
    } catch (error) {
      logger.error('error', 'ipc', 'search.getStatus', 'Failed to get search status', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // ── Phase 2: Document Parser ────────────────────────────────────

  // parser.importFile: Import a single document (PDF/DOCX) from file path
  safeHandle(IPC_CHANNELS.PARSER_IMPORT_FILE, async (_event, filePath: string): Promise<ImportResult> => {
    try {
      logger.info('app', 'ipc', 'parser.importFile', 'Importing document', { filePath });
      return documentImporter.importDocument(filePath);
    } catch (error) {
      logger.error('error', 'ipc', 'parser.importFile', 'Import failed', {
        filePath,
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // parser.importUrl: Import a webpage from URL
  safeHandle(IPC_CHANNELS.PARSER_IMPORT_URL, async (_event, url: string): Promise<ImportResult> => {
    try {
      logger.info('app', 'ipc', 'parser.importUrl', 'Importing webpage', { url });
      return documentImporter.importWebpage(url);
    } catch (error) {
      logger.error('error', 'ipc', 'parser.importUrl', 'Import failed', {
        url,
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // parser.importBatch: Import multiple documents
  safeHandle(
    IPC_CHANNELS.PARSER_IMPORT_BATCH,
    async (_event, filePaths: string[]): Promise<ImportResult[]> => {
      try {
        logger.info('app', 'ipc', 'parser.importBatch', 'Batch importing documents', {
          count: filePaths.length,
        });
        return documentImporter.importBatch(filePaths);
      } catch (error) {
        logger.error('error', 'ipc', 'parser.importBatch', 'Batch import failed', {
          error: error instanceof Error ? error.message : String(error),
        });
        throw error;
      }
    },
  );

  // ── MarkItDown Integration ──────────────────────────────────────

  // markitdown.convert: Convert URL to Markdown (Python markitdown with fallback)
  safeHandle(IPC_CHANNELS.MARKITDOWN_CONVERT, async (_event, url: string) => {
    try {
      // Lazy import to avoid loading at startup
      const { convertUrlToMarkdown } = await import('./services/parser/markitdownService');
      return convertUrlToMarkdown(url);
    } catch (error) {
      logger.error('error', 'ipc', 'markitdown.convert', 'Conversion failed', {
        url,
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error), engine: 'fallback' as const };
    }
  });

  // markitdown.check: Check if Python markitdown is available
  safeHandle(IPC_CHANNELS.MARKITDOWN_CHECK, async () => {
    try {
      const { checkMarkItDownAvailability } = await import('./services/parser/markitdownService');
      return checkMarkItDownAvailability();
    } catch {
      return false;
    }
  });

  // ── Phase 3: File Converter ─────────────────────────────────────

  function notifyJobsChanged(): void {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(IPC_CHANNELS.FILE_CONVERT_JOBS_CHANGED, { timestamp: Date.now() });
      }
    }
  }

  safeHandle(IPC_CHANNELS.FILE_CONVERT, async (_event, params: { filePath: string }) => {
    try {
      if (!params.filePath) {
        return { success: false, error: 'filePath is required' };
      }

      const { convertFileToMarkdown } = await import('./services/parser/markitdownService');

      // Create ProcessJob
      const jobId = randomUUID();
      const now = Math.floor(Date.now() / 1000);
      const job: ProcessJob = {
        id: jobId,
        type: 'markitdown',
        status: 'running',
        progress: 0,
        createdAt: now,
        updatedAt: now,
        startedAt: now,
        metadata: { filePath: params.filePath },
      };
      storage.insertProcessJob(job);
      notifyJobsChanged();

      // Run conversion
      const result = await convertFileToMarkdown(params.filePath);

      if (result.success) {
        storage.updateProcessJob(jobId, {
          status: 'succeeded',
          progress: 100,
          completedAt: Math.floor(Date.now() / 1000),
          metadata: { filePath: params.filePath, title: result.title, engine: result.engine, charCount: result.markdown?.length },
        });
      } else {
        storage.updateProcessJob(jobId, {
          status: 'failed',
          progress: 0,
          errorMessage: result.error,
          completedAt: Math.floor(Date.now() / 1000),
        });
      }
      notifyJobsChanged();

      return { success: result.success, jobId, markdown: result.markdown, title: result.title, error: result.error, engine: result.engine };
    } catch (error) {
      logger.error('error', 'ipc', 'fileConverter.convert', 'File conversion failed', {
        filePath: params.filePath,
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.FILE_CONVERT_STATUS, async (_event, params: { jobId: string }) => {
    try {
      const job = storage.getProcessJob(params.jobId);
      return { success: true, job };
    } catch (error) {
      return { success: false, job: null };
    }
  });

  safeHandle(IPC_CHANNELS.FILE_CONVERT_LIST, async (_event, params?: { limit?: number }) => {
    try {
      const jobs = storage.listProcessJobs({ type: 'markitdown', limit: params?.limit ?? 50 });
      return { success: true, jobs };
    } catch (error) {
      return { success: false, jobs: [] };
    }
  });

  safeHandle(IPC_CHANNELS.FILE_CONVERT_SAVE_TO_INBOX, async (_event, params: { jobId: string; markdown: string; title?: string; filePath?: string }) => {
    try {
      if (!params.markdown || !params.markdown.trim()) {
        return { success: false, error: 'Markdown content is empty' };
      }

      const sourceItem: SourceItem = {
        id: randomUUID(),
        type: 'text',
        source: 'manual',
        contentPath: params.filePath || '',
        previewText: params.markdown.slice(0, 200),
        status: 'inbox',
        createdAt: Math.floor(Date.now() / 1000),
        title: params.title,
        metadata: { convertedMarkdown: params.markdown },
      };
      storage.insertSourceItem(sourceItem);

      // Link job to source item
      if (params.jobId) {
        storage.updateProcessJob(params.jobId, { sourceItemId: sourceItem.id });
      }

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.RECORDS_CHANGED, { action: 'file_converted', id: sourceItem.id, timestamp: Date.now() });
        }
      }

      return { success: true, sourceItem };
    } catch (error) {
      logger.error('error', 'ipc', 'fileConverter.saveToInbox', 'Failed to save converted file to inbox', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.FILE_CONVERT_PREVIEW, async (_event, params: { filePath: string }) => {
    try {
      if (!params.filePath) {
        return { success: false, error: 'filePath is required' };
      }
      const { convertFileToMarkdown } = await import('./services/parser/markitdownService');
      const result = await convertFileToMarkdown(params.filePath);
      return { success: result.success, markdown: result.markdown, title: result.title, error: result.error, engine: result.engine };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CALENDAR_SHOW_NOTIFICATION, async (_event, params: { title: string; body: string }) => {
    try {
      if (!params?.title?.trim()) return false;
      const notification = new Notification({
        title: params.title.trim(),
        body: params.body?.trim() || '',
        silent: false,
      });
      notification.show();
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'calendar.showNotification', 'Failed to show notification', {
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  });

  // ── Phase 3: Scheduler ──────────────────────────────────────────

  safeHandle(IPC_CHANNELS.SCHEDULER_CREATE_TASK, async (_event, params: CreateTaskParams) => {
    try {
      return schedulerService.createTask(params);
    } catch (error) {
      logger.error('error', 'ipc', 'scheduler.createTask', 'Failed to create task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SCHEDULER_UPDATE_TASK, async (_event, id: string, updates: Partial<CreateTaskParams>) => {
    try {
      return schedulerService.updateTask(id, updates);
    } catch (error) {
      logger.error('error', 'ipc', 'scheduler.updateTask', 'Failed to update task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SCHEDULER_DELETE_TASK, async (_event, id: string) => {
    try {
      schedulerService.deleteTask(id);
    } catch (error) {
      logger.error('error', 'ipc', 'scheduler.deleteTask', 'Failed to delete task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SCHEDULER_TOGGLE_TASK, async (_event, id: string, enabled: boolean) => {
    try {
      return schedulerService.toggleTask(id, enabled);
    } catch (error) {
      logger.error('error', 'ipc', 'scheduler.toggleTask', 'Failed to toggle task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SCHEDULER_GET_TASKS, async () => {
    try {
      return schedulerService.getTasks();
    } catch (error) {
      logger.error('error', 'ipc', 'scheduler.getTasks', 'Failed to get tasks', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SCHEDULER_GET_TASK, async (_event, id: string) => {
    try {
      return schedulerService.getTask(id);
    } catch (error) {
      logger.error('error', 'ipc', 'scheduler.getTask', 'Failed to get task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.SCHEDULER_RUN_NOW, async (_event, id: string): Promise<TaskExecutionResult> => {
    try {
      return schedulerService.runTaskNow(id);
    } catch (error) {
      logger.error('error', 'ipc', 'scheduler.runNow', 'Failed to run task', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- V2.1: OutputSpecService ------------------------------------------------
  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_INFO, async () => {
    return outputSpecService.getSpecPackInfo();
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_ACTIVE_PROFILE, async () => {
    return outputSpecService.getActiveProfile();
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_PROFILE, async (_event, profileId: string) => {
    return outputSpecService.getProfile(profileId);
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_TEMPLATE, async (_event, templateName?: string) => {
    return outputSpecService.getTemplate(templateName as 'default' | 'with-raw-content' | 'manual-minimal' ?? 'default');
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_TAG_RULES, async () => {
    return outputSpecService.getTagRules();
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_CATEGORY_RULES, async () => {
    return outputSpecService.getCategoryRules();
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_DISTILL_TEMPLATE, async (_event, templateName?: string) => {
    return outputSpecService.getDistillTemplate(
      templateName as 'obsidian' | 'plain' | 'summary' ?? 'obsidian',
    );
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_SNIPPET, async (_event, snippetName: string) => {
    return outputSpecService.getSnippet(snippetName as 'rawContentSection' | 'frontmatterBlock');
  });

  safeHandle(IPC_CHANNELS.OUTPUT_SPEC_GET_RAW_CONTENT_SECTION, async (_event, rawContent?: string) => {
    return outputSpecService.getRawContentSection(rawContent);
  });

  // -- V2.1: Content Pipeline ------------------------------------------------
  safeHandle(IPC_CHANNELS.PIPELINE_PROCESS_TEXT, async (_event, text: string, options?: {
    skipExport?: boolean;
    vaultPath?: string;
    defaultFolder?: string;
    source?: 'clipboard' | 'screenshot' | 'manual' | 'vault_import';
    project?: string;
  }) => {
    try {
      return await contentPipeline.processText(text, options);
    } catch (error) {
      logger.error('error', 'ipc', 'pipeline.processText', 'Pipeline processing failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIPELINE_GET_STATUS, async (_event, sourceItemId: string) => {
    try {
      return contentPipeline.getStatus(sourceItemId);
    } catch (error) {
      logger.error('error', 'ipc', 'pipeline.getStatus', 'Failed to get pipeline status', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIPELINE_RETRY_EXPORT, async (_event, sourceItemId: string) => {
    try {
      return await contentPipeline.retryExport(sourceItemId);
    } catch (error) {
      logger.error('error', 'ipc', 'pipeline.retryExport', 'Failed to retry export', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIPELINE_GET_STATE_HISTORY, async (_event, sourceItemId: string) => {
    try {
      return contentStateMachine.getHistory(sourceItemId);
    } catch (error) {
      logger.error('error', 'ipc', 'pipeline.getStateHistory', 'Failed to get state history', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIPELINE_CHECK_DUPLICATE, async (_event, text: string) => {
    try {
      const result = contentStateMachine.findDuplicate(text);
      return result ? { isDuplicate: true, sourceItemId: result.sourceItem.id, originalId: result.originalId } : { isDuplicate: false };
    } catch (error) {
      logger.error('error', 'ipc', 'pipeline.checkDuplicate', 'Failed to check duplicate', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // ─── V2.1 Phase 6.1: Unified Error Model ───────────────────────

  safeHandle(IPC_CHANNELS.ERRORS_LIST, async (_event, filter?: {
    status?: string;
    errorType?: string;
    originalId?: string;
    limit?: number;
    offset?: number;
  }) => {
    try {
      return errorService.listRecords(filter as any);
    } catch (error) {
      logger.error('error', 'ipc', 'errors.list', 'Failed to list error records', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.ERRORS_GET, async (_event, errorId: string) => {
    try {
      const record = errorService.getRecord(errorId);
      if (!record) {
        throw new Error(`ErrorRecord not found: ${errorId}`);
      }
      return record;
    } catch (error) {
      logger.error('error', 'ipc', 'errors.get', 'Failed to get error record', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.ERRORS_RESOLVE, async (_event, errorId: string) => {
    try {
      return errorService.resolveRecord(errorId);
    } catch (error) {
      logger.error('error', 'ipc', 'errors.resolve', 'Failed to resolve error record', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.ERRORS_DISMISS, async (_event, errorId: string) => {
    try {
      return errorService.dismissRecord(errorId);
    } catch (error) {
      logger.error('error', 'ipc', 'errors.dismiss', 'Failed to dismiss error record', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.ERRORS_CLEAR_RESOLVED, async () => {
    try {
      return errorService.clearResolved();
    } catch (error) {
      logger.error('error', 'ipc', 'errors.clearResolved', 'Failed to clear resolved records', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // ─── V2.1 Phase 6.3: Unified Retry ──────────────────────────────

  safeHandle(IPC_CHANNELS.RETRY_ERROR, async (_event, errorId: string) => {
    try {
      const { retryService } = await import('./retryService');
      return await retryService.retry(errorId);
    } catch (error) {
      logger.error('error', 'ipc', 'retry.error', 'Failed to retry error', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // ─── V2.1 Phase 6.5: Advanced Control Panel ─────────────────────

  safeHandle(IPC_CHANNELS.LOCAL_MODEL_STATUS, async () => {
    try {
      // Read model config from settings since localModelService may not be initialized
      const currentSettings = settings.load();
      const providers = currentSettings.providers ?? [];
      const enabledProviders = providers.filter((p) => p.enabled);
      const defaultTier = currentSettings.defaultTier ?? 'local_light';

      return {
        enabled: enabledProviders.length > 0,
        configuredModel: enabledProviders.find((p) => p.tier === defaultTier)?.modelId ?? '',
        effectiveModel: enabledProviders[0]?.modelId ?? '',
        providerCount: enabledProviders.length,
        defaultTier,
        providers: enabledProviders.map((p) => ({ name: p.name, model: p.modelId, tier: p.tier })),
      };
    } catch (error) {
      logger.error('error', 'ipc', 'localModel.getRuntimeStatus', 'Failed to get model status', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIPELINE_BATCH_PROCESSED_AT, async (_event, sourceItemIds: string[]) => {
    try {
      const db = storage.getDb();
      if (!db) return {};
      const result: Record<string, number | null> = {};
      for (const id of sourceItemIds) {
        const row = db.prepare(
          `SELECT MIN(created_at) as first_processed
           FROM content_state_history
           WHERE source_item_id = ? AND to_state = 'structured'`,
        ).get(id) as { first_processed: number | null } | undefined;
        result[id] = row?.first_processed ?? null;
      }
      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'pipeline.batchProcessedAt', 'Failed to get processedAt', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- V2.1 Phase 7.1: Unified Capture Adapter ---------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_RECORD, async (_event, input: CaptureInput) => {
    try {
      const captureRecord = captureRegistry.capture(input);
      // Process through the pipeline automatically
      const result = await contentPipeline.processCaptureRecord(captureRecord);
      return {
        success: result.success,
        stage: result.stage,
        sourceItemId: result.sourceItemId,
        error: result.error,
        captureRecord,
      };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.record', 'Failed to capture and process', {
        error: error instanceof Error ? error.message : String(error),
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'capture_record',
        error,
        userMessage: '内容收集失败，请重试。',
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_GET_AVAILABLE_TYPES, async () => {
    try {
      return captureRegistry.getAvailableTypes();
    } catch (error) {
      logger.error('error', 'ipc', 'capture.getAvailableTypes', 'Failed to get available types', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- V2.1 Phase 7.2: Clipboard text capture ----------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_COLLECT_CLIPBOARD, async () => {
    try {
      // 1. Read system clipboard text
      const rawText = clipboard.readText();
      const trimmed = rawText.trim();

      // 2. Empty check — do not create a record
      if (!trimmed) {
        logger.info('app', 'ipc', 'capture.collectClipboard', 'Clipboard is empty, skipping');
        errorService.recordError({
          errorType: 'capture_failed',
          stage: 'capture_clipboard',
          error: new Error('Clipboard is empty'),
          userMessage: '剪贴板内容为空，无法收集。',
        });
        return { success: false, reason: 'empty' };
      }

      // 3. Short text warning (non-blocking)
      if (trimmed.length < 10) {
        logger.info('app', 'ipc', 'capture.collectClipboard', 'Clipboard text is very short', {
          length: trimmed.length,
        });
      }

      // 4. Use clipboardTextAdapter to produce CaptureRecord
      const captureRecord = captureRegistry.capture({
        sourceType: 'clipboard_text',
        text: trimmed,
        sourceApp: 'AcMind',
      });

      // 5. Process through pipeline (includes dedup via original_id)
      const result = await contentPipeline.processCaptureRecord(captureRecord);

      logger.info('app', 'ipc', 'capture.collectClipboard', 'Clipboard text collected', {
        originalId: captureRecord.original_id,
        stage: result.stage,
        success: result.success,
      });

      return { success: result.success, stage: result.stage, sourceItemId: result.sourceItemId, error: result.error };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.collectClipboard', 'Failed to collect clipboard text', {
        error: error instanceof Error ? error.message : String(error),
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'capture_clipboard',
        error,
        userMessage: '收集剪贴板文本失败，请重试。',
      });
      throw error;
    }
  });

  // -- V2.1 Phase 7.3: Screenshot capture ------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_COLLECT_SCREENSHOT, async () => {
    try {
      // 1. Use Electron desktopCapturer to capture the primary screen
      const { desktopCapturer } = require('electron');
      const sources = await desktopCapturer.getSources({
        types: ['screen'],
        thumbnailSize: { width: 1920, height: 1080 },
      });

      if (!sources || sources.length === 0) {
        logger.warn('app', 'ipc', 'capture.collectScreenshot', 'No screen sources available');
        errorService.recordError({
          errorType: 'capture_failed',
          stage: 'capture_screenshot',
          error: new Error('No screen sources available'),
          userMessage: '未检测到屏幕源，无法截屏。',
        });
        return { success: false, error: 'No screen sources available' };
      }

      // Use the first (primary) screen source
      const source = sources[0];
      const thumbnail = source.thumbnail;

      if (!thumbnail || thumbnail.isEmpty()) {
        logger.warn('app', 'ipc', 'capture.collectScreenshot', 'Screenshot thumbnail is empty');
        errorService.recordError({
          errorType: 'capture_failed',
          stage: 'capture_screenshot',
          error: new Error('Screenshot thumbnail is empty'),
          userMessage: '截屏缩略图为空，请重试。',
        });
        return { success: false, error: 'Screenshot thumbnail is empty' };
      }

      const pngBuffer = thumbnail.toPNG();

      // 2. Determine save directory
      const storageRoot = resolveStorageRoot(DEFAULT_SETTINGS.storageRoot);
      const screenshotsDir = path.join(storageRoot, 'screenshots');
      if (!existsSync(screenshotsDir)) {
        mkdirSync(screenshotsDir, { recursive: true });
      }

      // 3. Use screenshotAdapter to produce CaptureRecord
      const captureRecord = captureRegistry.capture({
        sourceType: 'screenshot',
        buffer: pngBuffer,
        saveDir: screenshotsDir,
        sourceApp: 'AcMind',
      });

      // 4. Process through pipeline (includes dedup via original_id)
      const result = await contentPipeline.processCaptureRecord(captureRecord);

      logger.info('app', 'ipc', 'capture.collectScreenshot', 'Screenshot collected', {
        originalId: captureRecord.original_id,
        stage: result.stage,
        success: result.success,
        filePath: captureRecord.raw_file_path,
      });

      return { success: result.success, stage: result.stage, sourceItemId: result.sourceItemId, error: result.error };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.collectScreenshot', 'Failed to collect screenshot', {
        error: error instanceof Error ? error.message : String(error),
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'capture_screenshot',
        error,
        userMessage: '截屏收集失败，请重试。',
      });
      throw error;
    }
  });

  // -- V2.1 Phase 7.4: Webpage content capture --------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_COLLECT_WEBPAGE, async (_event, params: {
    url: string;
    title?: string;
    rawText?: string;
    fetchContent?: boolean;
  }) => {
    try {
      const { url, title, rawText, fetchContent } = params;

      // 1. Validate URL
      if (!url?.trim()) {
        errorService.recordError({
          errorType: 'capture_failed',
          stage: 'capture_webpage',
          error: new Error('URL is required'),
          userMessage: '网页 URL 为空，无法收集。',
        });
        return { success: false, error: 'URL is required' };
      }

      let finalTitle = title?.trim() || '';
      let finalRawText = rawText?.trim() || '';
      let inputMode: 'url_fetch' | 'paste' = rawText?.trim() ? 'paste' : 'url_fetch';

      // 2. If fetchContent mode (or no rawText provided), try to fetch the page
      if (fetchContent || !finalRawText) {
        try {
          const { convertUrlToMarkdown } = await import('./services/parser/markitdownService');
          const result = await convertUrlToMarkdown(url.trim());

          if (result.success && result.markdown) {
            finalRawText = result.markdown;
            if (!finalTitle && result.title) {
              finalTitle = result.title;
            }
            inputMode = 'url_fetch';
            logger.info('app', 'ipc', 'capture.collectWebpage', 'URL content fetched', {
              url,
              engine: result.engine,
              charCount: result.markdown.length,
            });
          } else {
            logger.warn('app', 'ipc', 'capture.collectWebpage', 'URL fetch failed, proceeding with available data', {
              url,
              error: result.error,
            });
            // Don't fail — proceed with whatever we have (URL only is fine)
          }
        } catch (fetchErr) {
          logger.warn('app', 'ipc', 'capture.collectWebpage', 'URL fetch error, proceeding with available data', {
            url,
            error: fetchErr instanceof Error ? fetchErr.message : String(fetchErr),
          });
        }
      }

      // 3. Use webpageAdapter to produce CaptureRecord
      const captureRecord = captureRegistry.capture({
        sourceType: 'webpage',
        url: url.trim(),
        title: finalTitle || undefined,
        rawText: finalRawText || undefined,
        sourceApp: 'AcMind',
        inputMode,
      });

      // 4. Process through pipeline (includes dedup via original_id)
      const result = await contentPipeline.processCaptureRecord(captureRecord);

      logger.info('app', 'ipc', 'capture.collectWebpage', 'Webpage content collected', {
        originalId: captureRecord.original_id,
        stage: result.stage,
        success: result.success,
        inputMode,
      });

      return { success: result.success, stage: result.stage, sourceItemId: result.sourceItemId, error: result.error };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.collectWebpage', 'Failed to collect webpage content', {
        error: error instanceof Error ? error.message : String(error),
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'capture_webpage',
        error,
        userMessage: '网页内容收集失败，请重试。',
      });
      throw error;
    }
  });

  // -- V2.1 Phase 7.5: File import -------------------------------------------
  safeHandle(IPC_CHANNELS.CAPTURE_COLLECT_FILE, async (_event, params: {
    filePath: string;
    title?: string;
  }) => {
    try {
      const { filePath, title } = params;

      // 1. Validate file path
      if (!filePath?.trim()) {
        errorService.recordError({
          errorType: 'capture_failed',
          stage: 'capture_file',
          error: new Error('File path is required'),
          userMessage: '文件路径为空，无法导入。',
        });
        return { success: false, error: 'File path is required' };
      }

      // 2. Use fileAdapter to produce CaptureRecord
      const captureRecord = captureRegistry.capture({
        sourceType: 'file',
        filePath: filePath.trim(),
        title: title?.trim() || undefined,
        sourceApp: 'AcMind',
      });

      // 3. Process through pipeline (includes dedup via original_id)
      const result = await contentPipeline.processCaptureRecord(captureRecord);

      logger.info('app', 'ipc', 'capture.collectFile', 'File imported', {
        originalId: captureRecord.original_id,
        stage: result.stage,
        success: result.success,
        filePath,
        readableText: captureRecord.metadata?.readable_text_available,
      });

      return { success: result.success, stage: result.stage, sourceItemId: result.sourceItemId, error: result.error };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.collectFile', 'Failed to import file', {
        error: error instanceof Error ? error.message : String(error),
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'capture_file',
        error,
        userMessage: '文件导入失败，请检查文件路径后重试。',
      });
      throw error;
    }
  });

  // -- V2.1 Phase 7.5: File selection dialog ---------------------------------
  safeHandle(IPC_CHANNELS.DIALOG_OPEN_FILE, async (_event, options?: {
    title?: string;
    filters?: { name: string; extensions: string[] }[];
  }) => {
    try {
      const win = BrowserWindow.getFocusedWindow();
      const result = await dialog.showOpenDialog(win!, {
        title: options?.title ?? '选择文件',
        filters: options?.filters ?? [{ name: '所有文件', extensions: ['*'] }],
        properties: ['openFile'],
      });
      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'dialog.openFile', 'Failed to open file dialog', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- Phase 10: Directory selection dialog ----------------------------------
  safeHandle(IPC_CHANNELS.DIALOG_SELECT_DIRECTORY, async (_event, options?: {
    title?: string;
  }) => {
    try {
      const win = BrowserWindow.getFocusedWindow();
      const result = await dialog.showOpenDialog(win!, {
        title: options?.title ?? '选择文件夹',
        properties: ['openDirectory'],
      });
      if (result.canceled || result.filePaths.length === 0) {
        return null;
      }
      return result.filePaths[0];
    } catch (error) {
      logger.error('error', 'ipc', 'dialog.selectDirectory', 'Failed to open directory dialog', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  // -- V2.1 Phase 8: AI Strategy & Regeneration ------------------------------
  safeHandle(IPC_CHANNELS.STRATEGY_REGENERATE, async (_event, params: {
    sourceItemId: string;
    regenerationTier?: AiTier;
    regenerationProfileId?: string;
  }) => {
    try {
      const { sourceItemId, regenerationTier, regenerationProfileId } = params;

      if (!sourceItemId?.trim()) {
        return { success: false, error: 'sourceItemId is required' };
      }

      const result = await contentPipeline.regenerateContent(sourceItemId, {
        regenerationTier,
        regenerationProfileId,
      });

      logger.info('app', 'ipc', 'strategy.regenerate', 'Content regeneration completed', {
        sourceItemId,
        success: result.success,
        regenerationTier,
        regenerationProfileId,
      });

      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'strategy.regenerate', 'Failed to regenerate content', {
        error: error instanceof Error ? error.message : String(error),
        sourceItemId: params.sourceItemId,
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // -- V2.1 Phase 10: Voice workflow -------------------------------------------
  safeHandle(IPC_CHANNELS.VOICE_IMPORT_AUDIO, async (_event, params: {
    filePath: string;
    title?: string;
  }) => {
    try {
      const { filePath, title } = params;
      if (!filePath?.trim()) {
        return { success: false, error: '文件路径为空' };
      }
      const result = await voiceWatchService.importAudioFile(filePath.trim(), title?.trim());
      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'voice.importAudio', 'Failed to import audio', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_GET_STATUS, async () => {
    try {
      return audioTranscriptionService.getRuntimeStatus();
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.getStatus', 'Failed to get whisper status', {
        error: error instanceof Error ? error.message : String(error),
      });
      return {
        status: 'error' as const,
        engine: null,
        message: error instanceof Error ? error.message : String(error),
      };
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_GET_MODELS, async () => {
    try {
      return audioTranscriptionService.getWhisperModels();
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.getModels', 'Failed to get whisper models', {
        error: error instanceof Error ? error.message : String(error),
      });
      return [];
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_DOWNLOAD_MODEL, async (_event, modelSize: string) => {
    try {
      const targetModel = modelSize as 'tiny' | 'base' | 'small';
      const progressEmitter = (progress: number) => {
        _event.sender.send(IPC_CHANNELS.WHISPER_DOWNLOAD_PROGRESS, progress);
      };
      await audioTranscriptionService.downloadBundledWhisperModel(targetModel, progressEmitter);
      return {
        success: true,
        skipped: false,
        modelSize,
        message: '本地 Whisper 模型已缓存到应用目录',
      };
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.downloadModel', 'Failed to handle whisper model download', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_OPEN_CACHE_DIR, async () => {
    try {
      const cacheDir = audioTranscriptionService.getWhisperModelCacheDir();
      mkdirSync(cacheDir, { recursive: true });
      const result = await shell.openPath(cacheDir);
      if (result) {
        return { success: false, error: result };
      }
      return { success: true, path: cacheDir };
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.openCacheDir', 'Failed to open whisper cache dir', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_DELETE_MODEL, async (_event, modelSize: string) => {
    try {
      audioTranscriptionService.deleteBundledWhisperModel(modelSize as 'tiny' | 'base' | 'small');
      return {
        success: true,
        skipped: false,
        modelSize,
        message: '本地 Whisper 模型缓存已删除',
      };
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.deleteModel', 'Failed to handle whisper model delete', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_INITIALIZE, async (_event, modelSize: string) => {
    try {
      const status = audioTranscriptionService.initializeWhisper();
      return { success: true, modelSize, ...status };
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.initialize', 'Failed to initialize whisper', {
        error: error instanceof Error ? error.message : String(error),
      });
      return {
        success: false,
        status: 'error' as const,
        engine: null,
        message: error instanceof Error ? error.message : String(error),
        modelSize,
      };
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_REPAIR, async (event) => {
    try {
      const progressEmitter = (progress: number) => {
        event.sender.send(IPC_CHANNELS.WHISPER_DOWNLOAD_PROGRESS, progress);
      };
      const result = await audioTranscriptionService.repairWhisperEnvironment(undefined, progressEmitter);
      return { success: true, ...result };
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.repair', 'Failed to repair whisper environment', {
        error: error instanceof Error ? error.message : String(error),
      });
      return {
        success: false,
        engine: null,
        repaired: false,
        message: error instanceof Error ? error.message : String(error),
      };
    }
  });

  safeHandle(IPC_CHANNELS.WHISPER_TRANSCRIBE, async (_event, audioData: Float32Array | number[] | ArrayBuffer, options?: {
    language?: string;
    translate?: boolean;
    sampleRate?: number;
  }) => {
    try {
      let pcm: Float32Array;
      if (audioData instanceof Float32Array) {
        pcm = audioData;
      } else if (Array.isArray(audioData)) {
        pcm = Float32Array.from(audioData);
      } else if (audioData instanceof ArrayBuffer) {
        pcm = new Float32Array(audioData);
      } else {
        return { success: false, error: '音频数据类型不支持' };
      }

      const result = await audioTranscriptionService.transcribePcm(pcm, options);
      return {
        success: true,
        text: result.text,
        engine: result.engine,
        elapsedMs: result.elapsedMs,
      };
    } catch (error) {
      logger.error('error', 'ipc', 'whisper.transcribe', 'Failed to transcribe audio', {
        error: error instanceof Error ? error.message : String(error),
      });
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });

  safeHandle('voice.importAudioBuffer', async (_event, params: {
    data: ArrayBuffer;
    mimeType?: string;
    title?: string;
  }) => {
    let tempFilePath: string | null = null;

    try {
      const { data, mimeType, title } = params;
      if (!(data instanceof ArrayBuffer) || data.byteLength === 0) {
        return { success: false, error: '音频数据为空' };
      }

      const storageRoot = settings.getStorageRoot();
      const tempDir = path.join(storageRoot, 'tmp', 'capsule-voice');
      mkdirSync(tempDir, { recursive: true });

      const ext = mimeType?.includes('webm')
        ? '.webm'
        : mimeType?.includes('ogg')
          ? '.ogg'
          : mimeType?.includes('wav')
            ? '.wav'
            : '.webm';
      tempFilePath = path.join(tempDir, `capsule-voice-${Date.now()}-${randomUUID()}${ext}`);

      writeFileSync(tempFilePath, Buffer.from(data));

      const result = await voiceWatchService.importAudioFile(tempFilePath, title?.trim());
      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'voice.importAudioBuffer', 'Failed to import audio buffer', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    } finally {
      if (tempFilePath) {
        try {
          unlinkSync(tempFilePath);
        } catch {
          // ignore temp cleanup failures
        }
      }
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_START_WATCH, async (_event, params: {
    folderPath: string;
  }) => {
    try {
      const { folderPath } = params;
      if (!folderPath?.trim()) {
        return { success: false, error: '文件夹路径为空' };
      }
      const result = voiceWatchService.startWatching(folderPath.trim());
      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'voice.startWatch', 'Failed to start voice watch', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_STOP_WATCH, async () => {
    try {
      voiceWatchService.stopWatching();
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'voice.stopWatch', 'Failed to stop voice watch', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_GET_WATCH_STATE, async () => {
    try {
      return voiceWatchService.getState();
    } catch (error) {
      logger.error('error', 'ipc', 'voice.getWatchState', 'Failed to get watch state', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { status: 'error', watchPath: null, error: String(error), importedCount: 0, pendingCount: 0 };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_RETRY_TRANSCRIPTION, async (_event, params: {
    captureItemId: string;
  }) => {
    try {
      const { captureItemId } = params;
      if (!captureItemId?.trim()) {
        return { success: false, error: 'captureItemId is required' };
      }
      const result = await audioTranscriptionService.retryTranscription(captureItemId.trim());
      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'voice.retryTranscription', 'Failed to retry transcription', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_GET_TRANSCRIPTION_STATUS, async (_event, params: {
    captureItemId: string;
  }) => {
    try {
      const { captureItemId } = params;
      if (!captureItemId?.trim()) {
        return { transcriptStatus: 'not_started' };
      }
      return audioTranscriptionService.getTranscriptionStatus(captureItemId.trim());
    } catch (error) {
      logger.error('error', 'ipc', 'voice.getTranscriptionStatus', 'Failed to get transcription status', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { transcriptStatus: 'not_started' };
    }
  });

  // ── Phase 12.6: Local Diagnostics Export ────────────────────────

  safeHandle(IPC_CHANNELS.DIAGNOSTICS_EXPORT, async () => {
    try {
      const filePath = logger.exportDiagnostics();
      return { success: true, filePath };
    } catch (error) {
      logger.error('error', 'ipc', 'diagnostics.export', 'Failed to export diagnostics', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // ── Phase 0: AcMind 模块 IPC 边界 ──────────────────────────────

  // clipboard.*
  safeHandle(IPC_CHANNELS.CLIPBOARD_LIST_ITEMS, async (_event, params?: { limit?: number; offset?: number }) => {
    try {
      const items = storage.listClipboardItems(params?.limit ?? 100, params?.offset ?? 0);
      return { success: true, items };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.listItems', 'Failed to list clipboard items', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, items: [] };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_GET_ITEM, async (_event, params: { id: string }) => {
    try {
      const item = storage.getClipboardItem(params.id);
      return { success: true, item };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.getItem', 'Failed to get clipboard item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, item: null };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_PIN_ITEM, async (_event, params: { id: string }) => {
    try {
      storage.updateClipboardItemPinned(params.id, true);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.pinItem', 'Failed to pin clipboard item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_UNPIN_ITEM, async (_event, params: { id: string }) => {
    try {
      storage.updateClipboardItemPinned(params.id, false);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.unpinItem', 'Failed to unpin clipboard item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_DELETE_ITEM, async (_event, params: { id: string }) => {
    try {
      storage.deleteClipboardItem(params.id);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.deleteItem', 'Failed to delete clipboard item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_SAVE_TO_INBOX, async (_event, params: { id: string }) => {
    try {
      const item = storage.getClipboardItem(params.id);
      if (!item) return { success: false, error: 'Clipboard item not found' };

      // Check if already saved to inbox
      if (item.sourceItemId) {
        const existing = storage.getSourceItem(item.sourceItemId);
        if (existing) {
          return { success: true, sourceItem: existing, alreadySaved: true };
        }
      }

      // Determine SourceItem type based on content
      let sourceType: SourceItem['type'] = 'text';
      let contentPath = '';
      const newId = randomUUID();
      if (item.contentType === 'url') sourceType = 'url';
      else if (item.contentType === 'image') {
        sourceType = 'image';
        // Resolve contentPath from asset files if available
        if (item.assetFileIds && item.assetFileIds.length > 0) {
          const firstAsset = storage.getAssetFile(item.assetFileIds[0]);
          if (firstAsset?.localPath && existsSync(firstAsset.localPath)) {
            contentPath = firstAsset.localPath;
          }
        }
      } else if (item.text) {
        // For text items, materialize content to a file
        const storageRoot = settings.getStorageRoot();
        const dateDir = new Date().toISOString().slice(0, 10);
        const sourcesDir = path.join(storageRoot, 'sources', dateDir);
        mkdirSync(sourcesDir, { recursive: true });
        contentPath = path.join(sourcesDir, `${newId}.txt`);
        writeFileSync(contentPath, item.text, 'utf8');
      }

      const sourceItem: SourceItem = {
        id: newId,
        type: sourceType,
        source: 'clipboard',
        contentPath,
        status: 'inbox',
        previewText: item.text?.slice(0, 200),
        originalUrl: item.contentType === 'url' ? item.text : undefined,
        createdAt: Date.now(),
      };
      storage.insertSourceItem(sourceItem);

      // Link ClipboardItem to SourceItem
      storage.updateClipboardItemSourceItemId(params.id, sourceItem.id);

      // Link asset files to the new SourceItem (for image items)
      if (item.assetFileIds) {
        for (const assetFileId of item.assetFileIds) {
          storage.updateAssetFileSourceItemId(assetFileId, sourceItem.id);
        }
      }

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.CLIPBOARD_ITEMS_CHANGED, { timestamp: Date.now() });
          win.webContents.send(IPC_CHANNELS.RECORDS_CHANGED, { action: 'clipboard_saved', id: sourceItem.id, timestamp: Date.now() });
        }
      }

      return { success: true, sourceItem };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.saveToInbox', 'Failed to save clipboard item to inbox', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_SEARCH_ITEMS, async (_event, params: { query: string; contentType?: string }) => {
    try {
      if (!params.query || !params.query.trim()) {
        return { success: true, items: [] };
      }
      const items = storage.searchClipboardItems(params.query.trim(), params.contentType);
      return { success: true, items };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.searchItems', 'Failed to search clipboard items', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, items: [] };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_COPY_ITEM, async (_event, params: { id: string }) => {
    try {
      const item = storage.getClipboardItem(params.id);
      if (!item) return { success: false, error: 'Clipboard item not found' };
      if (!item.text) return { success: false, error: 'Item has no text content' };

      // Write to system clipboard and tell watcher to ignore the next copy
      clipboard.writeText(item.text);
      clipboardWatcher.ignoreNextCopy(1);

      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.copyItem', 'Failed to copy clipboard item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_CLEAR_HISTORY, async () => {
    try {
      storage.clearClipboardItems();
      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.CLIPBOARD_ITEMS_CHANGED, { timestamp: Date.now() });
        }
      }
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'clipboard.clearHistory', 'Failed to clear clipboard history', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_PAUSE, async () => {
    try {
      captureService.pauseClipboard();
      return { success: true };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_RESUME, async () => {
    try {
      captureService.resumeClipboard();
      return { success: true };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CLIPBOARD_IS_PAUSED, async () => {
    try {
      return { success: true, paused: captureService.isClipboardPaused() };
    } catch (error) {
      return { success: false, paused: false };
    }
  });

  // shelf.*
  safeHandle(IPC_CHANNELS.SHELF_LIST_ITEMS, async (_event, params?: { status?: string }) => {
    try {
      const items = storage.listShelfItems(params?.status as ShelfItem['status'] | undefined);
      return { success: true, items };
    } catch (error) {
      logger.error('error', 'ipc', 'shelf.listItems', 'Failed to list shelf items', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, items: [] };
    }
  });

  safeHandle(IPC_CHANNELS.SHELF_GET_ITEM, async (_event, params: { id: string }) => {
    try {
      const item = storage.getShelfItem(params.id);
      return { success: true, item };
    } catch (error) {
      logger.error('error', 'ipc', 'shelf.getItem', 'Failed to get shelf item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, item: null };
    }
  });

  safeHandle(IPC_CHANNELS.SHELF_ADD_FILES, async (_event, params: { filePaths: string[]; label?: string }) => {
    try {
      if (!params.filePaths || params.filePaths.length === 0) {
        return { success: false, error: 'No files provided' };
      }

      // Create asset files for each file
      const assetFileIds: string[] = [];
      for (const filePath of params.filePaths) {
        const ext = path.extname(filePath).toLowerCase();
        const kind = inferFileKind(ext);
        const assetFile: AssetFile = {
          id: randomUUID(),
          kind,
          originalName: filePath.split('/').pop() || filePath,
          localPath: filePath,
          createdAt: Date.now(),
        };
        storage.insertAssetFile(assetFile);
        assetFileIds.push(assetFile.id);
      }

      const label = params.label || params.filePaths.map(p => p.split('/').pop()).join(', ');
      const item: ShelfItem = {
        id: randomUUID(),
        assetFileIds,
        label,
        origin: 'drag_drop',
        status: 'temporary',
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      storage.insertShelfItem(item);

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.SHELF_ITEMS_CHANGED, { timestamp: Date.now() });
        }
      }

      return { success: true, item };
    } catch (error) {
      logger.error('error', 'ipc', 'shelf.addFiles', 'Failed to add files to shelf', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.SHELF_ADD_TEXT, async (_event, params: { text: string; label?: string }) => {
    try {
      if (!params.text || !params.text.trim()) {
        return { success: false, error: 'Text is empty' };
      }

      const item: ShelfItem = {
        id: randomUUID(),
        assetFileIds: [],
        label: params.label ?? params.text.slice(0, 50),
        origin: 'manual',
        status: 'temporary',
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      storage.insertShelfItem(item);

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.SHELF_ITEMS_CHANGED, { timestamp: Date.now() });
        }
      }

      return { success: true, item };
    } catch (error) {
      logger.error('error', 'ipc', 'shelf.addText', 'Failed to add text to shelf', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.SHELF_REMOVE_ITEM, async (_event, params: { id: string }) => {
    try {
      storage.deleteShelfItem(params.id);

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.SHELF_ITEMS_CHANGED, { timestamp: Date.now() });
        }
      }

      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'shelf.removeItem', 'Failed to remove shelf item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.SHELF_SAVE_TO_INBOX, async (_event, params: { id: string }) => {
    try {
      const item = storage.getShelfItem(params.id);
      if (!item) return { success: false, error: 'Shelf item not found' };

      // Check if already saved
      if (item.sourceItemId) {
        const existing = storage.getSourceItem(item.sourceItemId);
        if (existing) {
          return { success: true, sourceItem: existing, alreadySaved: true };
        }
      }

      // Determine source type based on content
      let sourceType: SourceItem['type'] = 'text';
      let contentPath = '';
      if (item.assetFileIds.length > 0) {
        // Check first asset to determine type
        const firstAsset = storage.getAssetFile(item.assetFileIds[0]);
        if (firstAsset) {
          if (firstAsset.kind === 'image') sourceType = 'image';
          else if (firstAsset.kind === 'html') sourceType = 'url';
          else if (firstAsset.kind === 'pdf' || firstAsset.kind === 'docx' || firstAsset.kind === 'markdown') sourceType = 'text';
          // Set contentPath to the first asset file so getSourceItemContent() can read it
          if (firstAsset.localPath && existsSync(firstAsset.localPath)) {
            contentPath = firstAsset.localPath;
          }
        }
      }

      const sourceItem: SourceItem = {
        id: randomUUID(),
        type: sourceType,
        source: 'manual',
        contentPath,
        status: 'inbox',
        title: item.label,
        createdAt: Date.now(),
      };
      storage.insertSourceItem(sourceItem);

      // Link shelf item to source item
      storage.updateShelfItemSourceItemId(params.id, sourceItem.id);
      storage.updateShelfItemStatus(params.id, 'saved_to_inbox');

      // Link all asset files to the new SourceItem
      for (const assetFileId of item.assetFileIds) {
        storage.updateAssetFileSourceItemId(assetFileId, sourceItem.id);
      }

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.SHELF_ITEMS_CHANGED, { timestamp: Date.now() });
          win.webContents.send(IPC_CHANNELS.RECORDS_CHANGED, { action: 'shelf_saved', id: sourceItem.id, timestamp: Date.now() });
        }
      }

      return { success: true, sourceItem };
    } catch (error) {
      logger.error('error', 'ipc', 'shelf.saveToInbox', 'Failed to save shelf item to inbox', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // ── Phase 2A: capture.* ──────────────────────────────────────────

  safeHandle(IPC_CHANNELS.CAPTURE_START_AREA, async () => {
    try {
      // 触发区域截图：先全屏截图，返回路径供 overlay 使用
      // 实际区域裁剪由 renderer CaptureOverlay 完成后调用 capture.screenshot
      const success = await captureService.captureScreenshot();
      return { success };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.startAreaCapture', 'Failed to start area capture', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_CANCEL, async () => {
    try {
      // 取消截图（当前为 stub，实际取消由 renderer overlay 处理）
      return { success: true };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_PIN_IMAGE, async (_event, params: { filePath: string; sourceItemId?: string }) => {
    try {
      if (!params.filePath) {
        return { success: false, error: 'filePath is required' };
      }
      const pinned = pinnedImageController.pinImage(params.filePath, params.sourceItemId);
      if (!pinned) {
        return { success: false, error: 'Failed to pin image' };
      }
      return { success: true, pinnedImage: pinned };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.pinImage', 'Failed to pin image', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_SAVE_TO_INBOX, async (_event, params: { id: string }) => {
    try {
      const result = pinnedImageController.saveToInbox(params.id);
      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'capture.saveToInbox', 'Failed to save pinned image to inbox', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_LIST_RECENT, async (_event, params?: { limit?: number }) => {
    try {
      const items = captureService.listRecentCaptures(params?.limit ?? 50);
      return { success: true, items };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.listRecentCaptures', 'Failed to list recent captures', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, items: [] };
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_LIST_PINNED, async () => {
    try {
      const pinnedImages = pinnedImageController.listPinnedImages();
      return { success: true, pinnedImages };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.listPinnedImages', 'Failed to list pinned images', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, pinnedImages: [] };
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_CLOSE_PINNED, async (_event, params: { id: string }) => {
    try {
      pinnedImageController.closePinnedImage(params.id);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.closePinnedImage', 'Failed to close pinned image', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // ── Phase 2B: OCR ────────────────────────────────────────────────

  safeHandle(IPC_CHANNELS.CAPTURE_OCR_EXTRACT, async (_event, params: { imagePath: string; language?: string }) => {
    try {
      if (!params.imagePath) {
        return { success: false, error: 'imagePath is required' };
      }
      const result = await ocrService.extractText(params.imagePath, params.language);
      return { success: true, ...result };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.ocrExtract', 'Failed to extract OCR text', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, text: '', error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.CAPTURE_OCR_SAVE_TO_INBOX, async (_event, params: { text: string; sourceImagePath?: string }) => {
    try {
      if (!params.text || !params.text.trim()) {
        return { success: false, error: 'OCR text is empty' };
      }

      const sourceItem: SourceItem = {
        id: randomUUID(),
        type: 'text',
        source: 'screenshot',
        contentPath: '',
        previewText: params.text.slice(0, 200),
        status: 'inbox',
        createdAt: Math.floor(Date.now() / 1000),
        ocrText: params.text,
      };
      storage.insertSourceItem(sourceItem);

      // Notify renderer
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.RECORDS_CHANGED, { action: 'ocr_saved', id: sourceItem.id, timestamp: Date.now() });
        }
      }

      return { success: true, sourceItem };
    } catch (error) {
      logger.error('error', 'ipc', 'capture.ocrSaveToInbox', 'Failed to save OCR text to inbox', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // aiRuntime.*
  safeHandle(IPC_CHANNELS.AI_RUNTIME_LIST_ACTIONS, async (_event, params?: { enabledOnly?: boolean }) => {
    try {
      const actions = storage.listAIActions(params?.enabledOnly ?? false);
      return { success: true, actions };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.listActions', 'Failed to list AI actions', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, actions: [] };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_GET_ACTION, async (_event, params: { id: string }) => {
    try {
      const action = storage.getAIAction(params.id);
      return { success: true, action };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.getAction', 'Failed to get AI action', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, action: null };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_CREATE_ACTION, async (_event, params: { name: string; inputTypes: SourceType[]; actionType: AIAction['actionType']; promptProfileId?: string }) => {
    try {
      const action: AIAction = {
        id: randomUUID(),
        name: params.name,
        inputTypes: params.inputTypes,
        actionType: params.actionType,
        promptProfileId: params.promptProfileId,
        enabled: true,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      storage.insertAIAction(action);
      return { success: true, action };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.createAction', 'Failed to create AI action', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_UPDATE_ACTION, async (_event, params: { id: string; updates: Partial<Pick<AIAction, 'name' | 'inputTypes' | 'actionType' | 'promptProfileId' | 'enabled'>> }) => {
    try {
      const existing = storage.getAIAction(params.id);
      if (!existing) return { success: false, error: 'AI action not found' };
      const updated: AIAction = { ...existing, ...params.updates, updatedAt: Date.now() };
      storage.updateAIAction(updated);
      return { success: true, action: updated };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.updateAction', 'Failed to update AI action', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_DELETE_ACTION, async (_event, params: { id: string }) => {
    try {
      storage.deleteAIAction(params.id);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.deleteAction', 'Failed to delete AI action', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_RUN_ACTION, async (_event, params: { actionId: string; input: string; sourceType?: SourceType }) => {
    try {
      const action = storage.getAIAction(params.actionId);
      if (!action) return { success: false, error: 'AI action not found' };
      if (!action.enabled) return { success: false, error: 'AI action is disabled' };

      const result = await aiActionRunner.run(action, params.input, params.sourceType);

      // 通知渲染进程任务状态变化
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.AI_RUNTIME_JOB_CHANGED, { timestamp: Date.now() });
        }
      }

      return {
        success: result.success,
        taskId: result.taskId,
        content: result.content,
        rawText: result.rawText,
        modelCall: result.modelCall,
        routingReason: result.routingReason,
        qualityScore: result.qualityScore,
        usedFallback: result.usedFallback,
        error: result.error,
      };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.runAction', 'Failed to run AI action', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_LIST_JOBS, async (_event, params?: { status?: string }) => {
    try {
      const tasks = storage.getAiTasks(params?.status ? { status: params.status as AiTaskStatus } : undefined);
      return { success: true, jobs: tasks };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.listJobs', 'Failed to list AI jobs', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, jobs: [] };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_GET_JOB, async (_event, params: { id: string }) => {
    try {
      const task = storage.getAiTask(params.id);
      return { success: true, job: task };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.getJob', 'Failed to get AI job', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, job: null };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_CANCEL_JOB, async (_event, params: { id: string }) => {
    try {
      storage.updateAiTask(params.id, { status: 'cancelled' });
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.cancelJob', 'Failed to cancel AI job', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.AI_RUNTIME_HEALTH_CHECK, async (_event, params: { providerId: string }) => {
    try {
      const providers = storage.getProviderConfigs();
      const provider = providers.find((p) => p.id === params.providerId);
      if (!provider) return { success: false, error: 'Provider not found' };
      const result = await aiProviderService.healthCheck(provider);
      return { success: true, ...result };
    } catch (error) {
      logger.error('error', 'ipc', 'aiRuntime.healthCheck', 'Health check failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // ── Pin Pool ──────────────────────────────────────────────────

  safeHandle(IPC_CHANNELS.PIN_POOL_LIST, async (_event, filter?: import('../shared/types').PinItemListFilter) => {
    try {
      return storage.listPinItems(filter);
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.list', 'Failed to list pin items', {
        error: error instanceof Error ? error.message : String(error),
      });
      return [];
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_GET, async (_event, id: string) => {
    try {
      return storage.getPinItem(id);
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.get', 'Failed to get pin item', {
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_CREATE_FROM_TEXT, async (_event, text: string, title?: string) => {
    try {
      const { randomUUID: uuid } = await import('node:crypto');
      const now = Math.floor(Date.now() / 1000);
      const pin: import('../shared/types').PinItem = {
        id: uuid(),
        captureItemId: '',
        originalId: uuid(),
        sourceType: 'manual_text',
        title: title || text.slice(0, 32) || '未命名 Pin',
        previewText: text.slice(0, 180),
        rawText: text,
        status: 'pinned',
        createdAt: now,
        pinnedAt: now,
        updatedAt: now,
      };
      storage.insertPinItem(pin);
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.PIN_POOL_CHANGED, { action: 'created', id: pin.id, timestamp: now });
        }
      }
      return pin;
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.createFromText', 'Failed to create pin from text', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_CREATE_FROM_CAPTURE, async (_event, captureItemId: string, overrides?: Partial<import('../shared/types').PinItem>) => {
    try {
      const { randomUUID: uuid } = await import('node:crypto');
      const captureItem = storage.getCaptureItem(captureItemId);
      if (!captureItem) throw new Error('Capture item not found');
      const now = Math.floor(Date.now() / 1000);
      const pin: import('../shared/types').PinItem = {
        id: uuid(),
        captureItemId,
        originalId: captureItemId,
        sourceType: 'clipboard_text',
        title: captureItem.title || captureItem.rawText?.slice(0, 32) || '未命名 Pin',
        previewText: captureItem.rawText?.slice(0, 180),
        rawText: captureItem.rawText,
        status: 'pinned',
        createdAt: now,
        pinnedAt: now,
        updatedAt: now,
        ...overrides,
      };
      storage.insertPinItem(pin);
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.PIN_POOL_CHANGED, { action: 'created', id: pin.id, timestamp: now });
        }
      }
      return pin;
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.createFromCapture', 'Failed to create pin from capture', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_PREFILTER, async (_event, id: string) => {
    try {
      const pin = storage.getPinItem(id);
      if (!pin) throw new Error('Pin item not found');
      const content = pin.rawText || pin.previewText || '';
      const { mockDistiller } = await import('./services/distiller/mockDistiller');
      const result = await mockDistiller.runTask('prefilter', { content });
      storage.updatePinItem(id, { prefilterResult: result });
      const updated = storage.getPinItem(id)!;
      return { pin: updated, result };
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.prefilter', 'Failed to prefilter pin', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_PROMOTE_TO_INBOX, async (_event, id: string) => {
    try {
      const pin = storage.getPinItem(id);
      if (!pin) throw new Error('Pin item not found');
      const sourceItem: SourceItem = {
        id: randomUUID(),
        type: 'text',
        source: 'manual',
        contentPath: '',
        status: 'inbox',
        title: pin.title,
        previewText: pin.previewText,
        createdAt: Date.now(),
      };
      storage.insertSourceItem(sourceItem);
      storage.updatePinItem(id, { status: 'promoted' });
      emitRecordsChanged('created', sourceItem.id);
      return { pin: storage.getPinItem(id)!, sourceItem };
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.promoteToInbox', 'Failed to promote pin to inbox', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_UPDATE, async (_event, id: string, patch: Partial<import('../shared/types').PinItem>) => {
    try {
      storage.updatePinItem(id, patch);
      return storage.getPinItem(id);
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.update', 'Failed to update pin', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_IGNORE, async (_event, id: string) => {
    try {
      storage.updatePinItem(id, { status: 'ignored' });
      return storage.getPinItem(id);
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.ignore', 'Failed to ignore pin', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  });

  safeHandle(IPC_CHANNELS.PIN_POOL_DELETE, async (_event, id: string) => {
    try {
      storage.deletePinItem(id);
      return true;
    } catch (error) {
      logger.error('error', 'ipc', 'pinPool.delete', 'Failed to delete pin', {
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  });

  // ── Voice Workflow (Phase 10) ─────────────────────────────────

  safeHandle(IPC_CHANNELS.VOICE_GET_DICTATION_GUIDE, async () => {
    try {
      return { success: true, guide: '按住录音按钮说话，松开后自动转写并整理。' };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_GET_DICTATION_DIAGNOSTICS, async () => {
    try {
      const [recorder, asrStatus] = await Promise.all([
        getRecorderAvailability(),
        Promise.resolve(asrProvider.getStatus()),
      ]);

      const whisperStatus = await audioTranscriptionService.getRuntimeStatus();
      const items: import('../shared/types').DictationDiagnosticItem[] = [
        {
          key: 'browser_microphone',
          label: '浏览器麦克风',
          ok: true,
          message: '前端会在点击自检时尝试获取麦克风权限并立即释放。',
        },
        {
          key: 'recorder_tool',
          label: '录音工具',
          ok: recorder.available,
          message: recorder.message,
        },
        {
          key: 'asr_provider',
          label: 'ASR 配置',
          ok: asrStatus.configured,
          message: asrStatus.message,
        },
        {
          key: 'whisper_runtime',
          label: '本地转写引擎',
          ok: whisperStatus.status === 'ready',
          message: whisperStatus.message,
        },
      ];

      return {
        ok: items.every((item) => item.ok),
        checkedAt: Date.now(),
        items,
      } satisfies import('../shared/types').DictationDiagnosticReport;
    } catch (error) {
      logger.error('error', 'ipc', 'voice.getDictationDiagnostics', 'Failed to build dictation diagnostics', {
        error: error instanceof Error ? error.message : String(error),
      });
      return {
        ok: false,
        checkedAt: Date.now(),
        items: [],
      } satisfies import('../shared/types').DictationDiagnosticReport;
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_REQUEST_MICROPHONE_ACCESS, async () => {
    try {
      if (process.platform !== 'darwin') {
        return { success: false, supported: false, granted: false, message: '麦克风授权请求仅在 macOS 上可用。' };
      }

      const { systemPreferences } = await import('electron');
      const granted = await systemPreferences.askForMediaAccess('microphone');
      return {
        success: true,
        supported: true,
        granted,
        message: granted
          ? '麦克风权限已授权。'
          : '麦克风权限尚未授权。请在系统提示中允许，或到系统设置中开启。',
      };
    } catch (error) {
      logger.error('error', 'ipc', 'voice.requestMicrophoneAccess', 'Failed to request microphone access', {
        error: error instanceof Error ? error.message : String(error),
      });
      return {
        success: false,
        supported: false,
        granted: false,
        message: error instanceof Error ? error.message : String(error),
      };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_POLISH_TRANSCRIPT, async (_event, request: import('../shared/types').VoicePolishRequest) => {
    try {
      const { polishTranscriptLocally } = await import('./voice/polish');
      const result = polishTranscriptLocally(request);
      return { success: true, result };
    } catch (error) {
      logger.error('error', 'ipc', 'voice.polishTranscript', 'Failed to polish transcript', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_CREATE_PIN_FROM_TRANSCRIPT, async (_event, request: import('../shared/types').VoiceCreatePinRequest) => {
    try {
      const { randomUUID: uuid } = await import('node:crypto');
      const now = Math.floor(Date.now() / 1000);
      const text = request.polishedText || request.transcript;
      const pin: import('../shared/types').PinItem = {
        id: uuid(),
        captureItemId: '',
        originalId: uuid(),
        sourceType: 'audio',
        title: request.title || text.slice(0, 32) || '语音 Pin',
        previewText: text.slice(0, 180),
        rawText: text,
        status: 'pinned',
        createdAt: now,
        pinnedAt: now,
        updatedAt: now,
      };
      storage.insertPinItem(pin);
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send(IPC_CHANNELS.PIN_POOL_CHANGED, { action: 'created', id: pin.id, timestamp: now });
        }
      }
      return { success: true, pin };
    } catch (error) {
      logger.error('error', 'ipc', 'voice.createPinFromTranscript', 'Failed to create pin from transcript', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // ── DistilledNotes ────────────────────────────────────────────

  safeHandle(IPC_CHANNELS.DISTILLED_NOTES_LIST, async (_event, params?: { limit?: number; offset?: number }) => {
    try {
      const notes = storage.listDistilledNotes(params);
      return { success: true, notes };
    } catch (error) {
      logger.error('error', 'ipc', 'distilledNotes.list', 'Failed to list distilled notes', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, notes: [] };
    }
  });

  safeHandle(IPC_CHANNELS.DISTILLED_NOTES_GET, async (_event, params: { id: string }) => {
    try {
      const note = storage.getDistilledNote(params.id);
      return { success: true, note };
    } catch (error) {
      logger.error('error', 'ipc', 'distilledNotes.get', 'Failed to get distilled note', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, note: null };
    }
  });

  safeHandle(IPC_CHANNELS.DISTILLED_NOTES_CREATE, async (_event, params: { note: import('../shared/types').DistilledNote }) => {
    try {
      storage.insertDistilledNote(params.note);
      return { success: true, note: params.note };
    } catch (error) {
      logger.error('error', 'ipc', 'distilledNotes.create', 'Failed to create distilled note', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.DISTILLED_NOTES_UPDATE, async (_event, params: { id: string; patch: Partial<import('../shared/types').DistilledNote> }) => {
    try {
      storage.updateDistilledNote(params.id, params.patch);
      const note = storage.getDistilledNote(params.id);
      return { success: true, note };
    } catch (error) {
      logger.error('error', 'ipc', 'distilledNotes.update', 'Failed to update distilled note', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.DISTILLED_NOTES_DELETE, async (_event, params: { id: string }) => {
    try {
      storage.deleteDistilledNote(params.id);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'distilledNotes.delete', 'Failed to delete distilled note', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  // ── VaultSearch ───────────────────────────────────────────────

  safeHandle(IPC_CHANNELS.VAULT_SEARCH, async (_event, params: { keyword: string; folderPath?: string; limit?: number }) => {
    try {
      if (!params.keyword || !params.keyword.trim()) {
        return { success: false, error: 'keyword is required', results: [] };
      }
      const vaultPath = storage.getSetting('obsidian_vault_path');
      if (!vaultPath) {
        return { success: false, error: 'Vault path not configured', results: [] };
      }
      const results = vaultScanner.search(vaultPath, params.keyword, {
        limit: params.limit ?? 50,
        folderPath: params.folderPath,
      });
      return { success: true, results };
    } catch (error) {
      logger.error('error', 'ipc', 'vaultSearch.search', 'Failed to search vault', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, results: [], error: error instanceof Error ? error.message : String(error) };
    }
  });

  // ── Voice Dictionary ───────────────────────────────────────────

  safeHandle(IPC_CHANNELS.VOICE_DICTIONARY_LIST, async () => {
    try {
      const entries = voiceDictionaryStore.list();
      return { success: true, entries };
    } catch (error) {
      logger.error('error', 'ipc', 'voiceDictionary.list', 'Failed to list dictionary', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, entries: [] };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_DICTIONARY_ADD, async (_event, params: { phrase: string; note?: string }) => {
    try {
      const entry = voiceDictionaryStore.add(params.phrase, params.note);
      return { success: true, entry };
    } catch (error) {
      logger.error('error', 'ipc', 'voiceDictionary.add', 'Failed to add dictionary entry', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_DICTIONARY_DELETE, async (_event, params: { id: string }) => {
    try {
      voiceDictionaryStore.remove(params.id);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'voiceDictionary.delete', 'Failed to delete dictionary entry', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.VOICE_DICTIONARY_TOGGLE, async (_event, params: { id: string; enabled: boolean }) => {
    try {
      voiceDictionaryStore.toggle(params.id, params.enabled);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'voiceDictionary.toggle', 'Failed to toggle dictionary entry', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  // ── ASR Provider ───────────────────────────────────────────────

  safeHandle(IPC_CHANNELS.ASR_GET_STATUS, async () => {
    try {
      const status = asrProvider.getStatus();
      return { success: true, status };
    } catch (error) {
      logger.error('error', 'ipc', 'asr.getStatus', 'Failed to get ASR status', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, status: { provider: 'none', configured: false, message: 'Error' } };
    }
  });

  safeHandle(IPC_CHANNELS.ASR_TRANSCRIBE, async (_event, params: { filePath: string; language?: string; translate?: boolean; prompt?: string }) => {
    try {
      const result = await asrProvider.transcribe(params.filePath, {
        language: params.language,
        translate: params.translate,
        prompt: params.prompt,
      });
      return { success: result.success, text: result.text, error: result.error, engine: result.engine };
    } catch (error) {
      logger.error('error', 'ipc', 'asr.transcribe', 'Failed to transcribe', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, text: '', error: error instanceof Error ? error.message : String(error) };
    }
  });

  // ─── Dictation (OpenLess-inspired) ─────────────────────────────
  safeHandle('dictation:start', async () => {
    try {
      await dictationCoordinator.beginSession();
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'dictation.start', 'Failed to start dictation', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle('dictation:stop', async () => {
    try {
      await dictationCoordinator.endSession();
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'dictation.stop', 'Failed to stop dictation', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle('dictation:cancel', async () => {
    dictationCoordinator.cancelSession();
    return { success: true };
  });

  safeHandle('dictation:getHistory', async (_event, params?: { limit?: number; offset?: number }) => {
    try {
      const store = getDictationHistoryStore(settings.getStorageRoot());
      return store.list(params?.limit, params?.offset);
    } catch (error) {
      logger.error('error', 'ipc', 'dictation.getHistory', 'Failed to get history', {
        error: error instanceof Error ? error.message : String(error),
      });
      return [];
    }
  });

  safeHandle('dictation:clearHistory', async () => {
    try {
      const store = getDictationHistoryStore(settings.getStorageRoot());
      store.clear();
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'dictation.clearHistory', 'Failed to clear history', {
        error: error instanceof Error ? error.message : String(error),
      });
      return { success: false };
    }
  });

  // ─── Batch 4: Dashboard Stats ─────────────────────────────────
  safeHandle(IPC_CHANNELS.DASHBOARD_GET_STATS, async () => {
    const db = storage.db;
    if (!db) return null;

    const todayStart = Math.floor(new Date().setHours(0, 0, 0, 0) / 1000);

    const todayCollected = (
      db.prepare('SELECT COUNT(*) as c FROM source_items WHERE created_at >= ?').get(todayStart) as { c: number }
    ).c;

    const todayDistilled = (
      db.prepare('SELECT COUNT(*) as c FROM distilled_outputs WHERE created_at >= ?').get(todayStart) as { c: number }
    ).c;

    const todayExported = (
      db.prepare('SELECT COUNT(*) as c FROM export_records WHERE exported_at >= ?').get(todayStart) as { c: number }
    ).c;

    const inboxPending = (
      db.prepare("SELECT COUNT(*) as c FROM source_items WHERE status = 'inbox'").get() as { c: number }
    ).c;

    const shelfItems = (
      db.prepare("SELECT COUNT(*) as c FROM shelf_items WHERE status = 'temporary'").get() as { c: number }
    ).c;

    const recentItems = storage.getSourceItems({ limit: 10 });

    let clipboardWatching = false;
    let clipboardPaused = false;
    try {
      clipboardWatching = clipboardWatcher.isEnabled();
      clipboardPaused = clipboardWatcher.isPaused();
    } catch { /* ignore */ }

    let aiProviderReady = false;
    try {
      const providers = storage.getProviderConfigs();
      aiProviderReady = providers.some(p => p.enabled);
    } catch { /* ignore */ }

    let vaultConfigured = false;
    try {
      const vaultCfg = storage.getVaultConfig();
      vaultConfigured = !!vaultCfg?.vaultPath;
    } catch { /* ignore */ }

    let markItDownAvailable = false;
    try {
      const { checkMarkItDownAvailability } = await import('./services/parser/markitdownService');
      markItDownAvailable = await checkMarkItDownAvailability();
    } catch { /* ignore */ }

    return {
      todayCollected,
      todayDistilled,
      todayExported,
      inboxPending,
      shelfItems,
      recentItems,
      clipboardWatching,
      clipboardPaused,
      aiProviderReady,
      vaultConfigured,
      markItDownAvailable,
    };
  });

  // ─── Batch 4: Capsule Status ──────────────────────────────────
  safeHandle(IPC_CHANNELS.CAPSULE_GET_STATUS, async () => {
    const db = storage.db;
    if (!db) return { clipboardWatching: false, shelfItemCount: 0, inboxPendingCount: 0, backgroundTaskCount: 0 };

    const inboxPendingCount = (
      db.prepare("SELECT COUNT(*) as c FROM source_items WHERE status = 'inbox'").get() as { c: number }
    ).c;

    const shelfItemCount = (
      db.prepare("SELECT COUNT(*) as c FROM shelf_items WHERE status = 'temporary'").get() as { c: number }
    ).c;

    const backgroundTaskCount = (
      db.prepare("SELECT COUNT(*) as c FROM ai_tasks WHERE status IN ('queued', 'running')").get() as { c: number }
    ).c;

    let clipboardWatching = false;
    try {
      clipboardWatching = clipboardWatcher.isEnabled() && !clipboardWatcher.isPaused();
    } catch { /* ignore */ }

    return { clipboardWatching, shelfItemCount, inboxPendingCount, backgroundTaskCount };
  });

  // ─── Batch 5: Health Check ────────────────────────────────────
  safeHandle(IPC_CHANNELS.HEALTH_CHECK, async () => {
    const checks: Array<{ name: string; ok: boolean; message?: string }> = [];

    // Database
    try {
      const db = storage.db;
      if (db) {
        db.prepare('SELECT 1').get();
        checks.push({ name: '数据库', ok: true });
      } else {
        checks.push({ name: '数据库', ok: false, message: '数据库未初始化' });
      }
    } catch (e) {
      checks.push({ name: '数据库', ok: false, message: e instanceof Error ? e.message : '未知错误' });
    }

    // Data directory
    try {
      const fs = await import('fs');
      const s = settings.load();
      const dataDir = (s as any).storageRoot || (s as any).dataDir;
      if (dataDir) {
        fs.accessSync(dataDir, fs.constants.R_OK | fs.constants.W_OK);
        checks.push({ name: '数据目录', ok: true });
      } else {
        checks.push({ name: '数据目录', ok: false, message: '未配置数据目录' });
      }
    } catch (e) {
      checks.push({ name: '数据目录', ok: false, message: '数据目录不可访问' });
    }

    // Clipboard watcher
    try {
      const enabled = clipboardWatcher.isEnabled();
      checks.push({ name: '剪贴板监听', ok: enabled, message: enabled ? undefined : '已暂停或未启用' });
    } catch {
      checks.push({ name: '剪贴板监听', ok: false, message: '未初始化' });
    }

    // AI Provider
    try {
      const providers = storage.getProviderConfigs();
      const hasEnabled = providers.some(p => p.enabled);
      checks.push({ name: 'AI Provider', ok: hasEnabled, message: hasEnabled ? `${providers.filter(p => p.enabled).length} 个已启用` : '无已启用的 Provider' });
    } catch {
      checks.push({ name: 'AI Provider', ok: false, message: '无法读取配置' });
    }

    return { ok: checks.every(c => c.ok), checks };
  });

  // ─── Batch 6: Knowledge Projects ──────────────────────────────
  safeHandle(IPC_CHANNELS.PROJECTS_LIST, async () => {
    return storage.listKnowledgeProjects();
  });

  safeHandle(IPC_CHANNELS.PROJECTS_CREATE, async (_event, data: { name: string; description?: string; color?: string }) => {
    return storage.createKnowledgeProject(data);
  });

  safeHandle(IPC_CHANNELS.PROJECTS_UPDATE, async (_event, data: { id: string; name?: string; description?: string; status?: string; color?: string }) => {
    return storage.updateKnowledgeProject(data);
  });

  safeHandle(IPC_CHANNELS.PROJECTS_DELETE, async (_event, { id }: { id: string }) => {
    return storage.deleteKnowledgeProject(id);
  });

  safeHandle(IPC_CHANNELS.PROJECTS_ADD_ITEM, async (_event, data: { projectId: string; itemType: string; itemId: string }) => {
    return storage.addProjectItem(data);
  });

  safeHandle(IPC_CHANNELS.PROJECTS_REMOVE_ITEM, async (_event, data: { projectId: string; itemId: string }) => {
    return storage.removeProjectItem(data);
  });

  // ─── Batch 6: Tags ───────────────────────────────────────────
  safeHandle(IPC_CHANNELS.TAGS_LIST, async () => {
    return storage.listTagSummaries();
  });

  safeHandle(IPC_CHANNELS.TAGS_RENAME, async (_event, data: { oldName: string; newName: string }) => {
    return storage.renameTag(data);
  });

  safeHandle(IPC_CHANNELS.TAGS_DELETE, async (_event, { name }: { name: string }) => {
    return storage.deleteTag(name);
  });

  // ─── Batch 6: Datasets ───────────────────────────────────────
  safeHandle(IPC_CHANNELS.DATASETS_V2_CREATE, async (_event, data: { name: string; description?: string; purpose?: string }) => {
    return storage.createDataset(data);
  });

  safeHandle(IPC_CHANNELS.DATASETS_V2_LIST, async () => {
    return storage.listDatasets();
  });

  safeHandle(IPC_CHANNELS.DATASETS_V2_GET, async (_event, { id }: { id: string }) => {
    return storage.getDataset(id);
  });

  safeHandle(IPC_CHANNELS.DATASETS_V2_ADD_ITEMS, async (_event, data: { datasetId: string; items: Array<{ sourceType: string; sourceId: string }> }) => {
    return storage.addDatasetItems(data);
  });

  safeHandle(IPC_CHANNELS.DATASETS_V2_UPDATE_ITEM, async (_event, data: { id: string; quality?: string; privacyLevel?: string; included?: boolean; reason?: string }) => {
    return storage.updateDatasetItem(data);
  });

  safeHandle(IPC_CHANNELS.DATASETS_V2_EXPORT, async (_event, data: { datasetId: string; format: string; includeExcluded?: boolean }) => {
    return storage.exportDataset(data);
  });

  safeHandle(IPC_CHANNELS.DATASETS_V2_DELETE, async (_event, { id }: { id: string }) => {
    return storage.deleteDataset(id);
  });

  // ─── ToolBench: GitHub Projects ──────────────────────────────────
  safeHandle(IPC_CHANNELS.TOOLBENCH_LIST_GITHUB_PROJECTS, async () => {
    try {
      const projects = storage.listGithubProjects();
      // Compute status based on localPath existence
      const fs = await import('node:fs');
      for (const p of projects) {
        if (p.localPath) {
          p.status = fs.existsSync(p.localPath) ? 'available' : 'missing_path';
        } else if (!p.repoUrl) {
          p.status = 'not_configured';
        } else {
          p.status = 'saved';
        }
      }
      return { success: true, projects };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.listGithubProjects', 'Failed', { error });
      return { success: false, projects: [] };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_CREATE_GITHUB_PROJECT, async (_event, input: any) => {
    try {
      const id = `gh_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      storage.insertGithubProject({ id, ...input });
      return { success: true, id };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.createGithubProject', 'Failed', { error });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_UPDATE_GITHUB_PROJECT, async (_event, { id, patch }: { id: string; patch: any }) => {
    try {
      storage.updateGithubProject(id, patch);
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.updateGithubProject', 'Failed', { error });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_DELETE_GITHUB_PROJECT, async (_event, { id }: { id: string }) => {
    try {
      storage.deleteGithubProject(id);
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.deleteGithubProject', 'Failed', { error });
      return { success: false };
    }
  });

  // ─── ToolBench: Local Scripts ────────────────────────────────────
  safeHandle(IPC_CHANNELS.TOOLBENCH_LIST_SCRIPTS, async () => {
    try {
      const scripts = storage.listLocalScripts();
      return { success: true, scripts };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.listScripts', 'Failed', { error });
      return { success: false, scripts: [] };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_CREATE_SCRIPT, async (_event, input: any) => {
    try {
      const id = `script_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      storage.insertLocalScript({ id, ...input });
      return { success: true, id };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.createScript', 'Failed', { error });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_UPDATE_SCRIPT, async (_event, { id, patch }: { id: string; patch: any }) => {
    try {
      storage.updateLocalScript(id, patch);
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.updateScript', 'Failed', { error });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_DELETE_SCRIPT, async (_event, { id }: { id: string }) => {
    try {
      storage.deleteLocalScript(id);
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.deleteScript', 'Failed', { error });
      return { success: false };
    }
  });

  // ─── ToolBench: Utility actions ──────────────────────────────────
  safeHandle(IPC_CHANNELS.TOOLBENCH_OPEN_URL, async (_event, { url }: { url: string }) => {
    try {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return { success: false, error: '只允许 http/https 链接' };
      }
      await shell.openExternal(url);
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.openUrl', 'Failed', { error });
      return { success: false, error: '打开链接失败' };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_OPEN_PATH, async (_event, { path: dirPath }: { path: string }) => {
    try {
      const fs = await import('node:fs');
      if (!fs.existsSync(dirPath)) {
        return { success: false, error: '路径不存在' };
      }
      await shell.openPath(dirPath);
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.openPath', 'Failed', { error });
      return { success: false, error: '打开目录失败' };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_COPY_COMMAND, async (_event, { command }: { command: string }) => {
    try {
      clipboard.writeText(command);
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.copyCommand', 'Failed', { error });
      return { success: false, error: '复制失败' };
    }
  });

  // ─── ToolBench: Scan & Import ─────────────────────────────────────
  safeHandle(IPC_CHANNELS.TOOLBENCH_SCAN_LOCAL_DIR, async (_event, { dirPath }: { dirPath: string }) => {
    try {
      const fs = await import('node:fs');
      if (!fs.existsSync(dirPath)) {
        return { success: false, error: '目录不存在', repos: [] };
      }
      const { gitRepoScanner } = await import('./services/importer/gitRepoScanner');
      const repos = gitRepoScanner.scan(dirPath);
      for (const repo of repos) {
        const existing = storage.getGithubProjectByLocalPath(repo.localPath);
        repo.alreadyImported = !!existing;
      }
      return { success: true, repos };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.scanLocalDir', 'Failed', { error });
      return { success: false, error: String(error), repos: [] };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_BATCH_IMPORT_PROJECTS, async (_event, { repos }: { repos: any[] }) => {
    try {
      let imported = 0;
      let skipped = 0;
      for (const repo of repos) {
        const existing = storage.getGithubProjectByLocalPath(repo.localPath);
        if (existing) { skipped++; continue; }
        const id = `gh_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
        storage.insertGithubProject({
          id,
          name: repo.name,
          description: repo.description || '',
          localPath: repo.localPath,
          category: 'other',
          tags: [],
          status: 'available',
        });
        imported++;
      }
      return { success: true, imported, skipped };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.batchImportProjects', 'Failed', { error });
      return { success: false, imported: 0, skipped: 0 };
    }
  });

  safeHandle(IPC_CHANNELS.TOOLBENCH_PICK_DIRECTORY, async () => {
    try {
      const result = await dialog.showOpenDialog({ properties: ['openDirectory'] });
      if (result.canceled || result.filePaths.length === 0) {
        return { success: false, path: '' };
      }
      return { success: true, path: result.filePaths[0] };
    } catch (error) {
      logger.error('app', 'ipc', 'toolbench.pickDirectory', 'Failed', { error });
      return { success: false, path: '' };
    }
  });

  // ─── Dashboard Widget (独立仪表盘) ──────────────────────────────
  safeHandle(IPC_CHANNELS.DASHBOARD_WIDGET_GET_MEDIA, async () => {
    try {
      const { getMediaInfo } = await import('./services/dashboard/mediaService');
      const media = await getMediaInfo();
      return { success: true, media };
    } catch (error) {
      logger.error('app', 'ipc', 'dashboardWidget.getMedia', 'Failed', { error });
      return { success: false, media: { source: null, trackName: '', artist: '', album: '', duration: 0, position: 0, state: 'stopped', artworkDataUrl: null } };
    }
  });

  safeHandle(IPC_CHANNELS.DASHBOARD_WIDGET_MEDIA_CONTROL, async (_event, action: string) => {
    try {
      const { mediaControl } = await import('./services/dashboard/mediaService');
      await mediaControl(action as 'playpause' | 'next' | 'previous');
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'dashboardWidget.mediaControl', 'Failed', { error });
      return { success: false };
    }
  });

  safeHandle(IPC_CHANNELS.DASHBOARD_WIDGET_GET_CALENDAR, async () => {
    try {
      const { getTodayCalendarEvents } = await import('./services/dashboard/calendarService');
      const events = await getTodayCalendarEvents();
      return { success: true, events };
    } catch (error) {
      logger.error('app', 'ipc', 'dashboardWidget.getCalendar', 'Failed', { error });
      return { success: false, events: [] };
    }
  });

  safeHandle(IPC_CHANNELS.DASHBOARD_WIDGET_TOGGLE_WINDOW, async (_event, enabled: boolean) => {
    try {
      if (enabled) {
        deps.widgetController?.show();
      } else {
        deps.widgetController?.hide();
      }
      return { success: true };
    } catch (error) {
      logger.error('app', 'ipc', 'dashboardWidget.toggleWindow', 'Failed', { error });
      return { success: false };
    }
  });

  // ─── Phase A: Agent Chat ──────────────────────────────────────
  const { chatService } = await import('./services/chat/chatService');
  const { AGENT_CHAT_IPC_CHANNELS } = await import('../shared/types');

  // Sessions
  safeHandle(AGENT_CHAT_IPC_CHANNELS.SESSIONS_LIST, async (_event, filter?: { status?: 'active' | 'archived' | 'deleted'; limit?: number; offset?: number }) => {
    try {
      const sessions = chatService.listSessions(filter);
      return { success: true, sessions };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.sessions.list', 'Failed to list sessions', { error });
      return { success: false, sessions: [] };
    }
  });

  safeHandle(AGENT_CHAT_IPC_CHANNELS.SESSIONS_GET, async (_event, id: string) => {
    try {
      const session = chatService.getSession(id);
      return { success: true, session };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.sessions.get', 'Failed to get session', { error });
      return { success: false, session: null };
    }
  });

  safeHandle(AGENT_CHAT_IPC_CHANNELS.SESSIONS_CREATE, async (_event, params?: { title?: string; metadata?: import('../shared/types').ChatSessionMetadata; providerId?: string; modelId?: string }) => {
    try {
      const session = chatService.createSession(params);
      return { success: true, session };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.sessions.create', 'Failed to create session', { error });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(AGENT_CHAT_IPC_CHANNELS.SESSIONS_UPDATE, async (_event, id: string, patch: Partial<import('../shared/types').ChatSession>) => {
    try {
      const session = chatService.updateSession(id, patch);
      return { success: true, session };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.sessions.update', 'Failed to update session', { error });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(AGENT_CHAT_IPC_CHANNELS.SESSIONS_DELETE, async (_event, id: string) => {
    try {
      const success = chatService.deleteSession(id);
      return { success };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.sessions.delete', 'Failed to delete session', { error });
      return { success: false };
    }
  });

  // Messages
  safeHandle(AGENT_CHAT_IPC_CHANNELS.MESSAGES_LIST, async (_event, sessionId: string, filter?: { limit?: number }) => {
    try {
      const messages = chatService.listMessages(sessionId, filter);
      return { success: true, messages };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.messages.list', 'Failed to list messages', { error });
      return { success: false, messages: [] };
    }
  });

  safeHandle('agentChat.messages.createSystem', async (_event, sessionId: string, content: string) => {
    try {
      const message = chatService.createSystemMessage(sessionId, content);
      return { success: true, message };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.messages.createSystem', 'Failed to create system message', { error });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle('agentChat.skills.list', async () => {
    try {
      const skills = skillRegistry.getAll().map((skill) => ({
        name: skill.name,
        description: skill.description,
        category: skill.category,
        requiresConfirmation: skill.requiresConfirmation,
      }));
      return { success: true, skills };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.skills.list', 'Failed to list skills', { error });
      return { success: false, skills: [] };
    }
  });

  // Send message (starts streaming)
  safeHandle(AGENT_CHAT_IPC_CHANNELS.SEND_MESSAGE, async (_event, params: { sessionId: string; content: string; providerId?: string }) => {
    try {
      // Get provider if specified
      let provider: import('../shared/types').ProviderConfig | undefined;
      if (params.providerId) {
        const providers = storage.getProviderConfigs();
        provider = providers.find(p => p.id === params.providerId && p.enabled);
      } else {
        // M8: 未传 providerId 时，回退到设置中的默认 provider
        const appSettings = settings.load();
        if (appSettings.agentChat?.defaultProviderId) {
          const providers = storage.getProviderConfigs();
          provider = providers.find(p => p.id === appSettings.agentChat.defaultProviderId && p.enabled);
        }
      }

      const result = await chatService.sendMessage({
        sessionId: params.sessionId,
        content: params.content,
        provider,
      });

      return result;
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.send', 'Failed to send message', { error });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  // Stop generation
  safeHandle(AGENT_CHAT_IPC_CHANNELS.STOP_GENERATION, async () => {
    try {
      const stopped = chatService.stopGeneration();
      return { success: true, stopped };
    } catch (error) {
      logger.error('error', 'ipc', 'agentChat.stop', 'Failed to stop generation', { error });
      return { success: false };
    }
  });

  // ─── Phase C: Agent Tasks ──────────────────────────────────────
  const { agentTaskService } = await import('./services/chat/agentTaskService');
  const { AGENT_TASKS_IPC_CHANNELS } = await import('../shared/types');
  const { skillRegistry } = await import('./services/chat/skillRegistry');

  // Register built-in skills
  const { default: scanInboxSkill } = await import('./services/chat/skills/scanInboxSkill');
  const { default: checkAcMindSkill } = await import('./services/chat/skills/checkAcMindSkill');
  const { default: scanObsidianInboxSkill } = await import('./services/chat/skills/scanObsidianInboxSkill');
  const { default: webScraperSkill } = await import('./services/chat/skills/webScraperSkill');
  const { default: fileSearchSkill } = await import('./services/chat/skills/fileSearchSkill');
  const { default: markdownGeneratorSkill } = await import('./services/chat/skills/markdownGeneratorSkill');
  skillRegistry.register(scanInboxSkill);
  skillRegistry.register(checkAcMindSkill);
  skillRegistry.register(scanObsidianInboxSkill);
  skillRegistry.register(webScraperSkill);
  skillRegistry.register(fileSearchSkill);
  skillRegistry.register(markdownGeneratorSkill);

  safeHandle(AGENT_TASKS_IPC_CHANNELS.LIST, async (_event, filter?: { status?: string; limit?: number; offset?: number }) => {
    try {
      const tasks = agentTaskService.listTasks(filter);
      return { success: true, tasks };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.list', 'Failed to list tasks', { error });
      return { success: false, tasks: [] };
    }
  });

  safeHandle(AGENT_TASKS_IPC_CHANNELS.GET, async (_event, id: string) => {
    try {
      const task = agentTaskService.getTask(id);
      return { success: true, task };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.get', 'Failed to get task', { error });
      return { success: false, task: null };
    }
  });

  safeHandle(AGENT_TASKS_IPC_CHANNELS.CREATE, async (_event, params: { sessionId: string; name: string; skillName?: string; inputParams?: Record<string, unknown> }) => {
    try {
      const task = agentTaskService.createTask(params);
      return { success: true, task };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.create', 'Failed to create task', { error });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(AGENT_TASKS_IPC_CHANNELS.UPDATE, async (_event, id: string, updates: Partial<import('../shared/types').AgentTask>) => {
    try {
      agentTaskService.updateTask(id, updates);
      const task = agentTaskService.getTask(id);
      return { success: true, task };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.update', 'Failed to update task', { error });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(AGENT_TASKS_IPC_CHANNELS.DELETE, async (_event, id: string) => {
    try {
      const success = agentTaskService.deleteTask(id);
      return { success };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.delete', 'Failed to delete task', { error });
      return { success: false };
    }
  });

  safeHandle(AGENT_TASKS_IPC_CHANNELS.RUN_NOW, async (_event, id: string) => {
    try {
      await agentTaskService.runTask(id);
      const task = agentTaskService.getTask(id);
      return { success: true, task };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.runNow', 'Failed to run task', { error });
      return { success: false, error: error instanceof Error ? error.message : String(error) };
    }
  });

  safeHandle(AGENT_TASKS_IPC_CHANNELS.HISTORY, async (_event, taskId: string) => {
    try {
      const events = agentTaskService.getTaskEvents(taskId);
      return { success: true, events };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.history', 'Failed to get task history', { error });
      return { success: false, events: [] };
    }
  });

  safeHandle(AGENT_TASKS_IPC_CHANNELS.CANCEL, async (_event, id: string) => {
    try {
      agentTaskService.cancelTask(id);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'agentTasks.cancel', 'Failed to cancel task', { error });
      return { success: false };
    }
  });

  // ─── Phase D: Scheduled Agent Tasks IPC Handlers ───────────────────────

  const { SCHEDULED_AGENT_TASKS_IPC_CHANNELS } = await import('../shared/types');

  safeHandle(SCHEDULED_AGENT_TASKS_IPC_CHANNELS.LIST, async () => {
    try {
      const tasks = schedulerService.listScheduledAgentTasks();
      return { success: true, tasks };
    } catch (error) {
      logger.error('error', 'ipc', 'scheduledAgentTasks.list', 'Failed to list scheduled agent tasks', { error });
      return { success: false, tasks: [] };
    }
  });

  safeHandle(SCHEDULED_AGENT_TASKS_IPC_CHANNELS.GET, async (_event, id: string) => {
    try {
      const task = schedulerService.getScheduledAgentTask(id);
      return { success: true, task };
    } catch (error) {
      logger.error('error', 'ipc', 'scheduledAgentTasks.get', 'Failed to get scheduled agent task', { error });
      return { success: false, task: null };
    }
  });

  safeHandle(SCHEDULED_AGENT_TASKS_IPC_CHANNELS.CREATE, async (_event, params: { name: string; cronExpression: string; skillName: string; inputParams?: Record<string, unknown>; enabled?: boolean }) => {
    try {
      const task = schedulerService.createScheduledAgentTask(params);
      return { success: true, task };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'ipc', 'scheduledAgentTasks.create', 'Failed to create scheduled agent task', { error: errorMsg });
      return { success: false, error: errorMsg };
    }
  });

  safeHandle(SCHEDULED_AGENT_TASKS_IPC_CHANNELS.UPDATE, async (_event, id: string, updates: Partial<import('../shared/types').ScheduledAgentTask>) => {
    try {
      const task = schedulerService.updateScheduledAgentTask(id, updates);
      return { success: true, task };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'ipc', 'scheduledAgentTasks.update', 'Failed to update scheduled agent task', { error: errorMsg });
      return { success: false, error: errorMsg };
    }
  });

  safeHandle(SCHEDULED_AGENT_TASKS_IPC_CHANNELS.DELETE, async (_event, id: string) => {
    try {
      schedulerService.deleteScheduledAgentTask(id);
      return { success: true };
    } catch (error) {
      logger.error('error', 'ipc', 'scheduledAgentTasks.delete', 'Failed to delete scheduled agent task', { error });
      return { success: false };
    }
  });

  safeHandle(SCHEDULED_AGENT_TASKS_IPC_CHANNELS.RUN_NOW, async (_event, id: string) => {
    try {
      await schedulerService.runScheduledAgentTaskNow(id);
      return { success: true };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'ipc', 'scheduledAgentTasks.runNow', 'Failed to run scheduled agent task', { error: errorMsg });
      return { success: false, error: errorMsg };
    }
  });

  logger.info('app', 'ipc', 'register', 'IPC handlers registered', {
    channels: Object.values(IPC_CHANNELS).join(', '),
  });
}
