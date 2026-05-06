import { app, globalShortcut } from 'electron';
import type { AppSettings } from '../shared/types';
import { DEFAULT_CAPSULE_SETTINGS } from '../shared/capsuleSettings';
import { logger } from './logger';

// ---------------------------------------------------------------------------
// ShortcutManager
// ---------------------------------------------------------------------------

export interface ShortcutManagerOptions {
  onScreenshot: () => void;
  onToggleDashboard: () => void;
  onVoiceInput?: () => void;
}

export interface ShortcutRegistrationStatus {
  screenshotShortcut: string;
  dashboardShortcut: string;
  voiceInputShortcut: string;
  captureHubShortcut: string;
  modeToggleShortcut: string;
  trayOpenDashboardShortcut: string;
  trayCycleModeShortcut: string;
  trayQuitShortcut: string;
  screenshotRegistered: boolean;
  dashboardRegistered: boolean;
  voiceInputRegistered: boolean;
  captureHubRegistered: boolean;
  modeToggleRegistered: boolean;
  trayOpenDashboardRegistered: boolean;
  trayCycleModeRegistered: boolean;
  trayQuitRegistered: boolean;
}

const DEFAULT_SHORTCUT_STATUS: ShortcutRegistrationStatus = {
  screenshotShortcut: '',
  dashboardShortcut: '',
  voiceInputShortcut: '',
  captureHubShortcut: '',
  modeToggleShortcut: '',
  trayOpenDashboardShortcut: '',
  trayCycleModeShortcut: '',
  trayQuitShortcut: '',
  screenshotRegistered: true,
  dashboardRegistered: true,
  voiceInputRegistered: true,
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
  private pendingSettings: Pick<AppSettings, 'screenshotShortcut' | 'dashboardShortcut' | 'capsule'> | null = null;

  /**
   * Register global shortcuts.
   */
  register(options: ShortcutManagerOptions, settings?: Pick<AppSettings, 'screenshotShortcut' | 'dashboardShortcut' | 'capsule'>): void {
    if (!app.isReady()) {
      logger.warn('app', 'shortcutManager', 'register', 'Cannot register shortcuts before app is ready');
      return;
    }

    // Unregister any existing shortcuts first
    this.unregister();

    this.options = options;
    const effectiveSettings = this.pendingSettings ?? settings;
    this.pendingSettings = null;

    const screenshotShortcut = effectiveSettings?.screenshotShortcut ?? 'Cmd+Shift+1';
    const dashboardShortcut = effectiveSettings?.dashboardShortcut ?? 'Cmd+Shift+Space';

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

    // Voice input shortcut (Phase 6)
    const voiceInputShortcut = effectiveSettings?.capsule?.shortcuts?.voiceInput?.trim()
      || DEFAULT_CAPSULE_SETTINGS.shortcuts.voiceInput;
    let voiceInputOk = true;
    if (options.onVoiceInput) {
      voiceInputOk = globalShortcut.register(voiceInputShortcut, () => {
        logger.info('app', 'shortcutManager', 'voiceInput', 'Voice input shortcut triggered');
        options.onVoiceInput?.();
      });
    }

    this.registered = true;
    this.status = {
      ...DEFAULT_SHORTCUT_STATUS,
      screenshotShortcut,
      dashboardShortcut,
      voiceInputShortcut,
      screenshotRegistered: screenshotOk,
      dashboardRegistered: dashboardOk,
      voiceInputRegistered: voiceInputOk,
    };

    logger.info('app', 'shortcutManager', 'register', 'Global shortcuts registered', {
      screenshot: { accelerator: screenshotShortcut, registered: screenshotOk },
      dashboard: { accelerator: dashboardShortcut, registered: dashboardOk },
      voiceInput: { accelerator: voiceInputShortcut, registered: voiceInputOk },
    });

    if (!screenshotOk) {
      logger.warn('error', 'shortcutManager', 'register', `Failed to register screenshot shortcut: ${screenshotShortcut}`);
    }
    if (!dashboardOk) {
      logger.warn('error', 'shortcutManager', 'register', `Failed to register dashboard shortcut: ${dashboardShortcut}`);
    }
    if (!voiceInputOk) {
      logger.warn('error', 'shortcutManager', 'register', `Failed to register voice input shortcut: ${voiceInputShortcut}`);
    }
  }

  /**
   * Re-register shortcuts using the last registered callbacks.
   * Useful after settings change without needing a full app restart.
   */
  refresh(settings?: Pick<AppSettings, 'screenshotShortcut' | 'dashboardShortcut' | 'capsule'>): void {
    if (!this.options) {
      this.pendingSettings = settings ?? this.pendingSettings;
      logger.warn('app', 'shortcutManager', 'refresh', 'Shortcut refresh queued until initial registration');
      return;
    }

    this.register(this.options, settings);
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
