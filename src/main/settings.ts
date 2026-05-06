import os from 'node:os';
import path from 'node:path';
import type { AppSettings, ExternalProcessorSettings } from '../shared/types';
import { DEFAULT_SETTINGS } from '../shared/defaultSettings';
import { DEFAULT_USER_PROFILE, DEFAULT_USER_PREFERENCES, DEFAULT_MODEL_STRATEGY_SETTINGS } from '../shared/types';
import { DEFAULT_DICTATION_SETTINGS } from '../shared/types';
import { mergeCapsuleSettings } from '../shared/capsuleSettings';
import { storage } from './storage';
import { logger } from './logger';

// ---------------------------------------------------------------------------
// Settings key for SQLite storage
// ---------------------------------------------------------------------------

const SETTINGS_KEY = 'app_settings';

export function resolveStorageRoot(root: string): string {
  if (root.startsWith('~/')) {
    return path.join(os.homedir(), root.slice(2));
  }
  return root;
}

// ---------------------------------------------------------------------------
// SettingsService
// ---------------------------------------------------------------------------

class SettingsService {
  private cachedSettings: AppSettings | null = null;

  /**
   * Load settings from SQLite, merging with defaults.
   * Returns the cached settings if already loaded.
   */
  load(): AppSettings {
    if (this.cachedSettings) {
      return this.cachedSettings;
    }

    try {
      const raw = storage.getSetting(SETTINGS_KEY);
      if (raw) {
        const parsed = this.migrateLegacyIdentifiers(JSON.parse(raw) as Partial<AppSettings>);
        this.cachedSettings = this.mergeWithDefaults(parsed);
        logger.info('app', 'settings', 'load', 'Settings loaded from storage');
      } else {
        this.cachedSettings = { ...DEFAULT_SETTINGS };
        this.persist();
        logger.info('app', 'settings', 'load', 'Default settings created');
      }
    } catch (error) {
      logger.error(
        'error',
        'settings',
        'load',
        'Failed to load settings, using defaults',
        { error: error instanceof Error ? error.message : String(error) },
      );
      this.cachedSettings = { ...DEFAULT_SETTINGS };
    }

    return this.cachedSettings;
  }

  /**
   * Update settings with a partial patch.
   * Persists the merged result to SQLite.
   */
  update(patch: Partial<AppSettings>): AppSettings {
    const current = this.load();
    const mergedPreferences = patch.preferences
      ? {
          ...current.preferences,
          ...patch.preferences,
          defaultStartPage: patch.preferences.defaultStartPage === 'dashboard'
            ? 'daily-flow'
            : patch.preferences.defaultStartPage ?? current.preferences.defaultStartPage,
        }
      : current.preferences;

    const merged: AppSettings = {
      ...current,
      ...patch,
      // Deep merge nested objects
      vault: patch.vault ? { ...current.vault, ...patch.vault } : current.vault,
      providers: patch.providers !== undefined ? patch.providers : current.providers,
      capsule: patch.capsule ? mergeCapsuleSettings(patch.capsule) : current.capsule,
      profile: patch.profile ? { ...current.profile, ...patch.profile } : current.profile,
      preferences: mergedPreferences,
      dictation: patch.dictation
        ? { ...(current.dictation ?? DEFAULT_DICTATION_SETTINGS), ...patch.dictation }
        : current.dictation,
      transcription: patch.transcription
        ? { ...current.transcription, ...patch.transcription }
        : current.transcription,
      externalProcessor: patch.externalProcessor ? { ...current.externalProcessor, ...patch.externalProcessor } : current.externalProcessor,
    };

    this.cachedSettings = merged;
    this.persist();

    logger.info('app', 'settings', 'update', 'Settings updated', {
      keys: Object.keys(patch).join(', '),
    });

    return merged;
  }

  /**
   * Get the storage root directory path.
   */
  getStorageRoot(): string {
    return resolveStorageRoot(this.load().storageRoot);
  }

  /**
   * Get default settings (for reference).
   */
  getDefaults(): AppSettings {
    return { ...DEFAULT_SETTINGS };
  }

  /**
   * Get external processor settings.
   */
  getExternalProcessorSettings(): ExternalProcessorSettings {
    return this.load().externalProcessor ?? DEFAULT_SETTINGS.externalProcessor;
  }

  /** @deprecated Use getExternalProcessorSettings */
  getVaultKeeperSettings(): ExternalProcessorSettings {
    return this.getExternalProcessorSettings();
  }

  /**
   * Migrate legacy pinmind-* identifiers to acmind-* equivalents.
   */
  private migrateLegacyIdentifiers(partial: Partial<AppSettings>): Partial<AppSettings> {
    let result = partial;

    // Migrate legacy 'pinmind-inbox' → 'acmind-inbox' in capsule settings
    const dest = partial.capsule?.quickCapture?.defaultDestination as string | undefined;
    if (dest === 'pinmind-inbox') {
      result = {
        ...result,
        capsule: {
          ...result.capsule,
          quickCapture: { ...result.capsule!.quickCapture!, defaultDestination: 'acmind-inbox' },
        } as AppSettings['capsule'],
      };
    }

    // Migrate legacy 'vaultkeeper' → 'externalProcessor' in settings
    const legacy = (partial as Record<string, unknown>).vaultkeeper as Record<string, unknown> | undefined;
    if (legacy && !partial.externalProcessor) {
      const { vaultkeeper: _vk, ...rest } = result as Record<string, unknown>;
      result = {
        ...rest,
        externalProcessor: legacy,
      } as unknown as Partial<AppSettings>;
    }

    return result;
  }

  /**
   * Merge a partial settings object with defaults.
   */
  private mergeWithDefaults(partial: Partial<AppSettings>): AppSettings {
    const preferences = partial.preferences
      ? {
          ...DEFAULT_USER_PREFERENCES,
          ...partial.preferences,
          defaultStartPage: partial.preferences.defaultStartPage === 'dashboard'
            ? 'daily-flow'
            : partial.preferences.defaultStartPage ?? DEFAULT_USER_PREFERENCES.defaultStartPage,
        }
      : DEFAULT_USER_PREFERENCES;

    return {
      storageRoot: partial.storageRoot ?? DEFAULT_SETTINGS.storageRoot,
      pollIntervalMs: partial.pollIntervalMs ?? DEFAULT_SETTINGS.pollIntervalMs,
      autoCapture: partial.autoCapture ?? DEFAULT_SETTINGS.autoCapture,
      hasCompletedOnboarding: partial.hasCompletedOnboarding ?? DEFAULT_SETTINGS.hasCompletedOnboarding,
      screenshotShortcut: partial.screenshotShortcut ?? DEFAULT_SETTINGS.screenshotShortcut,
      dashboardShortcut: partial.dashboardShortcut ?? DEFAULT_SETTINGS.dashboardShortcut,
      launchAtLogin: partial.launchAtLogin ?? DEFAULT_SETTINGS.launchAtLogin,
      providers: partial.providers ?? DEFAULT_SETTINGS.providers,
      defaultTier: partial.defaultTier ?? DEFAULT_SETTINGS.defaultTier,
      vault: {
        ...DEFAULT_SETTINGS.vault,
        ...(partial.vault ?? {}),
      },
      logLevel: partial.logLevel ?? DEFAULT_SETTINGS.logLevel,
      scopeMode: partial.scopeMode ?? DEFAULT_SETTINGS.scopeMode,
      scopedApps: partial.scopedApps ?? DEFAULT_SETTINGS.scopedApps,
      showFloatingButton: partial.showFloatingButton ?? DEFAULT_SETTINGS.showFloatingButton,
      capsule: partial.capsule ? mergeCapsuleSettings(partial.capsule) : DEFAULT_SETTINGS.capsule,
      minimizeToTray: partial.minimizeToTray ?? DEFAULT_SETTINGS.minimizeToTray,
      backgroundClipboard: partial.backgroundClipboard ?? DEFAULT_SETTINGS.backgroundClipboard,
      showCaptureToast: partial.showCaptureToast ?? DEFAULT_SETTINGS.showCaptureToast,
      autoAiProcess: partial.autoAiProcess ?? DEFAULT_SETTINGS.autoAiProcess,
      autoExportObsidian: partial.autoExportObsidian ?? DEFAULT_SETTINGS.autoExportObsidian,
      profile: { ...DEFAULT_USER_PROFILE, ...(partial.profile ?? {}) },
      preferences,
      modelStrategy: { ...DEFAULT_MODEL_STRATEGY_SETTINGS, ...(partial.modelStrategy ?? {}) },
      externalProcessor: { ...DEFAULT_SETTINGS.externalProcessor, ...(partial.externalProcessor ?? {}) },
      transcription: { ...DEFAULT_SETTINGS.transcription, ...(partial.transcription ?? {}) },
      voiceWatchEnabled: partial.voiceWatchEnabled ?? DEFAULT_SETTINGS.voiceWatchEnabled,
      voiceWatchFolderPath: partial.voiceWatchFolderPath ?? DEFAULT_SETTINGS.voiceWatchFolderPath,
      voiceAutoImportEnabled: partial.voiceAutoImportEnabled ?? DEFAULT_SETTINGS.voiceAutoImportEnabled,
      voiceSupportedExtensions: partial.voiceSupportedExtensions ?? DEFAULT_SETTINGS.voiceSupportedExtensions,
      voiceImportDelayMs: partial.voiceImportDelayMs ?? DEFAULT_SETTINGS.voiceImportDelayMs,
      voiceDedupEnabled: partial.voiceDedupEnabled ?? DEFAULT_SETTINGS.voiceDedupEnabled,
      dashboardWidget: partial.dashboardWidget ?? DEFAULT_SETTINGS.dashboardWidget,
      dictation: partial.dictation
        ? { ...DEFAULT_DICTATION_SETTINGS, ...partial.dictation }
        : DEFAULT_DICTATION_SETTINGS,
      agentChat: { ...DEFAULT_SETTINGS.agentChat, ...(partial.agentChat ?? {}) },
    };
  }

  /**
   * Persist current cached settings to SQLite.
   */
  private persist(): void {
    if (!this.cachedSettings) return;
    if (!storage.isInitialized()) return;
    storage.setSetting(SETTINGS_KEY, JSON.stringify(this.cachedSettings));
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const settings = new SettingsService();
