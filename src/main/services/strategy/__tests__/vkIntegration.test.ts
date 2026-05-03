// VaultKeeper 策略集成测试
// Phase 9: 测试 6 种策略的 postProcess 行为
// 重点：失败占位、字段回填、不覆盖旧占位文件

import { describe, it, expect, vi } from 'vitest';

// Mock dependencies that strategies import
vi.mock('../../logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() },
}));

vi.mock('../../errors', () => ({
  PinError: class PinError extends Error {
    code: string;
    constructor(code: string, message: string) {
      super(message);
      this.code = code;
    }
  },
}));

import { WebpageStrategy } from '../strategies/webpageStrategy';
import { PdfStrategy } from '../strategies/pdfStrategy';
import { DocxStrategy } from '../strategies/docxStrategy';
import { ImageStrategy } from '../strategies/imageStrategy';
import { AudioStrategy } from '../strategies/audioStrategy';
import { VideoStrategy } from '../strategies/videoStrategy';
import type { StrategyInput } from '../types';

const webpageStrategy = new WebpageStrategy();
const pdfStrategy = new PdfStrategy();
const docxStrategy = new DocxStrategy();
const imageStrategy = new ImageStrategy();
const audioStrategy = new AudioStrategy();
const videoStrategy = new VideoStrategy();

function makeInput(overrides: Partial<StrategyInput> = {}): StrategyInput {
  return {
    source_type: 'manual_text',
    content: '',
    ...overrides,
  };
}

/**
 * 构造 AI 原始输出（postProcess 的第一个参数 raw）
 * 使用 snake_case 字段名，与 ProcessedContent 一致
 */
function makeRaw(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    title: 'Test Title',
    summary: 'Test summary',
    tags: ['test'],
    body_markdown: 'Test body',
    suggested_folder: 'Inbox',
    quality_flags: [],
    ...overrides,
  };
}

// =========================================================================
// Webpage Strategy
// =========================================================================

describe('WebpageStrategy — VK integration', () => {
  it('should extract domain tag from source_url', () => {
    const input = makeInput({ source_url: 'https://example.com/article' });
    const raw = makeRaw();
    const processed = webpageStrategy.postProcess(raw, input);
    expect(processed.tags).toContain('example.com');
  });

  it('should remove placeholder flag when parsed_markdown exists', () => {
    const input = makeInput({
      source_type: 'webpage',
      source_url: 'https://example.com',
      parsed_markdown: '# Article\n\nFull content',
    });
    const raw = makeRaw({ quality_flags: ['placeholder'] });
    const processed = webpageStrategy.postProcess(raw, input);
    expect(processed.quality_flags).not.toContain('placeholder');
  });

  it('should keep placeholder flag when no parsed_markdown and no content', () => {
    const input = makeInput({
      source_type: 'webpage',
      source_url: 'https://example.com',
      content: '',
    });
    const raw = makeRaw({ quality_flags: ['placeholder'] });
    const processed = webpageStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('placeholder');
  });

  it('should add placeholder flag when content is empty and no parsed_markdown', () => {
    const input = makeInput({
      source_type: 'webpage',
      source_url: 'https://example.com',
      content: '',
    });
    const raw = makeRaw({ quality_flags: [] });
    const processed = webpageStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('placeholder');
    expect(processed.summary).toContain('等待后续处理');
  });
});

// =========================================================================
// PDF Strategy
// =========================================================================

describe('PDFStrategy — VK integration', () => {
  it('should generate placeholder with needs_ocr hint via metadata', () => {
    const input = makeInput({
      source_type: 'pdf',
      raw_file_path: '/tmp/scanned.pdf',
      metadata: { processing_hint: 'needs_ocr' },
    });
    const raw = makeRaw();
    const processed = pdfStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('placeholder');
    expect(processed.quality_flags).toContain('incomplete');
    expect(processed.tags).toContain('待OCR');
  });

  it('should generate placeholder with 待解析 tag when no OCR hint', () => {
    const input = makeInput({
      source_type: 'pdf',
      raw_file_path: '/tmp/text.pdf',
    });
    const raw = makeRaw();
    const processed = pdfStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('placeholder');
    expect(processed.quality_flags).toContain('incomplete');
    expect(processed.tags).toContain('待解析');
  });

  it('should not generate placeholder when parsed_markdown exists', () => {
    const input = makeInput({
      source_type: 'pdf',
      raw_file_path: '/tmp/text.pdf',
      parsed_markdown: '# PDF Content\n\nExtracted text',
    });
    const raw = makeRaw({ quality_flags: ['placeholder', 'incomplete'] });
    const processed = pdfStrategy.postProcess(raw, input);
    expect(processed.quality_flags).not.toContain('placeholder');
    expect(processed.quality_flags).not.toContain('incomplete');
  });

  it('should preserve file path in placeholder body', () => {
    const input = makeInput({
      source_type: 'pdf',
      raw_file_path: '/tmp/important.pdf',
    });
    const raw = makeRaw();
    const processed = pdfStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('/tmp/important.pdf');
  });
});

// =========================================================================
// DOCX Strategy
// =========================================================================

describe('DOCXStrategy — VK integration', () => {
  it('should remove placeholder and incomplete flags when parsed_markdown exists', () => {
    const input = makeInput({
      source_type: 'docx',
      raw_file_path: '/tmp/test.docx',
      parsed_markdown: '# DOCX Heading\n\nDOCX content',
    });
    const raw = makeRaw({ quality_flags: ['placeholder', 'incomplete'] });
    const processed = docxStrategy.postProcess(raw, input);
    expect(processed.quality_flags).not.toContain('placeholder');
    expect(processed.quality_flags).not.toContain('incomplete');
  });

  it('should keep placeholder flag when no parsed_markdown', () => {
    const input = makeInput({
      source_type: 'docx',
      raw_file_path: '/tmp/test.docx',
    });
    const raw = makeRaw();
    const processed = docxStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('placeholder');
    expect(processed.quality_flags).toContain('incomplete');
  });

  it('should preserve file path in placeholder body', () => {
    const input = makeInput({
      source_type: 'docx',
      raw_file_path: '/tmp/report.docx',
    });
    const raw = makeRaw();
    const processed = docxStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('/tmp/report.docx');
  });
});

// =========================================================================
// Image Strategy
// =========================================================================

describe('ImageStrategy — VK integration', () => {
  it('should add OCR source annotation when extracted_text exists', () => {
    const input = makeInput({
      source_type: 'image',
      raw_file_path: '/tmp/test.png',
      extracted_text: 'OCR extracted text from image',
    });
    const raw = makeRaw({ body_markdown: 'Some body' });
    const processed = imageStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('🖼️ 来源：图片（OCR 提取）');
    // Strategy prepends annotation to raw body_markdown, doesn't inject extracted_text
    expect(processed.body_markdown).toContain('Some body');
  });

  it('should remove needs_ocr and placeholder flags when extracted_text exists', () => {
    const input = makeInput({
      source_type: 'image',
      raw_file_path: '/tmp/test.png',
      extracted_text: 'OCR text',
    });
    const raw = makeRaw({ quality_flags: ['needs_ocr', 'placeholder'] });
    const processed = imageStrategy.postProcess(raw, input);
    expect(processed.quality_flags).not.toContain('needs_ocr');
    expect(processed.quality_flags).not.toContain('placeholder');
  });

  it('should generate placeholder with needs_ocr when no extracted_text', () => {
    const input = makeInput({
      source_type: 'image',
      raw_file_path: '/tmp/test.png',
    });
    const raw = makeRaw();
    const processed = imageStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('needs_ocr');
    expect(processed.quality_flags).toContain('placeholder');
  });

  it('should preserve image path in placeholder body', () => {
    const input = makeInput({
      source_type: 'image',
      raw_file_path: '/tmp/test.png',
    });
    const raw = makeRaw();
    const processed = imageStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('/tmp/test.png');
  });
});

// =========================================================================
// Audio Strategy
// =========================================================================

describe('AudioStrategy — VK integration', () => {
  it('should add transcription source annotation when transcript_text exists', () => {
    const input = makeInput({
      source_type: 'audio',
      raw_file_path: '/tmp/test.mp3',
      transcript_text: 'Audio transcript content',
    });
    const raw = makeRaw({ body_markdown: 'Some body' });
    const processed = audioStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('🎤 来源：语音转写');
    // Strategy prepends annotation to raw body_markdown, doesn't inject transcript_text
    expect(processed.body_markdown).toContain('Some body');
  });

  it('should remove needs_transcription and placeholder flags when transcript_text exists', () => {
    const input = makeInput({
      source_type: 'audio',
      raw_file_path: '/tmp/test.mp3',
      transcript_text: 'Transcript',
    });
    const raw = makeRaw({ quality_flags: ['needs_transcription', 'placeholder'] });
    const processed = audioStrategy.postProcess(raw, input);
    expect(processed.quality_flags).not.toContain('needs_transcription');
    expect(processed.quality_flags).not.toContain('placeholder');
  });

  it('should generate placeholder with needs_transcription when no transcript_text', () => {
    const input = makeInput({
      source_type: 'audio',
      raw_file_path: '/tmp/test.mp3',
    });
    const raw = makeRaw();
    const processed = audioStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('needs_transcription');
    expect(processed.quality_flags).toContain('placeholder');
  });

  it('should preserve audio path in placeholder body', () => {
    const input = makeInput({
      source_type: 'audio',
      raw_file_path: '/tmp/test.mp3',
    });
    const raw = makeRaw();
    const processed = audioStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('/tmp/test.mp3');
  });
});

// =========================================================================
// Video Strategy
// =========================================================================

describe('VideoStrategy — VK integration', () => {
  it('should add transcription source annotation when transcript_text exists', () => {
    const input = makeInput({
      source_type: 'video',
      raw_file_path: '/tmp/test.mp4',
      transcript_text: 'Video transcript content',
    });
    const raw = makeRaw({ body_markdown: 'Some body' });
    const processed = videoStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('🎬 来源：视频转写');
    // Strategy prepends annotation to raw body_markdown, doesn't inject transcript_text
    expect(processed.body_markdown).toContain('Some body');
  });

  it('should remove needs_transcription and placeholder flags when transcript_text exists', () => {
    const input = makeInput({
      source_type: 'video',
      raw_file_path: '/tmp/test.mp4',
      transcript_text: 'Transcript',
    });
    const raw = makeRaw({ quality_flags: ['needs_transcription', 'placeholder'] });
    const processed = videoStrategy.postProcess(raw, input);
    expect(processed.quality_flags).not.toContain('needs_transcription');
    expect(processed.quality_flags).not.toContain('placeholder');
  });

  it('should generate placeholder with needs_transcription when no transcript_text', () => {
    const input = makeInput({
      source_type: 'video',
      raw_file_path: '/tmp/test.mp4',
    });
    const raw = makeRaw();
    const processed = videoStrategy.postProcess(raw, input);
    expect(processed.quality_flags).toContain('needs_transcription');
    expect(processed.quality_flags).toContain('placeholder');
  });

  it('should preserve video path in placeholder body', () => {
    const input = makeInput({
      source_type: 'video',
      raw_file_path: '/tmp/test.mp4',
    });
    const raw = makeRaw();
    const processed = videoStrategy.postProcess(raw, input);
    expect(processed.body_markdown).toContain('/tmp/test.mp4');
  });
});
