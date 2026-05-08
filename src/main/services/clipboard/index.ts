import { clipboard, nativeImage, BrowserWindow } from 'electron'
import crypto from 'crypto'
import log from 'electron-log'
import { createSourceItem } from '../storage'
import * as assets from '../assets'
import type { SourceType } from '../../../shared/types'

let monitorInterval: NodeJS.Timeout | null = null
let lastTextHash: string = ''
let lastImageHash: string = ''
let isWatching = false

function getTextHash(): string {
  const text = clipboard.readText()
  return crypto.createHash('md5').update(text).digest('hex')
}

function getImageHash(): string {
  const image = clipboard.readImage()
  if (image.isEmpty()) return ''
  const buffer = image.toPNG()
  return crypto.createHash('md5').update(buffer).digest('hex')
}

export function startClipboardMonitor(intervalMs = 1000): void {
  if (isWatching) {
    log.warn('Clipboard monitor already running')
    return
  }

  lastTextHash = getTextHash()
  lastImageHash = getImageHash()
  isWatching = true

  log.info('Clipboard monitor started')

  monitorInterval = setInterval(() => {
    checkClipboard()
  }, intervalMs)
}

export function stopClipboardMonitor(): void {
  if (monitorInterval) {
    clearInterval(monitorInterval)
    monitorInterval = null
  }
  isWatching = false
  log.info('Clipboard monitor stopped')
}

export function getClipboardStatus(): { watching: boolean; interval: number } {
  return { watching: isWatching, interval: isWatching ? 1000 : 0 }
}

export function toggleClipboardMonitor(): { watching: boolean } {
  if (isWatching) {
    stopClipboardMonitor()
  } else {
    startClipboardMonitor()
  }
  return { watching: isWatching }
}

async function checkClipboard(): Promise<void> {
  try {
    const currentTextHash = getTextHash()
    const currentImageHash = getImageHash()

    if (currentTextHash && currentTextHash !== lastTextHash) {
      lastTextHash = currentTextHash
      const text = clipboard.readText()
      
      if (text.trim()) {
        const urlMatch = text.match(/^https?:\/\/[^\s]+$/)
        const type: SourceType = urlMatch ? 'webpage' : 'text'
        
        await createSourceItem({
          type,
          source: 'clipboard',
          status: 'inbox',
          title: text.slice(0, 50),
          previewText: text,
          originalUrl: urlMatch ? text : undefined,
          contentPath: '',
          tags: [],
          assetFileIds: [],
          metadata: { capturedAt: Date.now() }
        })

        notifyRenderer('clipboard:newItem', { type: 'text', content: text })
        log.info('Clipboard text captured:', text.slice(0, 50))
      }
    }

    if (currentImageHash && currentImageHash !== lastImageHash) {
      lastImageHash = currentImageHash
      const image = clipboard.readImage()
      
      if (!image.isEmpty()) {
        const buffer = image.toPNG()
        const tempPath = `/tmp/clipboard_${Date.now()}.png`
        const fs = require('fs')
        fs.writeFileSync(tempPath, buffer)

        const asset = assets.saveAssetFile(undefined, `clipboard_${Date.now()}.png`, tempPath)
        
        await createSourceItem({
          type: 'image',
          source: 'clipboard',
          status: 'inbox',
          title: `截图 ${new Date().toLocaleString('zh-CN')}`,
          previewText: '剪贴板图片',
          contentPath: asset.localPath,
          tags: [],
          assetFileIds: [asset.id],
          metadata: { capturedAt: Date.now() }
        })

        notifyRenderer('clipboard:newItem', { type: 'image', assetId: asset.id })
        log.info('Clipboard image captured')
        
        fs.unlinkSync(tempPath)
      }
    }
  } catch (error) {
    log.error('Clipboard check error:', error)
  }
}

function notifyRenderer(channel: string, data: unknown): void {
  const windows = BrowserWindow.getAllWindows()
  windows.forEach(win => {
    if (!win.isDestroyed()) {
      win.webContents.send(channel, data)
    }
  })
}
