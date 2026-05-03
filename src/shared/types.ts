import type { DesktopMuseCapsuleSettings } from './capsuleSettings';
import type { DistilledDocumentType } from './markdownSpec';

// AcMind Core Type Definitions
// Source: AcMind Phase 0-5 Implementation Plan + Governance Spec

// ─── SourceItem ───────────────────────────────────────────────
// Represents a captured content item (text, image, or URL)

export interface SourceItem {
  id: string;
  captureItemId?: string;
  type: 'text' | 'image' | 'url';
  source: 'clipboard' | 'screenshot' | 'manual' | 'vault_import' | 'audio';
  contentPath: string;
  contentHash?: string;
  previewText?: string;
  ocrText?: string;
  sourceApp?: string | null;
  originalUrl?: string;
  createdAt: number;
  status: 'inbox' | 'distilling' | 'distilled' | 'exported' | 'archived';
  title?: string;
  tags?: string[];
  vaultImportPath?: string;
  /** V2.1: Original content identifier for deduplication */
  originalId?: string;
  /** V2.1 Phase 8: Extended metadata (model call records, quality info, regeneration history) */
  metadata?: Record<string, unknown>;
}

// ─── AiTask ───────────────────────────────────────────────────
// Represents a single AI processing task against a SourceItem

export type AiTier = 'local_light' | 'cloud_standard' | 'cloud_advanced';
export type AiOperation = 'rename' | 'summarize' | 'classify' | 'tag' | 'valueScore' | 'cleanSuggest' | 'prefilter';
export type AiTaskStatus = 'queued' | 'running' | 'done' | 'failed' | 'cancelled';

export interface AiTask {
  id: string;
  sourceItemId: string;
  tier: AiTier;
  operation: AiOperation;
  status: AiTaskStatus;
  provider: string;
  model: string;
  input: Record<string, unknown>;
  output?: Record<string, unknown>;
  error?: string;
  createdAt: number;
  updatedAt: number;
  startedAt?: number;
  finishedAt?: number;
  latencyMs?: number;
}

// ─── DistilledOutput ──────────────────────────────────────────
// The structured result of AI distillation for a SourceItem

export interface DistilledOutput {
  id: string;
  sourceItemId: string;
  taskId: string;
  operation?: AiOperation;
  suggestedTitle?: string;
  summary?: string;
  category?: string;
  tags?: string[];
  documentType?: DistilledDocumentType;
  contentMarkdown?: string;
  valueScore?: number;
  cleanSuggestion?: 'keep' | 'merge' | 'discard';
  confidence?: number;
  reviewStatus?: 'pending' | 'accepted' | 'edited' | 'rejected';
  reviewedAt?: number;
  acceptedKnowledgeCardId?: string;
  createdAt: number;
}

// ─── ExportRecord ─────────────────────────────────────────────
// Records an export of a distilled item to a vault (e.g. Obsidian)

export interface ExportRecord {
  id: string;
  sourceItemId: string;
  distilledOutputId: string;
  knowledgeCardId?: string;
  vaultPath: string;
  relativeFilePath: string;
  frontmatter: Record<string, unknown>;
  exportedAt: number;
  status: 'success' | 'conflict' | 'failed';
  conflictResolution?: 'overwrite' | 'rename' | 'skip';
  error?: string;
}

export interface KnowledgeCard {
  id: string;
  sourceItemId: string;
  distilledOutputId?: string;
  canonicalTitle: string;
  summary?: string;
  category?: string;
  tags: string[];
  body?: string;
  status: 'active' | 'archived' | 'draft';
  createdAt: number;
  updatedAt: number;
}

export interface KnowledgeEdge {
  id: string;
  fromKnowledgeCardId: string;
  toKnowledgeCardId: string;
  relationType: 'duplicate_of' | 'derived_from' | 'related_to' | 'same_topic';
  status: 'suggested' | 'accepted' | 'rejected';
  confidence?: number;
  reason?: string;
  createdAt: number;
  updatedAt: number;
}

export interface ReviewEvent {
  id: string;
  sourceItemId: string;
  distilledOutputId: string;
  knowledgeCardId?: string;
  action: 'approve' | 'edit' | 'discard' | 'export';
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  actor: 'user' | 'system';
  provider?: string;
  model?: string;
  taskId?: string;
  createdAt: number;
}

export interface TrainingExample {
  id: string;
  capability: 'rename' | 'summary' | 'classify' | 'tag';
  sourceItemId: string;
  distilledOutputId?: string;
  knowledgeCardId?: string;
  input: Record<string, unknown>;
  teacherOutput: Record<string, unknown>;
  targetOutput: Record<string, unknown>;
  metadata: Record<string, unknown>;
  createdAt: number;
}

export interface DatasetSnapshot {
  id: string;
  name: string;
  description?: string;
  manifestPath: string;
  splitConfig: Record<string, unknown>;
  counts: Record<string, number>;
  status: 'draft' | 'frozen' | 'exported';
  createdAt: number;
  frozenAt?: number;
}

export interface TrainingRun {
  id: string;
  snapshotId: string;
  baseModel: string;
  status: 'queued' | 'running' | 'done' | 'failed' | 'cancelled';
  manifestPath?: string;
  artifactPath?: string;
  metrics?: Record<string, unknown>;
  error?: string;
  createdAt: number;
  finishedAt?: number;
}

export interface EvalRun {
  id: string;
  snapshotId: string;
  trainingRunId?: string;
  modelVersionId?: string;
  metrics: Record<string, unknown>;
  createdAt: number;
}

export interface ModelVersion {
  id: string;
  name: string;
  baseModel: string;
  artifactPath: string;
  modelfilePath?: string;
  provider: 'ollama';
  status: 'candidate' | 'active' | 'archived';
  notes?: string;
  createdAt: number;
  updatedAt: number;
}

// ─── UserProfile ──────────────────────────────────────────────
// User identity and personalization

export interface UserProfile {
  displayName: string;
  avatarType: 'initial' | 'image' | 'icon' | 'gradient';
  avatarImagePath?: string;
  bio?: string;
  roleTags: string[];
  workspaceName: string;
}

export const DEFAULT_USER_PROFILE: UserProfile = {
  displayName: '',
  avatarType: 'initial',
  bio: '',
  roleTags: [],
  workspaceName: '我的第二大脑',
};

// ─── UserPreferences ──────────────────────────────────────────
// UI and behavior preferences

export interface UserPreferences {
  themeMode: 'light' | 'dark' | 'system';
  accentColor: string;
  density: 'comfortable' | 'compact';
  defaultStartPage: string;
  showStatusBar: boolean;
}

export const DEFAULT_USER_PREFERENCES: UserPreferences = {
  themeMode: 'system',
  accentColor: '#F97316',
  density: 'comfortable',
  defaultStartPage: 'daily-flow',
  showStatusBar: true,
};

// ─── AppSettings ──────────────────────────────────────────────
// Global application settings

// ─── ModelStrategySettings (V2.1 Phase 8.6) ────────────────────
// Settings for model routing, privacy, and fallback behavior

export interface ModelStrategySettings {
  /** 是否允许云端处理 */
  allowCloud: boolean;
  /** 隐私模式：优先本地模型，云端需确认 */
  privacyMode: boolean;
  /** 默认模型层级 */
  defaultModelTier: 'local_light' | 'cloud_standard' | 'cloud_advanced';
  /** 长文本升级建议阈值（字符数） */
  longTextThreshold: number;
  /** 是否在长文本时提示升级到高级模型 */
  suggestUpgradeForLongText: boolean;
  /** fallback 策略：当首选模型不可用时的行为 */
  fallbackStrategy: 'downgrade' | 'placeholder' | 'ask';
}

export const DEFAULT_MODEL_STRATEGY_SETTINGS: ModelStrategySettings = {
  allowCloud: true,
  privacyMode: false,
  defaultModelTier: 'cloud_standard',
  longTextThreshold: 5000,
  suggestUpgradeForLongText: true,
  fallbackStrategy: 'downgrade',
};

// ─── VaultKeeperSettings (V2.1 Phase 9) ───────────────────────
// Configuration for VaultKeeper external processing service

export interface VaultKeeperSettings {
  /** 是否启用 VaultKeeper */
  enabled: boolean;
  /** VaultKeeper HTTP 端点 */
  endpoint: string;
  /** 请求超时（毫秒） */
  timeout: number;
  /** 可选 API Key */
  apiKey?: string;
}

// ─── TranscriptionSettings (V2.1 Phase 10) ─────────────────────
// Configuration for speech-to-text providers

export type TranscriptionProvider = 'local' | 'api';
export type TranscriptionLocalEngine = 'whisper-ctranslate2' | 'whisper';
export type TranscriptionModelSize = 'tiny' | 'base' | 'small';

export interface TranscriptionSettings {
  /** 转写提供方：本地引擎或外部 API */
  provider: TranscriptionProvider;
  /** 本地引擎优先级 */
  localEngine: TranscriptionLocalEngine;
  /** 本地引擎默认模型大小 */
  localModel: TranscriptionModelSize;
  /** 外部 API 端点（OpenAI-compatible transcription endpoint） */
  apiEndpoint: string;
  /** 外部 API Key */
  apiKey?: string;
  /** 外部 API 模型 ID */
  apiModel: string;
  /** 默认识别语言 */
  apiLanguage: string;
  /** 是否使用翻译模式 */
  apiTranslate: boolean;
  /** 可选提示词 */
  apiPrompt?: string;
  /** API 请求超时（毫秒） */
  apiTimeoutMs: number;
}

export interface AppSettings {
  storageRoot: string;
  pollIntervalMs: number;
  autoCapture: boolean;
  hasCompletedOnboarding: boolean;
  screenshotShortcut: string;
  dashboardShortcut: string;
  launchAtLogin: boolean;
  providers: ProviderConfig[];
  defaultTier: AiTier;
  vault: VaultConfig;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
  scopeMode: 'all' | 'scoped';
  scopedApps: string[];
  showFloatingButton: boolean;
  capsule: DesktopMuseCapsuleSettings;
  minimizeToTray: boolean;
  backgroundClipboard: boolean;
  showCaptureToast: boolean;
  autoAiProcess: boolean;
  autoExportObsidian: boolean;
  profile: UserProfile;
  preferences: UserPreferences;
  /** V2.1 Phase 8.6: 模型策略设置 */
  modelStrategy: ModelStrategySettings;
  /** V2.1 Phase 9: VaultKeeper 设置 */
  vaultkeeper: VaultKeeperSettings;
  /** V2.1 Phase 10: 语音转写设置 */
  transcription: TranscriptionSettings;
  /** V2.1 Phase 10: 语音监听开关 */
  voiceWatchEnabled: boolean;
  /** V2.1 Phase 10: 语音监听文件夹路径 */
  voiceWatchFolderPath: string | null;
  /** V2.1 Phase 10: 自动导入新录音 */
  voiceAutoImportEnabled: boolean;
  /** V2.1 Phase 10: 支持的音频格式 */
  voiceSupportedExtensions: string[];
  /** V2.1 Phase 10: 导入延迟（毫秒），等待 iCloud 同步 */
  voiceImportDelayMs: number;
  /** V2.1 Phase 10: 文件去重 */
  voiceDedupEnabled: boolean;
}

// ─── ProviderConfig ───────────────────────────────────────────
// Configuration for an AI provider (local or cloud)

export interface ProviderConfig {
  id: string;
  name: string;
  type: 'ollama' | 'openai_compatible';
  tier: AiTier;
  baseUrl: string;
  apiKey?: string;
  modelId: string;
  enabled: boolean;
  capabilities: string[];
}

// ─── VaultConfig ──────────────────────────────────────────────
// Configuration for the Obsidian vault export target

export interface VaultConfig {
  vaultPath: string;
  defaultFolder: string;
  template: string;
  pathRule: 'category_date' | 'category_title' | 'flat';
  conflictStrategy: 'rename' | 'skip' | 'overwrite';
  autoFrontmatter: boolean;
  frontmatterTemplate: Record<string, unknown>;
}

// ─── StorageStats ─────────────────────────────────────────────
// Aggregate storage statistics

export interface StorageStats {
  sourceItems: number;
  aiTasks: number;
  distilledOutputs: number;
  exportRecords: number;
}

// ─── Batch 4: Dashboard Stats ──────────────────────────────────

export interface DashboardStats {
  todayCollected: number;
  todayDistilled: number;
  todayExported: number;
  inboxPending: number;
  shelfItems: number;
  recentItems: SourceItem[];
  clipboardWatching: boolean;
  clipboardPaused: boolean;
  aiProviderReady: boolean;
  vaultConfigured: boolean;
  markItDownAvailable: boolean;
}

export interface CapsuleStatus {
  clipboardWatching: boolean;
  shelfItemCount: number;
  inboxPendingCount: number;
  backgroundTaskCount: number;
}

// ─── Batch 5: Health Check ─────────────────────────────────────

export interface HealthCheckResult {
  ok: boolean;
  checks: Array<{
    name: string;
    ok: boolean;
    message?: string;
  }>;
}

// ─── Batch 6: Knowledge Project ────────────────────────────────

export interface KnowledgeProject {
  id: string;
  name: string;
  description?: string;
  status: 'active' | 'paused' | 'archived';
  color?: string;
  createdAt: number;
  updatedAt: number;
}

export interface ProjectItem {
  id: string;
  projectId: string;
  itemType: 'source_item' | 'distilled_output';
  itemId: string;
  addedAt: number;
}

// ─── Batch 6: Tag Summary ──────────────────────────────────────

export interface TagSummary {
  name: string;
  count: number;
  sources: string[]; // which entity types use this tag
}

// ─── Batch 6: Dataset ──────────────────────────────────────────

export interface Dataset {
  id: string;
  name: string;
  description?: string;
  purpose: 'fine_tune' | 'rag' | 'evaluation' | 'archive';
  status: 'draft' | 'ready' | 'exported' | 'archived';
  itemCount: number;
  createdAt: number;
  updatedAt: number;
}

export interface DatasetItem {
  id: string;
  datasetId: string;
  sourceType: 'source_item' | 'distilled_output';
  sourceId: string;
  title?: string;
  content?: string;
  quality: 'high' | 'medium' | 'low' | 'excluded';
  privacyLevel: 'private' | 'safe' | 'sensitive';
  included: boolean;
  reason?: string;
  createdAt: number;
  updatedAt: number;
}

export interface DatasetExportOptions {
  format: 'jsonl' | 'markdown_bundle';
  includeExcluded: boolean;
}

// ─── Logger types ─────────────────────────────────────────────

export type LogChannel = 'app' | 'ai' | 'export' | 'error' | 'search';
export type LogLevel = AppSettings['logLevel'];

export interface LogEntry {
  time: string;
  channel: LogChannel;
  module: string;
  action: string;
  status: string;
  id?: string;
  message: string;
  detail?: string;
}

// ─── Utility Types ────────────────────────────────────────────

export type SourceItemStatus = SourceItem['status'];
export type SourceItemType = SourceItem['type'];
export type SourceItemSource = SourceItem['source'];

// ─── IPC channel names ────────────────────────────────────────

export const IPC_CHANNELS = {
  // Phase 1: Settings & App
  SETTINGS_GET: 'settings.get',
  SETTINGS_UPDATE: 'settings.update',
  APP_GET_VERSION: 'app.getVersion',
  APP_OPEN_STORAGE_ROOT: 'app.openStorageRoot',
  APP_OPEN_PATH: 'app.openPath',
  STORAGE_GET_STATS: 'storage.getStats',
  LOGGER_GET_LEVEL: 'logger.getLevel',
  LOGGER_SET_LEVEL: 'logger.setLevel',
  // Phase 2: Capture & Source Items
  SOURCE_ITEMS_LIST: 'sourceItems.list',
  SOURCE_ITEMS_GET: 'sourceItems.get',
  SOURCE_ITEMS_GET_CONTENT: 'sourceItems.getContent',
  SOURCE_ITEMS_DELETE: 'sourceItems.delete',
  SOURCE_ITEMS_DELETE_BATCH: 'sourceItems.deleteBatch',
  SOURCE_ITEMS_SEARCH: 'sourceItems.search',
  SOURCE_ITEMS_CREATE_TEXT: 'sourceItems.createText',
  SOURCE_ITEMS_ENSURE_FROM_CAPTURE: 'sourceItems.ensureFromCapture',
  SOURCE_ITEMS_GET_BY_CAPTURE_ITEM_ID: 'sourceItems.getByCaptureItemId',
  SOURCE_ITEMS_READ_IMAGE: 'sourceItems.readImage',
  RECORDS_CHANGED: 'records.changed',
  CAPTURE_SCREENSHOT: 'capture.screenshot',
  CLIPBOARD_GET_STATUS: 'clipboard.getStatus',
  CLIPBOARD_TOGGLE: 'clipboard.toggle',
  // Phase 3: AI Console
  PROVIDERS_LIST: 'providers.list',
  PROVIDERS_ADD: 'providers.add',
  PROVIDERS_UPDATE: 'providers.update',
  PROVIDERS_DELETE: 'providers.delete',
  PROVIDERS_SCAN_LOCAL: 'providers.scanLocal',
  PROVIDERS_TEST_CONNECTION: 'providers.testConnection',
  PROVIDERS_CHANGED: 'providers.changed',
  AI_TASKS_LIST: 'aiTasks.list',
  AI_TASKS_CANCEL: 'aiTasks.cancel',
  AI_TASKS_RETRY: 'aiTasks.retry',
  AI_TASKS_PAUSE: 'aiTasks.pause',
  AI_TASKS_RESUME: 'aiTasks.resume',
  AI_TASKS_IS_PAUSED: 'aiTasks.isPaused',
  AI_TASKS_STATUS_CHANGED: 'aiTasks.statusChanged',
  DISTILL_RUN: 'distill.run',
  DISTILL_RUN_SINGLE: 'distill.runSingle',
  LOGGER_READ: 'logger.read',
  // Phase 4: Real Distiller
  DISTILL_BATCH: 'distill.batch',
  DISTILL_BATCH_STATUS: 'distill.batchStatus',
  DISTILL_BATCH_CANCEL: 'distill.batchCancel',
  DISTILLED_OUTPUTS_LIST: 'distilledOutputs.list',
  DISTILLED_OUTPUTS_REVIEW: 'distilledOutputs.review',
  KNOWLEDGE_CARDS_LIST: 'knowledgeCards.list',
  KNOWLEDGE_CARDS_GET: 'knowledgeCards.get',
  KNOWLEDGE_CARDS_GET_BY_SOURCE_ITEM_ID: 'knowledgeCards.getBySourceItemId',
  KNOWLEDGE_CARDS_UPSERT_FROM_REVIEW: 'knowledgeCards.upsertFromReview',
  GRAPH_GET: 'graph.get',
  // Phase 5: Obsidian Export
  VAULT_GET_CONFIG: 'vault.getConfig',
  VAULT_UPDATE_CONFIG: 'vault.updateConfig',
  VAULT_VALIDATE_PATH: 'vault.validatePath',
  VAULT_PICK_FOLDER: 'vault.pickFolder',
  EXPORT_SINGLE: 'export.single',
  EXPORT_BATCH: 'export.batch',
  EXPORT_OPEN_FILE: 'export.openFile',
  EXPORT_REVEAL_IN_VAULT: 'export.revealInVault',
  EXPORT_HISTORY: 'export.history',
  EXPORT_RETRY: 'export.retry',
  TEMPLATE_PREVIEW: 'template.preview',
  // Phase 4.5: Datasets / Training / Models
  DATASETS_CREATE_SNAPSHOT: 'datasets.createSnapshot',
  DATASETS_LIST: 'datasets.list',
  DATASETS_GET: 'datasets.get',
  DATASETS_EXPORT_BUNDLE: 'datasets.exportBundle',
  TRAINING_RUNS_IMPORT_RESULT: 'trainingRuns.importResult',
  TRAINING_RUNS_LIST: 'trainingRuns.list',
  MODEL_VERSIONS_LIST: 'modelVersions.list',
  MODEL_VERSIONS_ACTIVATE: 'modelVersions.activate',
  MODEL_VERSIONS_ROLLBACK: 'modelVersions.rollback',
  // Phase 6: VaultKeeper Import
  IMPORT_SCAN: 'import.scan',
  IMPORT_START: 'import.start',
  IMPORT_STATUS: 'import.status',
  IMPORT_CANCEL: 'import.cancel',
  IMPORT_HISTORY: 'import.history',
  IMPORT_TASKS_LIST: 'import.tasks.list',
  IMPORT_TASK_CHANGED: 'import.task.changed',
  // Capture Inbox v0.1
  CAPTURE_ITEMS_LIST: 'captureItems.list',
  CAPTURE_ITEMS_GET: 'captureItems.get',
  CAPTURE_ITEMS_CREATE: 'captureItems.create',
  CAPTURE_ITEMS_UPDATE: 'captureItems.update',
  CAPTURE_ITEMS_DELETE: 'captureItems.delete',
  CAPTURE_ITEMS_EXPORT_MARKDOWN: 'captureItems.exportMarkdown',
  CAPTURE_ITEMS_READ_IMAGE: 'captureItems.readImage',
  CAPTURE_ITEMS_CHANGED: 'captureItems.changed',
  // Distill Loop (Bridge → Distill → Review → Export)
  DISTILL_BRIDGE_AND_RUN: 'distill.bridgeAndRun',
  DISTILL_BRIDGE_AND_RUN_BATCH: 'distill.bridgeAndRunBatch',
  EXPORT_GET_WITH_LINEAGE: 'export.getWithLineage',
  EXPORT_RECORDS_WITH_LINEAGE: 'export.recordsWithLineage',
  SOURCE_ITEMS_GET_DISTILL_STATUS: 'sourceItems.getDistillStatus',
  // Workspace directory operations (PersonalSpace)
  WORKSPACE_SELECT_DIRECTORY: 'workspace.selectDirectory',
  WORKSPACE_OPEN_DIRECTORY: 'workspace.openDirectory',
  WORKSPACE_TEST_WRITE: 'workspace.testWrite',
  // Phase 1: Hybrid Search
  SEARCH_HYBRID: 'search.hybrid',
  SEARCH_REBUILD_FTS: 'search.rebuildFts',
  SEARCH_GET_STATUS: 'search.getStatus',
  // Phase 2: Document Parser
  PARSER_IMPORT_FILE: 'parser.importFile',
  PARSER_IMPORT_URL: 'parser.importUrl',
  PARSER_IMPORT_BATCH: 'parser.importBatch',
  // MarkItDown integration
  MARKITDOWN_CONVERT: 'markitdown.convert',
  MARKITDOWN_CHECK: 'markitdown.check',
  // Phase 3: File Converter
  FILE_CONVERT: 'fileConverter.convert',
  FILE_CONVERT_STATUS: 'fileConverter.getStatus',
  FILE_CONVERT_LIST: 'fileConverter.listJobs',
  FILE_CONVERT_SAVE_TO_INBOX: 'fileConverter.saveToInbox',
  FILE_CONVERT_PREVIEW: 'fileConverter.preview',
  FILE_CONVERT_JOBS_CHANGED: 'fileConverter.jobsChanged',
  // Phase 3: Scheduler
  SCHEDULER_CREATE_TASK: 'scheduler.createTask',
  SCHEDULER_UPDATE_TASK: 'scheduler.updateTask',
  SCHEDULER_DELETE_TASK: 'scheduler.deleteTask',
  SCHEDULER_TOGGLE_TASK: 'scheduler.toggleTask',
  SCHEDULER_GET_TASKS: 'scheduler.getTasks',
  SCHEDULER_GET_TASK: 'scheduler.getTask',
  SCHEDULER_RUN_NOW: 'scheduler.runNow',
  // Voice / Whisper STT
  WHISPER_GET_STATUS: 'whisper.getStatus',
  WHISPER_GET_MODELS: 'whisper.getModels',
  WHISPER_DOWNLOAD_MODEL: 'whisper.downloadModel',
  WHISPER_DELETE_MODEL: 'whisper.deleteModel',
  WHISPER_INITIALIZE: 'whisper.initialize',
  WHISPER_TRANSCRIBE: 'whisper.transcribe',
  WHISPER_DOWNLOAD_PROGRESS: 'whisper.downloadProgress',
  // AI Polish (text refinement)
  POLISH_TEXT: 'polish.text',
  POLISH_GET_STYLES: 'polish.getStyles',
  // V2.1: OutputSpecService
  OUTPUT_SPEC_GET_INFO: 'outputSpec.getInfo',
  OUTPUT_SPEC_GET_PROFILE: 'outputSpec.getProfile',
  OUTPUT_SPEC_GET_ACTIVE_PROFILE: 'outputSpec.getActiveProfile',
  OUTPUT_SPEC_GET_TEMPLATE: 'outputSpec.getTemplate',
  OUTPUT_SPEC_GET_TAG_RULES: 'outputSpec.getTagRules',
  OUTPUT_SPEC_GET_CATEGORY_RULES: 'outputSpec.getCategoryRules',
  OUTPUT_SPEC_GET_DISTILL_TEMPLATE: 'outputSpec.getDistillTemplate',
  OUTPUT_SPEC_GET_SNIPPET: 'outputSpec.getSnippet',
  OUTPUT_SPEC_GET_RAW_CONTENT_SECTION: 'outputSpec.getRawContentSection',
  // V2.1: Content Pipeline
  PIPELINE_PROCESS_TEXT: 'pipeline.processText',
  PIPELINE_GET_STATUS: 'pipeline.getStatus',
  PIPELINE_RETRY_EXPORT: 'pipeline.retryExport',
  PIPELINE_GET_STATE_HISTORY: 'pipeline.getStateHistory',
  PIPELINE_CHECK_DUPLICATE: 'pipeline.checkDuplicate',
  // V2.1 Phase 6.1: Unified Error Model
  ERRORS_LIST: 'errors.list',
  ERRORS_GET: 'errors.get',
  ERRORS_RESOLVE: 'errors.resolve',
  ERRORS_DISMISS: 'errors.dismiss',
  ERRORS_CLEAR_RESOLVED: 'errors.clearResolved',
  // V2.1 Phase 6.3: Unified Retry
  RETRY_ERROR: 'retry.error',
  // V2.1 Phase 6.5: Advanced Control Panel
  LOCAL_MODEL_STATUS: 'localModel.getRuntimeStatus',
  // V2.1 Phase 6.5: Processing history batch processedAt
  PIPELINE_BATCH_PROCESSED_AT: 'pipeline.batchProcessedAt',
  // V2.1 Phase 7.1: Unified Capture Adapter
  CAPTURE_RECORD: 'capture.record',
  CAPTURE_GET_AVAILABLE_TYPES: 'capture.getAvailableTypes',
  // Phase 2A: Capture 截图与贴图
  CAPTURE_START_AREA: 'capture.startAreaCapture',
  CAPTURE_CANCEL: 'capture.cancelCapture',
  CAPTURE_PIN_IMAGE: 'capture.pinImage',
  CAPTURE_SAVE_TO_INBOX: 'capture.saveToInbox',
  CAPTURE_LIST_RECENT: 'capture.listRecentCaptures',
  CAPTURE_LIST_PINNED: 'capture.listPinnedImages',
  CAPTURE_CLOSE_PINNED: 'capture.closePinnedImage',
  CAPTURE_SCREENSHOTS_CHANGED: 'capture.screenshotsChanged',
  CAPTURE_PINNED_CHANGED: 'capture.pinnedChanged',
  // Phase 2B: OCR
  CAPTURE_OCR_EXTRACT: 'capture.ocrExtract',
  CAPTURE_OCR_SAVE_TO_INBOX: 'capture.ocrSaveToInbox',
  // V2.1 Phase 7.2: Clipboard text capture
  CAPTURE_COLLECT_CLIPBOARD: 'capture.collectClipboard',
  // V2.1 Phase 7.3: Screenshot capture
  CAPTURE_COLLECT_SCREENSHOT: 'capture.collectScreenshot',
  // V2.1 Phase 7.4: Webpage content capture
  CAPTURE_COLLECT_WEBPAGE: 'capture.collectWebpage',
  // V2.1 Phase 7.5: File import
  CAPTURE_COLLECT_FILE: 'capture.collectFile',
  // V2.1 Phase 7.5: File selection dialog
  DIALOG_OPEN_FILE: 'dialog.openFile',
  DIALOG_SELECT_DIRECTORY: 'dialog.selectDirectory',
  // V2.1 Phase 8: AI Strategy & Regeneration
  STRATEGY_REGENERATE: 'strategy.regenerate',
  // V2.1 Phase 9: VaultKeeper 深度接入
  VK_CHECK_HEALTH: 'vk.checkHealth',
  VK_GET_JOB_STATUS: 'vk.getJobStatus',
  VK_CANCEL_JOB: 'vk.cancelJob',
  VK_RESUBMIT_JOB: 'vk.resubmitJob',
  VK_GET_RECENT_JOBS: 'vk.getRecentJobs',
  VK_GET_FAILED_JOBS: 'vk.getFailedJobs',
  VK_MANUAL_INGEST: 'vk.manualIngest',
  // V2.1 Phase 10: Voice workflow
  VOICE_IMPORT_AUDIO: 'voice.importAudio',
  VOICE_START_WATCH: 'voice.startWatch',
  VOICE_STOP_WATCH: 'voice.stopWatch',
  VOICE_GET_WATCH_STATE: 'voice.getWatchState',
  VOICE_RETRY_TRANSCRIPTION: 'voice.retryTranscription',
  VOICE_GET_TRANSCRIPTION_STATUS: 'voice.getTranscriptionStatus',
  // V2.1 Phase 10: Voice dictation & polish
  VOICE_GET_DICTATION_GUIDE: 'voice.getDictationGuide',
  VOICE_POLISH_TRANSCRIPT: 'voice.polishTranscript',
  VOICE_CREATE_PIN_FROM_TRANSCRIPT: 'voice.createPinFromTranscript',
  // Phase 12.6: Local Diagnostics Export
  DIAGNOSTICS_EXPORT: 'diagnostics.export',

  // ─── Pin Pool ────────────────────────────────────────────────
  PIN_POOL_LIST: 'pinPool.list',
  PIN_POOL_GET: 'pinPool.get',
  PIN_POOL_CREATE_FROM_CAPTURE: 'pinPool.createFromCapture',
  PIN_POOL_CREATE_FROM_TEXT: 'pinPool.createFromText',
  PIN_POOL_PREFILTER: 'pinPool.prefilter',
  PIN_POOL_PROMOTE_TO_INBOX: 'pinPool.promoteToInbox',
  PIN_POOL_UPDATE: 'pinPool.update',
  PIN_POOL_IGNORE: 'pinPool.ignore',
  PIN_POOL_DELETE: 'pinPool.delete',
  PIN_POOL_CHANGED: 'pinPool.changed',

  // ─── Phase 0: AcMind 模块 IPC 边界 ──────────────────────────

  // clipboard.*
  CLIPBOARD_LIST_ITEMS: 'clipboard.listItems',
  CLIPBOARD_GET_ITEM: 'clipboard.getItem',
  CLIPBOARD_PIN_ITEM: 'clipboard.pinItem',
  CLIPBOARD_UNPIN_ITEM: 'clipboard.unpinItem',
  CLIPBOARD_DELETE_ITEM: 'clipboard.deleteItem',
  CLIPBOARD_SAVE_TO_INBOX: 'clipboard.saveToInbox',
  CLIPBOARD_ITEMS_CHANGED: 'clipboard.itemsChanged',
  CLIPBOARD_SEARCH_ITEMS: 'clipboard.searchItems',
  CLIPBOARD_COPY_ITEM: 'clipboard.copyItem',
  CLIPBOARD_CLEAR_HISTORY: 'clipboard.clearHistory',
  CLIPBOARD_PAUSE: 'clipboard.pause',
  CLIPBOARD_RESUME: 'clipboard.resume',
  CLIPBOARD_IS_PAUSED: 'clipboard.isPaused',

  // shelf.*
  SHELF_LIST_ITEMS: 'shelf.listItems',
  SHELF_GET_ITEM: 'shelf.getItem',
  SHELF_ADD_FILES: 'shelf.addFiles',
  SHELF_ADD_TEXT: 'shelf.addText',
  SHELF_REMOVE_ITEM: 'shelf.removeItem',
  SHELF_SAVE_TO_INBOX: 'shelf.saveToInbox',
  SHELF_ITEMS_CHANGED: 'shelf.itemsChanged',

  // aiRuntime.*
  AI_RUNTIME_LIST_ACTIONS: 'aiRuntime.listActions',
  AI_RUNTIME_GET_ACTION: 'aiRuntime.getAction',
  AI_RUNTIME_CREATE_ACTION: 'aiRuntime.createAction',
  AI_RUNTIME_UPDATE_ACTION: 'aiRuntime.updateAction',
  AI_RUNTIME_DELETE_ACTION: 'aiRuntime.deleteAction',
  AI_RUNTIME_RUN_ACTION: 'aiRuntime.runAction',
  AI_RUNTIME_LIST_JOBS: 'aiRuntime.listJobs',
  AI_RUNTIME_GET_JOB: 'aiRuntime.getJob',
  AI_RUNTIME_CANCEL_JOB: 'aiRuntime.cancelJob',
  AI_RUNTIME_JOB_CHANGED: 'aiRuntime.jobChanged',
  AI_RUNTIME_HEALTH_CHECK: 'aiRuntime.healthCheck',

  // ─── distilledNotes.* ────────────────────────────────────────
  DISTILLED_NOTES_LIST: 'distilledNotes.list',
  DISTILLED_NOTES_GET: 'distilledNotes.get',
  DISTILLED_NOTES_CREATE: 'distilledNotes.create',
  DISTILLED_NOTES_UPDATE: 'distilledNotes.update',
  DISTILLED_NOTES_DELETE: 'distilledNotes.delete',

  // ─── vaultSearch.* ───────────────────────────────────────────
  VAULT_SEARCH: 'vaultSearch.search',

  // ─── voiceDictionary.* ───────────────────────────────────────
  VOICE_DICTIONARY_LIST: 'voiceDictionary.list',
  VOICE_DICTIONARY_ADD: 'voiceDictionary.add',
  VOICE_DICTIONARY_DELETE: 'voiceDictionary.delete',
  VOICE_DICTIONARY_TOGGLE: 'voiceDictionary.toggle',

  // ─── asr.* ───────────────────────────────────────────────────
  ASR_GET_STATUS: 'asr.getStatus',
  ASR_TRANSCRIBE: 'asr.transcribe',

  // ─── Batch 4: Dashboard / Capsule / Utilities ────────────────
  DASHBOARD_GET_STATS: 'dashboard.getStats',
  CAPSULE_GET_STATUS: 'capsule.getStatus',

  // ─── Batch 5: Health Check ──────────────────────────────────
  HEALTH_CHECK: 'health.check',

  // ─── Batch 6: Knowledge Projects ────────────────────────────
  PROJECTS_LIST: 'projects.list',
  PROJECTS_GET: 'projects.get',
  PROJECTS_CREATE: 'projects.create',
  PROJECTS_UPDATE: 'projects.update',
  PROJECTS_DELETE: 'projects.delete',
  PROJECTS_ADD_ITEM: 'projects.addItem',
  PROJECTS_REMOVE_ITEM: 'projects.removeItem',

  // ─── Batch 6: Tags ──────────────────────────────────────────
  TAGS_LIST: 'tags.list',
  TAGS_MERGE: 'tags.merge',
  TAGS_RENAME: 'tags.rename',
  TAGS_DELETE: 'tags.delete',

  // ─── Batch 6: Datasets ─────────────────────────────────────
  DATASETS_V2_CREATE: 'datasets.v2.create',
  DATASETS_V2_LIST: 'datasets.v2.list',
  DATASETS_V2_GET: 'datasets.v2.get',
  DATASETS_V2_ADD_ITEMS: 'datasets.v2.addItems',
  DATASETS_V2_UPDATE_ITEM: 'datasets.v2.updateItem',
  DATASETS_V2_EXPORT: 'datasets.v2.export',
  DATASETS_V2_DELETE: 'datasets.v2.delete',
} as const;

export type IpcChannel = (typeof IPC_CHANNELS)[keyof typeof IPC_CHANNELS];

// ─── SourceItems filter for list API ──────────────────────────

export interface SourceItemListFilter {
  status?: SourceItemStatus;
  type?: SourceItemType;
  source?: SourceItemSource;
  limit?: number;
  offset?: number;
}

// ─── Distill Lineage Status (for real-time status display) ────

export interface DistillLineageStatus {
  captureItemId: string;
  sourceItemId: string | null;
  sourceItemStatus: SourceItemStatus | null;
  aiTasks: AiTask[];
  distilledOutputs: DistilledOutput[];
  exportRecords: ExportRecord[];
  bridgeExists: boolean;
}

// ─── Error Handling Types (from PinStack) ──────────────────────

export type AppErrorCode =
  | 'PERMISSION_DENIED'
  | 'CAPTURE_FAILED'
  | 'STORAGE_ERROR'
  | 'AI_PROVIDER_ERROR'
  | 'AI_TASK_FAILED'
  | 'EXPORT_FAILED'
  | 'VAULT_NOT_CONFIGURED'
  | 'NETWORK_ERROR'
  | 'UNKNOWN'
  // PinStack-specific error codes
  | 'INTERNAL_ERROR'
  | 'PERMISSION_REQUIRED'
  | 'FILE_MISSING'
  | 'RECORD_NOT_FOUND'
  | 'IMAGE_DECODE_FAILED'
  | 'SHORTCUT_REGISTRATION_FAILED';

export interface AppErrorPayload {
  code: AppErrorCode;
  message: string;
  detail?: string;
  source?: string;
}

export type Result<T> =
  | { ok: true; value: T; data?: T }
  | { ok: false; error: AppErrorPayload };

export type AppToastLevel = 'info' | 'success' | 'warning' | 'error';

// ─── Unified Error Model (V2.1 Phase 6.1) ──────────────────────

/** Unified error type classification */
export type ErrorType =
  | 'capture_failed'
  | 'process_failed'
  | 'export_failed'
  | 'permission_required'
  | 'conflict_pending'
  | 'template_missing'
  | 'vault_missing'
  | 'model_unavailable'
  // Phase 9.7: VaultKeeper 错误类型
  | 'vaultkeeper_unavailable'
  | 'external_job_failed'
  | 'external_result_invalid'
  | 'external_result_ingest_failed'
  | 'unknown_error';

/** Error record lifecycle status */
export type ErrorStatus = 'open' | 'resolved' | 'dismissed';

/** A single unified error record persisted in the database */
export interface ErrorRecord {
  error_id: string;
  error_type: ErrorType;
  /** The source item that triggered the error (if available) */
  original_id?: string;
  /** The output that was being produced when the error occurred (if available) */
  output_id?: string;
  /** Pipeline stage where the error occurred */
  stage: string;
  /** Machine-readable error message (developer-facing) */
  message: string;
  /** User-friendly Chinese error message */
  user_message: string;
  /** Raw error details (stack trace, HTTP response, etc.) — only shown in dev mode */
  raw_error?: string;
  /** Whether this error can be retried automatically or manually */
  retryable: boolean;
  /** How many times this error has been retried */
  retry_count: number;
  created_at: number;
  resolved_at?: number;
  status: ErrorStatus;
}

// ─── Permission Types (from PinStack) ──────────────────────────

export type PermissionCheckSource =
  | 'app-launch'
  | 'capture-screenshot'
  | 'clipboard-monitor'
  | 'export-file'
  // PinStack-specific sources
  | 'manual-refresh'
  | 'renderer-query'
  | 'activate'
  | 'focus'
  | 'settings-return'
  | 'capture-hub';

export interface PermissionDiagnostics {
  checks: Array<{
    permission: string;
    status: 'granted' | 'denied' | 'not-determined';
    source: string;
  }>;
  timestamp: number;
  // PinStack-specific fields
  appName?: string;
  executablePath?: string;
  appPath?: string;
  appBundlePath?: string;
  bundleId?: string;
  isDev?: boolean;
  isPackaged?: boolean;
  lastSource?: PermissionCheckSource;
  instanceMismatchSuspected?: boolean;
  instanceMismatchMessage?: string;
  installLocationStable?: boolean;
  installLocationMessage?: string;
  identityFingerprint?: string;
  automationCapability?: 'available' | 'partial' | 'unavailable';
}

export interface PermissionItem {
  key: string;
  title: string;
  state: PermissionState;
  message: string;
  detail?: string;
  actionLabel?: string;
  canRetry?: boolean;
  canOpenSystemSettings?: boolean;
  needsAttention?: boolean;
  blocking?: boolean;
  settingsTarget?: PermissionSettingsTarget;
  lastCheckedAt?: number;
  systemStatus?: string;
  probeStatus?: PermissionProbeStatus;
  probeError?: string;
  desktopProbeStatus?: PermissionProbeStatus;
  desktopProbeError?: string;
  recommendedAction?: string;
}

export type PermissionItemStatus = PermissionItem;

export type PermissionProbeStatus = 'ok' | 'denied' | 'unknown' | 'success' | 'failed' | 'not-run';

export type PermissionState = 'granted' | 'denied' | 'pending' | 'not-determined' | 'unknown' | 'requires-restart';

export interface PermissionStatusSnapshot {
  screenRecording: PermissionState;
  accessibility: PermissionState;
  fullDiskAccess: PermissionState;
  lastChecked: number;
  // PinStack-specific fields
  items?: PermissionItem[];
  hasIssues?: boolean;
  hasBlockingIssues?: boolean;
  updatedAt?: number;
  source?: PermissionCheckSource;
  diagnostics?: PermissionDiagnostics;
}

export type PermissionSettingsTarget =
  | 'system-preferences'
  | 'terminal'
  | 'finder'
  // PinStack-specific targets
  | 'privacyGeneral'
  | 'privacyAccessibility'
  | 'privacyInputMonitoring'
  | 'keyboardShortcuts'
  | 'privacyScreenCapture';

// ─── Capture Types (from PinStack) ────────────────────────────

export interface RuntimeSettings {
  captureSize: CaptureSizeOption;
  captureRatio: CaptureRatioOption;
  scopeMode: 'all' | 'scoped';
  scopedApps: string[];
  // PinStack-specific fields
  defaultCaptureSizePreset?: string;
  defaultCaptureCustomSize?: CaptureSizeOption;
  rememberCaptureRecentSizes?: boolean;
  captureRecentSizes?: CaptureSizeOption[];
}

export interface CaptureSizeOption {
  id?: string;
  label?: string;
  width: number;
  height: number;
}

export interface CaptureRatioOption {
  id?: string;
  label?: string;
  ratio?: number;
  width?: number;
  height?: number;
}

export interface CaptureLauncherVisualState {
  state?: string;
  hubOpen?: boolean;
  weakened?: boolean;
  edge?: string | null;
  edgeDistance?: number;
}

export type CaptureLauncherVisualStateValue = 'idle' | 'recording' | 'countdown' | 'capturing';

export interface CaptureRecordingState {
  isRecording?: boolean;
  startTime?: number | null;
  sourceApp?: string | null;
  // PinStack-specific fields
  active?: boolean;
  startedAt?: number | null;
}

export interface CaptureSelectionBounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

export type CaptureMode = 'free' | 'fixed' | 'region' | 'ratio';

export interface CaptureSessionConfig {
  sourceApp?: string;
  captureRatio?: CaptureRatioOption | null;
  captureSize?: CaptureSizeOption | null;
  // PinStack-specific fields
  mode?: CaptureMode;
  ratio?: CaptureRatioOption | null;
  size?: CaptureSizeOption | null;
}

export interface RecordItem {
  id: string;
  timestamp: number;
  type: 'text' | 'image' | 'url';
  preview: string;
  sourceApp?: string;
  source?: string;
  createdAt?: number;
}

// ─── Capture Adapter Architecture (V2.1 Phase 7.1) ──────────────────
// Unified capture entry point: all sources produce a CaptureRecord,
// which then enters the state machine → auto-organize → Markdown → Obsidian pipeline.

/** Supported source types for content capture */
export type SourceType =
  | 'manual_text'
  | 'clipboard_text'
  | 'clipboard_image'
  | 'screenshot'
  | 'pinned_image'
  | 'webpage'
  | 'file'
  | 'image'
  | 'audio'
  | 'video'
  | 'ocr_text'
  | 'system_context'
  // V2.1 Phase 7.6: VaultKeeper reserved source types
  | 'pdf'
  | 'docx'
  | 'unknown_file';

/**
 * V2.1 Phase 7.6: ComplexFileMetadata — metadata for media/complex files.
 *
 * Used by fileAdapter to record processing hints and future VaultKeeper integration fields.
 * All fields are optional; adapters fill what they know at capture time.
 */
export interface ComplexFileMetadata {
  filename?: string;
  extension?: string;
  mime_type?: string;
  file_size?: number;
  imported_at?: string;

  /** What kind of processing this file needs (set at capture time) */
  processing_hint?:
    | 'none'
    | 'needs_ocr'
    | 'needs_transcription'
    | 'needs_video_transcription'
    | 'needs_document_parse'
    | 'needs_manual_review';

  /** Which external processor should handle this file */
  external_processor?: 'vaultkeeper' | 'ocr' | 'whisper' | 'manual' | 'none';

  /** Current status of external processing */
  external_processing_status?:
    | 'not_required'
    | 'pending'
    | 'processing'
    | 'completed'
    | 'failed';

  /** Job ID from external processor (for result callback) */
  external_job_id?: string;

  /** Text extracted by OCR or other processor (result callback field) */
  extracted_text?: string;
  /** Transcript from audio/video processing (result callback field) */
  transcript_text?: string;
  /** Parsed markdown from document processing (result callback field) */
  parsed_markdown?: string;

  /** Whether readable text was available at capture time */
  readable_text_available?: boolean;
}

/**
 * CaptureRecord — the unified output of every CaptureAdapter.
 *
 * Invariants:
 *  - Every record has a unique `original_id` for deduplication.
 *  - Every record has a `source_type` indicating its origin.
 *  - Every record has a `created_at` timestamp.
 *  - Raw content goes into the appropriate field (raw_text / raw_file_path / raw_url).
 *  - Extra information goes into `metadata`.
 *
 * CaptureAdapter does NOT handle Markdown generation, Obsidian writing, or UI rendering.
 */
export interface CaptureRecord {
  /** Unique identifier for deduplication (SHA-256 hash or UUID) */
  original_id: string;
  /** The source type that produced this record */
  source_type: SourceType;
  /** ISO 8601 timestamp of when the capture occurred */
  created_at: string;
  /** Raw text content (for manual_text, clipboard_text, webpage) */
  raw_text?: string;
  /** File path to the captured file (for screenshot, file, image, audio, video) */
  raw_file_path?: string;
  /** URL of the captured webpage */
  raw_url?: string;
  /** Optional title extracted from the source */
  title?: string;
  /** Optional preview text for display */
  preview_text?: string;
  /** The application where the content originated (e.g. "Safari", "VS Code") */
  source_app?: string;
  /** Extra metadata specific to the source type */
  metadata: Record<string, unknown>;
}

/**
 * RegenerationRecord — tracks a regeneration attempt.
 * Preserves original_id for deduplication.
 */
export interface RegenerationRecord {
  /** Unique ID for this regeneration attempt */
  regeneration_id: string;
  /** The original_id of the content being regenerated */
  original_id: string;
  /** The source item ID */
  source_item_id: string;
  /** Model tier used for regeneration */
  regeneration_tier: AiTier;
  /** Prompt profile ID used for regeneration */
  regeneration_profile_id: string;
  /** Model call record from the regeneration */
  model_call: {
    model_tier: string;
    provider: string;
    model_name: string;
    prompt_profile_id: string;
    prompt_profile_version: string;
    created_at: number;
    status: string;
  };
  /** Quality score after regeneration */
  quality_score: number;
  /** Quality flags after regeneration */
  quality_flags: string[];
  /** Whether fallback was used */
  used_fallback: boolean;
  /** Timestamp */
  created_at: number;
  /** Status */
  status: 'success' | 'failed' | 'fallback';
}

/**
 * CaptureAdapter — interface for all capture source adapters.
 *
 * Each adapter is responsible for:
 *  1. Collecting raw content from its specific source.
 *  2. Normalizing it into a standard CaptureRecord.
 *
 * Each adapter must NOT:
 *  - Generate Markdown
 *  - Write to Obsidian
 *  - Handle UI rendering
 */
export interface CaptureAdapter<TInput = unknown> {
  /** The source type this adapter handles */
  readonly sourceType: SourceType;
  /**
   * Capture content from the source and produce a CaptureRecord.
   * @param input - Source-specific input (text, file path, URL, etc.)
   * @returns A normalized CaptureRecord
   * @throws Error if capture fails
   */
  capture(input: TInput): CaptureRecord;
}

/** Input type for the unified capture.record function */
export type CaptureInput =
  | { sourceType: 'manual_text'; text: string; sourceApp?: string }
  | { sourceType: 'clipboard_text'; text: string; sourceApp?: string; contentHash?: string }
  | { sourceType: 'screenshot'; filePath?: string; buffer?: Buffer; saveDir?: string; sourceApp?: string }
  | { sourceType: 'webpage'; url: string; title?: string; rawText?: string; sourceApp?: string; inputMode?: 'url_fetch' | 'paste' }
  | { sourceType: 'file'; filePath: string; title?: string; sourceApp?: string }
  | { sourceType: 'image'; filePath: string; sourceApp?: string }
  | { sourceType: 'audio'; filePath: string; title?: string; sourceApp?: string }
  | { sourceType: 'video'; filePath: string; title?: string; sourceApp?: string }
  | { sourceType: 'pdf'; filePath: string; title?: string; sourceApp?: string }
  | { sourceType: 'docx'; filePath: string; title?: string; sourceApp?: string }
  | { sourceType: 'unknown_file'; filePath: string; title?: string; sourceApp?: string };

// ─── CaptureItem (Capture Inbox v0.1) ─────────────────────────────────
// Represents a fragment captured in the Capture Inbox for later organization

export type CaptureItemType = 'text' | 'link' | 'image' | 'audio';
export type CaptureItemStatus = 'pending' | 'distilling' | 'archived' | 'ignored' | 'failed' | 'transcribing' | 'transcribed';

// ─── TranscriptStatus (Phase 10) ─────────────────────────────
export type TranscriptStatus =
  | 'not_started'
  | 'pending'
  | 'processing'
  | 'completed'
  | 'failed'
  | 'unsupported';

export interface CaptureItem {
  id: string;
  type: CaptureItemType;
  status: CaptureItemStatus;
  title: string;
  rawText: string;
  sourceUrl: string;
  filePath: string;
  userNote: string;
  capturedAt: number;
  updatedAt: number;
}

export interface CaptureItemListFilter {
  status?: CaptureItemStatus;
  type?: CaptureItemType;
  todayOnly?: boolean;
  limit?: number;
  offset?: number;
}

// ─── VaultKeeper Import Types (Phase 6) ─────────────────────────

export type ImportTaskStatus = 'scanning' | 'preview' | 'importing' | 'done' | 'failed' | 'cancelled';

export interface ImportTask {
  id: string;
  vaultPath: string;
  folderPath: string;
  status: ImportTaskStatus;
  totalFiles: number;
  importedCount: number;
  skippedCount: number;
  failedCount: number;
  excludePatterns: string[];
  includePatterns: string[];
  createdAt: number;
  startedAt?: number;
  finishedAt?: number;
  error?: string;
}

export interface ScannedVaultFile {
  relativePath: string;
  fileName: string;
  fileSize: number;
  modifiedAt: number;
  frontmatter: Record<string, unknown>;
  hasFrontmatter: boolean;
  title: string;
  tags: string[];
  willSkip: boolean;
  skipReason?: string;
}

export interface VaultSearchResult {
  relativePath: string;
  fileName: string;
  title: string;
  snippet: string;
  matchCount: number;
  fileSize: number;
  modifiedAt: number;
}

export interface ImportOptions {
  vaultPath: string;
  folderPath?: string;
  excludePatterns?: string[];
  includePatterns?: string[];
  skipDuplicates?: boolean;
  selectedFiles?: string[];
}

export interface ImportResult {
  taskId: string;
  imported: number;
  skipped: number;
  failed: number;
  errors: Array<{ filePath: string; error: string }>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 0: AcMind 统一数据对象
// 以下类型定义 AcMind 中枢的统一数据模型。
// 现有类型（SourceItem, AiTask, DistilledOutput 等）保持不变，
// 新增类型用于补齐模块边界。
//
// ─── 新旧类型映射关系（Phase 0.5 文档化）──────────────────────────────────
//
// AcMind 目标对象          当前等价/承接对象         映射策略
// ─────────────────────── ─────────────────────── ──────────────────────────
// ProcessJob              AiTask                  ProcessJob 是更广义的统一任务模型
//                                                 （支持 ocr/asr/markitdown/distill 等），
//                                                 AiTask 仅覆盖 AI 推理任务。
//                                                 当前阶段：ProcessJob 类型已定义，
//                                                 ai_tasks 表继续承接 AI 任务。
//                                                 Phase 2 拆 process_jobs 表。
//
// DistilledNote           DistilledOutput         DistilledNote 支持多源聚合
//                                                 （sourceItemIds: string[]），
//                                                 DistilledOutput 仅单源。
//                                                 当前阶段：DistilledNote 类型已定义，
//                                                 distilled_outputs 表继续承接。
//                                                 Phase 2 拆 distilled_notes 表。
//
// ShelfItem               pin_pool_items (legacy) ShelfItem 是新命名，
//                                                 pin_pool_items 是旧表。
//                                                 当前阶段：shelf_items 表已创建（v14），
//                                                 pin_pool_items 保留兼容。
//
// ClipboardItem           SourceItem (clipboard)  ClipboardItem 专用于剪贴板历史，
//                                                 当前由 SourceItem.source='clipboard'
//                                                 + clipboard.* IPC 承接。
//                                                 当前阶段：clipboard_items 表已创建（v14）。
//
// AssetFile               SourceItem.contentPath  AssetFile 独立管理资产文件元数据，
//                                                 当前由 SourceItem.contentPath 字段临时承接。
//                                                 当前阶段：asset_files 表已创建（v14）。
//
// AIAction                ProviderConfig +        AIAction 定义用户可触发的 AI 动作，
//                         AppSettings 相关字段    当前由 ProviderConfig / prompt profile
//                                                 相关结构分散承接。
//                                                 当前阶段：ai_actions 表已创建（v14）。
//
// ─── 原则 ─────────────────────────────────────────────────────────────────
// - 不为满足名字而制造重复平行模型
// - 旧类型继续使用，新类型逐步接管
// - UI 开发时优先使用新类型，旧类型标记为 @legacy
// - Phase 1/2 再逐步拆表和迁移
// ═══════════════════════════════════════════════════════════════════════════════

// ─── AssetFile ────────────────────────────────────────────────
// 图片、截图、音频、PDF、DOCX 等资产文件

export type AssetFileKind =
  | 'image'
  | 'audio'
  | 'video'
  | 'pdf'
  | 'docx'
  | 'html'
  | 'markdown'
  | 'other';

export interface AssetFile {
  id: string;
  sourceItemId?: string;
  kind: AssetFileKind;
  originalName?: string;
  localPath: string;
  mimeType?: string;
  sizeBytes?: number;
  sha256?: string;
  createdAt: number;
  metadata?: Record<string, unknown>;
}

// ─── ClipboardItem ────────────────────────────────────────────
// 剪贴板历史记录

export type ClipboardContentType = 'text' | 'image' | 'file' | 'url' | 'rich_text';

export interface ClipboardItem {
  id: string;
  sourceItemId?: string;
  contentType: ClipboardContentType;
  text?: string;
  assetFileIds?: string[];
  sourceApp?: string;
  isSensitive?: boolean;
  isPinned?: boolean;
  createdAt: number;
}

// ─── ShelfItem ────────────────────────────────────────────────
// 文件临时架项目

export type ShelfItemOrigin = 'drag_drop' | 'capture' | 'clipboard' | 'manual';
export type ShelfItemStatus = 'temporary' | 'saved_to_inbox' | 'processed' | 'removed';

export interface ShelfItem {
  id: string;
  sourceItemId?: string;
  assetFileIds: string[];
  label?: string;
  origin?: ShelfItemOrigin;
  status: ShelfItemStatus;
  createdAt: number;
  updatedAt: number;
}

// ─── ProcessJob ───────────────────────────────────────────────
// AI / 转换 / OCR / 转写任务（统一任务模型，与现有 AiTask 互补）

export type ProcessJobType =
  | 'ocr'
  | 'asr'
  | 'markitdown'
  | 'distill'
  | 'summarize'
  | 'tag'
  | 'export';

export type ProcessJobStatus = 'queued' | 'running' | 'succeeded' | 'failed' | 'cancelled';

export interface ProcessJob {
  id: string;
  type: ProcessJobType;
  sourceItemId?: string;
  assetFileIds?: string[];
  status: ProcessJobStatus;
  progress?: number;
  errorMessage?: string;
  createdAt: number;
  updatedAt: number;
  startedAt?: number;
  completedAt?: number;
  metadata?: Record<string, unknown>;
}

// ─── ProcessedContent (AI 处理输出结构) ────────────────────────
// 从 strategy/types.ts 提升到 shared，供 preload 桥接使用

export interface ProcessedContent {
  title: string;
  summary: string;
  tags: string[];
  body_markdown: string;
  suggested_folder: string;
  quality_flags: string[];
}

// ─── DistilledNote ────────────────────────────────────────────
// AI 整理后的结构化笔记（与现有 DistilledOutput 互补，支持多源聚合）

export interface DistilledNote {
  id: string;
  sourceItemIds: string[];
  title: string;
  summary: string;
  tags: string[];
  suggestedFolder?: string;
  bodyMarkdown: string;
  qualityFlags: string[];
  modelProvider?: string;
  modelName?: string;
  createdAt: number;
  updatedAt: number;
  metadata?: Record<string, unknown>;
}

// ─── AIAction ─────────────────────────────────────────────────
// 选中文字 / 截图 / 剪贴板后的 AI 动作定义

export type AIActionType =
  | 'summarize'
  | 'rewrite'
  | 'translate'
  | 'extract_todos'
  | 'to_markdown'
  | 'save_to_inbox'
  | 'custom';

export interface AIAction {
  id: string;
  name: string;
  inputTypes: SourceType[];
  actionType: AIActionType;
  promptProfileId?: string;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
}

// ─── PinItem (Pin Pool) ───────────────────────────────────────
// Pin Pool 中的条目，用于快速 pin 住内容后预筛/提升到 inbox

export type PinItemSourceType =
  | 'clipboard_text'
  | 'clipboard_image'
  | 'screenshot'
  | 'manual_text'
  | 'file'
  | 'pdf'
  | 'docx'
  | 'audio'
  | 'webpage'
  | 'image';

export type PinItemStatus = 'pinned' | 'promoted' | 'ignored' | 'deleted';

export interface PinItem {
  id: string;
  captureItemId: string;
  originalId: string;
  sourceType: PinItemSourceType;
  title: string;
  previewText?: string;
  rawText?: string;
  rawFilePath?: string;
  status: PinItemStatus;
  createdAt: number;
  pinnedAt: number;
  updatedAt: number;
  prefilterResult?: Record<string, unknown>;
}

export interface PinItemListFilter {
  status?: PinItemStatus;
  sourceType?: PinItemSourceType;
  limit?: number;
  offset?: number;
}

// ─── Voice Types (Phase 10) ───────────────────────────────────

export type VoiceSessionPhase = 'idle' | 'listening' | 'processing' | 'done' | 'error';

export type VoicePolishMode = 'raw' | 'light' | 'structured' | 'formal';

export interface VoiceDictionaryEntry {
  id: string;
  phrase: string;
  note?: string;
  enabled: boolean;
  hits: number;
  createdAt: number;
}

export interface VoicePolishRequest {
  transcript: string;
  mode?: VoicePolishMode;
  dictionary?: VoiceDictionaryEntry[];
}

export interface VoicePolishResult {
  rawTranscript: string;
  finalText: string;
  mode: VoicePolishMode;
  usedDictionary: string[];
  warning?: string;
}

export interface VoiceCreatePinRequest {
  transcript: string;
  polishedText?: string;
  title?: string;
  sourceApp?: string;
}

// ── Phase 2A: Pinned Image ────────────────────────────────────────

export interface PinnedImage {
  id: string;
  filePath: string;
  x: number;
  y: number;
  width: number;
  height: number;
  sourceItemId?: string;
  createdAt: number;
}

export interface CaptureSnapshot {
  id: string;
  filePath: string;
  sourceItemId?: string;
  ocrText?: string;
  createdAt: number;
}

export interface OcrResult {
  text: string;
  confidence?: number;
  language?: string;
  error?: string;
}
