// ProcessingJobService
// Phase 9.2: 根据 CaptureRecord 判断是否需要 VaultKeeper 处理，提交 Job
//
// 职责：
// - 判断 CaptureRecord 是否需要提交 VaultKeeper
// - 异步提交 Job（不阻塞主流程）
// - 可靠写回 external_job_id / external_processor / external_processing_status 到 SourceItem metadata
// - 提交失败时记录错误但不阻塞 pipeline
//
// 不负责：
// - 结果回填（由 ExternalResultIngestionService 处理）
// - Markdown 渲染
// - Obsidian 写入

import type { CaptureRecord, SourceType } from '../../../shared/types';
import { logger } from '../../logger';
import { errorService } from '../../errorService';
import { storage } from '../../storage';
import { vaultKeeperAdapter } from './vaultKeeperAdapter';
import type { VKJobType, VKSubmitJobRequest } from './types';

// ---------------------------------------------------------------------------
// SourceType → VKJobType 映射表
// ---------------------------------------------------------------------------

const SOURCE_TYPE_TO_JOB_TYPE: Partial<Record<SourceType, VKJobType>> = {
  webpage: 'webpage_extract',
  pdf: 'pdf_parse',
  docx: 'docx_parse',
  image: 'image_ocr',
  audio: 'audio_transcribe',
  video: 'video_transcribe',
};

// ---------------------------------------------------------------------------
// processing_hint → VKJobType 映射（补充 source_type 未覆盖的情况）
// ---------------------------------------------------------------------------

const HINT_TO_JOB_TYPE: Record<string, VKJobType> = {
  needs_ocr: 'image_ocr',
  needs_transcription: 'audio_transcribe',
  needs_video_transcription: 'video_transcribe',
  needs_document_parse: 'pdf_parse',
};

// ---------------------------------------------------------------------------
// ProcessingJobService
// ---------------------------------------------------------------------------

class ProcessingJobService {
  /**
   * 判断 CaptureRecord 是否需要提交 VaultKeeper 处理。
   * 返回 VKJobType 或 null（不需要外部处理）。
   */
  determineJobType(record: CaptureRecord): VKJobType | null {
    const meta = record.metadata ?? {};
    const hint = meta.processing_hint as string | undefined;
    const ext = (meta.extension as string)?.toLowerCase();

    // screenshot + needs_ocr → image_ocr
    if (record.source_type === 'screenshot' && hint === 'needs_ocr') {
      return 'image_ocr';
    }

    // 优先用 source_type 映射（排除 screenshot，已单独处理）
    if (record.source_type !== 'screenshot') {
      const bySourceType = SOURCE_TYPE_TO_JOB_TYPE[record.source_type];
      if (bySourceType) {
        return bySourceType;
      }
    }

    // 用 processing_hint 补充
    if (hint && hint !== 'none' && hint !== 'needs_manual_review') {
      const jobType = HINT_TO_JOB_TYPE[hint];
      if (jobType) {
        // 修正 needs_document_parse: .docx → docx_parse
        if (hint === 'needs_document_parse' && (ext === '.docx' || ext === '.doc')) {
          return 'docx_parse';
        }
        return jobType;
      }
    }

    return null;
  }

  /**
   * 异步提交 Job 到 VaultKeeper。
   * 不阻塞主流程；失败时记录错误但不抛出。
   * 可靠写回 external_job_id / external_processor / external_processing_status 到 SourceItem metadata。
   *
   * @param record CaptureRecord
   * @param sourceItemId 对应的 SourceItem ID（用于写回 metadata）
   * @returns job_id 或 null（提交失败/不需要处理）
   */
  async submitJob(record: CaptureRecord, sourceItemId?: string): Promise<string | null> {
    const jobType = this.determineJobType(record);
    if (!jobType) {
      logger.info('app', 'processingJobService', 'skip', '不需要 VaultKeeper 处理', {
        sourceType: record.source_type,
        originalId: record.original_id,
      });
      return null;
    }

    // 检查是否已有 job_id（避免重复提交）
    const meta = record.metadata ?? {};
    if (meta.external_job_id) {
      logger.info('app', 'processingJobService', 'already-submitted', '已有 external_job_id', {
        jobId: meta.external_job_id,
        originalId: record.original_id,
      });
      return meta.external_job_id as string;
    }

    const request: VKSubmitJobRequest = {
      job_type: jobType,
      file_path: record.raw_file_path,
      url: record.raw_url,
      original_id: record.original_id,
      options: {
        extension: meta.extension,
        mime_type: meta.mime_type,
        filename: meta.filename,
      },
    };

    try {
      const response = await vaultKeeperAdapter.submitJob(request);

      logger.info('app', 'processingJobService', 'submitted', `Job 提交成功: ${response.job_id}`, {
        jobType,
        originalId: record.original_id,
        jobId: response.job_id,
      });

      // 可靠写回 metadata
      if (sourceItemId) {
        this.writeMetadata(sourceItemId, {
          external_job_id: response.job_id,
          external_processor: 'vaultkeeper',
          external_processing_status: 'processing',
          external_job_type: jobType,
          external_submitted_at: response.submitted_at,
        });
      }

      return response.job_id;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.warn('app', 'processingJobService', 'submit-failed', `Job 提交失败: ${errorMsg}`, {
        jobType,
        originalId: record.original_id,
      });

      // 写入失败状态
      if (sourceItemId) {
        this.writeMetadata(sourceItemId, {
          external_processor: 'vaultkeeper',
          external_processing_status: 'failed',
          external_job_type: jobType,
          external_error: errorMsg,
        });
      }

      // VaultKeeper 不可用时优雅降级：记录错误但不阻塞
      errorService.createRecord({
        errorType: 'vaultkeeper_unavailable',
        originalId: record.original_id,
        stage: 'vk_submit',
        message: errorMsg,
        userMessage: `VaultKeeper 任务提交失败: ${errorMsg}`,
        retryable: true,
      });

      return null;
    }
  }

  /**
   * 将 VK 相关字段写入 SourceItem metadata。
   * 使用增量合并，不覆盖已有字段。
   */
  private writeMetadata(sourceItemId: string, fields: Record<string, unknown>): void {
    try {
      const existing = storage.getSourceItem(sourceItemId);
      if (!existing) {
        logger.warn('app', 'processingJobService', 'write-meta-fail', 'SourceItem not found', { sourceItemId });
        return;
      }
      const currentMeta = (existing.metadata ?? {}) as Record<string, unknown>;
      const merged = { ...currentMeta, ...fields };
      storage.updateSourceItem(sourceItemId, { metadata: merged });
      logger.info('app', 'processingJobService', 'write-meta', 'Metadata 写回成功', {
        sourceItemId,
        fields: Object.keys(fields),
      });
    } catch (error) {
      logger.error('error', 'processingJobService', 'write-meta-fail', 'Metadata 写回失败', {
        sourceItemId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}

export const processingJobService = new ProcessingJobService();
