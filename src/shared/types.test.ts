// PinMind Shared Types Unit Tests
// Tests for IPC_CHANNELS constant

import { describe, it, expect } from 'vitest';
import { IPC_CHANNELS } from './types';

describe('IPC_CHANNELS', () => {
  // -- Expected channel groups ----------------------------------------------

  const expectedPhase1 = [
    'settings.get',
    'settings.update',
    'app.getVersion',
    'app.openStorageRoot',
    'storage.getStats',
    'logger.getLevel',
    'logger.setLevel',
  ];

  const expectedPhase2 = [
    'sourceItems.list',
    'sourceItems.get',
    'sourceItems.getContent',
    'sourceItems.delete',
    'sourceItems.deleteBatch',
    'sourceItems.search',
    'sourceItems.createText',
    'sourceItems.ensureFromCapture',
    'sourceItems.getByCaptureItemId',
    'sourceItems.readImage',
    'records.changed',
    'capture.screenshot',
    'clipboard.getStatus',
    'clipboard.toggle',
  ];

  const expectedPhase3 = [
    'providers.list',
    'providers.add',
    'providers.update',
    'providers.delete',
    'providers.scanLocal',
    'providers.testConnection',
    'providers.changed',
    'aiTasks.list',
    'aiTasks.cancel',
    'aiTasks.retry',
    'aiTasks.pause',
    'aiTasks.resume',
    'aiTasks.isPaused',
    'aiTasks.statusChanged',
    'distill.run',
    'distill.runSingle',
    'logger.read',
  ];

  const expectedPhase4 = [
    'distill.batch',
    'distill.batchStatus',
    'distill.batchCancel',
    'distilledOutputs.list',
    'distilledOutputs.review',
    'knowledgeCards.list',
    'knowledgeCards.get',
    'knowledgeCards.getBySourceItemId',
    'knowledgeCards.upsertFromReview',
    'graph.get',
  ];

  const expectedPhase5 = [
    'vault.getConfig',
    'vault.updateConfig',
    'vault.validatePath',
    'vault.pickFolder',
    'export.single',
    'export.batch',
    'export.openFile',
    'export.revealInVault',
    'export.history',
    'export.retry',
    'template.preview',
  ];

  const expectedKnowledge = [
    'datasets.createSnapshot',
    'datasets.list',
    'datasets.get',
    'datasets.exportBundle',
    'trainingRuns.importResult',
    'trainingRuns.list',
    'modelVersions.list',
    'modelVersions.activate',
    'modelVersions.rollback',
  ];

  const expectedPhase6 = [
    'import.scan',
    'import.start',
    'import.status',
    'import.cancel',
    'import.history',
    'import.tasks.list',
    'import.task.changed',
  ];

  const expectedCaptureItems = [
    'captureItems.list',
    'captureItems.get',
    'captureItems.create',
    'captureItems.update',
    'captureItems.delete',
    'captureItems.exportMarkdown',
    'captureItems.readImage',
    'captureItems.changed',
  ];

  const expectedDistillLoop = [
    'distill.bridgeAndRun',
    'distill.bridgeAndRunBatch',
    'export.getWithLineage',
    'export.recordsWithLineage',
    'sourceItems.getDistillStatus',
  ];

  const expectedSearch = [
    'search.hybrid',
    'search.rebuildFts',
    'search.getStatus',
  ];

  const expectedParser = [
    'parser.importFile',
    'parser.importUrl',
    'parser.importBatch',
    'markitdown.convert',
    'markitdown.check',
  ];

  const expectedScheduler = [
    'scheduler.createTask',
    'scheduler.updateTask',
    'scheduler.deleteTask',
    'scheduler.toggleTask',
    'scheduler.getTasks',
    'scheduler.getTask',
    'scheduler.runNow',
  ];

  const expectedWhisper = [
    'whisper.getStatus',
    'whisper.getModels',
    'whisper.downloadModel',
    'whisper.deleteModel',
    'whisper.initialize',
    'whisper.transcribe',
    'whisper.downloadProgress',
  ];

  const expectedPolish = [
    'polish.text',
    'polish.getStyles',
  ];

  // V2.1: OutputSpec + Content Pipeline
  const expectedV21 = [
    'outputSpec.getInfo',
    'outputSpec.getActiveProfile',
    'outputSpec.getProfile',
    'outputSpec.getTemplate',
    'outputSpec.getTagRules',
    'outputSpec.getCategoryRules',
    'outputSpec.getDistillTemplate',
    'outputSpec.getSnippet',
    'outputSpec.getRawContentSection',
    'pipeline.processText',
    'pipeline.getStatus',
    'pipeline.retryExport',
    'pipeline.getStateHistory',
    'pipeline.checkDuplicate',
    'pipeline.batchProcessedAt',
  ];

  // V2.1 Phase 6.1–6.5: Unified Error Model + Retry + Control Panel
  const expectedPhase6New = [
    'errors.list',
    'errors.get',
    'errors.resolve',
    'errors.dismiss',
    'errors.clearResolved',
    'retry.error',
    'localModel.getRuntimeStatus',
  ];

  // V2.1 Phase 7.1: Unified Capture Adapter
  const expectedPhase71 = [
    'capture.record',
    'capture.getAvailableTypes',
  ];

  // V2.1 Phase 7.2: Clipboard text capture
  const expectedPhase72 = [
    'capture.collectClipboard',
  ];

  // V2.1 Phase 7.3: Screenshot capture
  const expectedPhase73 = [
    'capture.collectScreenshot',
  ];

  // V2.1 Phase 7.4: Webpage content capture
  const expectedPhase74 = [
    'capture.collectWebpage',
  ];

  // V2.1 Phase 7.5: File import + dialog
  const expectedPhase75 = [
    'capture.collectFile',
    'dialog.openFile',
  ];

  // V2.1 Phase 8: AI Strategy & Regeneration
  const expectedPhase8 = [
    'strategy.regenerate',
  ];

  const expectedWorkspace = [
    'workspace.selectDirectory',
    'workspace.openDirectory',
    'workspace.testWrite',
  ];

  const expectedVaultKeeper = [
    'vk.checkHealth',
    'vk.getJobStatus',
    'vk.cancelJob',
    'vk.resubmitJob',
    'vk.getRecentJobs',
    'vk.getFailedJobs',
    'vk.manualIngest',
  ];

  const expectedPhase10 = [
    'voice.importAudio',
    'voice.startWatch',
    'voice.stopWatch',
    'voice.getWatchState',
    'voice.retryTranscription',
    'voice.getTranscriptionStatus',
    'app.openPath',
    'dialog.selectDirectory',
  ];

  const expectedPhase126 = [
    'diagnostics.export',
  ];

  // -- Contains all expected channels ---------------------------------------

  it('should contain all Phase 1 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase1) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 2 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase2) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 3 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase3) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 4 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase4) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 5 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase5) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 6 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase6) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all workspace channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedWorkspace) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all VaultKeeper channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedVaultKeeper) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all distill loop channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedDistillLoop) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all search channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedSearch) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all parser channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedParser) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all scheduler channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedScheduler) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all whisper channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedWhisper) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all polish channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPolish) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all V2.1 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedV21) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 6.1–6.5 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase6New) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 7.1 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase71) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 7.2 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase72) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 7.3 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase73) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 7.4 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase74) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 7.5 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase75) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 8 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase8) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 10 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase10) {
      expect(values).toContain(channel);
    }
  });

  it('should contain all Phase 12.6 channel names', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const channel of expectedPhase126) {
      expect(values).toContain(channel);
    }
  });

  // -- Values are unique ----------------------------------------------------

  it('should have unique values (no duplicate channel names)', () => {
    const values = Object.values(IPC_CHANNELS);
    const uniqueValues = new Set(values);
    expect(uniqueValues.size).toBe(values.length);
  });

  // -- Key naming convention ------------------------------------------------

  it('should use UPPER_SNAKE_CASE for all keys', () => {
    const keys = Object.keys(IPC_CHANNELS);
    for (const key of keys) {
      expect(key).toMatch(/^[A-Z][A-Z0-9_]*$/);
    }
  });

  // -- Value format ---------------------------------------------------------

  it('should use dot-separated format for all values', () => {
    const values = Object.values(IPC_CHANNELS);
    for (const value of values) {
      // Values use dot-separated format like "settings.get", "app.getVersion", "sourceItems.list"
      // They may contain camelCase both before and after the dot
      expect(value).toMatch(/^[a-zA-Z][a-zA-Z0-9]*\.[a-zA-Z][a-zA-Z0-9.]*$/);
    }
  });

  // -- Total count ----------------------------------------------------------

  it('should have the expected total number of channels', () => {
    const totalExpected = new Set([
      ...expectedPhase1,
      ...expectedPhase2,
      ...expectedPhase3,
      ...expectedPhase4,
      ...expectedPhase5,
      ...expectedKnowledge,
      ...expectedPhase6,
      ...expectedCaptureItems,
      ...expectedWorkspace,
      ...expectedDistillLoop,
      ...expectedSearch,
      ...expectedParser,
      ...expectedScheduler,
      ...expectedWhisper,
      ...expectedPolish,
      ...expectedV21,
      ...expectedPhase6New,
      ...expectedPhase71,
      ...expectedPhase72,
      ...expectedPhase73,
      ...expectedPhase74,
      ...expectedPhase75,
      ...expectedPhase8,
      ...expectedVaultKeeper,
      ...expectedPhase10,
      ...expectedPhase126,
    ]).size;
    expect(Object.keys(IPC_CHANNELS).length).toBe(totalExpected);
  });
});
