/**
 * Page Smoke Tests — Phase 12.6
 *
 * Verifies that core page modules can be imported without errors.
 * Catches: broken imports, missing modules, syntax errors, circular dependencies.
 *
 * This is the minimal foundation. Full rendering tests (with @testing-library/react)
 * should be added later for deeper coverage.
 */
import { describe, it, expect } from 'vitest';

// Stub window.acmind so modules that reference it at import time don't crash.
const acmindStub: Record<string, unknown> = {
  app: {
    getPath: async () => '/tmp',
    getVersion: async () => '0.0.0',
    getPlatform: async () => 'darwin',
    getSystemInfo: async () => ({
      appVersion: '0.0.0',
      electronVersion: '0.0.0',
      chromeVersion: '0.0.0',
      nodeVersion: '0.0.0',
      osPlatform: 'darwin',
      osArch: 'arm64',
      osRelease: '24.0.0',
      storageRoot: '/tmp',
    }),
    openExternal: async () => {},
    openPath: async () => {},
  },
  onNavigate: () => () => {},
  onCapsuleExpand: () => () => {},
  onCapsuleCollapse: () => () => {},
  capsule: { getSettings: async () => ({}), setMode: async () => {}, move: async () => {} },
  ai: {
    getTask: async () => null,
    cancelTask: async () => {},
    onTaskUpdate: () => () => {},
    onLiveActivity: () => () => {},
    getTasksBySourceItem: async () => [],
    setLiveActivityEnabled: async () => ({}),
    isLiveActivityEnabled: async () => false,
  },
  voice: {
    importAudio: async () => ({}),
    importAudioBuffer: async () => ({}),
    startWatch: async () => ({}),
    stopWatch: async () => {},
    getWatchState: async () => ({ isWatching: false }),
    retryTranscription: async () => ({}),
    getTranscriptionStatus: async () => ({}),
  },
  settings: {
    get: async () => ({}),
    set: async () => ({}),
    onSettingsChanged: () => () => {},
  },
  onboarding: { isCompleted: async () => true, setCompleted: async () => {} },
  diagnostics: { export: async () => ({ success: true, filePath: '/tmp/diag.json' }) },
  logger: { getLevel: async () => 'info', setLevel: async (l: string) => l, read: async () => [] },
};

// Install stub globally before any module imports.
(globalThis as Record<string, unknown>).acmind = acmindStub;

// Also provide window for browser-like access patterns.
if (typeof globalThis.window === 'undefined') {
  (globalThis as Record<string, unknown>).window = globalThis;
}
(globalThis.window as Record<string, unknown>).acmind = acmindStub;

const pageModules = [
  { name: 'DailyKnowledgeFlowPage', loader: () => import('../pages/daily-flow/DailyKnowledgeFlowPage') },
  { name: 'SettingsPage', loader: () => import('../pages/settings/SettingsPage') },
  { name: 'DistillPage', loader: () => import('../pages/distill/DistillPage') },
  { name: 'ExportPage', loader: () => import('../pages/export/ExportPage') },
  { name: 'SearchPage', loader: () => import('../pages/search/index') },
  { name: 'ProcessingHistoryPage', loader: () => import('../pages/history/ProcessingHistoryPage') },
  { name: 'AIPage', loader: () => import('../pages/ai/AIPage') },
  { name: 'ErrorReviewPage', loader: () => import('../pages/errors/ErrorReviewPage') },
  { name: 'CapturePage', loader: () => import('../pages/capture/CapturePage') },
  { name: 'ImportPage', loader: () => import('../pages/import/ImportPage') },
];

describe('Page module smoke tests', () => {
  for (const { name, loader } of pageModules) {
    it(`${name} — module loads without error`, async () => {
      const mod = await loader();
      expect(mod).toBeDefined();
      // Verify the module exports something (default or named).
      const hasExport = mod.default !== undefined || Object.keys(mod).length > 0;
      expect(hasExport).toBe(true);
    });
  }
});
