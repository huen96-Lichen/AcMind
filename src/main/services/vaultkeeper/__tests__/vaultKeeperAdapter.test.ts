// ExternalProcessorAdapter 单元测试
// Phase 9: 测试 HTTP 通信、结果标准化、错误标准化、健康检查降级

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// Mock settings before importing adapter
vi.mock('../../../settings', () => ({
  settings: {
    getExternalProcessorSettings: vi.fn(() => ({
      enabled: true,
      endpoint: 'http://localhost:9800',
      timeout: 5000,
      apiKey: undefined,
    })),
  },
}));

vi.mock('../../../logger', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    debug: vi.fn(),
  },
}));

// Mock global fetch
const mockFetch = vi.fn();
(globalThis as any).fetch = mockFetch;

import { vaultKeeperAdapter } from '../vaultKeeperAdapter';
import type { VKJobType } from '../types';

describe('ExternalProcessorAdapter', () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  // =========================================================================
  // checkHealth
  // =========================================================================

  describe('checkHealth', () => {
    it('should return available=true when health endpoint responds OK', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          version: '1.0.0',
          supported_job_types: ['webpage_extract', 'pdf_parse', 'image_ocr'],
        }),
      });

      const result = await vaultKeeperAdapter.checkHealth();
      expect(result.available).toBe(true);
      expect(result.connection_method).toBe('http');
      expect(result.version).toBe('1.0.0');
      expect(result.supported_job_types).toContain('webpage_extract');
      expect(result.supported_job_types).toContain('pdf_parse');
      expect(result.supported_job_types).toContain('image_ocr');
    });

    it('should return available=false when health endpoint returns error', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 503,
        statusText: 'Service Unavailable',
        json: async () => ({ error: 'Service unavailable' }),
      });

      const result = await vaultKeeperAdapter.checkHealth();
      expect(result.available).toBe(false);
      expect(result.connection_method).toBe('http');
      expect(result.error).toContain('Service unavailable');
    });

    it('should return available=false when fetch throws (network error)', async () => {
      mockFetch.mockRejectedValueOnce(new Error('ECONNREFUSED'));

      const result = await vaultKeeperAdapter.checkHealth();
      expect(result.available).toBe(false);
      expect(result.error).toContain('ECONNREFUSED');
    });
  });

  // =========================================================================
  // submitJob
  // =========================================================================

  describe('submitJob', () => {
    it('should submit job and return job_id', async () => {
      // First call: checkHealth (cached from previous test or fresh)
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ version: '1.0.0', supported_job_types: ['pdf_parse'] }),
      });
      await vaultKeeperAdapter.checkHealth();

      // Second call: submitJob
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          job_id: 'vk-job-123',
          status: 'pending',
          submitted_at: 1700000000,
        }),
      });

      const result = await vaultKeeperAdapter.submitJob({
        job_type: 'pdf_parse',
        file_path: '/tmp/test.pdf',
        original_id: 'orig-123',
      });

      expect(result.job_id).toBe('vk-job-123');
      expect(result.status).toBe('pending');
      expect(result.submitted_at).toBe(1700000000);
    });

    it('should throw when VK is unavailable', async () => {
      // Set health to unavailable
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 503,
        statusText: 'Service Unavailable',
        json: async () => ({ error: 'down' }),
      });
      await vaultKeeperAdapter.checkHealth();

      await expect(
        vaultKeeperAdapter.submitJob({
          job_type: 'pdf_parse',
          file_path: '/tmp/test.pdf',
          original_id: 'orig-123',
        }),
      ).rejects.toThrow('外部处理服务不可用');
    });

    it('should throw when submit endpoint returns error', async () => {
      // Set health to available
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ version: '1.0.0', supported_job_types: ['pdf_parse'] }),
      });
      await vaultKeeperAdapter.checkHealth();

      // Submit fails
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 400,
        statusText: 'Bad Request',
        json: async () => ({ error: 'Invalid job_type' }),
      });

      await expect(
        vaultKeeperAdapter.submitJob({
          job_type: 'pdf_parse',
          file_path: '/tmp/test.pdf',
          original_id: 'orig-123',
        }),
      ).rejects.toThrow('Invalid job_type');
    });
  });

  // =========================================================================
  // getJobStatus
  // =========================================================================

  describe('getJobStatus', () => {
    it('should return job status', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          status: 'processing',
          progress: 50,
          submitted_at: 1700000000,
          started_at: 1700000010,
        }),
      });

      const result = await vaultKeeperAdapter.getJobStatus('vk-job-123');
      expect(result.job_id).toBe('vk-job-123');
      expect(result.status).toBe('processing');
      expect(result.progress).toBe(50);
      expect(result.submitted_at).toBe(1700000000);
      expect(result.started_at).toBe(1700000010);
    });

    it('should throw when job not found', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 404,
        statusText: 'Not Found',
        json: async () => ({ error: 'Job not found' }),
      });

      await expect(
        vaultKeeperAdapter.getJobStatus('nonexistent'),
      ).rejects.toThrow('Job not found');
    });
  });

  // =========================================================================
  // getJobResult
  // =========================================================================

  describe('getJobResult', () => {
    it('should return normalized result for pdf_parse', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          job_type: 'pdf_parse',
          status: 'completed',
          markdown: '# PDF Title\n\nPDF content',
          text: 'PDF Title PDF content',
          title: 'PDF Title',
          completed_at: 1700000100,
        }),
      });

      const result = await vaultKeeperAdapter.getJobResult('vk-job-123');
      expect(result.job_id).toBe('vk-job-123');
      expect(result.job_type).toBe('pdf_parse');
      expect(result.status).toBe('completed');
      expect(result.parsed_markdown).toContain('# PDF Title');
      expect(result.extracted_text).toContain('PDF Title');
      expect(result.extracted_title).toBe('PDF Title');
    });

    it('should return normalized result for image_ocr', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          job_type: 'image_ocr',
          status: 'completed',
          text: 'OCR extracted text',
          completed_at: 1700000100,
        }),
      });

      const result = await vaultKeeperAdapter.getJobResult('vk-job-456');
      expect(result.job_type).toBe('image_ocr');
      expect(result.extracted_text).toBe('OCR extracted text');
      expect(result.transcript_text).toBeUndefined();
      expect(result.parsed_markdown).toBeUndefined();
    });

    it('should return normalized result for audio_transcribe', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          job_type: 'audio_transcribe',
          status: 'completed',
          transcript: 'Hello world, this is a transcript.',
          completed_at: 1700000100,
        }),
      });

      const result = await vaultKeeperAdapter.getJobResult('vk-job-789');
      expect(result.job_type).toBe('audio_transcribe');
      expect(result.transcript_text).toBe('Hello world, this is a transcript.');
      expect(result.extracted_text).toBeUndefined();
    });

    it('should return normalized result for video_transcribe', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          job_type: 'video_transcribe',
          status: 'completed',
          transcript: 'Video transcript text',
          completed_at: 1700000100,
        }),
      });

      const result = await vaultKeeperAdapter.getJobResult('vk-job-vid');
      expect(result.job_type).toBe('video_transcribe');
      expect(result.transcript_text).toBe('Video transcript text');
    });

    it('should return normalized result for webpage_extract', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          job_type: 'webpage_extract',
          status: 'completed',
          markdown: '# Article Title\n\nArticle body',
          text: 'Article Title Article body',
          title: 'Article Title',
          completed_at: 1700000100,
        }),
      });

      const result = await vaultKeeperAdapter.getJobResult('vk-job-web');
      expect(result.job_type).toBe('webpage_extract');
      expect(result.parsed_markdown).toContain('# Article Title');
      expect(result.extracted_title).toBe('Article Title');
    });

    it('should return normalized result for docx_parse', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          job_type: 'docx_parse',
          status: 'completed',
          markdown: '# DOCX Heading\n\nDOCX content',
          text: 'DOCX Heading DOCX content',
          completed_at: 1700000100,
        }),
      });

      const result = await vaultKeeperAdapter.getJobResult('vk-job-docx');
      expect(result.job_type).toBe('docx_parse');
      expect(result.parsed_markdown).toContain('# DOCX Heading');
    });
  });

  // =========================================================================
  // cancelJob
  // =========================================================================

  describe('cancelJob', () => {
    it('should return true on successful cancel', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ success: true }),
      });

      const result = await vaultKeeperAdapter.cancelJob('vk-job-123');
      expect(result).toBe(true);
    });

    it('should throw on cancel failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 400,
        statusText: 'Bad Request',
        json: async () => ({ error: 'Cannot cancel completed job' }),
      });

      await expect(
        vaultKeeperAdapter.cancelJob('vk-job-123'),
      ).rejects.toThrow('Cannot cancel completed job');
    });
  });

  // =========================================================================
  // normalizeResult
  // =========================================================================

  describe('normalizeResult', () => {
    it('should normalize webpage_extract raw result', () => {
      const raw = { markdown: '# Title\n\nBody', text: 'Title Body', title: 'Title' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'webpage_extract', 'job-1');
      expect(result.parsed_markdown).toBe('# Title\n\nBody');
      expect(result.extracted_text).toBe('Title Body');
      expect(result.extracted_title).toBe('Title');
      expect(result.job_type).toBe('webpage_extract');
    });

    it('should normalize image_ocr raw result', () => {
      const raw = { text: 'OCR text' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'image_ocr', 'job-2');
      expect(result.extracted_text).toBe('OCR text');
      expect(result.transcript_text).toBeUndefined();
    });

    it('should normalize audio_transcribe raw result', () => {
      const raw = { transcript: 'Audio transcript' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'audio_transcribe', 'job-3');
      expect(result.transcript_text).toBe('Audio transcript');
      expect(result.extracted_text).toBeUndefined();
    });

    it('should normalize video_transcribe raw result', () => {
      const raw = { transcript: 'Video transcript' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'video_transcribe', 'job-4');
      expect(result.transcript_text).toBe('Video transcript');
    });

    it('should normalize pdf_parse raw result', () => {
      const raw = { markdown: '# PDF\n\nContent', text: 'PDF Content' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'pdf_parse', 'job-5');
      expect(result.parsed_markdown).toBe('# PDF\n\nContent');
      expect(result.extracted_text).toBe('PDF Content');
    });

    it('should normalize docx_parse raw result', () => {
      const raw = { markdown: '# DOCX\n\nContent', text: 'DOCX Content' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'docx_parse', 'job-6');
      expect(result.parsed_markdown).toBe('# DOCX\n\nContent');
    });

    it('should normalize file_convert raw result', () => {
      const raw = { markdown: 'Converted content' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'file_convert', 'job-7');
      expect(result.parsed_markdown).toBe('Converted content');
    });

    it('should preserve raw_result for debugging', () => {
      const raw = { text: 'OCR', extra: 'debug info' };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'image_ocr', 'job-8');
      expect(result.raw_result).toEqual(raw);
    });

    it('should extract metadata when present', () => {
      const raw = { text: 'OCR', metadata: { page_count: 5, language: 'zh' } };
      const result = vaultKeeperAdapter.normalizeResult(raw, 'image_ocr', 'job-9');
      expect(result.extracted_metadata).toEqual({ page_count: 5, language: 'zh' });
    });
  });

  // =========================================================================
  // normalizeError
  // =========================================================================

  describe('normalizeError', () => {
    it('should normalize Error object', () => {
      const result = vaultKeeperAdapter.normalizeError(new Error('Connection failed'), 'job-1');
      expect(result.status).toBe('failed');
      expect(result.error).toBe('Connection failed');
      expect(result.job_id).toBe('job-1');
    });

    it('should normalize string error', () => {
      const result = vaultKeeperAdapter.normalizeError('Something went wrong', 'job-2');
      expect(result.status).toBe('failed');
      expect(result.error).toBe('Something went wrong');
    });

    it('should handle unknown error type', () => {
      const result = vaultKeeperAdapter.normalizeError(42, 'job-3');
      expect(result.status).toBe('failed');
      expect(result.error).toBe('42');
    });
  });
});
