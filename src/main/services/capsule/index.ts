import { BrowserWindow, screen, globalShortcut } from 'electron'
import path from 'path'
import log from 'electron-log'
import { getSettings } from '../storage'

let capsuleWindow: BrowserWindow | null = null
let isVisible = false

interface CapsulePosition {
  x: number
  y: number
}

function calculatePosition(position: 'top' | 'bottom' | 'left' | 'right'): CapsulePosition {
  const primaryDisplay = screen.getPrimaryDisplay()
  const { width, height } = primaryDisplay.workAreaSize
  const { x: screenX, y: screenY } = primaryDisplay.bounds
  const capsuleWidth = 400
  const capsuleHeight = 300

  switch (position) {
    case 'top':
      return { x: screenX + (width - capsuleWidth) / 2, y: screenY }
    case 'bottom':
      return { x: screenX + (width - capsuleWidth) / 2, y: screenY + height - capsuleHeight }
    case 'left':
      return { x: screenX, y: screenY + (height - capsuleHeight) / 2 }
    case 'right':
      return { x: screenX + width - capsuleWidth, y: screenY + (height - capsuleHeight) / 2 }
    default:
      return { x: screenX + (width - capsuleWidth) / 2, y: screenY }
  }
}

export function createCapsuleWindow(): BrowserWindow | null {
  if (capsuleWindow) {
    return capsuleWindow
  }

  const settings = getSettings()
  const capsuleSettings = settings.desktopCapsule

  if (!capsuleSettings.isEnabled) {
    log.info('Desktop capsule is disabled')
    return null
  }

  const position = calculatePosition(capsuleSettings.position)
  const capsuleWidth = 400
  const capsuleHeight = 300

  capsuleWindow = new BrowserWindow({
    width: capsuleWidth,
    height: capsuleHeight,
    x: position.x,
    y: position.y,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    movable: true,
    visible: capsuleSettings.autoHide ? false : true,
    webPreferences: {
      preload: path.join(__dirname, '../preload/index.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  })

  isVisible = !capsuleSettings.autoHide

  capsuleWindow.loadURL('http://localhost:5173/#/capsule')

  if (capsuleSettings.autoHide) {
    capsuleWindow.setIgnoreMouseEvents(true)
  }

  capsuleWindow.on('closed', () => {
    capsuleWindow = null
    isVisible = false
  })

  log.info('Capsule window created at:', position)

  return capsuleWindow
}

export function showCapsule(): void {
  if (!capsuleWindow) {
    createCapsuleWindow()
  }

  if (capsuleWindow) {
    capsuleWindow.show()
    capsuleWindow.setIgnoreMouseEvents(false)
    isVisible = true
    log.info('Capsule shown')
  }
}

export function hideCapsule(): void {
  if (capsuleWindow) {
    capsuleWindow.hide()
    capsuleWindow.setIgnoreMouseEvents(true)
    isVisible = false
    log.info('Capsule hidden')
  }
}

export function toggleCapsule(): void {
  if (isVisible) {
    hideCapsule()
  } else {
    showCapsule()
  }
}

export function isCapsuleVisible(): boolean {
  return isVisible
}

export function getCapsuleWindow(): BrowserWindow | null {
  return capsuleWindow
}

export function closeCapsule(): void {
  if (capsuleWindow) {
    capsuleWindow.close()
    capsuleWindow = null
    isVisible = false
  }
}

export function registerCapsuleShortcut(): void {
  globalShortcut.register('CommandOrControl+Shift+C', () => {
    log.info('Capsule shortcut triggered')
    toggleCapsule()
  })
}

export function unregisterCapsuleShortcut(): void {
  globalShortcut.unregister('CommandOrControl+Shift+C')
}
