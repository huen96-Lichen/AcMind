import type { AppSettings } from './types';
import { DEFAULT_CAPSULE_SETTINGS } from './capsuleSettings';
import { DEFAULT_USER_PROFILE, DEFAULT_USER_PREFERENCES, DEFAULT_MODEL_STRATEGY_SETTINGS } from './types';
import { DEFAULT_OBSIDIAN_DOCUMENTS_ROOT } from './markdownSpec';

export const DEFAULT_SETTINGS: AppSettings = {
  storageRoot: '~/PinMind',
  pollIntervalMs: 500,
  autoCapture: true,
  hasCompletedOnboarding: false,
  screenshotShortcut: 'Cmd+Shift+1',
  dashboardShortcut: 'Cmd+Shift+Space',
  launchAtLogin: false,
  providers: [],
  defaultTier: 'local_light',
  vault: {
    vaultPath: DEFAULT_OBSIDIAN_DOCUMENTS_ROOT,
    defaultFolder: '00_Inbox/PinMind',
    template: '',
    pathRule: 'category_date',
    conflictStrategy: 'rename',
    autoFrontmatter: true,
    frontmatterTemplate: {}
  },
  logLevel: 'info',
  scopeMode: 'all',
  scopedApps: [],
  showFloatingButton: true,
  capsule: DEFAULT_CAPSULE_SETTINGS,
  minimizeToTray: false,
  backgroundClipboard: true,
  showCaptureToast: true,
  autoAiProcess: false,
  autoExportObsidian: false,
  profile: DEFAULT_USER_PROFILE,
  preferences: DEFAULT_USER_PREFERENCES,
  modelStrategy: DEFAULT_MODEL_STRATEGY_SETTINGS,
  vaultkeeper: {
    enabled: false,
    endpoint: '',
    timeout: 30000,
  },
  transcription: {
    provider: 'local',
    localEngine: 'whisper-ctranslate2',
    localModel: 'base',
    apiEndpoint: '',
    apiModel: 'whisper-1',
    apiLanguage: 'zh',
    apiTranslate: false,
    apiTimeoutMs: 30000,
  },
  // Phase 10: Voice workflow defaults
  voiceWatchEnabled: false,
  voiceWatchFolderPath: null,
  voiceAutoImportEnabled: true,
  voiceSupportedExtensions: ['.m4a', '.mp3', '.wav', '.aac'],
  voiceImportDelayMs: 3000,
  voiceDedupEnabled: true,
};
