import path from 'node:path';
import { BrowserWindow, ipcMain, screen } from 'electron';

import type {
  CapsuleState,
  DesktopMuseCapsuleSettings,
  DockEdge,
} from '../shared/capsuleSettings';
import { CAPSULE_SIZE_DIMS } from '../shared/capsuleSettings';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const EXPANDED_WIDTH = 360;
const EXPANDED_MIN_HEIGHT = 420;
const EXPANDED_MAX_HEIGHT = 560;
const WINDOW_PADDING = 24; // Extra space for hover scale + shadow
const EDGE_THRESHOLD = 20; // px from screen edge to trigger auto-dock

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface CapsuleControllerOptions {
  preloadPath: string;
  rendererFilePath: string;
  rendererDevUrl?: string;
  isDev: boolean;
  initialSettings?: DesktopMuseCapsuleSettings;
}

export interface CapsuleController {
  show: () => void;
  hide: () => void;
  toggle: () => void;
  expand: () => void;
  collapse: () => void;
  getState: () => CapsuleState;
  setState: (newState: CapsuleState) => void;
  destroy: () => void;
  getWindow: () => BrowserWindow | null;
  updateSettings: (settings: DesktopMuseCapsuleSettings) => void;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getDefaultPosition(
  settings: DesktopMuseCapsuleSettings,
): { x: number; y: number } {
  const { width: screenWidth, height: screenHeight } =
    screen.getPrimaryDisplay().workAreaSize;
  const dims = CAPSULE_SIZE_DIMS[settings.appearance.size];

  // If user chose "remember-last" and we have a saved position, use it
  if (
    settings.placement.defaultPosition === 'remember-last' &&
    settings.placement.lastPosition
  ) {
    return {
      x: settings.placement.lastPosition.x,
      y: settings.placement.lastPosition.y,
    };
  }

  const pad = 16;
  switch (settings.placement.defaultPosition) {
    case 'right-center':
      return {
        x: screenWidth - dims.width - pad,
        y: Math.round((screenHeight - dims.height) / 2),
      };
    case 'right-bottom':
      return {
        x: screenWidth - dims.width - pad,
        y: screenHeight - dims.height - pad - 80,
      };
    case 'left-center':
      return { x: pad, y: Math.round((screenHeight - dims.height) / 2) };
    case 'left-bottom':
      return {
        x: pad,
        y: screenHeight - dims.height - pad - 80,
      };
    case 'bottom-center':
      return {
        x: Math.round((screenWidth - dims.width) / 2),
        y: screenHeight - dims.height - pad,
      };
    default:
      return {
        x: screenWidth - dims.width - pad,
        y: Math.round((screenHeight - dims.height) / 2),
      };
  }
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

export function createCapsuleController(
  options: CapsuleControllerOptions,
): CapsuleController {
  let capsuleWindow: BrowserWindow | null = null;
  let currentState: CapsuleState = 'hidden_disabled';
  let capsuleSettings: DesktopMuseCapsuleSettings | null =
    options.initialSettings ?? null;

  // Drag state
  let dragStartWinX = 0;
  let dragStartWinY = 0;

  // Position before expand (so we can restore after collapse)
  let collapsedBounds: { x: number; y: number; width: number; height: number } | null = null;

  // Docked edge
  let dockedEdge: DockEdge = null;

  // ── Notify renderer of state change ──
  function notifyStateChanged(state: CapsuleState): void {
    if (capsuleWindow && !capsuleWindow.isDestroyed()) {
      capsuleWindow.webContents.send('capsule:state-changed', {
        state,
        edge: dockedEdge ?? undefined,
      });
    }
  }

  // ── Notify renderer of settings update ──
  function notifySettingsUpdated(settings: DesktopMuseCapsuleSettings): void {
    if (capsuleWindow && !capsuleWindow.isDestroyed()) {
      capsuleWindow.webContents.send('capsule:settings-updated', settings);
    }
  }

  // ── Get collapsed window dimensions based on settings ──
  function getCollapsedDims(): { width: number; height: number } {
    const size = capsuleSettings?.appearance.size ?? 'medium';
    return CAPSULE_SIZE_DIMS[size];
  }

  // ── Create window ──
  function createWindow(): BrowserWindow {
    const dims = getCollapsedDims();
    const pos = capsuleSettings
      ? getDefaultPosition(capsuleSettings)
      : { x: 0, y: 0 };

    const win = new BrowserWindow({
      width: dims.width + WINDOW_PADDING,
      height: dims.height + WINDOW_PADDING,
      x: pos.x,
      y: pos.y,
      transparent: true,
      frame: false,
      alwaysOnTop: true,
      skipTaskbar: true,
      hasShadow: false,
      resizable: false,
      movable: false, // We handle dragging ourselves via setBounds
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      show: false,
      backgroundColor: '#00000000',
      webPreferences: {
        preload: options.preloadPath,
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
        backgroundThrottling: false,
      },
    });

    // ── Safety net: force transparent background ──
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

    // ── Load dedicated capsule.html (both dev and production) ──
    // capsule.html does NOT import global styles.css, ensuring transparent background
    if (options.isDev && options.rendererDevUrl) {
      // Dev: load capsule.html via dev server (e.g. http://localhost:5173/capsule.html)
      const baseUrl = options.rendererDevUrl.replace(/\/$/, '');
      win.loadURL(baseUrl + '/capsule.html');
    } else {
      // Production: load capsule.html from built files
      const capsuleHtml = path.join(
        path.dirname(options.rendererFilePath),
        'capsule.html',
      );
      win.loadFile(capsuleHtml);
    }

    win.once('ready-to-show', () => {
      win.show();
    });

    // ── Auto-collapse on blur (click outside panel) ──
    win.on('blur', () => {
      // Only auto-collapse if currently expanded and setting is enabled
      if (
        currentState === 'expanded' &&
        capsuleSettings?.interaction.autoCollapseOnBlur
      ) {
        // Small delay to allow click events on the panel to process first
        setTimeout(() => {
          if (currentState === 'expanded') {
            controller.collapse();
          }
        }, 150);
      }
    });

    // ── IPC: capsule:toggle ──
    const toggleHandler = () => {
      controller.toggle();
    };
    ipcMain.on('capsule:toggle', toggleHandler);

    // ── IPC: capsule:expand ──
    const expandHandler = () => {
      controller.expand();
    };
    ipcMain.on('capsule:expand', expandHandler);

    // ── IPC: capsule:collapse ──
    const collapseHandler = () => {
      controller.collapse();
    };
    ipcMain.on('capsule:collapse', collapseHandler);

    // ── IPC: capsule:start-drag ──
    const startDragHandler = (
      _event: Electron.IpcMainEvent,
      screenX: number,
      screenY: number,
    ) => {
      if (!win || win.isDestroyed()) return;
      const bounds = win.getBounds();
      dragStartWinX = bounds.x;
      dragStartWinY = bounds.y;
    };
    ipcMain.on('capsule:start-drag', startDragHandler);

    // ── IPC: capsule:drag-move ──
    const dragMoveHandler = (
      _event: Electron.IpcMainEvent,
      deltaX: number,
      deltaY: number,
    ) => {
      if (!win || win.isDestroyed()) return;

      const newX = dragStartWinX + deltaX;
      const newY = dragStartWinY + deltaY;
      const bounds = win.getBounds();

      win.setBounds({
        x: Math.round(newX),
        y: Math.round(newY),
        width: bounds.width,
        height: bounds.height,
      });
    };
    ipcMain.on('capsule:drag-move', dragMoveHandler);

    // ── IPC: capsule:end-drag ──
    const endDragHandler = () => {
      // Save position for "remember-last"
      if (capsuleWindow && !capsuleWindow.isDestroyed() && capsuleSettings) {
        const bounds = capsuleWindow.getBounds();
        capsuleSettings.placement.lastPosition = {
          screenId: String(screen.getPrimaryDisplay().id),
          x: bounds.x,
          y: bounds.y,
          dockedEdge: dockedEdge,
        };
      }
    };
    ipcMain.on('capsule:end-drag', endDragHandler);

    // ── Cleanup on close ──
    win.on('closed', () => {
      ipcMain.removeListener('capsule:toggle', toggleHandler);
      ipcMain.removeListener('capsule:expand', expandHandler);
      ipcMain.removeListener('capsule:collapse', collapseHandler);
      ipcMain.removeListener('capsule:start-drag', startDragHandler);
      ipcMain.removeListener('capsule:drag-move', dragMoveHandler);
      ipcMain.removeListener('capsule:end-drag', endDragHandler);
      capsuleWindow = null;
      currentState = 'hidden_disabled';
    });

    capsuleWindow = win;
    return win;
  }

  // ── Dock to edge ──
  function dockToEdge(win: BrowserWindow, edge: 'left' | 'right' | 'bottom'): void {
    const { width: screenWidth, height: screenHeight } =
      screen.getPrimaryDisplay().workAreaSize;
    const bounds = win.getBounds();
    const visibleWidth = capsuleSettings?.placement.edgeVisibleWidth ?? 6;

    dockedEdge = edge;

    switch (edge) {
      case 'right':
        win.setBounds({
          x: screenWidth - visibleWidth,
          y: bounds.y,
          width: bounds.width,
          height: bounds.height,
        });
        break;
      case 'left':
        win.setBounds({
          x: -(bounds.width - visibleWidth),
          y: bounds.y,
          width: bounds.width,
          height: bounds.height,
        });
        break;
      case 'bottom':
        win.setBounds({
          x: bounds.x,
          y: screenHeight - visibleWidth,
          width: bounds.width,
          height: bounds.height,
        });
        break;
    }

    setState('edge_hidden');
  }

  // ── Ensure window exists ──
  function ensureWindow(): BrowserWindow {
    if (!capsuleWindow || capsuleWindow.isDestroyed()) {
      createWindow();
    }
    return capsuleWindow!;
  }

  // ── Set state ──
  function setState(newState: CapsuleState): void {
    const prev = currentState;
    currentState = newState;
    if (prev !== newState) {
      notifyStateChanged(newState);
    }
  }

  // ── Controller ──
  const controller: CapsuleController = {
    show(): void {
      const win = ensureWindow();
      const dims = getCollapsedDims();
      const pos = capsuleSettings
        ? getDefaultPosition(capsuleSettings)
        : { x: 0, y: 0 };

      // If currently expanded, keep expanded
      if (currentState === 'expanded') {
        win.setBounds({
          x: pos.x,
          y: pos.y,
          width: EXPANDED_WIDTH + WINDOW_PADDING,
          height: EXPANDED_MAX_HEIGHT + WINDOW_PADDING,
        });
      } else {
        win.setBounds({
          x: pos.x,
          y: pos.y,
          width: dims.width + WINDOW_PADDING,
          height: dims.height + WINDOW_PADDING,
        });
      }

      win.show();
      const newState = capsuleSettings?.enabled ? 'visible_idle' : 'hidden_disabled';
      setState(newState);

      // Send initial state to renderer after a short delay to ensure DOM is ready
      setTimeout(() => {
        notifyStateChanged(newState);
      }, 100);
    },

    hide(): void {
      if (capsuleWindow && !capsuleWindow.isDestroyed()) {
        capsuleWindow.hide();
      }
      setState('hidden_disabled');
    },

    toggle(): void {
      if (
        capsuleWindow &&
        !capsuleWindow.isDestroyed() &&
        capsuleWindow.isVisible()
      ) {
        this.hide();
      } else {
        this.show();
      }
    },

    expand(): void {
      const win = ensureWindow();
      const bounds = win.getBounds();

      // Save collapsed position for later restoration
      collapsedBounds = { ...bounds };

      // Calculate new position to keep on screen
      const { width: screenWidth, height: screenHeight } =
        screen.getPrimaryDisplay().workAreaSize;

      let newX = bounds.x;
      let newY = bounds.y;

      // Ensure expanded panel stays within screen bounds
      if (newX + EXPANDED_WIDTH + WINDOW_PADDING > screenWidth) {
        newX = screenWidth - EXPANDED_WIDTH - 20 - 8;
      }
      if (newX < 8) {
        newX = 8;
      }
      if (newY + EXPANDED_MAX_HEIGHT + WINDOW_PADDING > screenHeight) {
        newY = screenHeight - EXPANDED_MAX_HEIGHT - 20 - 8;
      }
      if (newY < 8) {
        newY = 8;
      }

      win.setBounds({
        x: Math.round(newX),
        y: Math.round(newY),
        width: EXPANDED_WIDTH + WINDOW_PADDING,
        height: EXPANDED_MAX_HEIGHT + WINDOW_PADDING,
      });

      setState('expanded');
    },

    collapse(): void {
      const win = ensureWindow();
      const dims = getCollapsedDims();

      // Restore collapsed position if we have one, otherwise use current
      if (collapsedBounds) {
        win.setBounds({
          x: collapsedBounds.x,
          y: collapsedBounds.y,
          width: dims.width + WINDOW_PADDING,
          height: dims.height + WINDOW_PADDING,
        });
        collapsedBounds = null;
      } else {
        const bounds = win.getBounds();
        win.setBounds({
          x: bounds.x,
          y: bounds.y,
          width: dims.width + WINDOW_PADDING,
          height: dims.height + WINDOW_PADDING,
        });
      }

      setState('visible_idle');
    },

    getState(): CapsuleState {
      return currentState;
    },

    setState(newState: CapsuleState): void {
      setState(newState);
    },

    destroy(): void {
      if (capsuleWindow && !capsuleWindow.isDestroyed()) {
        capsuleWindow.close();
      }
      capsuleWindow = null;
      currentState = 'hidden_disabled';
    },

    getWindow(): BrowserWindow | null {
      return capsuleWindow && !capsuleWindow.isDestroyed()
        ? capsuleWindow
        : null;
    },

    updateSettings(newSettings: DesktopMuseCapsuleSettings): void {
      capsuleSettings = newSettings;
      notifySettingsUpdated(newSettings);

      if (!newSettings.enabled && currentState !== 'hidden_disabled') {
        // Disabled → hide
        this.hide();
      } else if (newSettings.enabled && currentState === 'hidden_disabled') {
        // Re-enabled → show
        this.show();
      }
    },
  };

  return controller;
}
