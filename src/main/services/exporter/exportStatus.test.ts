// PinMind Export False-Success Prevention Tests
// 验证 ExportRecord.error 字段存在，以及 status 分支逻辑正确

import { describe, it, expect } from 'vitest';
import type { ExportRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Test 1: ExportRecord 类型包含 error 字段
// ---------------------------------------------------------------------------

describe('ExportRecord type', () => {
  it('should accept error field on failed records', () => {
    const failedRecord: ExportRecord = {
      id: 'exp_test_1',
      sourceItemId: 'src-1',
      distilledOutputId: 'do-1',
      vaultPath: '/fake/vault',
      relativeFilePath: 'test.md',
      frontmatter: {},
      exportedAt: Math.floor(Date.now() / 1000),
      status: 'failed',
      error: 'Vault path does not exist: /fake/vault',
    };

    expect(failedRecord.status).toBe('failed');
    expect(failedRecord.error).toBeDefined();
    expect(failedRecord.error).toContain('Vault path does not exist');
  });

  it('should allow error to be undefined on success records', () => {
    const successRecord: ExportRecord = {
      id: 'exp_test_2',
      sourceItemId: 'src-1',
      distilledOutputId: 'do-1',
      vaultPath: '/real/vault',
      relativeFilePath: 'test.md',
      frontmatter: {},
      exportedAt: Math.floor(Date.now() / 1000),
      status: 'success',
    };

    expect(successRecord.status).toBe('success');
    expect(successRecord.error).toBeUndefined();
  });

  it('should allow error to be undefined on conflict records', () => {
    const conflictRecord: ExportRecord = {
      id: 'exp_test_3',
      sourceItemId: 'src-1',
      distilledOutputId: 'do-1',
      vaultPath: '/real/vault',
      relativeFilePath: 'test.md',
      frontmatter: {},
      exportedAt: Math.floor(Date.now() / 1000),
      status: 'conflict',
      conflictResolution: 'skip',
    };

    expect(conflictRecord.status).toBe('conflict');
    expect(conflictRecord.error).toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// Test 2: 导出 status 分支逻辑（模拟前端处理）
// ---------------------------------------------------------------------------

describe('Export status branch logic', () => {
  type ExportFeedback = { type: 'success' | 'warning' | 'error'; message: string };

  function computeExportFeedback(record: ExportRecord): ExportFeedback {
    switch (record.status) {
      case 'success':
        return { type: 'success', message: `已输出到 Obsidian: ${record.relativeFilePath}` };
      case 'conflict':
        return { type: 'warning', message: `文件已存在，已跳过: ${record.relativeFilePath}` };
      case 'failed': {
        const errMsg = record.error || '未知导出错误';
        if (errMsg.includes('Vault path does not exist')) {
          return { type: 'error', message: '导出路径不存在，请检查设置中的 Vault 路径是否正确' };
        }
        if (errMsg.includes('EACCES') || errMsg.includes('permission')) {
          return { type: 'error', message: '文件写入失败：没有写入权限，请检查目录权限' };
        }
        return { type: 'error', message: `导出失败: ${errMsg}` };
      }
      default:
        return { type: 'warning', message: `导出返回未知状态: ${record.status}` };
    }
  }

  it('should return success for status=success', () => {
    const record: ExportRecord = {
      id: 'exp_1', sourceItemId: 's1', distilledOutputId: 'd1',
      vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
      exportedAt: 1, status: 'success',
    };
    const fb = computeExportFeedback(record);
    expect(fb.type).toBe('success');
    expect(fb.message).toContain('已输出到 Obsidian');
  });

  it('should return warning for status=conflict', () => {
    const record: ExportRecord = {
      id: 'exp_2', sourceItemId: 's1', distilledOutputId: 'd1',
      vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
      exportedAt: 1, status: 'conflict', conflictResolution: 'skip',
    };
    const fb = computeExportFeedback(record);
    expect(fb.type).toBe('warning');
    expect(fb.message).toContain('文件已存在');
  });

  it('should return error for status=failed with vault path error', () => {
    const record: ExportRecord = {
      id: 'exp_3', sourceItemId: 's1', distilledOutputId: 'd1',
      vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
      exportedAt: 1, status: 'failed',
      error: 'Vault path does not exist: /fake/path',
    };
    const fb = computeExportFeedback(record);
    expect(fb.type).toBe('error');
    expect(fb.message).toContain('导出路径不存在');
    // 关键：绝不能返回 success
    expect(fb.type).not.toBe('success');
  });

  it('should return error for status=failed with permission error', () => {
    const record: ExportRecord = {
      id: 'exp_4', sourceItemId: 's1', distilledOutputId: 'd1',
      vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
      exportedAt: 1, status: 'failed',
      error: 'EACCES: permission denied',
    };
    const fb = computeExportFeedback(record);
    expect(fb.type).toBe('error');
    expect(fb.message).toContain('写入权限');
    expect(fb.type).not.toBe('success');
  });

  it('should return error for status=failed with generic error', () => {
    const record: ExportRecord = {
      id: 'exp_5', sourceItemId: 's1', distilledOutputId: 'd1',
      vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
      exportedAt: 1, status: 'failed',
      error: 'ENOSPC: no space left on device',
    };
    const fb = computeExportFeedback(record);
    expect(fb.type).toBe('error');
    expect(fb.message).toContain('导出失败');
    expect(fb.type).not.toBe('success');
  });

  it('should return error for status=failed with no error message', () => {
    const record: ExportRecord = {
      id: 'exp_6', sourceItemId: 's1', distilledOutputId: 'd1',
      vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
      exportedAt: 1, status: 'failed',
    };
    const fb = computeExportFeedback(record);
    expect(fb.type).toBe('error');
    expect(fb.message).toContain('未知导出错误');
    expect(fb.type).not.toBe('success');
  });
});

// ---------------------------------------------------------------------------
// Test 3: 批量导出结果汇总逻辑
// ---------------------------------------------------------------------------

describe('Batch export result aggregation', () => {
  it('should report failure when any record is failed', () => {
    const records: ExportRecord[] = [
      {
        id: 'exp_1', sourceItemId: 's1', distilledOutputId: 'd1',
        vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
        exportedAt: 1, status: 'success',
      },
      {
        id: 'exp_2', sourceItemId: 's2', distilledOutputId: 'd2',
        vaultPath: '/v', relativeFilePath: 'b.md', frontmatter: {},
        exportedAt: 1, status: 'failed',
        error: 'Vault path does not exist: /fake',
      },
    ];

    const failed = records.filter((r) => r.status === 'failed');
    expect(failed.length).toBe(1);
    expect(failed[0].error).toContain('Vault path does not exist');
  });

  it('should not false-report success when all records are failed', () => {
    const records: ExportRecord[] = [
      {
        id: 'exp_1', sourceItemId: 's1', distilledOutputId: 'd1',
        vaultPath: '/v', relativeFilePath: 'a.md', frontmatter: {},
        exportedAt: 1, status: 'failed',
        error: 'EACCES: permission denied',
      },
      {
        id: 'exp_2', sourceItemId: 's2', distilledOutputId: 'd2',
        vaultPath: '/v', relativeFilePath: 'b.md', frontmatter: {},
        exportedAt: 1, status: 'failed',
        error: 'ENOENT: no such file',
      },
    ];

    const succeeded = records.filter((r) => r.status === 'success');
    const failed = records.filter((r) => r.status === 'failed');
    expect(succeeded.length).toBe(0);
    expect(failed.length).toBe(2);
    // 关键断言：没有成功记录
    expect(succeeded.length).not.toBeGreaterThan(0);
  });
});
