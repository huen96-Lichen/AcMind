import path from 'node:path';
import { BrowserWindow, ipcMain, screen } from 'electron';

// ---------------------------------------------------------------------------
// Constants — from AcMind (formerly PinStack) Sizing.swift + main.swift
// openNotchSize = 640×260, shadowPadding = 20
// windowSize = 640 × (260 + 20) = 640 × 280
// ---------------------------------------------------------------------------
const WINDOW_WIDTH = 640;
const WINDOW_HEIGHT = 280;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface WidgetWindowControllerOptions {
  preloadPath: string;
  rendererFilePath: string;
  rendererDevUrl?: string;
  isDev: boolean;
}

export interface WidgetWindowController {
  show: () => void;
  hide: () => void;
  toggle: () => void;
  expand: () => void;
  collapse: () => void;
  isVisible: () => boolean;
  destroy: () => void;
  getWindow: () => BrowserWindow | null;
}

// ---------------------------------------------------------------------------
// Helpers — from AcMind (formerly PinStack) main.swift createWindow()
// x = screenFrame.midX - (windowSize.width / 2)
// y = screenFrame.maxY - windowSize.height
// Electron: y=0 is top, so y = screenY (top of screen)
// ---------------------------------------------------------------------------

function getTopCenterPosition(): { x: number; y: number } {
  const display = screen.getPrimaryDisplay();
  const { x: screenX, y: screenY, width: screenWidth } = display.bounds;
  return {
    x: Math.round(screenX + (screenWidth / 2) - (WINDOW_WIDTH / 2)),
    y: Math.round(screenY),
  };
}

// ---------------------------------------------------------------------------
// Factory — from AcMind (formerly PinStack) NotchWindow.swift + main.swift
// ---------------------------------------------------------------------------

export function createWidgetWindowController(
  options: WidgetWindowControllerOptions,
): WidgetWindowController {
  let widgetWindow: BrowserWindow | null = null;
  let isExpanded = false;

  function notifyStateChanged(expanded: boolean): void {
    if (widgetWindow && !widgetWindow.isDestroyed()) {
      widgetWindow.webContents.send('widget:state-changed', { expanded });
    }
  }

  function createWindow(): BrowserWindow {
    const pos = getTopCenterPosition();

    // From pinstack NotchWindow.swift:
    // isFloatingPanel = true, isOpaque = false, backgroundColor = .clear,
    // isMovable = false, level = .mainMenu + 3, hasShadow = false
    // collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
    const win = new BrowserWindow({
      width: WINDOW_WIDTH,
      height: WINDOW_HEIGHT,
      x: pos.x,
      y: pos.y,
      transparent: true,
      frame: false,
      alwaysOnTop: true,        // level = .mainMenu + 3
      skipTaskbar: true,        // ignoresCycle
      hasShadow: false,         // hasShadow = false
      resizable: false,         // isMovable = false
      movable: false,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      show: false,
      backgroundColor: '#00000000', // backgroundColor = .clear
      focusable: false,         // canBecomeKey = false (legacy: true, but we use false for non-activating)
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

    // Load widget.html
    if (options.isDev && options.rendererDevUrl) {
      const baseUrl = options.rendererDevUrl.replace(/\/$/, '');
      win.loadURL(baseUrl + '/widget.html');
    } else {
      const widgetHtml = path.join(path.dirname(options.rendererFilePath), 'widget.html');
      win.loadFile(widgetHtml);
    }

    // From pinstack main.swift: setVisibleOnAllWorkspaces + orderFrontRegardless
    win.once('ready-to-show', () => {
      win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
      win.show();
    });

    // From pinstack NotchContentView.swift handleHover:
    // Auto-collapse on blur with delay
    win.on('blur', () => {
      if (isExpanded) {
        setTimeout(() => {
          if (isExpanded) controller.collapse();
        }, 200);
      }
    });

    // From pinstack main.swift: screenParametersChanged → recreate windows
    screen.on('display-metrics-changed', () => {
      if (widgetWindow && !widgetWindow.isDestroyed()) {
        const newPos = getTopCenterPosition();
        widgetWindow.setPosition(newPos.x, newPos.y);
      }
    });

    // IPC handlers for renderer → main communication
    const toggleHandler = () => controller.toggle();
    const expandHandler = () => controller.expand();
    const collapseHandler = () => controller.collapse();
    ipcMain.on('widget:toggle', toggleHandler);
    ipcMain.on('widget:expand', expandHandler);
    ipcMain.on('widget:collapse', collapseHandler);

    win.on('closed', () => {
      ipcMain.removeListener('widget:toggle', toggleHandler);
      ipcMain.removeListener('widget:expand', expandHandler);
      ipcMain.removeListener('widget:collapse', collapseHandler);
      widgetWindow = null;
      isExpanded = false;
    });

    widgetWindow = win;
    return win;
  }

  function ensureWindow(): BrowserWindow {
    if (!widgetWindow || widgetWindow.isDestroyed()) {
      createWindow();
    }
    return widgetWindow!;
  }

  const controller: WidgetWindowController = {
    show(): void {
      const win = ensureWindow();
      if (win.isMinimized()) win.restore();
      win.show();
    },

    hide(): void {
      if (widgetWindow && !widgetWindow.isDestroyed()) {
        widgetWindow.hide();
      }
    },

    toggle(): void {
      if (isExpanded) this.collapse();
      else this.expand();
    },

    // From pinstack NotchViewModel.swift: open()/close()
    // Window frame NEVER changes, only content animates via CSS
    expand(): void {
      isExpanded = true;
      notifyStateChanged(true);
    },

    collapse(): void {
      isExpanded = false;
      notifyStateChanged(false);
    },

    isVisible(): boolean {
      return widgetWindow !== null && !widgetWindow.isDestroyed() && widgetWindow.isVisible();
    },

    destroy(): void {
      if (widgetWindow && !widgetWindow.isDestroyed()) {
        widgetWindow.close();
      }
    },

    getWindow(): BrowserWindow | null {
      return widgetWindow && !widgetWindow.isDestroyed() ? widgetWindow : null;
    },
  };

  return controller;
}
