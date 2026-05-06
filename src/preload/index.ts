import { contextBridge, ipcRenderer } from 'electron';
import type {
  AppSettings,
  StorageStats,
  LogLevel,
  SourceItemListFilter,
  SourceItem,
  SourceItemType,
  ProviderConfig,
  AiTask,
  AiOperation,
  AiTier,
  LogChannel,
  DistilledOutput,
  DistillLineageStatus,
  ExportRecord,
  VaultConfig,
  RuntimeSettings,
  PermissionStatusSnapshot,
  CaptureRecordingState,
  CaptureLauncherVisualState,
  CaptureSessionConfig,
  RecordItem,
  PermissionCheckSource,
  CaptureItem,
  CaptureItemListFilter,
  KnowledgeCard,
  KnowledgeEdge,
  DatasetSnapshot,
  TrainingRun,
  EvalRun,
  ModelVersion,
  CaptureRecord,
  CaptureInput,
  PinItem,
  PinItemListFilter,
  VoiceCreatePinRequest,
  VoicePolishRequest,
  VoicePolishResult,
  ClipboardItem,
  ShelfItem,
  GithubToolProject,
  LocalScriptTool,
  ProcessJob,
  AIAction,
  AIActionType,
  SourceType,
  ProcessedContent,
  DistilledNote,
  VaultSearchResult,
  VoiceDictionaryEntry,
  ChatSession,
  ChatMessage,
  ChatSessionMetadata,
} from '../shared/types';
import { IPC_CHANNELS } from '../shared/types';

const DEFAULT_DISTILL_OPERATIONS = ['rename', 'summarize', 'classify', 'tag', 'valueScore', 'cleanSuggest'] as const;

async function bridgeCaptureItemToSourceItem(captureItemId: string): Promise<SourceItem> {
  return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_ENSURE_FROM_CAPTURE, captureItemId);
}

async function setCaptureItemDistilling(captureItemId: string): Promise<void> {
  await ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_UPDATE, captureItemId, { status: 'distilling' });
}

async function distillSourceItems(sourceItemIds: string[], operations?: AiOperation[], tier?: AiTier): Promise<AiTask[]> {
  return ipcRenderer.invoke('distill.run', sourceItemIds, operations ?? [...DEFAULT_DISTILL_OPERATIONS], tier);
}

async function bridgeAndRunWithFallback(
  captureItemId: string,
  operations?: AiOperation[],
  tier?: AiTier,
): Promise<{ sourceItem: SourceItem; tasks: AiTask[] }> {
  try {
    const sourceItem = await ipcRenderer.invoke(IPC_CHANNELS.DISTILL_BRIDGE_AND_RUN, captureItemId, operations, tier);
    return sourceItem;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.includes('No handler registered for')) {
      throw error;
    }

    const sourceItem = await bridgeCaptureItemToSourceItem(captureItemId);
    await setCaptureItemDistilling(captureItemId);
    const tasks = await distillSourceItems([sourceItem.id], operations, tier);
    return { sourceItem, tasks };
  }
}

async function bridgeAndRunBatchWithFallback(
  captureItemIds: string[],
  operations?: AiOperation[],
  tier?: AiTier,
): Promise<{ sourceItems: Array<{ id: string }>; tasks: AiTask[] }> {
  try {
    return await ipcRenderer.invoke(IPC_CHANNELS.DISTILL_BRIDGE_AND_RUN_BATCH, captureItemIds, operations, tier);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.includes('No handler registered for')) {
      throw error;
    }

    const sourceItems: Array<{ id: string }> = [];
    for (const captureItemId of captureItemIds) {
      const sourceItem = await bridgeCaptureItemToSourceItem(captureItemId);
      sourceItems.push({ id: sourceItem.id });
      await setCaptureItemDistilling(captureItemId);
    }
    const tasks = await distillSourceItems(sourceItems.map((item) => item.id), operations, tier);
    return { sourceItems, tasks };
  }
}

// ---------------------------------------------------------------------------
// Type-safe API surface exposed to the renderer process
// ---------------------------------------------------------------------------

const acmindApi = {
  // -- App ------------------------------------------------------------------
  app: {
    getVersion(): Promise<string> {
      return ipcRenderer.invoke(IPC_CHANNELS.APP_GET_VERSION);
    },
    openStorageRoot(): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.APP_OPEN_STORAGE_ROOT);
    },
    openPath(filePath: string): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.APP_OPEN_PATH, filePath);
    },
  },

  // -- Storage --------------------------------------------------------------
  storage: {
    getStats(): Promise<StorageStats> {
      return ipcRenderer.invoke(IPC_CHANNELS.STORAGE_GET_STATS);
    },
  },

  // -- SourceItems (Phase 2) ------------------------------------------------
  sourceItems: {
    list(filter?: SourceItemListFilter): Promise<SourceItem[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_LIST, filter);
    },
    get(id: string): Promise<SourceItem | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_GET, id);
    },
    getContent(id: string): Promise<{ type: SourceItemType; text?: string; dataUrl?: string } | null> {
      return ipcRenderer.invoke('sourceItems.getContent', id);
    },
    delete(id: string): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_DELETE, id);
    },
    deleteBatch(ids: string[]): Promise<{ deleted: string[]; failed: Array<{ id: string; error: string }> }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_DELETE_BATCH, ids);
    },
    search(query: string): Promise<SourceItem[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_SEARCH, query);
    },
    createText(text: string): Promise<SourceItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_CREATE_TEXT, text);
    },
    ensureFromCapture(captureItemId: string): Promise<SourceItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_ENSURE_FROM_CAPTURE, captureItemId);
    },
    getByCaptureItemId(captureItemId: string): Promise<SourceItem | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_GET_BY_CAPTURE_ITEM_ID, captureItemId);
    },
    readImage(filePath: string): Promise<{ ok: boolean; dataUrl?: string; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_READ_IMAGE, filePath);
    },
    // Distill Loop: Get full lineage status for a capture item
    getDistillStatus(captureItemId: string): Promise<DistillLineageStatus> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_GET_DISTILL_STATUS, captureItemId);
    },
    importFile(filePath: string): Promise<SourceItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_IMPORT_FILE, filePath);
    },
    saveUrl(url: string): Promise<SourceItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_SAVE_URL, url);
    },
    update(id: string, patch: Partial<SourceItem>): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.SOURCE_ITEMS_UPDATE, id, patch);
    },
  },

  // -- Capture (Phase 2) ----------------------------------------------------
  capture: {
    screenshot(): Promise<boolean> {
      return ipcRenderer.invoke('capture.screenshot');
    },
    takeScreenshot(): Promise<boolean> {
      return ipcRenderer.invoke('capture.screenshot');
    },
    takeFixedScreenshot(_size: unknown): Promise<boolean> {
      return ipcRenderer.invoke('capture.takeFixedScreenshot', _size);
    },
    takeRegionScreenshot(_bounds: unknown): Promise<void> {
      return ipcRenderer.invoke('capture.takeRegionScreenshot', _bounds);
    },
    takeRegionScreenshotCopy(_bounds: unknown): Promise<void> {
      return ipcRenderer.invoke('capture.takeRegionScreenshotCopy', _bounds);
    },
    takeRegionScreenshotSave(_bounds: unknown): Promise<void> {
      return ipcRenderer.invoke('capture.takeRegionScreenshotSave', _bounds);
    },
    takeRegionScreenshotSaveAs(_bounds: unknown): Promise<void> {
      return ipcRenderer.invoke('capture.takeRegionScreenshotSaveAs', _bounds);
    },
    takeRegionScreenshotPin(_bounds: unknown): Promise<void> {
      return ipcRenderer.invoke('capture.takeRegionScreenshotPin', _bounds);
    },
    cancelRegionScreenshot(): Promise<void> {
      return ipcRenderer.invoke('capture.cancelRegionScreenshot');
    },
    getSelectionSession(): Promise<CaptureSessionConfig> {
      return ipcRenderer.invoke('capture.getSelectionSession') as Promise<CaptureSessionConfig>;
    },
    getColorAtPosition(_x: number, _y: number): Promise<string> {
      return ipcRenderer.invoke('capture.getColorAtPosition', _x, _y);
    },
    ignoreNextCopy(): Promise<void> {
      return ipcRenderer.invoke('capture.ignoreNextCopy');
    },
    getRecordingState(): Promise<CaptureRecordingState> {
      return ipcRenderer.invoke('capture.getRecordingState') as Promise<CaptureRecordingState>;
    },
    onRecordingState(_cb: (state: CaptureRecordingState) => void): () => void {
      // stub - no real listener
      return () => {};
    },
    requestRecordingStop(): Promise<void> {
      return ipcRenderer.invoke('capture.requestRecordingStop');
    },
    getLauncherVisualState(): Promise<CaptureLauncherVisualState> {
      return ipcRenderer.invoke('capture.getLauncherVisualState') as Promise<CaptureLauncherVisualState>;
    },
    onLauncherVisualState(_cb: (state: CaptureLauncherVisualState) => void): () => void {
      // stub - no real listener
      return () => {};
    },
    launcherDragStart(_x: number, _y: number): Promise<void> {
      return ipcRenderer.invoke('capture.launcherDragStart', _x, _y);
    },
    launcherDragMove(_x: number, _y: number): Promise<void> {
      return ipcRenderer.invoke('capture.launcherDragMove', _x, _y);
    },
    launcherDragEnd(_x: number, _y: number): Promise<void> {
      return ipcRenderer.invoke('capture.launcherDragEnd', _x, _y);
    },
    toggleHub(): Promise<void> {
      return ipcRenderer.invoke('capture.toggleHub');
    },
    onHubShown(_cb: () => void): () => void {
      // stub - no real listener
      return () => {};
    },
    hideHub(): Promise<void> {
      return ipcRenderer.invoke('capture.hideHub');
    },
    reportHubHeight(_h: number): Promise<void> {
      return ipcRenderer.invoke('capture.reportHubHeight', _h);
    },
    // V2.1 Phase 7.1: Unified Capture Adapter
    record(input: {
      sourceType: 'manual_text' | 'clipboard_text' | 'screenshot' | 'webpage' | 'file' | 'image' | 'audio' | 'video' | 'pdf' | 'docx' | 'unknown_file';
      text?: string;
      filePath?: string;
      url?: string;
      title?: string;
      sourceApp?: string;
      contentHash?: string;
    }): Promise<{
      success: boolean;
      stage: string;
      sourceItemId: string;
      error?: string;
      captureRecord: CaptureRecord;
    }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_RECORD, input);
    },
    getAvailableTypes() {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_GET_AVAILABLE_TYPES);
    },
    // V2.1 Phase 7.2: Collect clipboard text
    collectClipboard() {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_COLLECT_CLIPBOARD);
    },
    // V2.1 Phase 7.3: Collect screenshot
    collectScreenshot() {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_COLLECT_SCREENSHOT);
    },
    // V2.1 Phase 7.4: Collect webpage content
    collectWebpage(params: { url: string; title?: string; rawText?: string; fetchContent?: boolean }) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_COLLECT_WEBPAGE, params);
    },
    // V2.1 Phase 7.5: Import file
    collectFile(params: { filePath: string; title?: string }) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_COLLECT_FILE, params);
    },
    // Phase 2A: 截图与贴图
    startAreaCapture() {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_START_AREA);
    },
    cancelCapture() {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_CANCEL);
    },
    pinImage(filePath: string, sourceItemId?: string) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_PIN_IMAGE, { filePath, sourceItemId });
    },
    saveToInbox(id: string) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_SAVE_TO_INBOX, { id });
    },
    listRecentCaptures(limit?: number) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_LIST_RECENT, { limit });
    },
    listPinnedImages() {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_LIST_PINNED);
    },
    closePinnedImage(id: string) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_CLOSE_PINNED, { id });
    },
    onItemsChanged(cb: (data: { timestamp: number }) => void): () => void {
      const handler = (_event: unknown, data: { timestamp: number }) => cb(data);
      ipcRenderer.on(IPC_CHANNELS.CAPTURE_SCREENSHOTS_CHANGED, handler);
      return () => { ipcRenderer.removeListener(IPC_CHANNELS.CAPTURE_SCREENSHOTS_CHANGED, handler); };
    },
    onPinnedChanged(cb: (data: { timestamp: number }) => void): () => void {
      const handler = (_event: unknown, data: { timestamp: number }) => cb(data);
      ipcRenderer.on(IPC_CHANNELS.CAPTURE_PINNED_CHANGED, handler);
      return () => { ipcRenderer.removeListener(IPC_CHANNELS.CAPTURE_PINNED_CHANGED, handler); };
    },
    // Phase 2B: OCR
    ocrExtract(imagePath: string, language?: string) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_OCR_EXTRACT, { imagePath, language });
    },
    ocrSaveToInbox(text: string, sourceImagePath?: string) {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_OCR_SAVE_TO_INBOX, { text, sourceImagePath });
    },
  },

  // -- Dialog (Phase 7.5) ----------------------------------------------------
  dialog: {
    openFile(options?: { title?: string; filters?: { name: string; extensions: string[] }[] }) {
      return ipcRenderer.invoke(IPC_CHANNELS.DIALOG_OPEN_FILE, options);
    },
    selectDirectory(options?: { title?: string }): Promise<string | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.DIALOG_SELECT_DIRECTORY, options);
    },
  },

  // -- Clipboard (Phase 2) --------------------------------------------------
  clipboard: {
    getStatus(): Promise<{ running: boolean; enabled: boolean }> {
      return ipcRenderer.invoke('clipboard.getStatus');
    },
    toggle(enabled: boolean): Promise<boolean> {
      return ipcRenderer.invoke('clipboard.toggle', enabled);
    },
    pause(): Promise<boolean> {
      return ipcRenderer.invoke('clipboard.pause');
    },
    resume(): Promise<boolean> {
      return ipcRenderer.invoke('clipboard.resume');
    },
    isPaused(): Promise<boolean> {
      return ipcRenderer.invoke('clipboard.isPaused');
    },
    listItems(params?: { limit?: number; offset?: number }): Promise<{ success: boolean; items: ClipboardItem[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_LIST_ITEMS, params);
    },
    getItem(id: string): Promise<{ success: boolean; item: ClipboardItem | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_GET_ITEM, { id });
    },
    searchItems(query: string, contentType?: string): Promise<{ success: boolean; items: ClipboardItem[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_SEARCH_ITEMS, { query, contentType });
    },
    copyItem(id: string): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_COPY_ITEM, { id });
    },
    deleteItem(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_DELETE_ITEM, { id });
    },
    pinItem(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_PIN_ITEM, { id });
    },
    unpinItem(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_UNPIN_ITEM, { id });
    },
    saveToInbox(id: string): Promise<{ success: boolean; sourceItem?: SourceItem; alreadySaved?: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_SAVE_TO_INBOX, { id });
    },
    clearHistory(): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CLIPBOARD_CLEAR_HISTORY);
    },
    onItemsChanged(callback: (data: { timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { timestamp: number }) => {
        callback(data);
      };
      ipcRenderer.on(IPC_CHANNELS.CLIPBOARD_ITEMS_CHANGED, handler);
      return () => {
        ipcRenderer.removeListener(IPC_CHANNELS.CLIPBOARD_ITEMS_CHANGED, handler);
      };
    },
  },

  // -- Shelf (Phase 1B) ----------------------------------------------------
  shelf: {
    listItems(status?: string): Promise<{ success: boolean; items: ShelfItem[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SHELF_LIST_ITEMS, { status });
    },
    getItem(id: string): Promise<{ success: boolean; item: ShelfItem | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SHELF_GET_ITEM, { id });
    },
    addFiles(filePaths: string[], label?: string): Promise<{ success: boolean; item?: ShelfItem; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SHELF_ADD_FILES, { filePaths, label });
    },
    addText(text: string, label?: string): Promise<{ success: boolean; item?: ShelfItem; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SHELF_ADD_TEXT, { text, label });
    },
    removeItem(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SHELF_REMOVE_ITEM, { id });
    },
    saveToInbox(id: string): Promise<{ success: boolean; sourceItem?: SourceItem; alreadySaved?: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.SHELF_SAVE_TO_INBOX, { id });
    },
    onItemsChanged(callback: (data: { timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { timestamp: number }) => {
        callback(data);
      };
      ipcRenderer.on(IPC_CHANNELS.SHELF_ITEMS_CHANGED, handler);
      return () => {
        ipcRenderer.removeListener(IPC_CHANNELS.SHELF_ITEMS_CHANGED, handler);
      };
    },
  },

  // -- Events (Phase 2) -----------------------------------------------------
  onRecordsChanged(callback: (event: { action: string; id: string; timestamp: number }) => void): () => void {
    const handler = (_event: Electron.IpcRendererEvent, data: { action: string; id: string; timestamp: number }) => {
      callback(data);
    };
    ipcRenderer.on(IPC_CHANNELS.RECORDS_CHANGED, handler);
    return () => {
      ipcRenderer.removeListener(IPC_CHANNELS.RECORDS_CHANGED, handler);
    };
  },

  // -- Providers (Phase 3) -------------------------------------------------
  providers: {
    list(): Promise<ProviderConfig[]> {
      return ipcRenderer.invoke('providers.list');
    },
    add(config: ProviderConfig): Promise<ProviderConfig> {
      return ipcRenderer.invoke('providers.add', config);
    },
    update(id: string, patch: Partial<ProviderConfig>): Promise<ProviderConfig> {
      return ipcRenderer.invoke('providers.update', id, patch);
    },
    delete(id: string): Promise<void> {
      return ipcRenderer.invoke('providers.delete', id);
    },
    scanLocal(): Promise<Array<{ name: string; size: number; modifiedAt: string }>> {
      return ipcRenderer.invoke('providers.scanLocal');
    },
    testConnection(id: string): Promise<{ ok: boolean; latencyMs: number; error?: string }> {
      return ipcRenderer.invoke('providers.testConnection', id);
    },
  },

  // -- AI Tasks (Phase 3) --------------------------------------------------
  aiTasks: {
    list(filter?: { status?: string; sourceItemId?: string; limit?: number }): Promise<AiTask[]> {
      return ipcRenderer.invoke('aiTasks.list', filter);
    },
    cancel(id: string): Promise<boolean> {
      return ipcRenderer.invoke('aiTasks.cancel', id);
    },
    retry(id: string): Promise<AiTask | null> {
      return ipcRenderer.invoke('aiTasks.retry', id);
    },
    pause(): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_TASKS_PAUSE);
    },
    resume(): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_TASKS_RESUME);
    },
    isPaused(): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_TASKS_IS_PAUSED);
    },
  },

  // -- Distill (Phase 3 + Phase 4) -----------------------------------------
  distill: {
    run(sourceItemIds: string[], operations: AiOperation[], tier?: AiTier): Promise<AiTask[]> {
      return ipcRenderer.invoke('distill.run', sourceItemIds, operations, tier);
    },
    runSingle(sourceItemId: string, operation: AiOperation, tier?: AiTier): Promise<AiTask> {
      return ipcRenderer.invoke('distill.runSingle', sourceItemId, operation, tier);
    },
    /** @deprecated Use distilledOutputs.review() instead — review flow consolidated into single endpoint */
    update(id: string, patch: Partial<DistilledOutput>): Promise<DistilledOutput> {
      return ipcRenderer.invoke('distill.update', id, patch);
    },
    /** @deprecated Use distilledOutputs.list() with reviewStatus filter instead */
    listPending(filter?: { sourceItemId?: string; limit?: number }): Promise<DistilledOutput[]> {
      return ipcRenderer.invoke('distill.listPending', filter);
    },
    /** @deprecated Use distilledOutputs.review() with action 'accept' instead */
    accept(id: string): Promise<DistilledOutput> {
      return ipcRenderer.invoke('distill.accept', id);
    },
    /** @deprecated Use distilledOutputs.review() with action 'reject' instead */
    reject(id: string): Promise<DistilledOutput> {
      return ipcRenderer.invoke('distill.reject', id);
    },
    // Phase 4: Batch processing with progress tracking
    batch(sourceItemIds: string[], operations: AiOperation[], tier?: AiTier): Promise<string> {
      return ipcRenderer.invoke('distill.batch', sourceItemIds, operations, tier);
    },
    batchStatus(batchId: string): Promise<{ batchId: string; total: number; done: number; failed: number; running: number; cancelled: boolean }> {
      return ipcRenderer.invoke('distill.batchStatus', batchId);
    },
    batchCancel(batchId: string): Promise<boolean> {
      return ipcRenderer.invoke('distill.batchCancel', batchId);
    },
    // Distill Loop: Bridge CaptureItem → SourceItem → Distill
    bridgeAndRun(captureItemId: string, operations?: AiOperation[], tier?: AiTier): Promise<{ sourceItem: SourceItem; tasks: AiTask[] }> {
      return bridgeAndRunWithFallback(captureItemId, operations, tier);
    },
    bridgeAndRunBatch(captureItemIds: string[], operations?: AiOperation[], tier?: AiTier): Promise<{ sourceItems: Array<{ id: string }>; tasks: AiTask[] }> {
      return bridgeAndRunBatchWithFallback(captureItemIds, operations, tier);
    },
  },

  // -- DistilledOutputs (Phase 4) ------------------------------------------
  distilledOutputs: {
    list(filter?: { sourceItemId?: string; reviewStatus?: string; limit?: number }): Promise<DistilledOutput[]> {
      return ipcRenderer.invoke('distilledOutputs.list', filter);
    },
    review(id: string, action: 'approve' | 'edit' | 'discard', data?: Record<string, unknown>): Promise<DistilledOutput> {
      return ipcRenderer.invoke('distilledOutputs.review', id, action, data);
    },
  },

  // -- Knowledge Graph / Datasets / Models ---------------------------------
  knowledgeCards: {
    list(filter?: { status?: string; category?: string; tag?: string; limit?: number }): Promise<KnowledgeCard[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.KNOWLEDGE_CARDS_LIST, filter);
    },
    get(id: string): Promise<KnowledgeCard | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.KNOWLEDGE_CARDS_GET, id);
    },
    getBySourceItemId(sourceItemId: string): Promise<KnowledgeCard | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.KNOWLEDGE_CARDS_GET_BY_SOURCE_ITEM_ID, sourceItemId);
    },
    upsertFromReview(
      distilledOutputId: string,
      action: 'approve' | 'edit' | 'discard',
      patch?: Partial<DistilledOutput>,
    ): Promise<KnowledgeCard | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.KNOWLEDGE_CARDS_UPSERT_FROM_REVIEW, distilledOutputId, action, patch);
    },
  },
  graph: {
    get(filter?: { cardId?: string; includeSuggested?: boolean; category?: string; tag?: string; limit?: number }): Promise<{
      cards: KnowledgeCard[];
      edges: KnowledgeEdge[];
    }> {
      return ipcRenderer.invoke(IPC_CHANNELS.GRAPH_GET, filter);
    },
  },
  datasets: {
    /** @deprecated Use datasets.create (v2) instead */
    createSnapshot(data: { name: string; description?: string; splitConfig?: Record<string, unknown> }): Promise<DatasetSnapshot> {
      return ipcRenderer.invoke(IPC_CHANNELS.DATASETS_CREATE_SNAPSHOT, data);
    },
    list(): Promise<DatasetSnapshot[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.DATASETS_V2_LIST);
    },
    get(id: string): Promise<DatasetSnapshot | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.DATASETS_V2_GET, id);
    },
    /** @deprecated Use datasets.exportDataset (v2) instead */
    exportBundle(snapshotId: string): Promise<{ bundleDir: string; manifest: unknown }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DATASETS_EXPORT_BUNDLE, snapshotId);
    },
    // Batch 6: Dataset management
    create: (data: { name: string; description?: string; purpose?: string }) => ipcRenderer.invoke(IPC_CHANNELS.DATASETS_V2_CREATE, data),
    addItems: (data: { datasetId: string; items: Array<{ sourceType: string; sourceId: string }> }) => ipcRenderer.invoke(IPC_CHANNELS.DATASETS_V2_ADD_ITEMS, data),
    updateItem: (data: { id: string; quality?: string; privacyLevel?: string; included?: boolean; reason?: string }) => ipcRenderer.invoke(IPC_CHANNELS.DATASETS_V2_UPDATE_ITEM, data),
    exportDataset: (data: { datasetId: string; format: string; includeExcluded?: boolean }) => ipcRenderer.invoke(IPC_CHANNELS.DATASETS_V2_EXPORT, data),
    delete: (id: string) => ipcRenderer.invoke(IPC_CHANNELS.DATASETS_V2_DELETE, { id }),
  },
  trainingRuns: {
    importResult(result: {
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
    }): Promise<{ trainingRun: TrainingRun | null; modelVersion: ModelVersion | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TRAINING_RUNS_IMPORT_RESULT, result);
    },
    list(): Promise<TrainingRun[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.TRAINING_RUNS_LIST);
    },
  },
  modelVersions: {
    list(): Promise<ModelVersion[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.MODEL_VERSIONS_LIST);
    },
    activate(id: string): Promise<ModelVersion | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.MODEL_VERSIONS_ACTIVATE, id);
    },
    rollback(id: string): Promise<ModelVersion | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.MODEL_VERSIONS_ROLLBACK, id);
    },
  },

  // -- Vault Configuration (Phase 5) ----------------------------------------
  vault: {
    getConfig(): Promise<VaultConfig> {
      return ipcRenderer.invoke('vault.getConfig');
    },
    updateConfig(config: Partial<VaultConfig>): Promise<VaultConfig> {
      return ipcRenderer.invoke('vault.updateConfig', config);
    },
    validatePath(vaultPath: string): Promise<{ valid: boolean; message: string }> {
      return ipcRenderer.invoke('vault.validatePath', vaultPath);
    },
    pickFolder(): Promise<string> {
      return ipcRenderer.invoke('vault.pickFolder');
    },
  },

  // -- Export (Phase 5) -----------------------------------------------------
  export: {
    single(distilledOutputId: string): Promise<ExportRecord> {
      return ipcRenderer.invoke('export.single', distilledOutputId);
    },
    batch(distilledOutputIds: string[]): Promise<ExportRecord[]> {
      return ipcRenderer.invoke('export.batch', distilledOutputIds);
    },
    openFile(recordId: string): Promise<boolean> {
      return ipcRenderer.invoke('export.openFile', recordId);
    },
    revealInVault(recordId: string): Promise<boolean> {
      return ipcRenderer.invoke('export.revealInVault', recordId);
    },
    history(filter?: { sourceItemId?: string; status?: string; limit?: number }): Promise<ExportRecord[]> {
      return ipcRenderer.invoke('export.history', filter);
    },
    retry(recordId: string): Promise<ExportRecord> {
      return ipcRenderer.invoke('export.retry', recordId);
    },
    // Export lineage queries
    getWithLineage(recordId: string): Promise<{ record: ExportRecord | null; sourceItem: SourceItem | null; distilledOutput: DistilledOutput | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.EXPORT_GET_WITH_LINEAGE, recordId);
    },
    /** @deprecated Use export.getWithLineage() for single-record queries; batch variant not yet consumed */
    recordsWithLineage(filter?: { sourceItemId?: string; status?: string; limit?: number }): Promise<Array<{ record: ExportRecord; sourceItem: SourceItem | null; distilledOutput: DistilledOutput | null }>> {
      return ipcRenderer.invoke(IPC_CHANNELS.EXPORT_RECORDS_WITH_LINEAGE, filter);
    },
  },

  // -- Template (Phase 5) ---------------------------------------------------
  template: {
    preview(distilledOutputId: string): Promise<string> {
      return ipcRenderer.invoke('template.preview', distilledOutputId);
    },
  },

  // -- Permissions (stubs) ---------------------------------------------------
  permissions: {
    getStatus(_source: PermissionCheckSource): Promise<PermissionStatusSnapshot> {
      return ipcRenderer.invoke('permissions.getStatus', _source) as Promise<PermissionStatusSnapshot>;
    },
    onStatusUpdated(cb: (snapshot: PermissionStatusSnapshot) => void): () => void {
      const handler = (
        _event: Electron.IpcRendererEvent,
        payload: { snapshot: PermissionStatusSnapshot; meta?: { source?: PermissionCheckSource; traceId?: string } }
      ) => {
        cb(payload.snapshot);
      };
      ipcRenderer.on('permissions.statusUpdated', handler);
      return () => {
        ipcRenderer.removeListener('permissions.statusUpdated', handler);
      };
    },
    refresh(_source: PermissionCheckSource, _traceId?: string): Promise<PermissionStatusSnapshot> {
      return ipcRenderer.invoke('permissions.refresh', _source, _traceId) as Promise<PermissionStatusSnapshot>;
    },
    openSettings(_key: string, _traceId?: string): Promise<void> {
      return ipcRenderer.invoke('permissions.openSettings', _key, _traceId);
    },
  },

  // -- Settings runtime (stubs) ----------------------------------------------
  settings: {
    get(): Promise<AppSettings> {
      return ipcRenderer.invoke(IPC_CHANNELS.SETTINGS_GET) as Promise<AppSettings>;
    },
    update(patch: Partial<AppSettings>): Promise<AppSettings> {
      return ipcRenderer.invoke(IPC_CHANNELS.SETTINGS_UPDATE, patch) as Promise<AppSettings>;
    },
    runtime: {
      get(): Promise<RuntimeSettings> {
        return ipcRenderer.invoke('settings.runtime.get') as Promise<RuntimeSettings>;
      },
    },
  },

  // -- Records (stubs - Phase 6) --------------------------------------------
  records: {
    recent(_count: number): Promise<RecordItem[]> {
      return ipcRenderer.invoke('records.recent', _count) as Promise<RecordItem[]>;
    },
    touch(_id: string): Promise<void> {
      return ipcRenderer.invoke('records.touch', _id);
    },
  },

  // -- Cutout (stubs - Phase 6) ---------------------------------------------
  cutout: {
    processFromRecord(_id: string): Promise<{ dataUrl: string; fileNameSuggestion: string }> {
      return ipcRenderer.invoke('cutout.processFromRecord', _id);
    },
    saveAsRecord(_params: unknown): Promise<{ recordId: string }> {
      return ipcRenderer.invoke('cutout.saveAsRecord', _params);
    },
  },

  // -- 外部处理服务 (Phase 9: 深度接入) ------------------------------------
  vk: {
    // 保留旧接口兼容
    task: {
      create(_params: unknown): Promise<{ id: string }> {
        return ipcRenderer.invoke('vk.task.create', _params);
      },
    },
    // Phase 9 新增
    checkHealth(): Promise<unknown> {
      return ipcRenderer.invoke(IPC_CHANNELS.VK_CHECK_HEALTH);
    },
    getJobStatus(jobId: string): Promise<unknown> {
      return ipcRenderer.invoke(IPC_CHANNELS.VK_GET_JOB_STATUS, jobId);
    },
    cancelJob(jobId: string): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.VK_CANCEL_JOB, jobId);
    },
    resubmitJob(originalId: string): Promise<{ success: boolean; message: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VK_RESUBMIT_JOB, originalId);
    },
    getRecentJobs(limit?: number): Promise<unknown[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.VK_GET_RECENT_JOBS, limit);
    },
    getFailedJobs(): Promise<unknown[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.VK_GET_FAILED_JOBS);
    },
    manualIngest(jobId: string, originalId?: string): Promise<unknown> {
      return ipcRenderer.invoke(IPC_CHANNELS.VK_MANUAL_INGEST, jobId, originalId);
    },
  },

  // -- Voice Workflow (Phase 10) -------------------------------------------
  voice: {
    getDictationGuide(): Promise<unknown> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_GET_DICTATION_GUIDE);
    },
    getDictationDiagnostics(): Promise<unknown> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_GET_DICTATION_DIAGNOSTICS);
    },
    requestMicrophoneAccess(): Promise<{ success: boolean; supported: boolean; granted: boolean; message: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_REQUEST_MICROPHONE_ACCESS);
    },
    polishTranscript(request: VoicePolishRequest): Promise<{ success: boolean; result?: VoicePolishResult; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_POLISH_TRANSCRIPT, request);
    },
    createPinFromTranscript(request: VoiceCreatePinRequest): Promise<{ success: boolean; captureItem?: CaptureItem; pin?: PinItem; polish?: VoicePolishResult; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_CREATE_PIN_FROM_TRANSCRIPT, request);
    },
    importAudio(params: { filePath: string; title?: string }): Promise<{ success: boolean; originalId?: string; captureItemId?: string; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_IMPORT_AUDIO, params);
    },
    importAudioBuffer(params: { data: ArrayBuffer; mimeType?: string; title?: string }): Promise<{ success: boolean; originalId?: string; captureItemId?: string; error?: string }> {
      return ipcRenderer.invoke('voice.importAudioBuffer', params);
    },
    startWatch(folderPath: string): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_START_WATCH, { folderPath });
    },
    stopWatch(): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_STOP_WATCH);
    },
    getWatchState(): Promise<{ status: string; watchPath: string | null; error: string | null; importedCount: number; pendingCount: number }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_GET_WATCH_STATE);
    },
    retryTranscription(captureItemId: string): Promise<{ success: boolean; jobId?: string; error?: string; engineUnavailable?: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_RETRY_TRANSCRIPTION, { captureItemId });
    },
    getTranscriptionStatus(captureItemId: string): Promise<{ transcriptStatus: string; transcriptText?: string; jobId?: string; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_GET_TRANSCRIPTION_STATUS, { captureItemId });
    },
  },

  // -- Dictation (OpenLess-inspired) ----------------------------------
  dictation: {
    start(): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke('dictation:start');
    },
    stop(): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke('dictation:stop');
    },
    cancel(): Promise<{ success: boolean }> {
      return ipcRenderer.invoke('dictation:cancel');
    },
    getHistory(params?: { limit?: number; offset?: number }): Promise<unknown[]> {
      return ipcRenderer.invoke('dictation:getHistory', params);
    },
    clearHistory(): Promise<{ success: boolean }> {
      return ipcRenderer.invoke('dictation:clearHistory');
    },
    onStateChange(callback: (payload: { state: string; level: number; elapsedMs: number; message: string; insertedChars: number; translation: boolean }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, payload: { state: string; level: number; elapsedMs: number; message: string; insertedChars: number; translation: boolean }) => callback(payload);
      ipcRenderer.on('dictation:state', handler);
      return () => { ipcRenderer.removeListener('dictation:state', handler); };
    },
  },

  // -- Import (Phase 6: External Import) ----------------------------------
  import: {
    scan(params: { vaultPath: string; folderPath?: string; excludePatterns?: string[] }): Promise<unknown> {
      return ipcRenderer.invoke('import.scan', params);
    },
    start(options: unknown): Promise<{ id: string }> {
      return ipcRenderer.invoke('import.start', options);
    },
    status(taskId: string): Promise<unknown> {
      return ipcRenderer.invoke('import.status', taskId);
    },
    cancel(taskId: string): Promise<boolean> {
      return ipcRenderer.invoke('import.cancel', taskId);
    },
    history(limit?: number): Promise<unknown> {
      return ipcRenderer.invoke('import.history', limit);
    },
    tasksList(filter?: { status?: string; limit?: number }): Promise<unknown> {
      return ipcRenderer.invoke('import.tasks.list', filter);
    },
  },

  // -- Logger Read (Phase 3) -----------------------------------------------
  logger: {
    getLevel(): Promise<LogLevel> {
      return ipcRenderer.invoke(IPC_CHANNELS.LOGGER_GET_LEVEL);
    },
    setLevel(level: LogLevel): Promise<LogLevel> {
      return ipcRenderer.invoke(IPC_CHANNELS.LOGGER_SET_LEVEL, level);
    },
    read(channel: LogChannel, limit?: number): Promise<string[]> {
      return ipcRenderer.invoke('logger.read', channel, limit);
    },
  },

  // -- Diagnostics Export (Phase 12.6) ------------------------------------
  diagnostics: {
    export(): Promise<{ success: boolean; filePath?: string; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DIAGNOSTICS_EXPORT);
    },
  },

  // -- AI Task Events (Phase 3) --------------------------------------------
  onAiTasksChanged(callback: (task: AiTask) => void): () => void {
    const handler = (_event: Electron.IpcRendererEvent, task: AiTask) => {
      callback(task);
    };
    ipcRenderer.on('aiTasks.statusChanged', handler);
    return () => {
      ipcRenderer.removeListener('aiTasks.statusChanged', handler);
    };
  },

  // -- Provider Events ----------------------------------------------------
  onProvidersChanged(callback: (event: { action: string; id: string; timestamp: number }) => void): () => void {
    const handler = (
      _event: Electron.IpcRendererEvent,
      data: { action: string; id: string; timestamp: number },
    ) => {
      callback(data);
    };
    ipcRenderer.on(IPC_CHANNELS.PROVIDERS_CHANGED, handler);
    return () => {
      ipcRenderer.removeListener(IPC_CHANNELS.PROVIDERS_CHANGED, handler);
    };
  },

  // -- Import Task Events (Phase 6) ----------------------------------------
  onImportTaskChanged(callback: (task: unknown) => void): () => void {
    const handler = (_event: Electron.IpcRendererEvent, task: unknown) => callback(task);
    ipcRenderer.on('import.task.changed', handler);
    return () => { ipcRenderer.removeListener('import.task.changed', handler); };
  },

  // -- Capture Inbox v0.1 -------------------------------------------------
  captureItems: {
    list(filter?: CaptureItemListFilter): Promise<CaptureItem[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_LIST, filter);
    },
    get(id: string): Promise<CaptureItem | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_GET, id);
    },
    create(data: {
      type: CaptureItem['type'];
      title?: string;
      rawText?: string;
      sourceUrl?: string;
      filePath?: string;
      userNote?: string;
      imageBase64?: string;
      imageMimeType?: string;
      imageOriginalName?: string;
    }): Promise<CaptureItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_CREATE, data);
    },
    update(id: string, patch: Partial<CaptureItem>): Promise<CaptureItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_UPDATE, id, patch);
    },
    delete(id: string): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_DELETE, id);
    },
    exportMarkdown(ids: string[]): Promise<string[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_EXPORT_MARKDOWN, ids);
    },
    readImage(filePath: string): Promise<{ ok: boolean; dataUrl?: string; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.CAPTURE_ITEMS_READ_IMAGE, filePath);
    },
  },

  onCaptureItemsChanged(callback: (event: { action: string; id: string; timestamp: number }) => void): () => void {
    const handler = (_event: Electron.IpcRendererEvent, data: { action: string; id: string; timestamp: number }) => {
      callback(data);
    };
    ipcRenderer.on(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, handler);
    return () => {
      ipcRenderer.removeListener(IPC_CHANNELS.CAPTURE_ITEMS_CHANGED, handler);
    };
  },

  // -- AcMind Pin Pool -----------------------------------------------------
  pinPool: {
    list(filter?: PinItemListFilter): Promise<PinItem[]> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_LIST, filter);
    },
    get(id: string): Promise<PinItem | null> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_GET, id);
    },
    createFromCapture(captureItemId: string, overrides?: Partial<PinItem>): Promise<PinItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_CREATE_FROM_CAPTURE, captureItemId, overrides);
    },
    createFromText(text: string, title?: string): Promise<PinItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_CREATE_FROM_TEXT, text, title);
    },
    prefilter(id: string): Promise<{ pin: PinItem; result: unknown }> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_PREFILTER, id);
    },
    promoteToInbox(id: string): Promise<{ pin: PinItem; sourceItem: SourceItem }> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_PROMOTE_TO_INBOX, id);
    },
    update(id: string, patch: Partial<PinItem>): Promise<PinItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_UPDATE, id, patch);
    },
    ignore(id: string): Promise<PinItem> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_IGNORE, id);
    },
    delete(id: string): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.PIN_POOL_DELETE, id);
    },
  },

  onPinPoolChanged(callback: (event: { action: string; id: string; timestamp: number }) => void): () => void {
    const handler = (_event: Electron.IpcRendererEvent, data: { action: string; id: string; timestamp: number }) => {
      callback(data);
    };
    ipcRenderer.on(IPC_CHANNELS.PIN_POOL_CHANGED, handler);
    return () => {
      ipcRenderer.removeListener(IPC_CHANNELS.PIN_POOL_CHANGED, handler);
    };
  },

  // -- AI Distillation Workbench --------------------------------------------
  workbench: {
    saveMarkdown(data: { content: string; filename?: string }): Promise<{ success: boolean; filePath?: string; filename?: string; error?: string }> {
      return ipcRenderer.invoke('workbench.saveMarkdown', data);
    },
    revealInFinder(filePath: string): Promise<boolean> {
      return ipcRenderer.invoke('workbench.revealInFinder', filePath);
    },
  },

  // -- Workspace directory operations (PersonalSpace) -------------------------
  workspace: {
    selectDirectory(): Promise<{ success: boolean; path?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_SELECT_DIRECTORY);
    },
    openDirectory(dirPath: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_OPEN_DIRECTORY, dirPath);
    },
    testWrite(dirPath: string): Promise<{ success: boolean; path?: string; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.WORKSPACE_TEST_WRITE, dirPath);
    },
  },

  // -- Capsule (Desktop Muse Capsule) ----------------------------------------
  capsule: {
    toggle: () => ipcRenderer.send('capsule:toggle'),
    expand: () => ipcRenderer.send('capsule:expand'),
    collapse: () => ipcRenderer.send('capsule:collapse'),
    startDrag: (screenX: number, screenY: number) => ipcRenderer.send('capsule:start-drag', screenX, screenY),
    dragMove: (deltaX: number, deltaY: number) => ipcRenderer.send('capsule:drag-move', deltaX, deltaY),
    endDrag: () => ipcRenderer.send('capsule:end-drag'),
    onStateChanged: (callback: (payload: { state: string; edge?: string; pendingCount?: number }) => void) => {
      const handler = (_event: Electron.IpcRendererEvent, payload: { state: string; edge?: string; pendingCount?: number }) => callback(payload);
      ipcRenderer.on('capsule:state-changed', handler);
      return () => ipcRenderer.removeListener('capsule:state-changed', handler);
    },
    getStatus: () => ipcRenderer.invoke(IPC_CHANNELS.CAPSULE_GET_STATUS) as Promise<import('../shared/types').CapsuleStatus>,
  },

  // -- Dashboard (Batch 4) ---------------------------------------------------
  dashboard: {
    getStats: () => ipcRenderer.invoke(IPC_CHANNELS.DASHBOARD_GET_STATS) as Promise<import('../shared/types').DashboardStats | null>,
  },

  // -- Health Check (Batch 5) -------------------------------------------------
  health: {
    check: () => ipcRenderer.invoke(IPC_CHANNELS.HEALTH_CHECK) as Promise<import('../shared/types').HealthCheckResult>,
  },

  // -- Batch 6: Knowledge Projects -------------------------------------------
  projects: {
    list: () => ipcRenderer.invoke(IPC_CHANNELS.PROJECTS_LIST),
    create: (data: { name: string; description?: string; color?: string }) => ipcRenderer.invoke(IPC_CHANNELS.PROJECTS_CREATE, data),
    update: (data: { id: string; name?: string; description?: string; status?: string; color?: string }) => ipcRenderer.invoke(IPC_CHANNELS.PROJECTS_UPDATE, data),
    delete: (id: string) => ipcRenderer.invoke(IPC_CHANNELS.PROJECTS_DELETE, { id }),
    addItem: (data: { projectId: string; itemType: string; itemId: string }) => ipcRenderer.invoke(IPC_CHANNELS.PROJECTS_ADD_ITEM, data),
    removeItem: (data: { projectId: string; itemId: string }) => ipcRenderer.invoke(IPC_CHANNELS.PROJECTS_REMOVE_ITEM, data),
  },

  // -- Batch 6: Tags ----------------------------------------------------------
  tags: {
    list: () => ipcRenderer.invoke(IPC_CHANNELS.TAGS_LIST),
    rename: (data: { oldName: string; newName: string }) => ipcRenderer.invoke(IPC_CHANNELS.TAGS_RENAME, data),
    delete: (name: string) => ipcRenderer.invoke(IPC_CHANNELS.TAGS_DELETE, { name }),
  },

  // Phase 1: Hybrid Search
  search: {
    hybrid: (query: string, options?: Record<string, unknown>, embeddingConfig?: Record<string, unknown>) =>
      ipcRenderer.invoke(IPC_CHANNELS.SEARCH_HYBRID, query, options, embeddingConfig),
    rebuildFts: () => ipcRenderer.invoke(IPC_CHANNELS.SEARCH_REBUILD_FTS),
    getStatus: () => ipcRenderer.invoke(IPC_CHANNELS.SEARCH_GET_STATUS),
  },
  // Phase 2: Document Parser
  parser: {
    importFile: (filePath: string) => ipcRenderer.invoke(IPC_CHANNELS.PARSER_IMPORT_FILE, filePath),
    importUrl: (url: string) => ipcRenderer.invoke(IPC_CHANNELS.PARSER_IMPORT_URL, url),
    importBatch: (filePaths: string[]) => ipcRenderer.invoke(IPC_CHANNELS.PARSER_IMPORT_BATCH, filePaths),
  },
  // MarkItDown integration
  markitdown: {
    convert: (url: string) => ipcRenderer.invoke(IPC_CHANNELS.MARKITDOWN_CONVERT, url),
    check: () => ipcRenderer.invoke(IPC_CHANNELS.MARKITDOWN_CHECK),
  },
  // Phase 3: File Converter (MarkItDown local file → Markdown)
  fileConverter: {
    convert(filePath: string): Promise<{ success: boolean; jobId: string; markdown?: string; title?: string; error?: string; engine?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.FILE_CONVERT, { filePath });
    },
    getStatus(jobId: string): Promise<{ success: boolean; job: ProcessJob | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.FILE_CONVERT_STATUS, { jobId });
    },
    listJobs(limit?: number): Promise<{ success: boolean; jobs: ProcessJob[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.FILE_CONVERT_LIST, { limit });
    },
    saveToInbox(jobId: string, markdown: string, title?: string, filePath?: string): Promise<{ success: boolean; sourceItem?: SourceItem; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.FILE_CONVERT_SAVE_TO_INBOX, { jobId, markdown, title, filePath });
    },
    preview(filePath: string): Promise<{ success: boolean; markdown?: string; title?: string; error?: string; engine?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.FILE_CONVERT_PREVIEW, { filePath });
    },
    onJobsChanged(cb: (data: { timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { timestamp: number }) => cb(data);
      ipcRenderer.on(IPC_CHANNELS.FILE_CONVERT_JOBS_CHANGED, handler);
      return () => { ipcRenderer.removeListener(IPC_CHANNELS.FILE_CONVERT_JOBS_CHANGED, handler); };
    },
  },
  // Calendar
  calendar: {
    showNotification(title: string, body: string): Promise<boolean> {
      return ipcRenderer.invoke(IPC_CHANNELS.CALENDAR_SHOW_NOTIFICATION, { title, body });
    },
  },
  // Phase 3: Scheduler
  scheduler: {
    createTask: (params: Record<string, unknown>) => ipcRenderer.invoke(IPC_CHANNELS.SCHEDULER_CREATE_TASK, params),
    updateTask: (id: string, updates: Record<string, unknown>) => ipcRenderer.invoke(IPC_CHANNELS.SCHEDULER_UPDATE_TASK, id, updates),
    deleteTask: (id: string) => ipcRenderer.invoke(IPC_CHANNELS.SCHEDULER_DELETE_TASK, id),
    toggleTask: (id: string, enabled: boolean) => ipcRenderer.invoke(IPC_CHANNELS.SCHEDULER_TOGGLE_TASK, id, enabled),
    getTasks: () => ipcRenderer.invoke(IPC_CHANNELS.SCHEDULER_GET_TASKS),
    getTask: (id: string) => ipcRenderer.invoke(IPC_CHANNELS.SCHEDULER_GET_TASK, id),
    runNow: (id: string) => ipcRenderer.invoke(IPC_CHANNELS.SCHEDULER_RUN_NOW, id),
  },
  // Voice / Whisper STT
  whisper: {
    getStatus: () => ipcRenderer.invoke(IPC_CHANNELS.WHISPER_GET_STATUS),
    getModels: () => ipcRenderer.invoke(IPC_CHANNELS.WHISPER_GET_MODELS),
    downloadModel: (modelSize: string, onProgress?: (progress: number) => void) => {
      const request = ipcRenderer.invoke(IPC_CHANNELS.WHISPER_DOWNLOAD_MODEL, modelSize);
      if (onProgress) {
        const handler = (_event: Electron.IpcRendererEvent, progress: number) => onProgress(progress);
        ipcRenderer.on(IPC_CHANNELS.WHISPER_DOWNLOAD_PROGRESS, handler);
        request.finally(() => {
          ipcRenderer.removeListener(IPC_CHANNELS.WHISPER_DOWNLOAD_PROGRESS, handler);
        });
      }
      return request;
    },
    openCacheDir: () => ipcRenderer.invoke(IPC_CHANNELS.WHISPER_OPEN_CACHE_DIR),
    deleteModel: (modelSize: string) => ipcRenderer.invoke(IPC_CHANNELS.WHISPER_DELETE_MODEL, modelSize),
    initialize: (modelSize: string) => ipcRenderer.invoke(IPC_CHANNELS.WHISPER_INITIALIZE, modelSize),
    repair: (onProgress?: (progress: number) => void) => {
      const request = ipcRenderer.invoke(IPC_CHANNELS.WHISPER_REPAIR);
      if (onProgress) {
        const handler = (_event: Electron.IpcRendererEvent, progress: number) => onProgress(progress);
        ipcRenderer.on(IPC_CHANNELS.WHISPER_DOWNLOAD_PROGRESS, handler);
        request.finally(() => {
          ipcRenderer.removeListener(IPC_CHANNELS.WHISPER_DOWNLOAD_PROGRESS, handler);
        });
      }
      return request;
    },
    transcribe: (audioData: Float32Array, options?: Record<string, unknown>) =>
      ipcRenderer.invoke(IPC_CHANNELS.WHISPER_TRANSCRIBE, audioData, options),
  },
  // AI Polish (text refinement)
  polish: {
    text: (text: string, style: string, customOptions?: Record<string, unknown>) =>
      ipcRenderer.invoke(IPC_CHANNELS.POLISH_TEXT, text, style, customOptions),
    getStyles: () => ipcRenderer.invoke(IPC_CHANNELS.POLISH_GET_STYLES),
  },
  // V2.1: OutputSpecService
  outputSpec: {
    getInfo: () => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_INFO),
    getActiveProfile: () => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_ACTIVE_PROFILE),
    getProfile: (profileId: string) => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_PROFILE, profileId),
    getTemplate: (templateName?: string) => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_TEMPLATE, templateName),
    getTagRules: () => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_TAG_RULES),
    getCategoryRules: () => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_CATEGORY_RULES),
    getDistillTemplate: (templateName?: string) => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_DISTILL_TEMPLATE, templateName),
    getSnippet: (snippetName: string) => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_SNIPPET, snippetName),
    getRawContentSection: (rawContent?: string) => ipcRenderer.invoke(IPC_CHANNELS.OUTPUT_SPEC_GET_RAW_CONTENT_SECTION, rawContent),
  },
  // V2.1: Content Pipeline
  pipeline: {
    processText: (text: string, options?: Record<string, unknown>) =>
      ipcRenderer.invoke(IPC_CHANNELS.PIPELINE_PROCESS_TEXT, text, options),
    getStatus: (sourceItemId: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.PIPELINE_GET_STATUS, sourceItemId),
    retryExport: (sourceItemId: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.PIPELINE_RETRY_EXPORT, sourceItemId),
    getStateHistory: (sourceItemId: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.PIPELINE_GET_STATE_HISTORY, sourceItemId),
    checkDuplicate: (text: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.PIPELINE_CHECK_DUPLICATE, text),
    batchProcessedAt: (sourceItemIds: string[]) =>
      ipcRenderer.invoke(IPC_CHANNELS.PIPELINE_BATCH_PROCESSED_AT, sourceItemIds),
    // V2.1 Phase 8: Regeneration
    regenerate: (sourceItemId: string, options?: { regenerationTier?: string; regenerationProfileId?: string }) =>
      ipcRenderer.invoke(IPC_CHANNELS.STRATEGY_REGENERATE, sourceItemId, options),
  },
  // V2.1 Phase 6.1: Unified Error Model
  errors: {
    list: (filter?: { status?: string; errorType?: string; originalId?: string; limit?: number; offset?: number }) =>
      ipcRenderer.invoke(IPC_CHANNELS.ERRORS_LIST, filter),
    get: (errorId: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.ERRORS_GET, errorId),
    resolve: (errorId: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.ERRORS_RESOLVE, errorId),
    dismiss: (errorId: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.ERRORS_DISMISS, errorId),
    clearResolved: () =>
      ipcRenderer.invoke(IPC_CHANNELS.ERRORS_CLEAR_RESOLVED),
  },
  // V2.1 Phase 6.3: Unified Retry
  retry: {
    error: (errorId: string) =>
      ipcRenderer.invoke(IPC_CHANNELS.RETRY_ERROR, errorId),
  },
  // V2.1 Phase 6.5: Advanced Control Panel
  localModel: {
    getRuntimeStatus: () =>
      ipcRenderer.invoke(IPC_CHANNELS.LOCAL_MODEL_STATUS),
  },
  // Phase 4: AI Runtime (Action 管理 + 真实 AI 调用)
  aiRuntime: {
    listActions(): Promise<{ success: boolean; actions: AIAction[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_LIST_ACTIONS);
    },
    getAction(id: string): Promise<{ success: boolean; action: AIAction | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_GET_ACTION, { id });
    },
    createAction(params: { name: string; inputTypes: SourceType[]; actionType: AIActionType; promptProfileId?: string }): Promise<{ success: boolean; action: AIAction }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_CREATE_ACTION, params);
    },
    updateAction(id: string, updates: Partial<AIAction>): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_UPDATE_ACTION, { id, updates });
    },
    deleteAction(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_DELETE_ACTION, { id });
    },
    runAction(actionId: string, input: string, sourceType?: SourceType): Promise<{
      success: boolean;
      taskId?: string;
      content?: ProcessedContent;
      rawText?: string;
      modelCall?: { providerId: string; modelId: string; latencyMs: number; promptTokens?: number; completionTokens?: number };
      routingReason?: string;
      qualityScore?: number;
      usedFallback?: boolean;
      error?: string;
    }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_RUN_ACTION, { actionId, input, sourceType });
    },
    listJobs(limit?: number): Promise<{ success: boolean; jobs: AiTask[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_LIST_JOBS, { limit });
    },
    getJob(id: string): Promise<{ success: boolean; job: AiTask | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_GET_JOB, { id });
    },
    cancelJob(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_CANCEL_JOB, { id });
    },
    healthCheck(providerId: string): Promise<{ success: boolean; ok?: boolean; latencyMs?: number; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.AI_RUNTIME_HEALTH_CHECK, { providerId });
    },
    onJobChanged(cb: (data: { timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { timestamp: number }) => cb(data);
      ipcRenderer.on(IPC_CHANNELS.AI_RUNTIME_JOB_CHANGED, handler);
      return () => { ipcRenderer.removeListener(IPC_CHANNELS.AI_RUNTIME_JOB_CHANGED, handler); };
    },
  },
  // Phase 5: DistilledNotes (蒸馏笔记 CRUD)
  distilledNotes: {
    list(params?: { limit?: number; offset?: number }): Promise<{ success: boolean; notes: DistilledNote[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DISTILLED_NOTES_LIST, params);
    },
    get(id: string): Promise<{ success: boolean; note: DistilledNote | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DISTILLED_NOTES_GET, { id });
    },
    create(note: DistilledNote): Promise<{ success: boolean; note: DistilledNote }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DISTILLED_NOTES_CREATE, { note });
    },
    update(id: string, patch: Partial<DistilledNote>): Promise<{ success: boolean; note: DistilledNote | null }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DISTILLED_NOTES_UPDATE, { id, patch });
    },
    delete(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DISTILLED_NOTES_DELETE, { id });
    },
  },
  // Phase 5: VaultSearch (Obsidian Vault 关键词搜索)
  vaultSearch: {
    search(keyword: string, options?: { folderPath?: string; limit?: number }): Promise<{ success: boolean; results: VaultSearchResult[]; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VAULT_SEARCH, { keyword, ...options });
    },
  },
  // Phase 6: Voice Dictionary (语音词典管理)
  voiceDictionary: {
    list(): Promise<{ success: boolean; entries: VoiceDictionaryEntry[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_DICTIONARY_LIST);
    },
    add(phrase: string, note?: string): Promise<{ success: boolean; entry: VoiceDictionaryEntry }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_DICTIONARY_ADD, { phrase, note });
    },
    delete(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_DICTIONARY_DELETE, { id });
    },
    toggle(id: string, enabled: boolean): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.VOICE_DICTIONARY_TOGGLE, { id, enabled });
    },
  },
  // Phase 6: ASR Provider (语音转写)
  asr: {
    getStatus(): Promise<{ success: boolean; status: { provider: string; configured: boolean; message: string; endpoint?: string } }> {
      return ipcRenderer.invoke(IPC_CHANNELS.ASR_GET_STATUS);
    },
    transcribe(filePath: string, options?: { language?: string; translate?: boolean; prompt?: string }): Promise<{ success: boolean; text: string; error?: string; engine?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.ASR_TRANSCRIBE, { filePath, ...options });
    },
  },
  // ToolBench: GitHub Projects & Local Scripts
  toolBench: {
    listGithubProjects(): Promise<{ success: boolean; projects: GithubToolProject[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_LIST_GITHUB_PROJECTS);
    },
    createGithubProject(input: Omit<GithubToolProject, 'id' | 'createdAt' | 'updatedAt' | 'lastUsedAt'>): Promise<{ success: boolean; id?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_CREATE_GITHUB_PROJECT, input);
    },
    updateGithubProject(id: string, patch: Partial<GithubToolProject>): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_UPDATE_GITHUB_PROJECT, { id, patch });
    },
    deleteGithubProject(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_DELETE_GITHUB_PROJECT, { id });
    },
    listScripts(): Promise<{ success: boolean; scripts: LocalScriptTool[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_LIST_SCRIPTS);
    },
    createScript(input: Omit<LocalScriptTool, 'id' | 'createdAt' | 'updatedAt' | 'lastUsedAt'>): Promise<{ success: boolean; id?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_CREATE_SCRIPT, input);
    },
    updateScript(id: string, patch: Partial<LocalScriptTool>): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_UPDATE_SCRIPT, { id, patch });
    },
    deleteScript(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_DELETE_SCRIPT, { id });
    },
    openUrl(url: string): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_OPEN_URL, { url });
    },
    openPath(dirPath: string): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_OPEN_PATH, { path: dirPath });
    },
    copyCommand(command: string): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_COPY_COMMAND, { command });
    },
    scanLocalDir(dirPath: string): Promise<{ success: boolean; repos?: any[]; error?: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_SCAN_LOCAL_DIR, { dirPath });
    },
    batchImportProjects(repos: any[]): Promise<{ success: boolean; imported: number; skipped: number }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_BATCH_IMPORT_PROJECTS, { repos });
    },
    pickDirectory(): Promise<{ success: boolean; path: string }> {
      return ipcRenderer.invoke(IPC_CHANNELS.TOOLBENCH_PICK_DIRECTORY);
    },
  },
  // Dashboard Widget (独立仪表盘)
  dashboardWidget: {
    getMedia(): Promise<{ success: boolean; media: any }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DASHBOARD_WIDGET_GET_MEDIA);
    },
    mediaControl(action: 'playpause' | 'next' | 'previous'): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DASHBOARD_WIDGET_MEDIA_CONTROL, action);
    },
    getCalendar(): Promise<{ success: boolean; events: any[] }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DASHBOARD_WIDGET_GET_CALENDAR);
    },
    toggleWindow(enabled: boolean): Promise<{ success: boolean }> {
      return ipcRenderer.invoke(IPC_CHANNELS.DASHBOARD_WIDGET_TOGGLE_WINDOW, enabled);
    },
  },

  // -- Phase A: Agent Chat --------------------------------------------
  agentChat: {
    // Sessions
    listSessions(filter?: { status?: 'active' | 'archived' | 'deleted'; limit?: number; offset?: number }): Promise<{ success: boolean; sessions: ChatSession[] }> {
      return ipcRenderer.invoke('agentChat.sessions.list', filter);
    },
    getSession(id: string): Promise<{ success: boolean; session: ChatSession | null }> {
      return ipcRenderer.invoke('agentChat.sessions.get', id);
    },
    createSession(params?: { title?: string; metadata?: ChatSessionMetadata; providerId?: string; modelId?: string }): Promise<{ success: boolean; session?: ChatSession; error?: string }> {
      return ipcRenderer.invoke('agentChat.sessions.create', params);
    },
    updateSession(id: string, patch: Partial<ChatSession>): Promise<{ success: boolean; session?: ChatSession; error?: string }> {
      return ipcRenderer.invoke('agentChat.sessions.update', id, patch);
    },
    deleteSession(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke('agentChat.sessions.delete', id);
    },
    // Messages
    listMessages(sessionId: string, filter?: { limit?: number }): Promise<{ success: boolean; messages: ChatMessage[] }> {
      return ipcRenderer.invoke('agentChat.messages.list', sessionId, filter);
    },
    createSystemMessage(sessionId: string, content: string): Promise<{ success: boolean; message?: ChatMessage; error?: string }> {
      return ipcRenderer.invoke('agentChat.messages.createSystem', sessionId, content);
    },
    listSkills(): Promise<{ success: boolean; skills: Array<{ name: string; description: string; category: string; requiresConfirmation: boolean }> }> {
      return ipcRenderer.invoke('agentChat.skills.list');
    },
    sendMessage(params: { sessionId: string; content: string; providerId?: string }): Promise<{ success: boolean; messageId?: string; error?: string }> {
      return ipcRenderer.invoke('agentChat.send', params);
    },
    stopGeneration(): Promise<{ success: boolean; stopped?: boolean }> {
      return ipcRenderer.invoke('agentChat.stop');
    },
    // Event listeners
    onStreamChunk(callback: (data: { messageId: string; chunk: string; accumulated: string; timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { messageId: string; chunk: string; accumulated: string; timestamp: number }) => callback(data);
      ipcRenderer.on('agentChat.stream.chunk', handler);
      return () => { ipcRenderer.removeListener('agentChat.stream.chunk', handler); };
    },
    onStreamDone(callback: (data: { messageId: string; interrupted: boolean; timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { messageId: string; interrupted: boolean; timestamp: number }) => callback(data);
      ipcRenderer.on('agentChat.stream.done', handler);
      return () => { ipcRenderer.removeListener('agentChat.stream.done', handler); };
    },
    onStreamError(callback: (data: { messageId: string; error: string; timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { messageId: string; error: string; timestamp: number }) => callback(data);
      ipcRenderer.on('agentChat.stream.error', handler);
      return () => { ipcRenderer.removeListener('agentChat.stream.error', handler); };
    },
    onSessionChanged(callback: (data: { action: string; id: string; timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { action: string; id: string; timestamp: number }) => callback(data);
      ipcRenderer.on('agentChat.session.changed', handler);
      return () => { ipcRenderer.removeListener('agentChat.session.changed', handler); };
    },
    onMessageChanged(callback: (data: { action: string; id: string; sessionId: string; timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { action: string; id: string; sessionId: string; timestamp: number }) => callback(data);
      ipcRenderer.on('agentChat.message.changed', handler);
      return () => { ipcRenderer.removeListener('agentChat.message.changed', handler); };
    },
  },

  // -- Phase C: Agent Tasks --------------------------------------------
  agentTasks: {
    list(filter?: { status?: string; limit?: number; offset?: number }): Promise<{ success: boolean; tasks: import('../shared/types').AgentTask[] }> {
      return ipcRenderer.invoke('agentTasks.list', filter);
    },
    get(id: string): Promise<{ success: boolean; task: import('../shared/types').AgentTask | null }> {
      return ipcRenderer.invoke('agentTasks.get', id);
    },
    create(params: { sessionId: string; name: string; skillName?: string; inputParams?: Record<string, unknown> }): Promise<{ success: boolean; task?: import('../shared/types').AgentTask; error?: string }> {
      return ipcRenderer.invoke('agentTasks.create', params);
    },
    update(id: string, updates: Partial<import('../shared/types').AgentTask>): Promise<{ success: boolean; task?: import('../shared/types').AgentTask; error?: string }> {
      return ipcRenderer.invoke('agentTasks.update', id, updates);
    },
    delete(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke('agentTasks.delete', id);
    },
    runNow(id: string): Promise<{ success: boolean; task?: import('../shared/types').AgentTask; error?: string }> {
      return ipcRenderer.invoke('agentTasks.runNow', id);
    },
    history(taskId: string): Promise<{ success: boolean; events: import('../shared/types').AgentTaskEvent[] }> {
      return ipcRenderer.invoke('agentTasks.history', taskId);
    },
    cancel(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke('agentTasks.cancel', id);
    },
    onTaskChanged(callback: (data: { task: import('../shared/types').AgentTask; timestamp: number }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { task: import('../shared/types').AgentTask; timestamp: number }) => callback(data);
      ipcRenderer.on('agentTasks.task.changed', handler);
      return () => { ipcRenderer.removeListener('agentTasks.task.changed', handler); };
    },
  },

  // -- Phase D: Scheduled Agent Tasks ---------------------------------
  scheduledAgentTasks: {
    list(): Promise<{ success: boolean; tasks: import('../shared/types').ScheduledAgentTask[] }> {
      return ipcRenderer.invoke('scheduledAgentTasks.list');
    },
    get(id: string): Promise<{ success: boolean; task: import('../shared/types').ScheduledAgentTask | null }> {
      return ipcRenderer.invoke('scheduledAgentTasks.get', id);
    },
    create(params: { name: string; cronExpression: string; skillName: string; inputParams?: Record<string, unknown>; enabled?: boolean }): Promise<{ success: boolean; task?: import('../shared/types').ScheduledAgentTask; error?: string }> {
      return ipcRenderer.invoke('scheduledAgentTasks.create', params);
    },
    update(id: string, updates: Partial<import('../shared/types').ScheduledAgentTask>): Promise<{ success: boolean; task?: import('../shared/types').ScheduledAgentTask; error?: string }> {
      return ipcRenderer.invoke('scheduledAgentTasks.update', id, updates);
    },
    delete(id: string): Promise<{ success: boolean }> {
      return ipcRenderer.invoke('scheduledAgentTasks.delete', id);
    },
    runNow(id: string): Promise<{ success: boolean; error?: string }> {
      return ipcRenderer.invoke('scheduledAgentTasks.runNow', id);
    },
    onTaskChanged(callback: (data: { action: string; task: import('../shared/types').ScheduledAgentTask }) => void): () => void {
      const handler = (_event: Electron.IpcRendererEvent, data: { action: string; task: import('../shared/types').ScheduledAgentTask }) => callback(data);
      ipcRenderer.on('scheduledAgentTasks.task.changed', handler);
      return () => { ipcRenderer.removeListener('scheduledAgentTasks.task.changed', handler); };
    },
  },
} as const;

// ---------------------------------------------------------------------------
// Expose via contextBridge
// ---------------------------------------------------------------------------
// 'acmind' is the legacy name kept for backward compatibility with existing renderer code.
// New code MUST use 'acmind'. Both names point to the same API object.
// TODO: Migrate all renderer code from window.acmind to window.acmind, then remove 'acmind'.

contextBridge.exposeInMainWorld('acmind', acmindApi);  // legacy, deprecated
contextBridge.exposeInMainWorld('acmind', acmindApi);   // canonical

// ---------------------------------------------------------------------------
// Type declaration for renderer global
// ---------------------------------------------------------------------------

declare global {
  interface Window {
    /** @deprecated Use window.acmind instead. Will be removed after migration. */
    pinmind: typeof acmindApi;
    acmind: typeof acmindApi;
  }
}
