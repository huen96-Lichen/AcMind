// PinMind Obsidian Exporter
// Core export logic: generates Markdown, writes to vault, creates ExportRecords
//
// Safety guarantees:
//   - Atomic writes (temp file + rename)
//   - original_id dedup check
//   - Vault path validation (exists + is directory + writable)
//   - Full ExportRecord with traceability fields
//   - User-friendly error messages

import crypto from 'node:crypto';
import path from 'node:path';
import { existsSync } from 'node:fs';
import type { DistilledOutput, ExportRecord, SourceItem, VaultConfig } from '../../../shared/types';
import { DEFAULT_OBSIDIAN_DOCUMENTS_ROOT } from '../../../shared/markdownSpec';
import { storage } from '../../storage';
import { logger } from '../../logger';
import { errorService } from '../../errorService';
import { markdownBuilder } from './markdownBuilder';
import { pathResolver } from './pathResolver';
import { conflictHandler } from './conflictHandler';
import { buildStandardFields, buildFrontmatterData, type FrontmatterExtras } from './standardFields';
import { outputSpecService } from '../outputSpec';
import { safeWrite, validateVaultPath } from './safeWrite';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ExportOptions {
  vaultConfig?: Partial<VaultConfig>;
  template?: string;
  conflictStrategy?: VaultConfig['conflictStrategy'];
  /** If true, skip original_id dedup check and allow re-export */
  force?: boolean;
}

// ---------------------------------------------------------------------------
// ObsidianExporter
// ---------------------------------------------------------------------------

class ObsidianExporter {
  /**
   * Export a single distilled output to the Obsidian vault.
   * Returns the created ExportRecord.
   */
  exportSingle(distilledOutputId: string, options?: ExportOptions): ExportRecord {
    const startTime = Date.now();

    // Fetch distilled output
    const distilledOutput = this.getDistilledOutput(distilledOutputId);

    // Fetch source item
    const sourceItem = storage.getSourceItem(distilledOutput.sourceItemId);
    if (!sourceItem) {
      throw new Error(`SourceItem not found: ${distilledOutput.sourceItemId}`);
    }
    const knowledgeCard =
      storage.getKnowledgeCardBySourceItemId(sourceItem.id) ??
      (distilledOutput.acceptedKnowledgeCardId ? storage.getKnowledgeCard(distilledOutput.acceptedKnowledgeCardId) : null);

    // Get vault config
    const vaultConfig = storage.getVaultConfig();
    const effectiveConfig: VaultConfig = {
      ...vaultConfig,
      vaultPath: vaultConfig.vaultPath || DEFAULT_OBSIDIAN_DOCUMENTS_ROOT,
      defaultFolder: vaultConfig.defaultFolder ?? '',
      ...options?.vaultConfig,
    };

    try {
      // Phase 1: Review status check
      const allowedStatuses = ['pending', 'accepted', 'edited'];
      if (!allowedStatuses.includes(distilledOutput.reviewStatus ?? 'pending')) {
        throw new Error(`Distilled output is not approved for export (status: ${distilledOutput.reviewStatus}): ${distilledOutputId}`);
      }

      // Phase 2: Validate vault path (enhanced: exists + is directory + writable)
      const vaultValidation = validateVaultPath(effectiveConfig.vaultPath);
      if (!vaultValidation.valid) {
        throw new Error(vaultValidation.userMessage);
      }

      // Phase 2.5: Only complete distilled-note outputs are exportable.
      // Single-field outputs from rename/classify/tag must never produce files.
      this.assertExportable(distilledOutput);

      // Phase 3: Dedup check — skip if same original_id already exported (unless force)
      if (!options?.force && sourceItem.originalId) {
        const existingRecords = storage.getExportRecords({ sourceItemId: sourceItem.id });
        const alreadyExported = existingRecords.some((r) => r.status === 'success');
        if (alreadyExported) {
          logger.info('export', 'obsidianExporter', 'exportSingle', 'Skipping: already exported', {
            sourceItemId: sourceItem.id,
            originalId: sourceItem.originalId,
          });
          // Return a conflict record to indicate the skip
          const record = this.createExportRecord({
            distilledOutput,
            sourceItem,
            vaultConfig: effectiveConfig,
            relativePath: this.safeRelativePath(effectiveConfig, distilledOutput, sourceItem),
            status: 'conflict',
            knowledgeCardId: knowledgeCard?.id,
            conflictResolution: 'skip',
            error: '内容已导出过，如需重新导出请使用强制模式。',
          });
          return record;
        }
      }

      // Phase 4: Resolve file path
      const targetPath = pathResolver.resolve(effectiveConfig, distilledOutput, sourceItem);

      // Phase 5: Handle conflicts
      const conflictStrategy = options?.conflictStrategy ?? effectiveConfig.conflictStrategy;
      const resolution = conflictHandler.resolve(targetPath, conflictStrategy);

      if (resolution.action === 'skip') {
        logger.warn('export', 'obsidianExporter', 'exportSingle', 'File already exists, skipping', {
          distilledOutputId,
          filePath: resolution.filePath,
        });

        const record = this.createExportRecord({
          distilledOutput,
          sourceItem,
          vaultConfig: effectiveConfig,
          relativePath: path.relative(effectiveConfig.vaultPath, resolution.filePath),
          status: 'conflict',
          knowledgeCardId: knowledgeCard?.id,
          conflictResolution: 'skip',
        });
        return record;
      }

      // Phase 6: Generate Markdown content
      const markdown = markdownBuilder.build(distilledOutput, sourceItem, effectiveConfig, options?.template);

      // Phase 7: Atomic write (temp file + rename)
      const writeResult = safeWrite(resolution.filePath, markdown);

      const record = this.createExportRecord({
        distilledOutput,
        sourceItem,
        vaultConfig: effectiveConfig,
        relativePath: path.relative(effectiveConfig.vaultPath, writeResult.filePath),
        status: 'success',
        knowledgeCardId: knowledgeCard?.id,
        conflictResolution: resolution.action === 'overwrite' ? 'overwrite' : resolution.action === 'rename' ? 'rename' : undefined,
      });

      // Update source item status to 'exported'
      storage.updateSourceItem(sourceItem.id, { status: 'exported' });

      const latencyMs = Date.now() - startTime;
      logger.info('export', 'obsidianExporter', 'exportSingle', `Export completed: ${record.id}`, {
        distilledOutputId,
        filePath: writeResult.filePath,
        action: resolution.action,
        latencyMs,
      });

      return record;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('export', 'obsidianExporter', 'exportSingle', 'Failed to write file', {
        error: errorMsg,
      });

      // Record to unified error model
      errorService.recordError({
        errorType: 'export_failed',
        originalId: sourceItem?.originalId,
        outputId: distilledOutput?.id,
        stage: 'obsidian_export',
        error,
        userMessage: '导出到 Obsidian 失败，请检查仓库路径和权限。',
      });

      const failedRecord = this.createExportRecord({
        distilledOutput,
        sourceItem,
        vaultConfig: effectiveConfig,
        relativePath: this.safeRelativePath(effectiveConfig, distilledOutput, sourceItem),
        status: 'failed',
        knowledgeCardId: knowledgeCard?.id,
        error: errorMsg,
      });
      return failedRecord;
    }
  }

  /**
   * Export multiple distilled outputs to the Obsidian vault.
   * Returns an array of ExportRecords (successful and failed).
   */
  exportBatch(distilledOutputIds: string[], options?: ExportOptions): ExportRecord[] {
    const records: ExportRecord[] = [];
    const startTime = Date.now();

    logger.info('export', 'obsidianExporter', 'exportBatch', `Starting batch export`, {
      count: distilledOutputIds.length,
    });

    for (const id of distilledOutputIds) {
      try {
        const record = this.exportSingle(id, options);
        records.push(record);
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);

        // Record to unified error model
        const distilledOutput = this.getDistilledOutput(id);
        const sourceItem = storage.getSourceItem(distilledOutput.sourceItemId);
        errorService.recordError({
          errorType: 'export_failed',
          originalId: sourceItem?.originalId,
          outputId: distilledOutput?.id,
          stage: 'obsidian_batch_export',
          error,
          userMessage: '批量导出中某项失败，请检查错误记录。',
        });

        // Create a failed export record
        const storedVaultConfig = storage.getVaultConfig();
        const vaultConfig = {
          ...storedVaultConfig,
          vaultPath: storedVaultConfig.vaultPath || DEFAULT_OBSIDIAN_DOCUMENTS_ROOT,
          defaultFolder: storedVaultConfig.defaultFolder ?? '',
        };

        const failedRecord = this.createExportRecord({
          distilledOutput,
          sourceItem: sourceItem ?? {
            id: distilledOutput.sourceItemId,
            type: 'text',
            source: 'manual',
            contentPath: '',
            createdAt: distilledOutput.createdAt,
            status: 'distilled',
          },
          vaultConfig,
          relativePath: '',
          status: 'failed',
          knowledgeCardId: distilledOutput.acceptedKnowledgeCardId,
          error: errorMsg,
        });

        records.push(failedRecord);

        logger.error('export', 'obsidianExporter', 'exportBatch', `Failed to export: ${id}`, {
          error: errorMsg,
        });
      }
    }

    const latencyMs = Date.now() - startTime;
    const succeeded = records.filter((r) => r.status === 'success').length;
    const failed = records.filter((r) => r.status === 'failed').length;

    logger.info('export', 'obsidianExporter', 'exportBatch', `Batch export completed`, {
      total: records.length,
      succeeded,
      failed,
      latencyMs,
    });

    return records;
  }

  /**
   * Retry a failed export.
   * Uses force mode to bypass dedup check.
   */
  retryExport(recordId: string): ExportRecord {
    // Find the export record
    const records = storage.getExportRecords({});
    const record = records.find((r) => r.id === recordId);
    if (!record) {
      throw new Error(`ExportRecord not found: ${recordId}`);
    }

    if (record.status === 'success') {
      throw new Error('Cannot retry a successful export');
    }

    // Re-export using the distilled output with force=true to bypass dedup
    return this.exportSingle(record.distilledOutputId, { force: true });
  }

  /**
   * Generate a template preview for a distilled output (without writing to disk).
   */
  preview(distilledOutputId: string): string {
    const distilledOutput = this.getDistilledOutput(distilledOutputId);
    const sourceItem = storage.getSourceItem(distilledOutput.sourceItemId);
    if (!sourceItem) {
      throw new Error(`SourceItem not found: ${distilledOutput.sourceItemId}`);
    }

    const vaultConfig = storage.getVaultConfig();
    return markdownBuilder.buildPreview(distilledOutput, sourceItem);
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  /**
   * Get a distilled output by ID, throwing if not found.
   */
  private getDistilledOutput(id: string): DistilledOutput {
    const outputs = storage.getDistilledOutputs({});
    const output = outputs.find((o) => o.id === id);
    if (!output) {
      throw new Error(`DistilledOutput not found: ${id}`);
    }
    return output;
  }

  private safeRelativePath(
    vaultConfig: VaultConfig,
    distilledOutput: DistilledOutput,
    sourceItem: SourceItem | { id: string; type: string; source: string; contentPath: string; createdAt: number; status: string },
  ): string {
    try {
      return pathResolver.resolveRelative(vaultConfig, distilledOutput, sourceItem as SourceItem);
    } catch {
      return '';
    }
  }

  private assertExportable(distilledOutput: DistilledOutput): void {
    const markdown = distilledOutput.contentMarkdown?.trim();
    if (!markdown) {
      throw new Error(`不可导出：当前结果没有 Markdown 正文。请先生成完整蒸馏结果，不要导出 ${distilledOutput.operation ?? 'unknown'} 碎片结果。`);
    }
    if (!distilledOutput.suggestedTitle?.trim()) {
      throw new Error('不可导出：当前结果缺少标题。');
    }
    if (!distilledOutput.summary?.trim()) {
      throw new Error('不可导出：当前结果缺少摘要。');
    }
  }

  /**
   * Create an ExportRecord and persist it to storage.
   * Includes full traceability: original_id, output_id, source_type, source_app, created, updated.
   */
  private createExportRecord(params: {
    distilledOutput: DistilledOutput;
    sourceItem: { id: string; type: string; source: string; contentPath: string; createdAt: number; status: string; originalId?: string; sourceApp?: string | null };
    vaultConfig: VaultConfig;
    relativePath: string;
    status: ExportRecord['status'];
    knowledgeCardId?: string;
    conflictResolution?: ExportRecord['conflictResolution'];
    error?: string;
  }): ExportRecord {
    const now = new Date().toISOString().replace('T', ' ').replace(/\.\d+Z$/, '');

    // Build extras for traceability
    const extras: FrontmatterExtras = {
      original_id: params.sourceItem.originalId,
      output_id: params.distilledOutput.id,
      source_type: params.sourceItem.source,
      source_app: params.sourceItem.sourceApp ?? undefined,
      writer_app: 'PinMind',
      created: new Date(params.sourceItem.createdAt * 1000).toISOString().replace('T', ' ').replace(/\.\d+Z$/, ''),
      updated: now,
    };

    const record: ExportRecord = {
      id: `exp_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`,
      sourceItemId: params.distilledOutput.sourceItemId,
      distilledOutputId: params.distilledOutput.id,
      knowledgeCardId: params.knowledgeCardId,
      vaultPath: params.vaultConfig.vaultPath,
      relativeFilePath: params.relativePath,
      frontmatter: {
        ...buildFrontmatterData(
          buildStandardFields(params.distilledOutput, params.sourceItem as SourceItem, {
            project: '默认',
            status: 'exported',
            includeRawContent: false,
          }),
          outputSpecService.getActiveProfile(),
          extras,
        ),
        error: params.error,
      },
      exportedAt: Math.floor(Date.now() / 1000),
      status: params.status,
      conflictResolution: params.conflictResolution,
      error: params.error,
    };

    storage.insertExportRecord(record);
    return record;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const obsidianExporter = new ObsidianExporter();
