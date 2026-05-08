import { app, BrowserWindow, globalShortcut, Menu, Tray, nativeImage } from 'electron'
import path from 'path'
import log from 'electron-log'
import { initStorage, closeStorage } from './services/storage'
import { initAssetStore, closeAssetStore } from './services/assets'
import { startClipboardMonitor, stopClipboardMonitor } from './services/clipboard'
import { registerIpcHandlers } from './ipc'

log.transports.file.level = 'info'
log.transports.console.level = 'debug'

log.info('AcMind Electron starting...')

let mainWindow: BrowserWindow | null = null
let tray: Tray | null = null

const isDev = !app.isPackaged

function createMainWindow(): BrowserWindow {
  log.info('Creating main window...')
  
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'AcMind',
    frame: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, '../preload/index.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: false
    }
  })

  mainWindow.on('ready-to-show', () => {
    log.info('Main window ready to show')
    mainWindow?.show()
  })

  mainWindow.on('closed', () => {
    mainWindow = null
  })

  mainWindow.on('close', (event) => {
    if (process.platform === 'darwin') {
      event.preventDefault()
      mainWindow?.hide()
    }
  })

  if (isDev) {
    mainWindow.loadURL('http://localhost:5173')
    mainWindow.webContents.openDevTools()
  } else {
    mainWindow.loadFile(path.join(__dirname, '../../dist/index.html'))
  }

  return mainWindow
}

function createTray(): void {
  const iconPath = isDev 
    ? path.join(__dirname, '../../Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png')
    : path.join(process.resourcesPath, 'Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png')
  
  try {
    const icon = nativeImage.createFromPath(iconPath)
    tray = new Tray(icon.isEmpty() ? nativeImage.createEmpty() : icon)
  } catch {
    tray = new Tray(nativeImage.createEmpty())
  }

  const contextMenu = Menu.buildFromTemplate([
    { label: '显示 AcMind', click: () => mainWindow?.show() },
    { type: 'separator' },
    { label: '截取屏幕', click: () => mainWindow?.webContents.send('shortcut:screenshot') },
    { label: '打开收集箱', click: () => mainWindow?.show() },
    { type: 'separator' },
    { label: '退出', click: () => { app.quit() } }
  ])

  tray.setToolTip('AcMind')
  tray.setContextMenu(contextMenu)
  tray.on('click', () => mainWindow?.show())
}

function registerGlobalShortcuts(): void {
  globalShortcut.register('CommandOrControl+Shift+A', () => {
    log.info('Global shortcut: show AcMind')
    if (mainWindow?.isVisible()) {
      mainWindow.hide()
    } else {
      mainWindow?.show()
    }
  })
  
  globalShortcut.register('CommandOrControl+Shift+S', () => {
    log.info('Global shortcut: screenshot')
    mainWindow?.webContents.send('shortcut:screenshot')
  })
}

async function initApp(): Promise<void> {
  try {
    log.info('Initializing storage...')
    await initStorage()
    log.info('Storage initialized')

    log.info('Initializing asset store...')
    await initAssetStore()
    log.info('Asset store initialized')

    log.info('Registering IPC handlers...')
    registerIpcHandlers()
    log.info('IPC handlers registered')

    log.info('Starting clipboard monitor...')
    startClipboardMonitor()
    log.info('Clipboard monitor started')

    createMainWindow()
    createTray()
    registerGlobalShortcuts()

    log.info('AcMind Electron initialized successfully')
  } catch (error) {
    log.error('Failed to initialize app:', error)
    throw error
  }
}

app.whenReady().then(initApp).catch((error) => {
  log.error('App startup failed:', error)
  app.quit()
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('activate', () => {
  if (mainWindow === null) {
    createMainWindow()
  } else {
    mainWindow.show()
  }
})

app.on('will-quit', () => {
  log.info('App will quit')
  globalShortcut.unregisterAll()
  stopClipboardMonitor()
  closeAssetStore()
  closeStorage()
})

app.on('before-quit', () => {
  log.info('App before quit')
})

process.on('uncaughtException', (error) => {
  log.error('Uncaught exception:', error)
})

process.on('unhandledRejection', (reason) => {
  log.error('Unhandled rejection:', reason)
})
