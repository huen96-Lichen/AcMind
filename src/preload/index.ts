import { contextBridge, ipcRenderer } from 'electron'
import type { SourceItem, AppSettings, ProviderConfig } from '../shared/types'

interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

interface AIResponse {
  content: string
  usage?: { promptTokens: number; completionTokens: number; totalTokens: number }
  model?: string
  provider?: string
}

interface DistillResult {
  success: boolean
  distilledNote?: { id: string; title: string; summary: string; tags: string[] }
  error?: string
}

interface ExportResult {
  success: boolean
  filePath?: string
  error?: string
}

export interface ElectronAPI {
  app: { getVersion: () => Promise<string>; getPlatform: () => string }
  storage: {
    getSourceItems: (filter?: { status?: string; type?: string; source?: string; limit?: number }) => Promise<SourceItem[]>
    getSourceItem: (id: string) => Promise<SourceItem | null>
    createSourceItem: (item: Omit<SourceItem, 'id' | 'createdAt'>) => Promise<SourceItem>
    updateSourceItem: (id: string, updates: Partial<SourceItem>) => Promise<SourceItem>
    deleteSourceItem: (id: string) => Promise<void>
    searchSourceItems: (query: string) => Promise<SourceItem[]>
    getStats: () => Promise<{ total: number; inbox: number; distilled: number; exported: number }>
  }
  settings: { get: () => Promise<AppSettings>; update: (settings: Partial<AppSettings>) => Promise<AppSettings> }
  ai: {
    getProviders: () => Promise<ProviderConfig[]>
    addProvider: (provider: ProviderConfig) => Promise<ProviderConfig[]>
    chat: (providerId: string, messages: ChatMessage[]) => Promise<AIResponse>
    completion: (providerId: string, prompt: string) => Promise<AIResponse>
  }
  distill: {
    item: (sourceItemId: string) => Promise<DistillResult>
    batch: (sourceItemIds: string[]) => Promise<DistillResult[]>
    quick: (content: string) => Promise<string>
  }
  export: {
    toObsidian: (itemId: string, options?: unknown) => Promise<ExportResult>
    selectVault: () => Promise<string | null>
  }
  capture: {
    screenshot: () => Promise<string | null>
    screenshotRegion: () => Promise<string | null>
    selectFile: () => Promise<string[]>
    importFile: (filePath: string) => Promise<SourceItem | null>
    captureWebpage: (url: string) => Promise<SourceItem | null>
  }
  clipboard: {
    getStatus: () => Promise<{ watching: boolean; interval: number }>
    toggle: () => Promise<{ watching: boolean }>
    start: () => Promise<{ watching: boolean }>
    stop: () => Promise<{ watching: boolean }>
  }
  asset: { get: (id: string) => Promise<unknown>; readBase64: (filePath: string) => Promise<string | null> }
  on: (channel: string, callback: (...args: unknown[]) => void) => () => void
  off: (channel: string, callback: (...args: unknown[]) => void) => void
}

const api: ElectronAPI = {
  app: { getVersion: () => ipcRenderer.invoke('app:getVersion'), getPlatform: () => process.platform },
  storage: {
    getSourceItems: (filter) => ipcRenderer.invoke('storage:getSourceItems', filter),
    getSourceItem: (id) => ipcRenderer.invoke('storage:getSourceItem', id),
    createSourceItem: (item) => ipcRenderer.invoke('storage:createSourceItem', item),
    updateSourceItem: (id, updates) => ipcRenderer.invoke('storage:updateSourceItem', id, updates),
    deleteSourceItem: (id) => ipcRenderer.invoke('storage:deleteSourceItem', id),
    searchSourceItems: (query) => ipcRenderer.invoke('storage:searchSourceItems', query),
    getStats: () => ipcRenderer.invoke('storage:getStats')
  },
  settings: { get: () => ipcRenderer.invoke('settings:get'), update: (settings) => ipcRenderer.invoke('settings:update', settings) },
  ai: {
    getProviders: () => ipcRenderer.invoke('ai:getProviders'),
    addProvider: (provider) => ipcRenderer.invoke('ai:addProvider', provider),
    chat: (providerId, messages) => ipcRenderer.invoke('ai:chat', { providerId, messages }),
    completion: (providerId, prompt) => ipcRenderer.invoke('ai:completion', { providerId, prompt })
  },
  distill: {
    item: (sourceItemId) => ipcRenderer.invoke('distill:item', sourceItemId),
    batch: (sourceItemIds) => ipcRenderer.invoke('distill:batch', sourceItemIds),
    quick: (content) => ipcRenderer.invoke('distill:quick', content)
  },
  export: {
    toObsidian: (itemId, options) => ipcRenderer.invoke('export:toObsidian', itemId, options),
    selectVault: () => ipcRenderer.invoke('export:selectVault')
  },
  capture: {
    screenshot: () => ipcRenderer.invoke('capture:screenshot'),
    screenshotRegion: () => ipcRenderer.invoke('capture:screenshotRegion'),
    selectFile: () => ipcRenderer.invoke('capture:selectFile'),
    importFile: (filePath) => ipcRenderer.invoke('capture:importFile', filePath),
    captureWebpage: (url) => ipcRenderer.invoke('capture:captureWebpage', url)
  },
  clipboard: {
    getStatus: () => ipcRenderer.invoke('clipboard:getStatus'),
    toggle: () => ipcRenderer.invoke('clipboard:toggle'),
    start: () => ipcRenderer.invoke('clipboard:start'),
    stop: () => ipcRenderer.invoke('clipboard:stop')
  },
  asset: { get: (id) => ipcRenderer.invoke('asset:get', id), readBase64: (filePath) => ipcRenderer.invoke('asset:readBase64', filePath) },
  on: (channel, callback) => { const sub = (_e: Electron.IpcRendererEvent, ...args: unknown[]) => callback(...args); ipcRenderer.on(channel, sub); return () => ipcRenderer.removeListener(channel, sub) },
  off: (channel, callback) => ipcRenderer.removeListener(channel, callback as (...args: unknown[]) => void)
}

contextBridge.exposeInMainWorld('electronAPI', api)
