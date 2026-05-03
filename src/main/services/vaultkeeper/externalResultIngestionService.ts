// ExternalResultIngestionService
// Phase 9.3: VaultKeeper 处理结果回填机制
//
// 职责：
// - 根据 external_job_id 找到对应的 SourceItem
// - 回填 extracted_text / transcript_text / parsed_markdown
// - 更新 external_processing_status
// - 触发重新 AI 整理
// - 记录处理历史
//
// 不负责：
// - Markdown 渲染
// - Obsidian 写入
// - VaultKeeper 通信（由 VaultKeeperAdapter 处理）

import { logger } from '../../logger';
import { storage } from '../../storage';
import { errorService } from '../../errorService';
import { vaultKeeperAdapter } from './vaultKeeperAdapter';
import type { VKJobResult } from './types';

// ---------------------------------------------------------------------------
// 回填结果
// ---------------------------------------------------------------------------

export interface IngestionResult {
  success: boolean;
  sourceItemId?: string;
  originalId?: string;
  fieldsUpdated: string[];
  reprocessed: boolean;
  error?: string;
}

// ---------------------------------------------------------------------------
// ExternalResultIngestionService
// ---------------------------------------------------------------------------

class ExternalResultIngestionService {
  /**
   * 根据 job_id 查询 VaultKeeper 结果并回填到 SourceItem。
   *
   * 流程：
   * 1. 通过 job_id 查询 VK 获取结果
   * 2. 通过 original_id 找到 SourceItem
   * 3. 回填 extracted_text / transcript_text / parsed_markdown
   * 4. 触发重新 AI 整理（通过 pipeline）
   */
  async ingestResult(jobId: string, originalId: string): Promise<IngestionResult> {
    try {
      // Step 1: 获取 VK 结果
      const vkResult = await vaultKeeperAdapter.getJobResult(jobId);

      if (vkResult.status !== 'completed') {
        return {
          success: false,
          originalId,
          fieldsUpdated: [],
          reprocessed: false,
          error: `Job 未完成: ${vkResult.status} - ${vkResult.error ?? ''}`,
        };
      }

      // Step 2: 通过 original_id 找到 SourceItem
      const sourceItem = storage.getSourceItemByOriginalId(originalId);
      if (!sourceItem) {
        return {
          success: false,
          originalId,
          fieldsUpdated: [],
          reprocessed: false,
          error: `找不到对应的 SourceItem: ${originalId}`,
        };
      }

      // Step 3: 回填字段到 metadata
      const fieldsUpdated = this.ingestFields(sourceItem.id, vkResult);

      // 更新 external_processing_status
      this.updateProcessingStatus(sourceItem.id, 'completed', jobId);

      logger.info('app', 'externalResultIngestion', 'ingested',
        `结果回填成功: ${sourceItem.id}`, {
          jobId,
          originalId,
          fieldsUpdated,
        });

      // Step 4: 触发重新 AI 整理
      let reprocessed = false;
      if (fieldsUpdated.length > 0) {
        try {
          await this.triggerReprocessing(sourceItem.id, originalId);
          reprocessed = true;
        } catch (reprocessError) {
          logger.warn('app', 'externalResultIngestion', 'reprocess-failed',
            '重新整理失败，但结果已回填', {
              sourceItemId: sourceItem.id,
              error: reprocessError instanceof Error ? reprocessError.message : String(reprocessError),
            });
        }
      }

      return {
        success: true,
        sourceItemId: sourceItem.id,
        originalId,
        fieldsUpdated,
        reprocessed,
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'externalResultIngestion', 'ingest-failed',
        `结果回填失败: ${errorMsg}`, { jobId, originalId });

      errorService.createRecord({
        errorType: 'external_result_ingest_failed',
        originalId,
        stage: 'vk_ingest',
        message: errorMsg,
        userMessage: `VaultKeeper 结果回填失败: ${errorMsg}`,
        retryable: true,
      });

      return {
        success: false,
        originalId,
        fieldsUpdated: [],
        reprocessed: false,
        error: errorMsg,
      };
    }
  }

  /**
   * 仅靠 external_job_id 定位记录并回填结果。
   * 遍历 SourceItem 查找 metadata.external_job_id 匹配的记录。
   */
  async ingestByJobId(jobId: string): Promise<IngestionResult> {
    logger.info('app', 'externalResultIngestion', 'ingest-by-job-id', '通过 job_id 定位并回填', {
      jobId,
    });

    // 查找匹配的 SourceItem
    const sourceItem = storage.findSourceItemByMetadata('external_job_id', jobId);
    if (!sourceItem) {
      return {
        success: false,
        fieldsUpdated: [],
        reprocessed: false,
        error: `找不到 external_job_id=${jobId} 对应的 SourceItem`,
      };
    }

    const originalId = sourceItem.originalId;
    if (!originalId) {
      return {
        success: false,
        fieldsUpdated: [],
        reprocessed: false,
        error: `SourceItem ${sourceItem.id} 没有 originalId`,
      };
    }
    return this.ingestResult(jobId, originalId);
  }

  /**
   * 手动触发结果回填（从 UI 调用）。
   * 支持两种模式：
   * 1. 同时提供 jobId + originalId → 直接回填
   * 2. 仅提供 jobId → 通过 metadata 查找 originalId
   */
  async manualIngest(jobId: string, originalId?: string): Promise<IngestionResult> {
    logger.info('app', 'externalResultIngestion', 'manual-ingest', '手动触发结果回填', {
      jobId,
      originalId,
    });
    if (originalId) {
      return this.ingestResult(jobId, originalId);
    }
    return this.ingestByJobId(jobId);
  }

  // -------------------------------------------------------------------------
  // 内部方法
  // -------------------------------------------------------------------------

  /**
   * 将 VK 结果字段回填到 SourceItem 的 metadata。
   * 返回实际更新的字段名列表。
   */
  private ingestFields(sourceItemId: string, vkResult: VKJobResult): string[] {
    const fieldsUpdated: string[] = [];

    if (vkResult.extracted_text && vkResult.extracted_text.trim().length > 0) {
      this.writeMetadataField(sourceItemId, 'extracted_text', vkResult.extracted_text);
      fieldsUpdated.push('extracted_text');
    }

    if (vkResult.transcript_text && vkResult.transcript_text.trim().length > 0) {
      this.writeMetadataField(sourceItemId, 'transcript_text', vkResult.transcript_text);
      fieldsUpdated.push('transcript_text');
    }

    if (vkResult.parsed_markdown && vkResult.parsed_markdown.trim().length > 0) {
      this.writeMetadataField(sourceItemId, 'parsed_markdown', vkResult.parsed_markdown);
      fieldsUpdated.push('parsed_markdown');
    }

    if (vkResult.extracted_title) {
      this.writeMetadataField(sourceItemId, 'extracted_title', vkResult.extracted_title);
      fieldsUpdated.push('extracted_title');
    }

    return fieldsUpdated;
  }

  /**
   * 写入 metadata 字段到 SourceItem。
   * 通过 storage.updateSourceItem 更新 metadata 对象。
   */
  private writeMetadataField(sourceItemId: string, field: string, value: string): void {
    try {
      const existing = storage.getSourceItem(sourceItemId);
      if (!existing) return;

      // metadata 存储在 SourceItem.metadata 对象中
      const existingMeta = existing.metadata ?? {};
      storage.updateSourceItem(sourceItemId, {
        metadata: {
          ...existingMeta,
          [field]: value,
        },
      });

      logger.info('app', 'externalResultIngestion', 'write-field', `写入 ${field}`, {
        sourceItemId,
        fieldLength: value.length,
      });
    } catch (error) {
      logger.warn('app', 'externalResultIngestion', 'write-field-failed', `写入 ${field} 失败`, {
        sourceItemId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * 更新 SourceItem 的 external_processing_status。
   */
  private updateProcessingStatus(
    sourceItemId: string,
    status: 'completed' | 'failed' | 'processing',
    jobId: string,
  ): void {
    try {
      const existing = storage.getSourceItem(sourceItemId);
      if (!existing) return;

      const existingMeta = existing.metadata ?? {};
      storage.updateSourceItem(sourceItemId, {
        metadata: {
          ...existingMeta,
          external_processing_status: status,
          external_job_id: jobId,
          external_completed_at: status === 'completed' ? Math.floor(Date.now() / 1000) : undefined,
        },
      });

      logger.info('app', 'externalResultIngestion', 'update-status', `状态更新为 ${status}`, {
        sourceItemId,
        jobId,
      });
    } catch (error) {
      logger.warn('app', 'externalResultIngestion', 'update-status-failed', '状态更新失败', {
        sourceItemId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * 触发重新 AI 整理。
   * 回填结果后，需要重新运行策略处理以生成更好的 Markdown。
   * 使用 regenerateContent 方法，它会重新读取 metadata 中的 VK 结果字段。
   */
  private async triggerReprocessing(sourceItemId: string, originalId: string): Promise<void> {
    logger.info('app', 'externalResultIngestion', 'reprocess', '触发重新 AI 整理', {
      sourceItemId,
      originalId,
    });

    try {
      const { contentPipeline } = await import('../pipeline/contentPipelineService');
      const result = await contentPipeline.regenerateContent(sourceItemId, {});
      if (!result.success) {
        logger.warn('app', 'externalResultIngestion', 'reprocess-no-content', '重新整理未生成内容', {
          sourceItemId,
          error: result.error,
        });
      }
    } catch (error) {
      logger.warn('app', 'externalResultIngestion', 'reprocess-error', '重新整理触发失败', {
        sourceItemId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }
}

export const externalResultIngestionService = new ExternalResultIngestionService();
