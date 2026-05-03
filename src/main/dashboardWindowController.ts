import { BrowserWindow } from 'electron';
import path from 'node:path';
import { createBrandNativeImage } from './tray';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MIN_WIDTH = 900;
const MIN_HEIGHT = 600;
const DEFAULT_WIDTH = 1200;
const DEFAULT_HEIGHT = 800;

// ---------------------------------------------------------------------------
// DashboardWindowController
// ---------------------------------------------------------------------------

export interface DashboardWindowControllerOptions {
  preloadPath: string;
  rendererFilePath: string;
  rendererDevUrl?: string;
  isDev: boolean;
}

export interface DashboardWindowController {
  show: () => void;
  hide: () => void;
  toggle: () => void;
  isVisible: () => boolean;
  getWindow: () => BrowserWindow | null;
}

export function createDashboardWindowController(
  options: DashboardWindowControllerOptions,
): DashboardWindowController {
  let mainWindow: BrowserWindow | null = null;

  function createWindow(): BrowserWindow {
    const win = new BrowserWindow({
      width: DEFAULT_WIDTH,
      height: DEFAULT_HEIGHT,
      minWidth: MIN_WIDTH,
      minHeight: MIN_HEIGHT,
      title: 'PinMind',
      icon: createBrandNativeImage(),
      show: false,
      titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
      webPreferences: {
        preload: options.preloadPath,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
      },
    });

    // Load appropriate URL based on dev/prod
    if (options.isDev && options.rendererDevUrl) {
      win.loadURL(options.rendererDevUrl);
    } else {
      win.loadFile(options.rendererFilePath);
    }

    // Show window when ready to prevent visual flash
    win.once('ready-to-show', () => {
      win.show();
    });

    // On macOS, hide window instead of closing (app stays in tray)
    win.on('close', (event) => {
      if (process.platform === 'darwin') {
        event.preventDefault();
        win.hide();
      }
    });

    win.on('closed', () => {
      mainWindow = null;
    });

    mainWindow = win;
    return win;
  }

  function ensureWindow(): BrowserWindow {
    if (!mainWindow || mainWindow.isDestroyed()) {
      createWindow();
    }
    return mainWindow!;
  }

  return {
    show(): void {
      const win = ensureWindow();
      if (win.isMinimized()) {
        win.restore();
      }
      win.show();
      win.focus();
    },

    hide(): void {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.hide();
      }
    },

    toggle(): void {
      if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
        mainWindow.hide();
      } else {
        this.show();
      }
    },

    isVisible(): boolean {
      return mainWindow !== null && !mainWindow.isDestroyed() && mainWindow.isVisible();
    },

    getWindow(): BrowserWindow | null {
      return mainWindow && !mainWindow.isDestroyed() ? mainWindow : null;
    },
  };
}
