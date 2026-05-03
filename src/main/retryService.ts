// AcMind Unified Retry Service (V2.1 Phase 6.3)
// Centralized retry orchestration based on ErrorType.
// Each error type retries from the appropriate pipeline stage,
// ensuring no data loss, no duplicate overwrites, and full state tracking.

import type { ErrorRecord, ErrorType } from '../shared/types';
import { storage } from './storage';
import { logger } from './logger';
import { errorService } from './errorService';
import { contentStateMachine } from './services/pipeline/contentStateMachine';
import { contentPipeline } from './services/pipeline/contentPipelineService';
import { obsidianExporter } from './services/exporter/obsidianExporter';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_RETRY_COUNT = 10;

/** Maps each ErrorType to the stage from which retry should begin */
const RETRY_STAGE_MAP: Record<ErrorType, string> = {
  capture_failed: 'capture',
  process_failed: 'processing',
  export_failed: 'exporting',
  permission_required: 'exporting',
  conflict_pending: 'exporting',
  template_missing: 'exporting',
  vault_missing: 'exporting',
  model_unavailable: 'processing',
  // Phase 9.7: VaultKeeper 错误重试阶段
  vaultkeeper_unavailable: 'processing',
  external_job_failed: 'processing',
  external_result_invalid: 'processing',
  external_result_ingest_failed: 'processing',
  unknown_error: 'processing',
};

// ---------------------------------------------------------------------------
// RetryResult
// ---------------------------------------------------------------------------

export interface RetryResult {
  success: boolean;
  error_id: string;
  error_type: ErrorType;
  retry_count: number;
  message: string;
  user_message: string;
  /** The source item ID that was retried (if applicable) */
  source_item_id?: string;
}

// ---------------------------------------------------------------------------
// RetryService
// ---------------------------------------------------------------------------

class RetryService {
  /**
   * Retry an error based on its type.
   * This is the single entry point for all retry operations.
   */
  async retry(errorId: string): Promise<RetryResult> {
    // 1. Fetch the error record
    const record = errorService.getRecord(errorId);
    if (!record) {
      return this.fail(errorId, 'unknown_error', '未找到错误记录', '未找到对应的错误记录。');
    }

    // 2. Check if already resolved
    if (record.status !== 'open') {
      return this.fail(errorId, record.error_type, '错误已处理', '此错误已被解决或忽略，无需重试。');
    }

    // 3. Check retry count limit
    if (record.retry_count >= MAX_RETRY_COUNT) {
      return this.fail(errorId, record.error_type, '重试次数已达上限', `此错误已重试 ${record.retry_count} 次，请检查根本原因后再试。`, false);
    }

    // 4. Increment retry count
    const newRetryCount = errorService.incrementRetryCount(errorId);

    // 5. Find the source item by original_id
    let sourceItemId = this.findSourceItemId(record);
    if (!sourceItemId) {
      return this.fail(errorId, record.error_type, '未找到原始内容', '无法找到关联的内容记录，原始内容可能已被删除。');
    }

    // 6. Check current state is valid for retry
    const currentState = contentStateMachine.getCurrentState(sourceItemId);
    if (!contentStateMachine.canRetry(sourceItemId)) {
      return this.fail(errorId, record.error_type, '当前状态不允许重试', `内容当前状态为"${currentState}"，无法从该状态重试。`);
    }

    // 7. Dispatch to the appropriate retry handler based on error type
    logger.info('app', 'retryService', 'retry', `Retrying error ${errorId}`, {
      errorType: record.error_type,
      originalId: record.original_id,
      sourceItemId,
      retryCount: newRetryCount,
      currentState,
    });

    try {
      const result = await this.dispatchRetry(record, sourceItemId);
      return result;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'retryService', 'retry', `Retry failed for ${errorId}`, {
        error: errorMsg,
        errorType: record.error_type,
      });
      return this.fail(errorId, record.error_type, '重试失败', errorMsg);
    }
  }

  // -------------------------------------------------------------------------
  // Private: dispatch retry by error type
  // -------------------------------------------------------------------------

  private async dispatchRetry(record: ErrorRecord, sourceItemId: string): Promise<RetryResult> {
    switch (record.error_type) {
      case 'process_failed':
      case 'model_unavailable':
        return this.retryFromProcessing(record, sourceItemId);
      case 'export_failed':
      case 'permission_required':
      case 'conflict_pending':
      case 'template_missing':
      case 'vault_missing':
        return this.retryFromExporting(record, sourceItemId);
      case 'capture_failed':
        return this.fail(record.error_id, record.error_type, '捕获暂不支持重试', '捕获失败需要手动重新捕获内容。');
      case 'unknown_error':
        // Try from processing as a safe default
        return this.retryFromProcessing(record, sourceItemId);
      default:
        return this.fail(record.error_id, record.error_type, '不支持的错误类型', '此错误类型暂不支持自动重试。');
    }
  }

  /**
   * Retry from the processing stage:
   *   processing → structured → exporting → exported
   * Re-reads original content, re-organizes, then exports.
   */
  private async retryFromProcessing(record: ErrorRecord, sourceItemId: string): Promise<RetryResult> {
    const result = await contentPipeline.retryExport(sourceItemId);

    if (result.success) {
      errorService.resolveRecord(record.error_id);
      logger.info('app', 'retryService', 'retryFromProcessing', `Retry succeeded: ${record.error_id}`, {
        sourceItemId,
        outputPath: result.outputPath,
      });
      return {
        success: true,
        error_id: record.error_id,
        error_type: record.error_type,
        retry_count: record.retry_count + 1,
        message: '重试成功',
        user_message: '内容已成功重新整理并写入 Obsidian。',
        source_item_id: sourceItemId,
      };
    }

    // Retry failed — a new error was already recorded by contentPipeline.retryExport
    return {
      success: false,
      error_id: record.error_id,
      error_type: record.error_type,
      retry_count: record.retry_count + 1,
      message: result.error ?? '重试整理失败',
      user_message: '重新整理失败，请稍后重试或检查内容。',
      source_item_id: sourceItemId,
    };
  }

  /**
   * Retry from the exporting stage:
   *   exporting → exported
   * Re-generates Markdown and writes to Obsidian.
   * Does NOT re-organize content.
   */
  private async retryFromExporting(record: ErrorRecord, sourceItemId: string): Promise<RetryResult> {
    // Check if there's an existing export record to use the DistilledOutput path
    const exportRecords = storage.getExportRecords({ sourceItemId });
    const failedRecord = exportRecords.find((r) => r.status === 'failed');
    const conflictRecord = exportRecords.find((r) => r.status === 'conflict');

    if (failedRecord?.distilledOutputId) {
      // Use the ObsidianExporter path (DistilledOutput-based)
      try {
        const newRecord = obsidianExporter.retryExport(failedRecord.id);
        if (newRecord.status === 'success') {
          errorService.resolveRecord(record.error_id);
          logger.info('app', 'retryService', 'retryFromExporting', `Retry via exporter succeeded: ${record.error_id}`, {
            sourceItemId,
            exportRecordId: newRecord.id,
          });
          return {
            success: true,
            error_id: record.error_id,
            error_type: record.error_type,
            retry_count: record.retry_count + 1,
            message: '重试成功',
            user_message: '内容已成功重新写入 Obsidian。',
            source_item_id: sourceItemId,
          };
        }
        // Exporter returned a non-success record (conflict, etc.)
        return {
          success: false,
          error_id: record.error_id,
          error_type: record.error_type,
          retry_count: record.retry_count + 1,
          message: newRecord.error ?? '导出未成功',
          user_message: newRecord.error ?? '写入 Obsidian 未成功，请检查后重试。',
          source_item_id: sourceItemId,
        };
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        errorService.recordError({
          errorType: record.error_type,
          originalId: record.original_id,
          outputId: record.output_id,
          stage: 'retry_exporting',
          error,
          userMessage: '重新写入 Obsidian 失败，请检查仓库路径和权限。',
        });
        return {
          success: false,
          error_id: record.error_id,
          error_type: record.error_type,
          retry_count: record.retry_count + 1,
          message: errorMsg,
          user_message: '重新写入 Obsidian 失败，请检查仓库路径和权限。',
          source_item_id: sourceItemId,
        };
      }
    }

    if (conflictRecord?.distilledOutputId) {
      // Conflict case — try with force=true
      try {
        const newRecord = obsidianExporter.retryExport(conflictRecord.id);
        if (newRecord.status === 'success') {
          errorService.resolveRecord(record.error_id);
          return {
            success: true,
            error_id: record.error_id,
            error_type: record.error_type,
            retry_count: record.retry_count + 1,
            message: '重试成功',
            user_message: '冲突已解决，内容已成功写入 Obsidian。',
            source_item_id: sourceItemId,
          };
        }
        return {
          success: false,
          error_id: record.error_id,
          error_type: record.error_type,
          retry_count: record.retry_count + 1,
          message: '冲突仍未解决',
          user_message: '文件冲突仍然存在，请手动处理冲突后重试。',
          source_item_id: sourceItemId,
        };
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        return {
          success: false,
          error_id: record.error_id,
          error_type: record.error_type,
          retry_count: record.retry_count + 1,
          message: errorMsg,
          user_message: '处理冲突时出错，请稍后重试。',
          source_item_id: sourceItemId,
        };
      }
    }

    // Fallback: use the pipeline retryExport (re-organize + export)
    const result = await contentPipeline.retryExport(sourceItemId);
    if (result.success) {
      errorService.resolveRecord(record.error_id);
      return {
        success: true,
        error_id: record.error_id,
        error_type: record.error_type,
        retry_count: record.retry_count + 1,
        message: '重试成功',
        user_message: '内容已成功重新写入 Obsidian。',
        source_item_id: sourceItemId,
      };
    }

    return {
      success: false,
      error_id: record.error_id,
      error_type: record.error_type,
      retry_count: record.retry_count + 1,
      message: result.error ?? '重试导出失败',
      user_message: '重新写入失败，请检查仓库配置后重试。',
      source_item_id: sourceItemId,
    };
  }

  // -------------------------------------------------------------------------
  // Private: helpers
  // -------------------------------------------------------------------------

  private findSourceItemId(record: ErrorRecord): string | null {
    if (record.original_id) {
      const sourceItem = storage.getSourceItemByOriginalId(record.original_id);
      if (sourceItem) return sourceItem.id;
    }
    if (record.output_id) {
      // output_id might be a distilled_output_id or export_record id
      const exportRecords = storage.getExportRecords({});
      const match = exportRecords.find((r) => r.id === record.output_id || r.distilledOutputId === record.output_id);
      if (match) return match.sourceItemId;
    }
    return null;
  }

  private fail(
    errorId: string,
    errorType: ErrorType,
    message: string,
    user_message: string,
    retryable = true,
  ): RetryResult {
    return {
      success: false,
      error_id: errorId,
      error_type: errorType,
      retry_count: 0,
      message,
      user_message,
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const retryService = new RetryService();
