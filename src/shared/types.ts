// AcMind Core Type Definitions
// Mapped from Swift models in AcMindKit/Models/

// ─── SourceItem ───────────────────────────────────────────────

export type SourceType = 
  | 'text' 
  | 'image' 
  | 'audio' 
  | 'video' 
  | 'pdf' 
  | 'docx' 
  | 'screenshot' 
  | 'webpage' 
  | 'unknownFile'

export type SourceOrigin = 
  | 'manual' 
  | 'clipboard' 
  | 'screenshot' 
  | 'webpage' 
  | 'file' 
  | 'voice' 
  | 'capsule' 
  | 'imported'

export type SourceItemStatus = 
  | 'inbox' 
  | 'pending' 
  | 'capturing' 
  | 'captured' 
  | 'parsing' 
  | 'parsed' 
  | 'distilling' 
  | 'distilled' 
  | 'exporting' 
  | 'exported' 
  | 'archived' 
  | 'deleted'

export interface SourceItem {
  id: string
  type: SourceType
  source: SourceOrigin
  status: SourceItemStatus
  title?: string
  contentPath?: string
  contentHash?: string
  previewText?: string
  ocrText?: string
  transcript?: string
  polishedTranscript?: string
  sourceApp?: string
  originalUrl?: string
  tags: string[]
  captureItemId?: string
  vaultImportPath?: string
  assetFileIds: string[]
  metadata: Record<string, string>
  createdAt: Date
  updatedAt?: Date
}

// ─── AppSettings ──────────────────────────────────────────────

export type AppTheme = 'light' | 'dark' | 'system'

export interface DesktopCapsuleSettings {
  isEnabled: boolean
  hotkey?: string
  position: 'top' | 'bottom' | 'left' | 'right'
  autoHide: boolean
  showVoice: boolean
  showCapture: boolean
  showAgent: boolean
}

export const DEFAULT_DESKTOP_CAPSULE_SETTINGS: DesktopCapsuleSettings = {
  isEnabled: true,
  position: 'top',
  autoHide: true,
  showVoice: true,
  showCapture: true,
  showAgent: true
}

export interface AppSettings {
  theme: AppTheme
  language: string
  defaultProviderId?: string
  defaultModelId?: string
  vaultPath: string
  autoCaptureClipboard: boolean
  captureScreenshotHotkey?: string
  defaultExportTarget: 'obsidian' | 'folder' | 'clipboard'
  autoFrontmatter: boolean
  desktopCapsule: DesktopCapsuleSettings
}

export const DEFAULT_APP_SETTINGS: AppSettings = {
  theme: 'system',
  language: 'zh-CN',
  vaultPath: '',
  autoCaptureClipboard: true,
  defaultExportTarget: 'obsidian',
  autoFrontmatter: true,
  desktopCapsule: DEFAULT_DESKTOP_CAPSULE_SETTINGS
}

// ─── ProviderConfig ───────────────────────────────────────────

export type AiTier = 'local_light' | 'cloud_standard' | 'cloud_advanced'

export interface ProviderConfig {
  id: string
  name: string
  type: 'ollama' | 'openai_compatible'
  tier: AiTier
  baseUrl: string
  apiKey?: string
  modelId: string
  enabled: boolean
  capabilities: string[]
}

// ─── VaultConfig ─────────────────────────────────────────────

export interface VaultConfig {
  vaultPath: string
  defaultFolder: string
  template: string
  pathRule: 'category_date' | 'category_title' | 'flat'
  conflictStrategy: 'rename' | 'skip' | 'overwrite'
  autoFrontmatter: boolean
  frontmatterTemplate: Record<string, unknown>
}

// ─── DistilledNote ────────────────────────────────────────────

export interface DistilledNote {
  id: string
  sourceItemIds: string[]
  title: string
  summary: string
  tags: string[]
  suggestedFolder?: string
  bodyMarkdown: string
  qualityFlags: string[]
  modelProvider?: string
  modelName?: string
  reviewStatus: 'pending' | 'approved' | 'rejected' | 'regenerated'
  createdAt: Date
  updatedAt: Date
  metadata?: Record<string, unknown>
}

// ─── ExportRecord ─────────────────────────────────────────────

export interface ExportRecord {
  id: string
  sourceItemId: string
  distilledOutputId?: string
  knowledgeCardId?: string
  vaultPath: string
  relativeFilePath: string
  frontmatter: Record<string, unknown>
  exportedAt: Date
  status: 'pending' | 'exporting' | 'success' | 'failed'
  conflictResolution?: 'overwrite' | 'rename' | 'skip'
  error?: string
}

// ─── KnowledgeCard ────────────────────────────────────────────

export interface KnowledgeCard {
  id: string
  sourceItemId: string
  distilledOutputId?: string
  canonicalTitle: string
  summary?: string
  category?: string
  tags: string[]
  body?: string
  status: 'active' | 'archived' | 'draft'
  createdAt: Date
  updatedAt: Date
}

// ─── ClipboardItem ────────────────────────────────────────────

export type ClipboardContentType = 'text' | 'image' | 'file' | 'url' | 'rich_text'

export interface ClipboardItem {
  id: string
  sourceItemId?: string
  contentType: ClipboardContentType
  text?: string
  assetFileIds?: string[]
  sourceApp?: string
  isSensitive?: boolean
  isPinned?: boolean
  createdAt: Date
}

// ─── AssetFile ────────────────────────────────────────────────

export type AssetFileKind = 'image' | 'audio' | 'video' | 'pdf' | 'docx' | 'html' | 'markdown' | 'other'

export interface AssetFile {
  id: string
  sourceItemId?: string
  kind: AssetFileKind
  originalName?: string
  localPath: string
  mimeType?: string
  sizeBytes?: number
  sha256?: string
  createdAt: Date
  metadata?: Record<string, unknown>
}

// ─── IPC Channel Names ────────────────────────────────────────

export const IPC_CHANNELS = {
  // App
  APP_GET_VERSION: 'app:getVersion',
  APP_GET_PLATFORM: 'app:getPlatform',
  
  // Storage
  STORAGE_GET_SOURCE_ITEMS: 'storage:getSourceItems',
  STORAGE_GET_SOURCE_ITEM: 'storage:getSourceItem',
  STORAGE_CREATE_SOURCE_ITEM: 'storage:createSourceItem',
  STORAGE_UPDATE_SOURCE_ITEM: 'storage:updateSourceItem',
  STORAGE_DELETE_SOURCE_ITEM: 'storage:deleteSourceItem',
  STORAGE_SEARCH_SOURCE_ITEMS: 'storage:searchSourceItems',
  
  // Settings
  SETTINGS_GET: 'settings:get',
  SETTINGS_UPDATE: 'settings:update',
  
  // Capture
  CAPTURE_SCREENSHOT: 'capture:screenshot',
  CAPTURE_AREA_START: 'capture:areaStart',
  CAPTURE_AREA_CANCEL: 'capture:areaCancel',
  
  // Clipboard
  CLIPBOARD_GET_STATUS: 'clipboard:getStatus',
  CLIPBOARD_TOGGLE: 'clipboard:toggle',
  CLIPBOARD_ITEMS_CHANGED: 'clipboard:itemsChanged',
  
  // Events
  RECORDS_CHANGED: 'records:changed',
  SHORTCUT_SCREENSHOT: 'shortcut:screenshot'
} as const

export type IpcChannel = typeof IPC_CHANNELS[keyof typeof IPC_CHANNELS]
