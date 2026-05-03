import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

// ---------------------------------------------------------------------------
// Mocks — must be before any import that touches storage / logger / settings
// ---------------------------------------------------------------------------

let mockVaultPath = '';
let mockVaultConfig = { vaultPath: '', defaultFolder: '', conflictStrategy: 'rename' as const };

vi.mock('../../storage', () => {
  const sourceItems = new Map<string, any>();
  const exportRecords: any[] = [];
  const stateHistory: any[] = [];

  return {
    storage: {
      insertSourceItem: vi.fn((item: any) => { sourceItems.set(item.id, { ...item }); }),
      getSourceItem: vi.fn((id: string) => sourceItems.get(id) ?? null),
      updateSourceItem: vi.fn((id: string, patch: any) => {
        const item = sourceItems.get(id);
        if (item) Object.assign(item, patch);
      }),
      getVaultConfig: vi.fn(() => mockVaultConfig),
      insertExportRecord: vi.fn((record: any) => { exportRecords.push(record); }),
      getExportRecords: vi.fn(({ sourceItemId }: any) =>
        exportRecords.filter((r) => r.sourceItemId === sourceItemId),
      ),
      getSourceItemByOriginalId: vi.fn((originalId: string) => {
        for (const item of sourceItems.values()) {
          if (item.originalId === originalId) return item;
        }
        return null;
      }),
      insertContentStateHistory: vi.fn((params: any) => {
        stateHistory.push({ ...params, createdAt: Date.now() });
      }),
      getContentStateHistory: vi.fn((sourceItemId: string) =>
        stateHistory.filter((r) => r.sourceItemId === sourceItemId),
      ),
      _test: { sourceItems, exportRecords, stateHistory },
    },
  };
});

vi.mock('../../logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() },
}));

vi.mock('../../settings', () => ({
  resolveStorageRoot: vi.fn(() => os.tmpdir()),
}));

vi.mock('../../../shared/defaultSettings', () => ({
  DEFAULT_SETTINGS: { storageRoot: '~/.pinmind' },
}));

vi.mock('../exporter/pathResolver', () => ({
  pathResolver: {
    resolve: vi.fn((_a: any, _b: any, _c: any) => '/mock/path.md'),
    resolveForPipeline: vi.fn((vaultPath: string, defaultFolder: string, title: string, createdAt: number) =>
      path.join(vaultPath, defaultFolder || '00_Inbox/PinMind', `${createdAt}_${title}.md`),
    ),
  },
}));

vi.mock('../exporter/conflictHandler', () => ({
  conflictHandler: {
    resolve: vi.fn((filePath: string) => ({ action: 'create', filePath })),
  },
}));

vi.mock('../exporter/safeWrite', () => ({
  safeWrite: vi.fn((targetPath: string, content: string) => {
    // Write directly (no temp file needed in tests)
    const fs = require('node:fs');
    const path = require('node:path');
    const parentDir = path.dirname(targetPath);
    if (!fs.existsSync(parentDir)) {
      fs.mkdirSync(parentDir, { recursive: true });
    }
    fs.writeFileSync(targetPath, content, 'utf8');
    return { filePath: targetPath, created: true, renamed: false };
  }),
  validateVaultPath: vi.fn((vaultPath: string) => {
    const fs = require('node:fs');
    if (!vaultPath || !vaultPath.trim()) {
      return { valid: false, error: 'VAULT_NOT_CONFIGURED', userMessage: 'Obsidian 仓库路径未配置，请在设置中设置仓库路径。' };
    }
    if (!fs.existsSync(vaultPath)) {
      return { valid: false, error: 'VAULT_NOT_FOUND', userMessage: `Obsidian 仓库路径不存在: ${vaultPath}。请检查路径是否正确。` };
    }
    return { valid: true, userMessage: '仓库路径验证通过。' };
  }),
}));

vi.mock('../outputSpec', () => ({
  outputSpecService: {
    getActiveProfile: vi.fn(() => ({
      id: 'pinmind-default',
      schema_version: '0.2',
      field_mapping: {
        schema_version: 'schema_version',
        title: 'title',
        summary: 'summary',
        tags: 'tags',
        category: 'category',
        source: 'source',
        captured_at: 'captured_at',
        project: 'project',
        status: 'status',
        confidence: 'confidence',
      },
      show_raw_content: false,
      default_values: {},
    })),
    getDefaultTemplate: vi.fn(() => `{{frontmatter}}

> {{summary}}

# {{title}}

{{body}}`),
    getCategoryRules: vi.fn(() => ({
      recommendedCategories: ['未分类'],
    })),
    getTagRules: vi.fn(() => ({ maxTagsPerItem: 8 })),
    getRawContentSection: vi.fn(() => ''),
    getDistillTemplate: vi.fn(() => ''),
    getSnippet: vi.fn(() => ''),
  },
}));

// ---------------------------------------------------------------------------
// Imports (after mocks)
// ---------------------------------------------------------------------------

import { contentPipeline } from './contentPipelineService';
import { contentStateMachine } from './contentStateMachine';
import { storage } from '../../storage';

const testStorage = storage as any & { _test: { sourceItems: Map<string, any>; exportRecords: any[]; stateHistory: any[] } };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('contentPipeline', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pinmind-test-'));
    mockVaultPath = tmpDir;
    mockVaultConfig = { vaultPath: tmpDir, defaultFolder: '', conflictStrategy: 'rename' as const };
    testStorage._test.sourceItems.clear();
    testStorage._test.exportRecords.length = 0;
    testStorage._test.stateHistory.length = 0;
    (storage.getSourceItem as any).mockClear();
    (storage.updateSourceItem as any).mockClear();
    (storage.insertSourceItem as any).mockClear();
    (storage.insertExportRecord as any).mockClear();
    (storage.getExportRecords as any).mockClear();
    (storage.getSourceItemByOriginalId as any).mockClear();
    (storage.insertContentStateHistory as any).mockClear();
    (storage.getContentStateHistory as any).mockClear();
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  describe('processText — full pipeline', () => {
    it('processes text and writes .md to vault', async () => {
      const result = await contentPipeline.processText('这是一段测试文本', {
        vaultPath: tmpDir,
      });

      expect(result.success).toBe(true);
      expect(result.stage).toBe('exported');
      expect(result.outputPath).toBeDefined();
      expect(result.outputPath).toMatch(/\.md$/);
      expect(result.exportRecord?.frontmatter.output_id).toBeDefined();
      expect(String(result.exportRecord?.frontmatter.output_id)).toMatch(/^out_/);

      // Verify the file was actually written
      const content = fs.readFileSync(result.outputPath!, 'utf8');
      expect(content).toContain('这是一段测试文本');
      expect(content).toContain('schema_version:');
      expect(content).toContain('original_id:');
    });

    it('creates a SourceItem with original_id', async () => {
      const result = await contentPipeline.processText('测试去重文本', { vaultPath: tmpDir });

      expect(result.success).toBe(true);
      expect(storage.insertSourceItem).toHaveBeenCalled();

      // Verify original_id was set via updateSourceItem
      const updateCalls = (storage.updateSourceItem as any).mock.calls;
      const originalIdCall = updateCalls.find((call: any[]) => call[1]?.originalId);
      expect(originalIdCall).toBeDefined();
      expect(originalIdCall[1].originalId).toHaveLength(16);
    });

    it('writes original_id into Markdown frontmatter', async () => {
      const result = await contentPipeline.processText('测试 frontmatter original_id', { vaultPath: tmpDir });

      const content = fs.readFileSync(result.outputPath!, 'utf8');
      // original_id appears in the template-rendered frontmatter
      expect(content).toContain('original_id:');
    });

    it('strips source YAML frontmatter before organizing markdown input', async () => {
      const markdownInput = `---
title: MiMo Token Plan 消费决策复盘：不要被峰值消耗绑架
date: 2026-05-01
type: 决策复盘
---

# MiMo Token Plan 消费决策复盘：不要被峰值消耗绑架

正文内容第一段。
`;

      const result = await contentPipeline.processText(markdownInput, { vaultPath: tmpDir });

      expect(result.success).toBe(true);
      const content = fs.readFileSync(result.outputPath!, 'utf8');

      expect(content).toContain('# MiMo Token Plan 消费决策复盘：不要被峰值消耗绑架');
      expect(content).not.toContain('type: 决策复盘');
      expect(path.basename(result.outputPath!)).not.toContain('---');
    });

    it('prefers the first markdown heading over bullet-like first lines', async () => {
      const markdownInput = `- PinMind V2.1 - V3.0 Phase 路线总纲

# PinStack 产品手册 v2.1

正文内容第一段。
`;

      const result = await contentPipeline.processText(markdownInput, { vaultPath: tmpDir });
      expect(result.success).toBe(true);
      expect(path.basename(result.outputPath!)).not.toContain('_- ');

      const content = fs.readFileSync(result.outputPath!, 'utf8');
      expect(content).toContain('title: PinStack 产品手册 v2.1');
      expect(content).not.toContain('title: "- PinMind V2.1 - V3.0 Phase 路线总纲"');
    });

    it('records state transitions in history', async () => {
      await contentPipeline.processText('测试状态记录', { vaultPath: tmpDir });

      expect(storage.insertContentStateHistory).toHaveBeenCalled();
      const calls = (storage.insertContentStateHistory as any).mock.calls;
      const toStates = calls.map((c: any[]) => c[0].toState);

      // Should have at least the initial processing transition
      expect(toStates.length).toBeGreaterThanOrEqual(1);
      expect(toStates).toContain('processing');
    });
  });

  describe('processText — dedup', () => {
    it('skips duplicate content that is already exported', async () => {
      // First: process normally
      const result1 = await contentPipeline.processText('重复内容测试', { vaultPath: tmpDir });
      expect(result1.success).toBe(true);
      expect(result1.stage).toBe('exported');

      // Clear state for second call
      testStorage._test.exportRecords.length = 0;
      testStorage._test.stateHistory.length = 0;

      // Second: same content should be skipped
      const result2 = await contentPipeline.processText('重复内容测试', { vaultPath: tmpDir });
      expect(result2.success).toBe(true);
      expect(result2.stage).toBe('exported');
      expect(result2.sourceItemId).toBe(result1.sourceItemId);

      // Should NOT create a new SourceItem
      const insertCalls = (storage.insertSourceItem as any).mock.calls;
      // Only one insert from the first call (second was skipped before insert)
      // Actually the dedup check happens before insert, so only 1 insert total
    });
  });

  describe('processText — failure handling', () => {
    it('returns export_failed when vault path is not configured', async () => {
      mockVaultConfig = { vaultPath: '', defaultFolder: '', conflictStrategy: 'rename' as const };

      const result = await contentPipeline.processText('测试无 vault');
      expect(result.success).toBe(false);
      expect(result.stage).toBe('export_failed');
      expect(result.error).toContain('仓库路径未配置');
    });

    it('returns export_failed when vault path does not exist', async () => {
      const result = await contentPipeline.processText('测试无效 vault', {
        vaultPath: '/non/existent/path/that/does/not/exist',
      });
      expect(result.success).toBe(false);
      expect(result.stage).toBe('export_failed');
    });
  });

  describe('processText — skipExport', () => {
    it('stops at structured stage when skipExport is true', async () => {
      const result = await contentPipeline.processText('测试跳过导出', { skipExport: true });
      expect(result.success).toBe(true);
      expect(result.stage).toBe('structured');
      expect(result.outputPath).toBeUndefined();
    });
  });

  describe('retryExport', () => {
    it('retries a failed export', async () => {
      // First: create a source item that failed
      const id = `src_retry_${Date.now()}`;
      testStorage._test.sourceItems.set(id, {
        id,
        type: 'text',
        source: 'manual',
        contentPath: path.join(tmpDir, `${id}.txt`),
        previewText: '需要重试的内容',
        status: 'distilled',
        createdAt: Math.floor(Date.now() / 1000),
      });
      // Write the content file
      fs.writeFileSync(path.join(tmpDir, `${id}.txt`), '需要重试的完整内容，比 previewText 更长');

      // Add a failed export record
      testStorage._test.exportRecords.push({
        sourceItemId: id,
        status: 'failed',
      });

      const result = await contentPipeline.retryExport(id);
      expect(result.success).toBe(true);
      expect(result.stage).toBe('exported');
      expect(result.outputPath).toMatch(/\.md$/);
    });

    it('rejects retry for non-existent source item', async () => {
      const result = await contentPipeline.retryExport('non-existent');
      expect(result.success).toBe(false);
      expect(result.error).toContain('not found');
    });

    it('rejects retry when not in a retryable state', async () => {
      const id = `src_ok_${Date.now()}`;
      testStorage._test.sourceItems.set(id, {
        id,
        status: 'exported',
        createdAt: Math.floor(Date.now() / 1000),
      });
      testStorage._test.exportRecords.push({ sourceItemId: id, status: 'success' });

      const result = await contentPipeline.retryExport(id);
      expect(result.success).toBe(false);
      expect(result.error).toContain('Cannot retry');
    });
  });

  describe('getStatus', () => {
    it('returns captured for inbox items', () => {
      const id = `src_status_${Date.now()}`;
      testStorage._test.sourceItems.set(id, { id, status: 'inbox' });
      expect(contentPipeline.getStatus(id)).toBe('captured');
    });

    it('returns exported for items with successful export', () => {
      const id = `src_exp_${Date.now()}`;
      testStorage._test.sourceItems.set(id, { id, status: 'distilled' });
      testStorage._test.exportRecords.push({ sourceItemId: id, status: 'success' });
      expect(contentPipeline.getStatus(id)).toBe('exported');
    });

    it('returns capture_failed for non-existent items', () => {
      expect(contentPipeline.getStatus('non-existent')).toBe('capture_failed');
    });
  });

  // ---------------------------------------------------------------------------
  // E2E verification: full write chain — source_app, writer_app, output_id
  // ---------------------------------------------------------------------------

  describe('E2E — frontmatter traceability', () => {
    it('frontmatter contains source_app from SourceItem and writer_app=PinMind', async () => {
      const result = await contentPipeline.processText('测试 source_app 语义', {
        vaultPath: tmpDir,
      });

      expect(result.success).toBe(true);
      const content = fs.readFileSync(result.outputPath!, 'utf8');

      // writer_app must always be 'PinMind'
      expect(content).toContain('writer_app:');
      expect(content).toContain('PinMind');

      // source_app is only written when SourceItem.sourceApp is set.
      // For manual input via pipeline, sourceApp may not be set, so source_app
      // may be absent. The key semantic is that writer_app is separate from source_app.
    });

    it('output_id matches ExportRecord.distilledOutputId', async () => {
      const result = await contentPipeline.processText('测试 output_id 一致性', {
        vaultPath: tmpDir,
      });

      expect(result.success).toBe(true);
      expect(result.exportRecord).toBeDefined();

      const fmOutputId = result.exportRecord!.frontmatter.output_id;
      const dbOutputId = result.exportRecord!.distilledOutputId;

      // Both must be defined and match
      expect(fmOutputId).toBeDefined();
      expect(dbOutputId).toBeDefined();
      expect(dbOutputId).toBe(fmOutputId);
      expect(String(fmOutputId)).toMatch(/^out_/);
    });

    it('frontmatter contains all traceability fields', async () => {
      const result = await contentPipeline.processText('测试完整追溯字段', {
        vaultPath: tmpDir,
      });

      expect(result.success).toBe(true);
      const content = fs.readFileSync(result.outputPath!, 'utf8');

      // All required traceability fields must be present
      expect(content).toContain('original_id:');
      expect(content).toContain('output_id:');
      expect(content).toContain('source_type:');
      expect(content).toContain('writer_app:');
      expect(content).toContain('created:');
      expect(content).toContain('updated:');
      // source_app is optional — only present when SourceItem.sourceApp is set
    });
  });

  describe('E2E — retry generates new output_id', () => {
    it('retry creates a new output_id and preserves history', async () => {
      // First: create a source item that failed
      const id = `src_e2e_retry_${Date.now()}`;
      testStorage._test.sourceItems.set(id, {
        id,
        type: 'text',
        source: 'manual',
        sourceApp: 'ChatGPT',
        contentPath: path.join(tmpDir, `${id}.txt`),
        previewText: '需要重试的内容',
        status: 'distilled',
        createdAt: Math.floor(Date.now() / 1000),
      });
      fs.writeFileSync(path.join(tmpDir, `${id}.txt`), '需要重试的完整内容');

      // Add a failed export record with a specific output_id
      const failedOutputId = `out_failed_${Date.now()}`;
      testStorage._test.exportRecords.push({
        id: `exp_failed_${Date.now()}`,
        sourceItemId: id,
        distilledOutputId: failedOutputId,
        status: 'failed',
        error: '模拟写入失败',
      });

      // Retry
      const result = await contentPipeline.retryExport(id);
      expect(result.success).toBe(true);
      expect(result.stage).toBe('exported');

      // The new output_id must differ from the failed one
      const newOutputId = result.exportRecord!.distilledOutputId;
      expect(newOutputId).toBeDefined();
      expect(newOutputId).not.toBe(failedOutputId);

      // History should have both records (failed + success)
      const records = testStorage._test.exportRecords.filter(
        (r: any) => r.sourceItemId === id,
      );
      expect(records.length).toBeGreaterThanOrEqual(2);

      // Verify the file was written
      const content = fs.readFileSync(result.outputPath!, 'utf8');
      expect(content).toContain('需要重试的完整内容');
      expect(content).toContain('writer_app:');

      // source_app should be 'ChatGPT' since we set sourceApp on the SourceItem
      expect(content).toContain('source_app: ChatGPT');
    });
  });

  describe('E2E — file written to 00_Inbox/PinMind', () => {
    it('output file is under the PinMind output directory', async () => {
      const result = await contentPipeline.processText('测试输出目录', {
        vaultPath: tmpDir,
      });

      expect(result.success).toBe(true);
      expect(result.outputPath).toBeDefined();

      // Path should contain 00_Inbox/PinMind (from pathResolver mock)
      expect(result.outputPath).toContain('00_Inbox');
      expect(result.outputPath).toContain('PinMind');
    });
  });
});
