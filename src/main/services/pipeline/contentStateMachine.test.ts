import { describe, expect, it, vi, beforeEach } from 'vitest';

// ---------------------------------------------------------------------------
// Test state (module-level, shared across tests via beforeEach reset)
// ---------------------------------------------------------------------------

const testSourceItems = new Map<string, { id: string; status: string; originalId?: string }>();
const testExportRecords = new Map<string, Array<{ status: string }>>();
const testStateHistory: Array<{
  id: string;
  sourceItemId: string;
  fromState: string;
  toState: string;
  actor: string;
  reason?: string;
  error?: string;
  createdAt: number;
}> = [];

// Mock logger
vi.mock('../../logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() },
}));

// Use vi.hoisted to declare mockStorage so it's available in the hoisted vi.mock factory
const { mockStorage } = vi.hoisted(() => ({
  mockStorage: {
    getSourceItem: vi.fn(),
    updateSourceItem: vi.fn(),
    insertContentStateHistory: vi.fn(),
    getContentStateHistory: vi.fn(),
    getExportRecords: vi.fn(),
    getSourceItemByOriginalId: vi.fn(),
  },
}));

vi.mock('../../storage', () => ({
  storage: mockStorage,
}));

import { contentStateMachine } from './contentStateMachine';

describe('contentStateMachine', () => {
  beforeEach(() => {
    testSourceItems.clear();
    testExportRecords.clear();
    testStateHistory.length = 0;

    // Re-assign mock implementations
    mockStorage.getSourceItem.mockImplementation((id: string) => testSourceItems.get(id) ?? null);
    mockStorage.updateSourceItem.mockImplementation((id: string, patch: any) => {
      const item = testSourceItems.get(id);
      if (item) {
        Object.assign(item, patch);
        if (patch.originalId) item.originalId = patch.originalId as string;
      }
    });
    mockStorage.insertContentStateHistory.mockImplementation((params: any) => {
      testStateHistory.push({
        id: `csh_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
        sourceItemId: params.sourceItemId,
        fromState: params.fromState,
        toState: params.toState,
        actor: params.actor ?? 'system',
        reason: params.reason,
        error: params.error,
        createdAt: Date.now(),
      });
    });
    mockStorage.getContentStateHistory.mockImplementation((sourceItemId: string) =>
      testStateHistory.filter((r) => r.sourceItemId === sourceItemId),
    );
    mockStorage.getExportRecords.mockImplementation(({ sourceItemId }: any) =>
      testExportRecords.get(sourceItemId) ?? [],
    );
    mockStorage.getSourceItemByOriginalId.mockImplementation((originalId: string) => {
      for (const item of testSourceItems.values()) {
        if (item.originalId === originalId) return item;
      }
      return null;
    });
  });

  describe('generateContentHash', () => {
    it('produces consistent hash for same content', () => {
      const hash1 = contentStateMachine.generateContentHash('hello world');
      const hash2 = contentStateMachine.generateContentHash('hello world');
      expect(hash1).toBe(hash2);
      expect(hash1).toHaveLength(16);
    });

    it('normalizes whitespace', () => {
      const hash1 = contentStateMachine.generateContentHash('hello   world');
      const hash2 = contentStateMachine.generateContentHash('hello world');
      expect(hash1).toBe(hash2);
    });

    it('produces different hash for different content', () => {
      const hash1 = contentStateMachine.generateContentHash('hello world');
      const hash2 = contentStateMachine.generateContentHash('goodbye world');
      expect(hash1).not.toBe(hash2);
    });

    it('trims leading/trailing whitespace', () => {
      const hash1 = contentStateMachine.generateContentHash('  hello world  ');
      const hash2 = contentStateMachine.generateContentHash('hello world');
      expect(hash1).toBe(hash2);
    });
  });

  describe('findDuplicate', () => {
    it('returns null when no duplicate exists', () => {
      expect(contentStateMachine.findDuplicate('unique content')).toBeNull();
    });

    it('finds duplicate by original_id', () => {
      const hash = contentStateMachine.generateContentHash('duplicate content');
      testSourceItems.set('src-1', { id: 'src-1', status: 'exported', originalId: hash });

      const result = contentStateMachine.findDuplicate('duplicate content');
      expect(result).not.toBeNull();
      expect(result!.sourceItem.id).toBe('src-1');
      expect(result!.originalId).toBe(hash);
    });

    it('returns null for different content', () => {
      testSourceItems.set('src-1', {
        id: 'src-1',
        status: 'exported',
        originalId: contentStateMachine.generateContentHash('content A'),
      });
      expect(contentStateMachine.findDuplicate('content B')).toBeNull();
    });
  });

  describe('transition', () => {
    it('transitions from captured to processing', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      expect(contentStateMachine.transition('src-1', 'processing', { actor: 'pipeline' })).toBe(true);
      expect(mockStorage.updateSourceItem).toHaveBeenCalledWith('src-1', { status: 'distilling' });
    });

    it('rejects invalid transition', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      expect(contentStateMachine.transition('src-1', 'exported')).toBe(false);
    });

    it('returns true when already in target state', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      testExportRecords.set('src-1', []);

      expect(contentStateMachine.transition('src-1', 'processing', { actor: 'pipeline' })).toBe(true);
      expect(contentStateMachine.transition('src-1', 'processing')).toBe(true);
    });

    it('returns false for non-existent source item', () => {
      expect(contentStateMachine.transition('non-existent', 'processing')).toBe(false);
    });

    it('allows full pipeline: captured → processing → structured → exporting → exported', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      testExportRecords.set('src-1', []);

      expect(contentStateMachine.transition('src-1', 'processing', { actor: 'pipeline' })).toBe(true);
      expect(contentStateMachine.transition('src-1', 'structured', { actor: 'pipeline' })).toBe(true);
      expect(contentStateMachine.transition('src-1', 'exporting', { actor: 'pipeline' })).toBe(true);
      expect(contentStateMachine.transition('src-1', 'exported', { actor: 'pipeline' })).toBe(true);
    });

    it('allows failure state transitions with retry', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      testExportRecords.set('src-1', []);

      expect(contentStateMachine.transition('src-1', 'processing')).toBe(true);
      expect(contentStateMachine.transition('src-1', 'process_failed')).toBe(true);
      expect(contentStateMachine.getCurrentState('src-1')).toBe('process_failed');
      expect(contentStateMachine.canRetry('src-1')).toBe(true);
      expect(contentStateMachine.transition('src-1', 'processing')).toBe(true);
    });
  });

  describe('getCurrentState', () => {
    it('returns captured for inbox status', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      expect(contentStateMachine.getCurrentState('src-1')).toBe('captured');
    });

    it('returns exported when successful export record exists', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'distilled' });
      testExportRecords.set('src-1', [{ status: 'success' }]);
      expect(contentStateMachine.getCurrentState('src-1')).toBe('exported');
    });

    it('returns export_failed when failed export record exists', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'distilled' });
      testExportRecords.set('src-1', [{ status: 'failed' }]);
      expect(contentStateMachine.getCurrentState('src-1')).toBe('export_failed');
    });

    it('returns capture_failed for non-existent item', () => {
      expect(contentStateMachine.getCurrentState('non-existent')).toBe('capture_failed');
    });
  });

  describe('canRetry', () => {
    it('returns true for export_failed state', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'distilled' });
      testExportRecords.set('src-1', [{ status: 'failed' }]);
      expect(contentStateMachine.canRetry('src-1')).toBe(true);
    });

    it('returns false for exported state', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'exported' });
      testExportRecords.set('src-1', [{ status: 'success' }]);
      expect(contentStateMachine.canRetry('src-1')).toBe(false);
    });
  });

  describe('isExported', () => {
    it('returns true when exported', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'exported' });
      testExportRecords.set('src-1', [{ status: 'success' }]);
      expect(contentStateMachine.isExported('src-1')).toBe(true);
    });

    it('returns false when not exported', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      expect(contentStateMachine.isExported('src-1')).toBe(false);
    });
  });

  describe('getHistory', () => {
    it('returns empty history for new item', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });
      expect(contentStateMachine.getHistory('src-1')).toHaveLength(0);
    });

    it('records transitions in history', () => {
      testSourceItems.set('src-1', { id: 'src-1', status: 'inbox' });

      contentStateMachine.transition('src-1', 'processing', { actor: 'pipeline', reason: 'test' });
      contentStateMachine.transition('src-1', 'structured', { actor: 'pipeline', reason: 'test2' });

      const history = contentStateMachine.getHistory('src-1');
      expect(history).toHaveLength(2);
      expect(history[0].fromState).toBe('captured');
      expect(history[0].toState).toBe('processing');
      expect(history[1].fromState).toBe('processing');
      expect(history[1].toState).toBe('structured');
    });
  });
});
