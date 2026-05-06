import path from 'node:path';
import { BrowserWindow, screen } from 'electron';

// ---------------------------------------------------------------------------
// Constants — dictation capsule window sizing
// Recording state: 220×110, idle/collapsed: 220×42
// ---------------------------------------------------------------------------
const WINDOW_WIDTH = 220;
const WINDOW_HEIGHT_RECORDING = 110;
const WINDOW_HEIGHT_IDLE = 42;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface DictationWindowControllerOptions {
  preloadPath: string;
  rendererFilePath: string;
  rendererDevUrl?: string;
  isDev: boolean;
  onWindowCreated?: (window: BrowserWindow) => void;
}

export interface DictationWindowController {
  show: () => void;
  hide: () => void;
  isVisible: () => boolean;
  destroy: () => void;
  getWindow: () => BrowserWindow | null;
}

// ---------------------------------------------------------------------------
// Helpers — position: screen bottom center, 80px above Dock
// ---------------------------------------------------------------------------

function getBottomCenterPosition(): { x: number; y: number } {
  const display = screen.getPrimaryDisplay();
  const { x: screenX, y: screenY, width: screenWidth, height: screenHeight } = display.bounds;
  return {
    x: Math.round(screenX + (screenWidth / 2) - (WINDOW_WIDTH / 2)),
    y: Math.round(screenY + screenHeight - WINDOW_HEIGHT_RECORDING - 80),
  };
}

// ---------------------------------------------------------------------------
// Factory — mirrors widgetWindowController pattern
// ---------------------------------------------------------------------------

export function createDictationWindowController(
  options: DictationWindowControllerOptions,
): DictationWindowController {
  let dictationWindow: BrowserWindow | null = null;

  function createWindow(): BrowserWindow {
    const pos = getBottomCenterPosition();

    const win = new BrowserWindow({
      width: WINDOW_WIDTH,
      height: WINDOW_HEIGHT_RECORDING,
      x: pos.x,
      y: pos.y,
      transparent: true,
      frame: false,
      alwaysOnTop: true,
      skipTaskbar: true,
      hasShadow: false,
      resizable: false,
      movable: false,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      show: false,
      backgroundColor: '#00000000',
      focusable: false,
      webPreferences: {
        preload: options.preloadPath,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
        backgroundThrottling: false,
      },
    });

    // Force transparent background (triple insurance)
    const injectTransparentCSS = () => {
      win.webContents.insertCSS(`
        html, body, #root {
          background: transparent !important;
          background-color: transparent !important;
          background-image: none !important;
        }
      `);
    };
    win.webContents.on('dom-ready', injectTransparentCSS);
    win.webContents.on('did-finish-load', injectTransparentCSS);

    // Load dictation.html
    if (options.isDev && options.rendererDevUrl) {
      const baseUrl = options.rendererDevUrl.replace(/\/$/, '');
      win.loadURL(baseUrl + '/dictation.html');
    } else {
      const dictationHtml = path.join(path.dirname(options.rendererFilePath), 'dictation.html');
      win.loadFile(dictationHtml);
    }

    // Show on all workspaces
    win.once('ready-to-show', () => {
      win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
      win.show();
    });

    // Reposition on display change
    screen.on('display-metrics-changed', () => {
      if (dictationWindow && !dictationWindow.isDestroyed()) {
        const newPos = getBottomCenterPosition();
        dictationWindow.setPosition(newPos.x, newPos.y);
      }
    });

    dictationWindow = win;
    options.onWindowCreated?.(win);
    return win;
  }

  function ensureWindow(): BrowserWindow {
    if (!dictationWindow || dictationWindow.isDestroyed()) {
      createWindow();
    }
    return dictationWindow!;
  }

  const controller: DictationWindowController = {
    show(): void {
      const win = ensureWindow();
      if (win.isMinimized()) win.restore();
      win.show();
    },

    hide(): void {
      if (dictationWindow && !dictationWindow.isDestroyed()) {
        dictationWindow.hide();
      }
    },

    isVisible(): boolean {
      return dictationWindow !== null && !dictationWindow.isDestroyed() && dictationWindow.isVisible();
    },

    destroy(): void {
      if (dictationWindow && !dictationWindow.isDestroyed()) {
        dictationWindow.close();
      }
    },

    getWindow(): BrowserWindow | null {
      return dictationWindow && !dictationWindow.isDestroyed() ? dictationWindow : null;
    },
  };

  return controller;
}
