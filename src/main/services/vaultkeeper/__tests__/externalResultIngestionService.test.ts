// ExternalResultIngestionService 单元测试
// Phase 9: 测试结果回填、ingestByJobId、失败占位、不覆盖旧占位文件

import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../../../logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() },
}));

vi.mock('../../../errorService', () => ({
  errorService: { createRecord: vi.fn() },
}));

vi.mock('../../../storage', () => ({
  storage: {
    getSourceItemByOriginalId: vi.fn(),
    findSourceItemByMetadata: vi.fn(),
    getSourceItem: vi.fn(),
    updateSourceItem: vi.fn(),
    insertContentStateHistory: vi.fn(),
  },
}));

vi.mock('../vaultKeeperAdapter', () => ({
  vaultKeeperAdapter: {
    getJobResult: vi.fn(),
    getJobStatus: vi.fn(),
  },
}));

vi.mock('../../pipeline/contentPipelineService', () => ({
  contentPipeline: {
    regenerateContent: vi.fn().mockResolvedValue({ id: 'regen-1' }),
  },
}));

import { externalResultIngestionService } from '../externalResultIngestionService';
import { vaultKeeperAdapter } from '../vaultKeeperAdapter';
import { storage } from '../../../storage';
import { errorService } from '../../../errorService';
import { contentPipeline } from '../../pipeline/contentPipelineService';

/**
 * Helper: set up storage.getSourceItem to return the same item
 * that getSourceItemByOriginalId returns (needed by writeMetadataField / updateProcessingStatus).
 */
function mockSourceItem(item: { id: string; originalId: string; metadata: Record<string, unknown> }) {
  vi.mocked(storage.getSourceItemByOriginalId).mockReturnValue(item as any);
  vi.mocked(storage.getSourceItem).mockReturnValue(item as any);
}

describe('ExternalResultIngestionService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // =========================================================================
  // ingestResult — 基本回填
  // =========================================================================

  describe('ingestResult', () => {
    it('should backfill extracted_text for OCR result', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-1',
        job_type: 'image_ocr',
        status: 'completed',
        extracted_text: 'OCR extracted text',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-1',
        originalId: 'orig-1',
        metadata: { external_job_id: 'vk-job-1', external_processing_status: 'processing' },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-1', 'orig-1');

      expect(result.success).toBe(true);
      expect(result.fieldsUpdated).toContain('extracted_text');
      expect(result.reprocessed).toBe(true);

      // Verify metadata update was called (writeMetadataField + updateProcessingStatus)
      expect(storage.updateSourceItem).toHaveBeenCalled();
      // Verify reprocessing triggered
      expect(contentPipeline.regenerateContent).toHaveBeenCalledWith('si-1', {});
    });

    it('should backfill transcript_text for audio result', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-2',
        job_type: 'audio_transcribe',
        status: 'completed',
        transcript_text: 'Audio transcript content',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-2',
        originalId: 'orig-2',
        metadata: { external_job_id: 'vk-job-2' },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-2', 'orig-2');

      expect(result.success).toBe(true);
      expect(result.fieldsUpdated).toContain('transcript_text');
      expect(storage.updateSourceItem).toHaveBeenCalled();
    });

    it('should backfill transcript_text for video result', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-vid',
        job_type: 'video_transcribe',
        status: 'completed',
        transcript_text: 'Video transcript content',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-vid',
        originalId: 'orig-vid',
        metadata: { external_job_id: 'vk-job-vid' },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-vid', 'orig-vid');

      expect(result.success).toBe(true);
      expect(result.fieldsUpdated).toContain('transcript_text');
    });

    it('should backfill parsed_markdown for PDF result', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-3',
        job_type: 'pdf_parse',
        status: 'completed',
        parsed_markdown: '# PDF Title\n\nPDF content',
        extracted_text: 'PDF Title PDF content',
        extracted_title: 'PDF Title',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-3',
        originalId: 'orig-3',
        metadata: { external_job_id: 'vk-job-3' },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-3', 'orig-3');

      expect(result.success).toBe(true);
      expect(result.fieldsUpdated).toContain('parsed_markdown');
      expect(result.fieldsUpdated).toContain('extracted_text');
      expect(result.fieldsUpdated).toContain('extracted_title');
    });

    it('should backfill parsed_markdown for DOCX result', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-docx',
        job_type: 'docx_parse',
        status: 'completed',
        parsed_markdown: '# DOCX Heading\n\nDOCX content',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-docx',
        originalId: 'orig-docx',
        metadata: { external_job_id: 'vk-job-docx' },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-docx', 'orig-docx');

      expect(result.success).toBe(true);
      expect(result.fieldsUpdated).toContain('parsed_markdown');
    });

    it('should backfill parsed_markdown for webpage result', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-web',
        job_type: 'webpage_extract',
        status: 'completed',
        parsed_markdown: '# Article\n\nArticle body',
        extracted_title: 'Article',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-web',
        originalId: 'orig-web',
        metadata: { external_job_id: 'vk-job-web' },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-web', 'orig-web');

      expect(result.success).toBe(true);
      expect(result.fieldsUpdated).toContain('parsed_markdown');
      expect(result.fieldsUpdated).toContain('extracted_title');
    });
  });

  // =========================================================================
  // 失败占位 — VK 不可用时
  // =========================================================================

  describe('failure handling', () => {
    it('should return failure when SourceItem not found', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-404',
        job_type: 'pdf_parse',
        status: 'completed',
        parsed_markdown: 'content',
      });

      vi.mocked(storage.getSourceItemByOriginalId).mockReturnValue(null);

      const result = await externalResultIngestionService.ingestResult('vk-job-404', 'nonexistent');

      expect(result.success).toBe(false);
      expect(result.error).toContain('找不到');
      expect(storage.updateSourceItem).not.toHaveBeenCalled();
    });

    it('should return failure when VK job result has error status', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-fail',
        job_type: 'pdf_parse',
        status: 'failed',
        error: 'File corrupted',
      });

      // Note: implementation returns early when status !== 'completed',
      // without calling errorService.createRecord (that's only in the catch block)
      const result = await externalResultIngestionService.ingestResult('vk-job-fail', 'orig-fail');

      expect(result.success).toBe(false);
      expect(result.error).toContain('File corrupted');
      // errorService.createRecord is NOT called for non-completed status
      expect(errorService.createRecord).not.toHaveBeenCalled();
    });

    it('should return success with empty fieldsUpdated when VK result has no usable content', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-empty',
        job_type: 'image_ocr',
        status: 'completed',
        // No extracted_text, transcript_text, or parsed_markdown
      });

      mockSourceItem({
        id: 'si-empty',
        originalId: 'orig-empty',
        metadata: {},
      });

      // Implementation returns success=true when job completed, just with empty fieldsUpdated
      const result = await externalResultIngestionService.ingestResult('vk-job-empty', 'orig-empty');

      expect(result.success).toBe(true);
      expect(result.fieldsUpdated).toHaveLength(0);
      expect(result.reprocessed).toBe(false);
    });

    it('should record error when getJobResult throws', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockRejectedValue(
        new Error('Network timeout'),
      );

      const result = await externalResultIngestionService.ingestResult('vk-job-err', 'orig-err');

      expect(result.success).toBe(false);
      expect(result.error).toContain('Network timeout');
      expect(errorService.createRecord).toHaveBeenCalledWith(
        expect.objectContaining({ errorType: 'external_result_ingest_failed' }),
      );
    });
  });

  // =========================================================================
  // 不覆盖旧占位文件
  // =========================================================================

  describe('non-overwrite behavior', () => {
    it('should not overwrite existing non-placeholder metadata fields', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-nooverwrite',
        job_type: 'image_ocr',
        status: 'completed',
        extracted_text: 'New OCR text',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-nooverwrite',
        originalId: 'orig-nooverwrite',
        metadata: {
          external_job_id: 'vk-job-nooverwrite',
          existing_field: 'should_be_preserved',
          another_field: 42,
        },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-nooverwrite', 'orig-nooverwrite');

      expect(result.success).toBe(true);

      // writeMetadataField calls updateSourceItem with spread of existing metadata + new field
      // Find the call that wrote extracted_text
      const calls = vi.mocked(storage.updateSourceItem).mock.calls;
      const extractedTextCall = calls.find(
        (call) => typeof call[1] === 'object' && call[1] !== null && 'metadata' in call[1] &&
          (call[1] as any).metadata?.extracted_text === 'New OCR text',
      );
      expect(extractedTextCall).toBeDefined();
      const updatedMeta = (extractedTextCall![1] as any).metadata;
      expect(updatedMeta.existing_field).toBe('should_be_preserved');
      expect(updatedMeta.another_field).toBe(42);
      expect(updatedMeta.extracted_text).toBe('New OCR text');
    });

    it('should preserve existing extracted_text when new result has none', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-preserve',
        job_type: 'pdf_parse',
        status: 'completed',
        parsed_markdown: '# New parsed content',
        // No extracted_text in result
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-preserve',
        originalId: 'orig-preserve',
        metadata: {
          external_job_id: 'vk-job-preserve',
          extracted_text: 'Old OCR text that should be preserved',
        },
      });

      const result = await externalResultIngestionService.ingestResult('vk-job-preserve', 'orig-preserve');

      expect(result.success).toBe(true);

      // Find the call that wrote parsed_markdown
      const calls = vi.mocked(storage.updateSourceItem).mock.calls;
      const parsedCall = calls.find(
        (call) => typeof call[1] === 'object' && call[1] !== null && 'metadata' in call[1] &&
          (call[1] as any).metadata?.parsed_markdown === '# New parsed content',
      );
      expect(parsedCall).toBeDefined();
      const updatedMeta = (parsedCall![1] as any).metadata;
      // Old extracted_text should be preserved since new result didn't provide one
      expect(updatedMeta.extracted_text).toBe('Old OCR text that should be preserved');
      expect(updatedMeta.parsed_markdown).toBe('# New parsed content');
    });
  });

  // =========================================================================
  // ingestByJobId — 仅靠 job_id 定位
  // =========================================================================

  describe('ingestByJobId', () => {
    it('should find SourceItem by metadata and ingest', async () => {
      vi.mocked(storage.findSourceItemByMetadata).mockReturnValue({
        id: 'si-byjob',
        originalId: 'orig-byjob',
        metadata: { external_job_id: 'vk-job-byjob' },
      } as any);

      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-byjob',
        job_type: 'image_ocr',
        status: 'completed',
        extracted_text: 'Found by job id',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-byjob',
        originalId: 'orig-byjob',
        metadata: { external_job_id: 'vk-job-byjob' },
      });

      const result = await externalResultIngestionService.ingestByJobId('vk-job-byjob');

      expect(result.success).toBe(true);
      expect(storage.findSourceItemByMetadata).toHaveBeenCalledWith('external_job_id', 'vk-job-byjob');
    });

    it('should return failure when no SourceItem found by job_id', async () => {
      vi.mocked(storage.findSourceItemByMetadata).mockReturnValue(null);

      const result = await externalResultIngestionService.ingestByJobId('nonexistent-job');

      expect(result.success).toBe(false);
      expect(result.error).toContain('找不到');
    });

    it('should return failure when SourceItem has no originalId', async () => {
      vi.mocked(storage.findSourceItemByMetadata).mockReturnValue({
        id: 'si-no-orig',
        originalId: undefined,
        metadata: {},
      } as any);

      const result = await externalResultIngestionService.ingestByJobId('vk-job-no-orig');

      expect(result.success).toBe(false);
      expect(result.error).toContain('没有 originalId');
    });
  });

  // =========================================================================
  // manualIngest
  // =========================================================================

  describe('manualIngest', () => {
    it('should delegate to ingestResult when both jobId and originalId provided', async () => {
      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-manual',
        job_type: 'image_ocr',
        status: 'completed',
        extracted_text: 'Manual ingest text',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-manual',
        originalId: 'orig-manual',
        metadata: { external_job_id: 'vk-job-manual' },
      });

      const result = await externalResultIngestionService.manualIngest('vk-job-manual', 'orig-manual');

      expect(result.success).toBe(true);
      expect(storage.findSourceItemByMetadata).not.toHaveBeenCalled();
    });

    it('should delegate to ingestByJobId when only jobId provided', async () => {
      vi.mocked(storage.findSourceItemByMetadata).mockReturnValue({
        id: 'si-auto',
        originalId: 'orig-auto',
        metadata: { external_job_id: 'vk-job-auto' },
      } as any);

      vi.mocked(vaultKeeperAdapter.getJobResult).mockResolvedValue({
        job_id: 'vk-job-auto',
        job_type: 'pdf_parse',
        status: 'completed',
        parsed_markdown: '# Auto found',
        completed_at: 1700000100,
      });

      mockSourceItem({
        id: 'si-auto',
        originalId: 'orig-auto',
        metadata: { external_job_id: 'vk-job-auto' },
      });

      const result = await externalResultIngestionService.manualIngest('vk-job-auto');

      expect(result.success).toBe(true);
      expect(storage.findSourceItemByMetadata).toHaveBeenCalledWith('external_job_id', 'vk-job-auto');
    });
  });
});
