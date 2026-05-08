import { ipcMain, app, desktopCapturer, screen, dialog } from 'electron'
import log from 'electron-log'
import * as storage from '../services/storage'
import * as assets from '../services/assets'
import * as clipboard from '../services/clipboard'
import * as screenshot from '../services/screenshot'
import * as ai from '../services/ai'
import * as distill from '../services/distill'
import * as exportService from '../services/export'
import * as capsule from '../services/capsule'
import type { SourceItem, SourceItemStatus, SourceType } from '../../shared/types'

export function registerIpcHandlers(): void {
  ipcMain.handle('app:getVersion', () => app.getVersion())
  ipcMain.handle('app:getPlatform', () => process.platform)

  ipcMain.handle('storage:getSourceItems', (_event, filter?: { status?: SourceItemStatus; type?: SourceType; source?: string; limit?: number; offset?: number }) => {
    try { return storage.getSourceItems(filter) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('storage:getSourceItem', (_event, id: string) => {
    try { return storage.getSourceItem(id) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('storage:createSourceItem', (_event, item: Omit<SourceItem, 'id' | 'createdAt'>) => {
    try { return storage.createSourceItem(item) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('storage:updateSourceItem', (_event, id: string, updates: Partial<SourceItem>) => {
    try { return storage.updateSourceItem(id, updates) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('storage:deleteSourceItem', (_event, id: string) => {
    try { storage.deleteSourceItem(id) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('storage:searchSourceItems', (_event, query: string) => {
    try { return storage.searchSourceItems(query) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('storage:getStats', () => {
    try { return storage.getSourceItemStats() } catch (error) { log.error(error); throw error }
  })

  ipcMain.handle('settings:get', () => {
    try { return storage.getSettings() } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('settings:update', (_event, settings) => {
    try { return storage.updateSettings(settings) } catch (error) { log.error(error); throw error }
  })

  ipcMain.handle('ai:getProviders', () => ai.getProviders())
  ipcMain.handle('ai:addProvider', (_event, provider) => { ai.addProvider(provider); return ai.getProviders() })
  ipcMain.handle('ai:chat', async (_event, { providerId, messages }) => {
    try { return await ai.chat(providerId, messages) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('ai:completion', async (_event, { providerId, prompt }) => {
    try { return await ai.completion(providerId, prompt) } catch (error) { log.error(error); throw error }
  })

  ipcMain.handle('distill:item', async (_event, sourceItemId: string) => {
    try { return await distill.distillSourceItem(sourceItemId) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('distill:batch', async (_event, sourceItemIds: string[]) => {
    try { return await distill.distillBatch(sourceItemIds) } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('distill:quick', async (_event, content: string) => {
    try { return await distill.quickDistill(content) } catch (error) { log.error(error); throw error }
  })

  ipcMain.handle('export:toObsidian', async (_event, itemId: string, options?) => {
    try {
      const item = storage.getSourceItem(itemId)
      if (!item) throw new Error('Item not found')
      return await exportService.exportToObsidian(item, options)
    } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('export:selectVault', async () => {
    try { return await exportService.selectVaultPath() } catch (error) { log.error(error); throw error }
  })

  ipcMain.handle('capture:screenshot', async () => {
    try { const result = await screenshot.captureAndSave(); return result?.dataUrl || null } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('capture:screenshotRegion', async () => {
    return new Promise((resolve) => {
      screenshot.showSelectionOverlay(async (rect) => {
        if (rect) {
          const result = await screenshot.captureAndSave(rect)
          resolve(result?.dataUrl || null)
        } else {
          resolve(null)
        }
      })
    })
  })
  ipcMain.handle('capture:selectFile', async () => {
    try {
      const result = await dialog.showOpenDialog({
        properties: ['openFile', 'multiSelections'],
        filters: [
          { name: 'All Files', extensions: ['*'] },
          { name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'] },
          { name: 'Documents', extensions: ['pdf', 'docx', 'doc', 'txt', 'md'] }
        ]
      })
      return result.canceled ? [] : result.filePaths
    } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('capture:importFile', async (_event, filePath: string) => {
    try {
      const path = require('path')
      const fileName = path.basename(filePath)
      const ext = path.extname(filePath).toLowerCase()
      let type: SourceType = 'file'
      if (['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'].includes(ext)) type = 'image'
      else if (['.pdf'].includes(ext)) type = 'pdf'
      const asset = assets.saveAssetFile(undefined, fileName, filePath)
      return storage.createSourceItem({
        type, source: 'file', status: 'inbox', title: fileName,
        contentPath: asset.localPath, previewText: fileName,
        tags: [], assetFileIds: [asset.id], metadata: { originalPath: filePath }
      })
    } catch (error) { log.error(error); throw error }
  })
  ipcMain.handle('capture:captureWebpage', async (_event, url: string) => {
    try {
      return storage.createSourceItem({
        type: 'webpage', source: 'webpage', status: 'pending',
        title: url, previewText: url, originalUrl: url,
        contentPath: '', tags: [], assetFileIds: [], metadata: {}
      })
    } catch (error) { log.error(error); throw error }
  })

  ipcMain.handle('clipboard:getStatus', () => clipboard.getClipboardStatus())
  ipcMain.handle('clipboard:toggle', () => clipboard.toggleClipboardMonitor())
  ipcMain.handle('clipboard:start', () => { clipboard.startClipboardMonitor(); return { watching: true } })
  ipcMain.handle('clipboard:stop', () => { clipboard.stopClipboardMonitor(); return { watching: false } })

  ipcMain.handle('capsule:show', () => { capsule.showCapsule(); return { visible: true } })
  ipcMain.handle('capsule:hide', () => { capsule.hideCapsule(); return { visible: false } })
  ipcMain.handle('capsule:toggle', () => { capsule.toggleCapsule(); return { visible: capsule.isCapsuleVisible() } })
  ipcMain.handle('capsule:isVisible', () => ({ visible: capsule.isCapsuleVisible() }))

  ipcMain.handle('asset:get', (_event, id: string) => {
    try { return assets.getAssetFile(id) } catch { throw new Error('Asset not found') }
  })
  ipcMain.handle('asset:readBase64', (_event, filePath: string) => {
    try { return assets.readAssetAsBase64(filePath) } catch { return null }
  })

  ipcMain.handle('quicknote:add', async (_event, content: string) => {
    try {
      return storage.createSourceItem({
        type: 'text', source: 'manual', status: 'inbox',
        title: content.slice(0, 50), previewText: content,
        contentPath: '', tags: ['quicknote'], assetFileIds: [], metadata: {}
      })
    } catch (error) { log.error(error); throw error }
  })

  log.info('All IPC handlers registered')
}
