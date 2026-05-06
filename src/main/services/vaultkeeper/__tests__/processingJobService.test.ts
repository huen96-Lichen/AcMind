// ProcessingJobService 单元测试
// Phase 9: 测试 determineJobType 映射、submitJob metadata 写回、失败占位

import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { CaptureRecord } from '../../../../shared/types';

// Mock dependencies
vi.mock('../../../logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() },
}));

vi.mock('../../../errorService', () => ({
  errorService: { createRecord: vi.fn() },
}));

vi.mock('../../../storage', () => ({
  storage: {
    getSourceItem: vi.fn(),
    updateSourceItem: vi.fn(),
  },
}));

vi.mock('../vaultKeeperAdapter', () => ({
  vaultKeeperAdapter: {
    submitJob: vi.fn(),
    checkHealth: vi.fn(),
  },
}));

import { processingJobService } from '../processingJobService';
import { vaultKeeperAdapter } from '../vaultKeeperAdapter';
import { storage } from '../../../storage';
import { errorService } from '../../../errorService';

function makeCaptureRecord(overrides: Partial<CaptureRecord> = {}): CaptureRecord {
  return {
    id: 'test-id',
    source_type: 'manual_text',
    raw_text: '测试内容',
    created_at: Date.now(),
    original_id: 'test-original-id',
    ...overrides,
  };
}

describe('ProcessingJobService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // =========================================================================
  // determineJobType
  // =========================================================================

  describe('determineJobType', () => {
    it('should return webpage_extract for webpage source_type', () => {
      const record = makeCaptureRecord({ source_type: 'webpage', raw_url: 'https://example.com' });
      expect(processingJobService.determineJobType(record)).toBe('webpage_extract');
    });

    it('should return pdf_parse for pdf source_type', () => {
      const record = makeCaptureRecord({
        source_type: 'pdf',
        raw_file_path: '/tmp/test.pdf',
        metadata: { extension: '.pdf' },
      });
      expect(processingJobService.determineJobType(record)).toBe('pdf_parse');
    });

    it('should return docx_parse for docx source_type', () => {
      const record = makeCaptureRecord({
        source_type: 'docx',
        raw_file_path: '/tmp/test.docx',
        metadata: { extension: '.docx' },
      });
      expect(processingJobService.determineJobType(record)).toBe('docx_parse');
    });

    it('should return image_ocr for image source_type', () => {
      const record = makeCaptureRecord({
        source_type: 'image',
        raw_file_path: '/tmp/test.png',
      });
      expect(processingJobService.determineJobType(record)).toBe('image_ocr');
    });

    it('should return audio_transcribe for audio source_type', () => {
      const record = makeCaptureRecord({
        source_type: 'audio',
        raw_file_path: '/tmp/test.mp3',
      });
      expect(processingJobService.determineJobType(record)).toBe('audio_transcribe');
    });

    it('should return video_transcribe for video source_type', () => {
      const record = makeCaptureRecord({
        source_type: 'video',
        raw_file_path: '/tmp/test.mp4',
      });
      expect(processingJobService.determineJobType(record)).toBe('video_transcribe');
    });

    it('should return image_ocr for screenshot + needs_ocr', () => {
      const record = makeCaptureRecord({
        source_type: 'screenshot',
        raw_file_path: '/tmp/screenshot.png',
        metadata: { processing_hint: 'needs_ocr' },
      });
      expect(processingJobService.determineJobType(record)).toBe('image_ocr');
    });

    it('should return null for manual_text (no VK needed)', () => {
      const record = makeCaptureRecord({ source_type: 'manual_text' });
      expect(processingJobService.determineJobType(record)).toBeNull();
    });

    it('should return null for clipboard_text (no VK needed)', () => {
      const record = makeCaptureRecord({ source_type: 'clipboard_text' });
      expect(processingJobService.determineJobType(record)).toBeNull();
    });

    it('should return null for screenshot without needs_ocr', () => {
      const record = makeCaptureRecord({ source_type: 'screenshot' });
      expect(processingJobService.determineJobType(record)).toBeNull();
    });

    it('should use processing_hint needs_transcription for audio', () => {
      const record = makeCaptureRecord({
        source_type: 'audio',
        metadata: { processing_hint: 'needs_transcription' },
      });
      expect(processingJobService.determineJobType(record)).toBe('audio_transcribe');
    });

    it('should use processing_hint needs_video_transcription for video', () => {
      const record = makeCaptureRecord({
        source_type: 'video',
        metadata: { processing_hint: 'needs_video_transcription' },
      });
      expect(processingJobService.determineJobType(record)).toBe('video_transcribe');
    });

    it('should use processing_hint needs_document_parse for pdf', () => {
      const record = makeCaptureRecord({
        source_type: 'file',
        metadata: { processing_hint: 'needs_document_parse', extension: '.pdf' },
      });
      expect(processingJobService.determineJobType(record)).toBe('pdf_parse');
    });

    it('should use processing_hint needs_document_parse for docx', () => {
      const record = makeCaptureRecord({
        source_type: 'file',
        metadata: { processing_hint: 'needs_document_parse', extension: '.docx' },
      });
      expect(processingJobService.determineJobType(record)).toBe('docx_parse');
    });

    it('should return null for needs_manual_review', () => {
      const record = makeCaptureRecord({
        source_type: 'file',
        metadata: { processing_hint: 'needs_manual_review' },
      });
      expect(processingJobService.determineJobType(record)).toBeNull();
    });

    it('should return null for unknown_file without hint', () => {
      const record = makeCaptureRecord({ source_type: 'unknown_file' });
      expect(processingJobService.determineJobType(record)).toBeNull();
    });
  });

  // =========================================================================
  // submitJob — metadata 写回
  // =========================================================================

  describe('submitJob — metadata writeback', () => {
    it('should write external_job_id, external_processor, external_processing_status on success', async () => {
      const record = makeCaptureRecord({
        source_type: 'pdf',
        raw_file_path: '/tmp/test.pdf',
        metadata: { extension: '.pdf' },
      });

      vi.mocked(storage.getSourceItem).mockReturnValue({
        id: 'si-123',
        metadata: { extension: '.pdf' },
      } as any);

      vi.mocked(vaultKeeperAdapter.submitJob).mockResolvedValue({
        job_id: 'vk-job-001',
        status: 'pending',
        submitted_at: 1700000000,
      });

      const jobId = await processingJobService.submitJob(record, 'si-123');

      expect(jobId).toBe('vk-job-001');
      expect(storage.updateSourceItem).toHaveBeenCalledWith('si-123', {
        metadata: {
          extension: '.pdf',
          external_job_id: 'vk-job-001',
          external_processor: 'external',
          external_processing_status: 'processing',
          external_job_type: 'pdf_parse',
          external_submitted_at: 1700000000,
        },
      });
    });

    it('should write failed status when submitJob throws', async () => {
      const record = makeCaptureRecord({
        source_type: 'pdf',
        raw_file_path: '/tmp/test.pdf',
        metadata: { extension: '.pdf' },
      });

      vi.mocked(storage.getSourceItem).mockReturnValue({
        id: 'si-456',
        metadata: {},
      } as any);

      vi.mocked(vaultKeeperAdapter.submitJob).mockRejectedValue(
        new Error('ECONNREFUSED'),
      );

      const jobId = await processingJobService.submitJob(record, 'si-456');

      expect(jobId).toBeNull();
      expect(storage.updateSourceItem).toHaveBeenCalledWith('si-456', {
        metadata: {
          external_processor: 'external',
          external_processing_status: 'failed',
          external_job_type: 'pdf_parse',
          external_error: 'ECONNREFUSED',
        },
      });
      expect(errorService.createRecord).toHaveBeenCalledWith(
        expect.objectContaining({
          errorType: 'external_service_unavailable',
          originalId: 'test-original-id',
          retryable: true,
        }),
      );
    });

    it('should not submit if external_job_id already exists', async () => {
      const record = makeCaptureRecord({
        source_type: 'pdf',
        raw_file_path: '/tmp/test.pdf',
        metadata: { extension: '.pdf', external_job_id: 'existing-job-id' },
      });

      const jobId = await processingJobService.submitJob(record, 'si-789');

      expect(jobId).toBe('existing-job-id');
      expect(vaultKeeperAdapter.submitJob).not.toHaveBeenCalled();
    });

    it('should return null for types that do not need VK', async () => {
      const record = makeCaptureRecord({ source_type: 'manual_text' });

      const jobId = await processingJobService.submitJob(record, 'si-000');

      expect(jobId).toBeNull();
      expect(vaultKeeperAdapter.submitJob).not.toHaveBeenCalled();
    });

    it('should not write metadata when sourceItemId is not provided', async () => {
      const record = makeCaptureRecord({
        source_type: 'pdf',
        raw_file_path: '/tmp/test.pdf',
        metadata: { extension: '.pdf' },
      });

      vi.mocked(vaultKeeperAdapter.submitJob).mockResolvedValue({
        job_id: 'vk-job-999',
        status: 'pending',
        submitted_at: 1700000000,
      });

      const jobId = await processingJobService.submitJob(record);

      expect(jobId).toBe('vk-job-999');
      expect(storage.updateSourceItem).not.toHaveBeenCalled();
    });
  });
});
