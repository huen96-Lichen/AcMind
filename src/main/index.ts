import path from 'node:path';
import os from 'node:os';
import { app, BrowserWindow } from 'electron';
import type { App as ElectronApp } from 'electron';

import { DEFAULT_SETTINGS } from '../shared/defaultSettings';
import { DEFAULT_DICTATION_SETTINGS } from '../shared/types';
import { logger } from './logger';
import { storage } from './storage';
import { errorService } from './errorService';
import { resolveStorageRoot, settings } from './settings';
import { registerIpcHandlers } from './ipc';
import { createTrayController } from './tray';
import { shortcutManager } from './shortcutManager';
import { createPermissionCoordinator, type PermissionCoordinator } from './permissionCoordinator';
import { createDashboardWindowController } from './dashboardWindowController';
import { createCapsuleController } from './capsuleController';
import { createWidgetWindowController } from './widgetWindowController';
import { createDictationWindowController } from './dictationWindowController';
import { dictationCoordinator } from './voice/coordinator';
import { captureService } from './captureService';
import { captureRegistry } from './services/capture';
import {
  manualTextAdapter,
  clipboardTextAdapter,
  screenshotAdapter,
  webpageAdapter,
  fileAdapter,
  imageAdapter,
  audioAdapter,
  videoAdapter,
} from './services/capture';
import { distillPipeline } from './services/distiller/distillPipeline';
import { taskQueue } from './services/aiHub/taskQueue';
import { schedulerService } from './services/scheduler/schedulerService';
import { outputSpecService } from './services/outputSpec';
import { initAutoUpdater } from './autoUpdater';
import { voiceDictionaryStore } from './voice';

// ---------------------------------------------------------------------------
// Process crash recovery
// ---------------------------------------------------------------------------

process.on('uncaughtException', (error) => {
  console.error('[FATAL] Uncaught exception:', error);
  logger.error('error', 'process', 'uncaughtException', 'Uncaught exception', {
    error: error.message,
    stack: error.stack,
  });
});

process.on('unhandledRejection', (reason) => {
  console.error('[FATAL] Unhandled rejection:', reason);
  logger.error('error', 'process', 'unhandledRejection', 'Unhandled promise rejection', {
    reason: reason instanceof Error ? reason.message : String(reason),
    stack: reason instanceof Error ? reason.stack : undefined,
  });
});

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const appWithState = app as ElectronApp & { isQuitting?: boolean };
const APP_DISPLAY_NAME = 'AcMind';

const isDev = Boolean(process.env.VITE_DEV_SERVER_URL);
const preloadPath = path.join(__dirname, '../preload/index.cjs');
const rendererFilePath = path.join(__dirname, '../renderer/index.html');
const rendererDevUrl = process.env.VITE_DEV_SERVER_URL;

// ---------------------------------------------------------------------------
// Module-level references
// ---------------------------------------------------------------------------

let dashboardController: ReturnType<typeof createDashboardWindowController> | null = null;
let capsuleController: ReturnType<typeof createCapsuleController> | null = null;
let widgetController: ReturnType<typeof createWidgetWindowController> | null = null;
let dictationController: ReturnType<typeof createDictationWindowController> | null = null;
let permissionCoordinator: PermissionCoordinator | null = null;
let lastVoiceInputTriggerAt = 0;

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

async function bootstrap(): Promise<void> {
  logger.info('app', 'bootstrap', 'start', 'AcMind starting...');

  // 1. Resolve the default storage root before SQLite is available.
  const storageRoot = resolveStorageRoot(DEFAULT_SETTINGS.storageRoot);

  // Ensure storageRoot directory exists
  const { mkdirSync } = await import('node:fs');
  mkdirSync(storageRoot, { recursive: true });

  // 2. Initialize logger
  const logDir = path.join(storageRoot, 'logs');
  logger.init(logDir);

  logger.info('app', 'bootstrap', 'settings', 'Settings loaded', {
    storageRoot,
    isDev,
  });

  // 2b. Configure Content-Security-Policy
  const { session } = await import('electron');
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    const csp = isDev
      ? "default-src 'self' http://localhost:* ws://localhost:* 'unsafe-inline' 'unsafe-eval'; img-src 'self' data: blob: https:; connect-src 'self' http://localhost:* ws://localhost:* https:; style-src 'self' 'unsafe-inline';"
      : "default-src 'self'; img-src 'self' data: blob:; connect-src 'self' https:; style-src 'self' 'unsafe-inline';";
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [csp],
      },
    });
  });

  // 3. Initialize storage (SQLite)
  try {
    storage.init(storageRoot);
    voiceDictionaryStore.init(storageRoot);
    // 3a. Initialize error service with the database instance
    const db = storage.getDb();
    if (db) {
      errorService.init(db);
    }
  } catch (error) {
    logger.error('error', 'bootstrap', 'storage', 'Storage initialization failed', {
      error: error instanceof Error ? error.message : String(error),
    });
  }

  // 3b. Initialize OutputSpecService (template pack)
  try {
    // Spec pack path: look for acmind_output_spec_pack in the app resources directory
    // In development, it's at the project root; in production, it's in the app bundle
    const specPackCandidates = [
      path.join(app.getAppPath(), 'acmind_output_spec_pack'),
      path.resolve(process.cwd(), 'acmind_output_spec_pack'),
    ];
    const specPackPath = specPackCandidates.find((p) => {
      const { existsSync } = require('node:fs');
      return existsSync(p);
    });
    if (specPackPath) {
      outputSpecService.init(specPackPath);
    } else {
      // Initialize with fallback defaults
      outputSpecService.init('');
    }
    logger.info('app', 'bootstrap', 'outputSpec', 'OutputSpecService initialized', {
      specPackPath: specPackPath ?? '(fallback defaults)',
    });
  } catch (error) {
    logger.error('error', 'bootstrap', 'outputSpec', 'OutputSpecService initialization failed', {
      error: error instanceof Error ? error.message : String(error),
    });
  }

  // 4. Load settings now that storage is available.
  const currentSettings = settings.load();

  // 5. Register capture adapters (unified capture architecture)
  captureRegistry.register(manualTextAdapter);
  captureRegistry.register(clipboardTextAdapter);
  captureRegistry.register(screenshotAdapter);
  captureRegistry.register(webpageAdapter);
  captureRegistry.register(fileAdapter);
  captureRegistry.register(imageAdapter);
  captureRegistry.register(audioAdapter);
  captureRegistry.register(videoAdapter);
  logger.info('app', 'bootstrap', 'captureAdapters', 'Capture adapters registered', {
    types: captureRegistry.getAvailableTypes(),
  });

  // 6. Initialize capture service (starts clipboard watcher)
  try {
    captureService.init();
  } catch (error) {
    logger.error('error', 'bootstrap', 'captureService', 'Capture service initialization failed', {
      error: error instanceof Error ? error.message : String(error),
    });
  }

  // 5b. Initialize AI subsystem (distillation pipeline + task queue)
  try {
    distillPipeline.init();

    // Forward task status changes to renderer via IPC
    taskQueue.onStatusChange(async (task) => {
      const { BrowserWindow } = await import('electron');
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send('aiTasks.statusChanged', task);
        }
      }
    });

    logger.info('app', 'bootstrap', 'aiSubsystem', 'AI subsystem initialized');
  } catch (error) {
    logger.error('error', 'bootstrap', 'aiSubsystem', 'AI subsystem initialization failed', {
      error: error instanceof Error ? error.message : String(error),
    });
  }

  // 5c. Initialize scheduler (automated tasks)
  try {
    schedulerService.init();
    logger.info('app', 'bootstrap', 'scheduler', 'Scheduler initialized');
  } catch (error) {
    logger.error('error', 'bootstrap', 'scheduler', 'Scheduler initialization failed', {
      error: error instanceof Error ? error.message : String(error),
    });
  }

  // 6. Create permission coordinator
  permissionCoordinator = createPermissionCoordinator({
    getShortcutRegistrationStatus: () => shortcutManager.getRegistrationStatus(),
    getPermissionAppMeta: () => ({
      appName: APP_DISPLAY_NAME,
      executablePath: app.getPath('exe'),
      appPath: app.getAppPath(),
      bundleId: 'com.acore.acmind',
      isDev,
      isPackaged: app.isPackaged,
    }),
    onSnapshotUpdated: (snapshot, meta) => {
      for (const win of BrowserWindow.getAllWindows()) {
        if (!win.isDestroyed()) {
          win.webContents.send('permissions.statusUpdated', { snapshot, meta });
        }
      }
    },
  });

  // 7. Create dashboard window controller
  dashboardController = createDashboardWindowController({
    preloadPath,
    rendererFilePath,
    rendererDevUrl,
    isDev,
  });

  // 7b. Create capsule controller
  const initialSettings = currentSettings;
  capsuleController = createCapsuleController({
    preloadPath,
    rendererFilePath,
    rendererDevUrl,
    isDev,
    initialSettings: initialSettings.capsule,
  });

  // 7c. Create dashboard widget (floating pill) controller
  widgetController = createWidgetWindowController({
    preloadPath,
    rendererFilePath,
    rendererDevUrl,
    isDev,
  });

  // Show widget if enabled in settings
  if (currentSettings.dashboardWidget?.enabled) {
    widgetController.show();
  }

  // 7b. Create dictation capsule window (OpenLess-inspired)
  dictationController = createDictationWindowController({
    preloadPath,
    rendererFilePath,
    rendererDevUrl,
    isDev,
  });
  dictationCoordinator.setDictationWindow(dictationController.getWindow());

  // 8. Register IPC handlers
  await registerIpcHandlers({
    permissionCoordinator: permissionCoordinator!,
    capsuleController,
    widgetController,
  });

  // 9. Create system tray
  createTrayController({
    onToggleWindow: () => {
      dashboardController?.toggle();
    },
    onShowSettings: () => {
      dashboardController?.show();
    },
    onQuit: () => {
      app.quit();
    },
  });

  // 10. Register global shortcuts
  shortcutManager.register({
    onScreenshot: () => {
      void captureService.captureScreenshot();
    },
    onToggleDashboard: () => {
      dashboardController?.toggle();
    },
    onVoiceInput: () => {
      const now = Date.now();
      if (now - lastVoiceInputTriggerAt < 450) {
        logger.debug('app', 'bootstrap', 'voiceInput', 'Ignored duplicate voice input trigger');
        return;
      }
      lastVoiceInputTriggerAt = now;

      // OpenLess-inspired: toggle dictation on hotkey
      const s = settings.load();
      if (!s.dictation?.enabled) {
        settings.update({
          dictation: { ...(s.dictation ?? DEFAULT_DICTATION_SETTINGS), enabled: true },
        });
      }
      if (dictationCoordinator.getPhase() === 'idle') {
        dictationController?.show();
        void dictationCoordinator.beginSession();
      } else if (dictationCoordinator.getPhase() === 'listening') {
        void dictationCoordinator.endSession();
      }
    },
  }, currentSettings);

  // 11. Show dashboard window
  dashboardController.show();

  // 11b. Show capsule (respect user setting)
  if (initialSettings.capsule?.enabled) {
    capsuleController.show();
  } else {
    capsuleController.hide();
  }

  logger.info('app', 'bootstrap', 'complete', 'AcMind ready', {
    captureService: captureService.getClipboardStatus(),
  });

  // 12. Initialize auto-updater
  initAutoUpdater(isDev);
}

// ---------------------------------------------------------------------------
// App lifecycle events
// ---------------------------------------------------------------------------

// Single instance lock (skip in dev mode to allow hot-reload restarts)
const hasSingleInstanceLock = isDev || app.requestSingleInstanceLock();

if (!hasSingleInstanceLock) {
  logger.info('app', 'lifecycle', 'singleInstance', 'Another instance is running, quitting');
  app.quit();
}

app.on('second-instance', () => {
  // Another instance was launched — focus our window
  dashboardController?.show();
});

app.on('before-quit', () => {
  appWithState.isQuitting = true;
  logger.info('app', 'lifecycle', 'before-quit', 'AcMind shutting down');
  shortcutManager.unregister();
  captureService.stop();
});

app.on('window-all-closed', () => {
  // On macOS, keep app running if capsule window is still alive
  if (process.platform !== 'darwin' && !capsuleController?.getWindow()) {
    app.quit();
  }
});

app.on('activate', () => {
  // On macOS, re-create window when dock icon is clicked and no windows are open
  dashboardController?.show();
});

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

if (hasSingleInstanceLock) {
  app.whenReady().then(() => {
    bootstrap().catch((error) => {
      console.error('[bootstrap] Fatal error during startup', error);
    });
  });
}
