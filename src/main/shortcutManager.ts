import { app, globalShortcut } from 'electron';
import type { AppSettings } from '../shared/types';
import { logger } from './logger';

// ---------------------------------------------------------------------------
// ShortcutManager
// ---------------------------------------------------------------------------

export interface ShortcutManagerOptions {
  onScreenshot: () => void;
  onToggleDashboard: () => void;
}

export interface ShortcutRegistrationStatus {
  screenshotShortcut: string;
  dashboardShortcut: string;
  captureHubShortcut: string;
  modeToggleShortcut: string;
  trayOpenDashboardShortcut: string;
  trayCycleModeShortcut: string;
  trayQuitShortcut: string;
  screenshotRegistered: boolean;
  dashboardRegistered: boolean;
  captureHubRegistered: boolean;
  modeToggleRegistered: boolean;
  trayOpenDashboardRegistered: boolean;
  trayCycleModeRegistered: boolean;
  trayQuitRegistered: boolean;
}

const DEFAULT_SHORTCUT_STATUS: ShortcutRegistrationStatus = {
  screenshotShortcut: '',
  dashboardShortcut: '',
  captureHubShortcut: '',
  modeToggleShortcut: '',
  trayOpenDashboardShortcut: '',
  trayCycleModeShortcut: '',
  trayQuitShortcut: '',
  screenshotRegistered: true,
  dashboardRegistered: true,
  captureHubRegistered: true,
  modeToggleRegistered: true,
  trayOpenDashboardRegistered: true,
  trayCycleModeRegistered: true,
  trayQuitRegistered: true,
};

class ShortcutManager {
  private options: ShortcutManagerOptions | null = null;
  private registered = false;
  private status: ShortcutRegistrationStatus = { ...DEFAULT_SHORTCUT_STATUS };

  /**
   * Register global shortcuts.
   */
  register(options: ShortcutManagerOptions, settings?: Pick<AppSettings, 'screenshotShortcut' | 'dashboardShortcut'>): void {
    if (!app.isReady()) {
      logger.warn('app', 'shortcutManager', 'register', 'Cannot register shortcuts before app is ready');
      return;
    }

    // Unregister any existing shortcuts first
    this.unregister();

    this.options = options;
    const screenshotShortcut = settings?.screenshotShortcut ?? 'Cmd+Shift+1';
    const dashboardShortcut = settings?.dashboardShortcut ?? 'Cmd+Shift+Space';

    // Screenshot shortcut
    const screenshotOk = globalShortcut.register(screenshotShortcut, () => {
      logger.info('app', 'shortcutManager', 'screenshot', 'Screenshot shortcut triggered (Phase 1: log only)');
      options.onScreenshot();
    });

    // Dashboard shortcut
    const dashboardOk = globalShortcut.register(dashboardShortcut, () => {
      logger.info('app', 'shortcutManager', 'dashboard', 'Dashboard shortcut triggered');
      options.onToggleDashboard();
    });

    this.registered = true;
    this.status = {
      ...DEFAULT_SHORTCUT_STATUS,
      screenshotShortcut,
      dashboardShortcut,
      screenshotRegistered: screenshotOk,
      dashboardRegistered: dashboardOk,
    };

    logger.info('app', 'shortcutManager', 'register', 'Global shortcuts registered', {
      screenshot: { accelerator: screenshotShortcut, registered: screenshotOk },
      dashboard: { accelerator: dashboardShortcut, registered: dashboardOk },
    });

    if (!screenshotOk) {
      logger.warn('error', 'shortcutManager', 'register', `Failed to register screenshot shortcut: ${screenshotShortcut}`);
    }
    if (!dashboardOk) {
      logger.warn('error', 'shortcutManager', 'register', `Failed to register dashboard shortcut: ${dashboardShortcut}`);
    }
  }

  /**
   * Unregister all global shortcuts.
   */
  unregister(): void {
    if (this.registered) {
      globalShortcut.unregisterAll();
      this.registered = false;
      this.options = null;
      this.status = { ...DEFAULT_SHORTCUT_STATUS };
      logger.info('app', 'shortcutManager', 'unregister', 'Global shortcuts unregistered');
    }
  }

  getRegistrationStatus(): ShortcutRegistrationStatus {
    return { ...this.status };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const shortcutManager = new ShortcutManager();
