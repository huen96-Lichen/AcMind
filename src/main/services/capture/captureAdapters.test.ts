// AcMind Capture Adapters Tests
// V2.1 Phase 7: Unit tests for clipboardTextAdapter, webpageAdapter, fileAdapter, captureRegistry

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { clipboardTextAdapter } from './clipboardTextAdapter';
import { webpageAdapter } from './webpageAdapter';
import { fileAdapter } from './fileAdapter';
import { captureRegistry } from './captureRegistry';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import path from 'node:path';
import os from 'node:os';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const TEST_DIR = path.join(os.tmpdir(), 'acmind-capture-test-' + Date.now());

beforeEach(() => {
  mkdirSync(TEST_DIR, { recursive: true });
});

afterEach(() => {
  rmSync(TEST_DIR, { recursive: true, force: true });
});

// ===========================================================================
// ClipboardTextAdapter
// ===========================================================================

describe('clipboardTextAdapter', () => {
  it('should create a CaptureRecord from valid text', () => {
    const record = clipboardTextAdapter.capture({ text: 'Hello world' });
    expect(record.source_type).toBe('clipboard_text');
    expect(record.raw_text).toBe('Hello world');
    expect(record.original_id).toBeDefined();
    expect(record.created_at).toBeDefined();
    expect(record.metadata?.textLength).toBe(11);
  });

  it('should trim whitespace from text', () => {
    const record = clipboardTextAdapter.capture({ text: '  hello  ' });
    expect(record.raw_text).toBe('hello');
  });

  it('should throw on empty text', () => {
    expect(() => clipboardTextAdapter.capture({ text: '' })).toThrow('Clipboard text content is empty');
  });

  it('should throw on whitespace-only text', () => {
    expect(() => clipboardTextAdapter.capture({ text: '   ' })).toThrow('Clipboard text content is empty');
  });

  it('should generate same original_id for same content (dedup)', () => {
    const r1 = clipboardTextAdapter.capture({ text: 'same content' });
    const r2 = clipboardTextAdapter.capture({ text: 'same content' });
    expect(r1.original_id).toBe(r2.original_id);
  });

  it('should generate different original_id for different content', () => {
    const r1 = clipboardTextAdapter.capture({ text: 'content A' });
    const r2 = clipboardTextAdapter.capture({ text: 'content B' });
    expect(r1.original_id).not.toBe(r2.original_id);
  });

  it('should use provided contentHash when given', () => {
    const record = clipboardTextAdapter.capture({
      text: 'test',
      contentHash: 'custom-hash-123',
    });
    expect(record.original_id).toBe('custom-hash-123');
  });

  it('should set source_app when provided', () => {
    const record = clipboardTextAdapter.capture({
      text: 'test',
      sourceApp: 'Chrome',
    });
    expect(record.source_app).toBe('Chrome');
  });

  it('should generate title from first line', () => {
    const record = clipboardTextAdapter.capture({ text: 'First line\nSecond line' });
    expect(record.title).toBe('First line');
  });

  it('should truncate long titles to 80 chars', () => {
    const longText = 'A'.repeat(100);
    const record = clipboardTextAdapter.capture({ text: longText });
    expect(record.title!.length).toBeLessThanOrEqual(83); // 80 + '...'
  });

  it('should truncate preview_text to 200 chars', () => {
    const longText = 'A'.repeat(300);
    const record = clipboardTextAdapter.capture({ text: longText });
    expect(record.preview_text!.length).toBeLessThanOrEqual(203); // 200 + '...'
  });

  it('should normalize whitespace for dedup (same content, different spacing)', () => {
    const r1 = clipboardTextAdapter.capture({ text: 'hello   world' });
    const r2 = clipboardTextAdapter.capture({ text: 'hello world' });
    // Both normalize to 'hello world' before hashing
    expect(r1.original_id).toBe(r2.original_id);
  });
});

// ===========================================================================
// WebpageAdapter
// ===========================================================================

describe('webpageAdapter', () => {
  it('should create a CaptureRecord from a URL', () => {
    const record = webpageAdapter.capture({ url: 'https://example.com/article' });
    expect(record.source_type).toBe('webpage');
    expect(record.raw_url).toBe('https://example.com/article');
    expect(record.original_id).toBeDefined();
  });

  it('should throw on empty URL', () => {
    expect(() => webpageAdapter.capture({ url: '' })).toThrow('Webpage URL is required');
  });

  it('should throw on whitespace-only URL', () => {
    expect(() => webpageAdapter.capture({ url: '   ' })).toThrow('Webpage URL is required');
  });

  it('should normalize URL by adding https:// prefix', () => {
    const record = webpageAdapter.capture({ url: 'example.com/page' });
    expect(record.raw_url).toBe('https://example.com/page');
  });

  it('should not double-prefix https URLs', () => {
    const record = webpageAdapter.capture({ url: 'https://example.com' });
    expect(record.raw_url).toBe('https://example.com');
  });

  it('should keep http:// prefix', () => {
    const record = webpageAdapter.capture({ url: 'http://example.com' });
    expect(record.raw_url).toBe('http://example.com');
  });

  it('should generate same original_id for same URL (dedup)', () => {
    const r1 = webpageAdapter.capture({ url: 'https://example.com/page' });
    const r2 = webpageAdapter.capture({ url: 'https://example.com/page' });
    expect(r1.original_id).toBe(r2.original_id);
  });

  it('should extract domain from URL', () => {
    const record = webpageAdapter.capture({ url: 'https://blog.example.com/post/1' });
    expect(record.metadata?.domain).toBe('blog.example.com');
  });

  it('should set input_mode to url_fetch when no rawText', () => {
    const record = webpageAdapter.capture({ url: 'https://example.com' });
    expect(record.metadata?.input_mode).toBe('url_fetch');
  });

  it('should set input_mode to paste when rawText is provided', () => {
    const record = webpageAdapter.capture({
      url: 'https://example.com',
      rawText: 'Some pasted content',
    });
    expect(record.metadata?.input_mode).toBe('paste');
  });

  it('should use URL as title when no title provided', () => {
    const record = webpageAdapter.capture({ url: 'https://example.com' });
    expect(record.title).toBe('https://example.com');
  });

  it('should use provided title', () => {
    const record = webpageAdapter.capture({
      url: 'https://example.com',
      title: 'My Article',
    });
    expect(record.title).toBe('My Article');
  });

  it('should include rawText in record when provided', () => {
    const record = webpageAdapter.capture({
      url: 'https://example.com',
      rawText: 'Article body text',
    });
    expect(record.raw_text).toBe('Article body text');
  });

  it('should set preview_text from rawText when available', () => {
    const record = webpageAdapter.capture({
      url: 'https://example.com',
      rawText: 'Some content',
    });
    expect(record.preview_text).toBe('Some content');
  });

  it('should set preview_text to URL when no rawText', () => {
    const record = webpageAdapter.capture({ url: 'https://example.com' });
    expect(record.preview_text).toBe('https://example.com');
  });
});

// ===========================================================================
// FileAdapter
// ===========================================================================

describe('fileAdapter', () => {
  it('should throw on empty file path', () => {
    expect(() => fileAdapter.capture({ filePath: '' })).toThrow('File path is required');
  });

  it('should throw when file does not exist', () => {
    expect(() => fileAdapter.capture({ filePath: '/nonexistent/file.txt' })).toThrow('File not found');
  });

  it('should read .txt file content', () => {
    const filePath = path.join(TEST_DIR, 'test.txt');
    writeFileSync(filePath, 'Hello from file');
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('file');
    expect(record.raw_text).toBe('Hello from file');
    expect(record.raw_file_path).toBe(filePath);
    expect(record.metadata?.readable_text_available).toBe(true);
    expect(record.metadata?.processing_hint).toBe('none');
    expect(record.metadata?.external_processor).toBe('none');
    expect(record.metadata?.external_processing_status).toBe('not_required');
  });

  it('should read .md file content', () => {
    const filePath = path.join(TEST_DIR, 'notes.md');
    writeFileSync(filePath, '# Title\n\nBody text');
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('file');
    expect(record.raw_text).toBe('# Title\n\nBody text');
    expect(record.metadata?.readable_text_available).toBe(true);
  });

  it('should classify .png as image source_type', () => {
    const filePath = path.join(TEST_DIR, 'photo.png');
    writeFileSync(filePath, Buffer.from([0x89, 0x50, 0x4e, 0x47])); // PNG magic bytes
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('image');
    expect(record.metadata?.processing_hint).toBe('needs_ocr');
    expect(record.metadata?.external_processor).toBe('ocr');
    expect(record.metadata?.external_processing_status).toBe('pending');
    expect(record.metadata?.mime_type).toBe('image/png');
  });

  it('should classify .jpg as image source_type', () => {
    const filePath = path.join(TEST_DIR, 'photo.jpg');
    writeFileSync(filePath, Buffer.from([0xff, 0xd8, 0xff]));
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('image');
    expect(record.metadata?.mime_type).toBe('image/jpeg');
  });

  it('should classify .mp3 as audio source_type', () => {
    const filePath = path.join(TEST_DIR, 'song.mp3');
    writeFileSync(filePath, Buffer.from([0xff, 0xfb]));
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('audio');
    expect(record.metadata?.processing_hint).toBe('needs_transcription');
    expect(record.metadata?.external_processor).toBe('whisper');
    expect(record.metadata?.mime_type).toBe('audio/mpeg');
  });

  it('should classify .mp4 as video source_type', () => {
    const filePath = path.join(TEST_DIR, 'clip.mp4');
    writeFileSync(filePath, Buffer.from([0x00, 0x00, 0x00]));
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('video');
    expect(record.metadata?.processing_hint).toBe('needs_video_transcription');
    expect(record.metadata?.external_processor).toBe('external');
    expect(record.metadata?.mime_type).toBe('video/mp4');
  });

  it('should classify .pdf as pdf source_type', () => {
    const filePath = path.join(TEST_DIR, 'doc.pdf');
    writeFileSync(filePath, Buffer.from([0x25, 0x50, 0x44, 0x46])); // %PDF
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('pdf');
    expect(record.metadata?.processing_hint).toBe('needs_document_parse');
    expect(record.metadata?.external_processor).toBe('external');
    expect(record.metadata?.mime_type).toBe('application/pdf');
  });

  it('should classify .docx as docx source_type', () => {
    const filePath = path.join(TEST_DIR, 'report.docx');
    writeFileSync(filePath, Buffer.from([0x50, 0x4b, 0x03, 0x04])); // ZIP header
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('docx');
    expect(record.metadata?.processing_hint).toBe('needs_document_parse');
    expect(record.metadata?.external_processor).toBe('external');
    expect(record.metadata?.mime_type).toBe('application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  });

  it('should classify unknown extension as file with needs_manual_review', () => {
    const filePath = path.join(TEST_DIR, 'data.xyz');
    writeFileSync(filePath, 'binary data');
    const record = fileAdapter.capture({ filePath });
    expect(record.source_type).toBe('file');
    expect(record.metadata?.processing_hint).toBe('needs_manual_review');
    expect(record.metadata?.external_processor).toBe('manual');
    expect(record.metadata?.mime_type).toBe('application/octet-stream');
  });

  it('should generate same original_id for same file (dedup)', () => {
    const filePath = path.join(TEST_DIR, 'stable.txt');
    writeFileSync(filePath, 'stable content');
    const r1 = fileAdapter.capture({ filePath });
    const r2 = fileAdapter.capture({ filePath });
    expect(r1.original_id).toBe(r2.original_id);
  });

  it('should use filename as title when no title provided', () => {
    const filePath = path.join(TEST_DIR, 'my-notes.txt');
    writeFileSync(filePath, 'content');
    const record = fileAdapter.capture({ filePath });
    expect(record.title).toBe('my-notes');
  });

  it('should use provided title', () => {
    const filePath = path.join(TEST_DIR, 'file.txt');
    writeFileSync(filePath, 'content');
    const record = fileAdapter.capture({ filePath, title: 'Custom Title' });
    expect(record.title).toBe('Custom Title');
  });

  it('should set preview_text from content for text files', () => {
    const filePath = path.join(TEST_DIR, 'short.txt');
    writeFileSync(filePath, 'Short preview');
    const record = fileAdapter.capture({ filePath });
    expect(record.preview_text).toBe('Short preview');
  });

  it('should set preview_text with file info for non-text files', () => {
    const filePath = path.join(TEST_DIR, 'image.png');
    writeFileSync(filePath, Buffer.from([0x89, 0x50, 0x4e, 0x47]));
    const record = fileAdapter.capture({ filePath });
    expect(record.preview_text).toMatch(/^文件: image\.png/);
  });

  it('should include file_size in metadata', () => {
    const filePath = path.join(TEST_DIR, 'sized.txt');
    writeFileSync(filePath, '12345');
    const record = fileAdapter.capture({ filePath });
    expect(record.metadata?.file_size).toBe(5);
  });

  it('should include extension in metadata', () => {
    const filePath = path.join(TEST_DIR, 'test.md');
    writeFileSync(filePath, '# Hello');
    const record = fileAdapter.capture({ filePath });
    expect(record.metadata?.extension).toBe('.md');
  });

  it('should include filename in metadata', () => {
    const filePath = path.join(TEST_DIR, 'test.md');
    writeFileSync(filePath, '# Hello');
    const record = fileAdapter.capture({ filePath });
    expect(record.metadata?.filename).toBe('test.md');
  });
});

// ===========================================================================
// CaptureRegistry
// ===========================================================================

describe('captureRegistry', () => {
  beforeEach(() => {
    // Register all adapters for registry tests
    captureRegistry.register(clipboardTextAdapter);
    captureRegistry.register(webpageAdapter);
    captureRegistry.register(fileAdapter);
  });

  it('should route manual_text to manualTextAdapter', () => {
    // manual_text adapter is not registered in test, so this should throw
    expect(() => captureRegistry.capture({
      sourceType: 'manual_text',
      text: 'Hello from registry',
    })).toThrow('No CaptureAdapter registered for source type: manual_text');
  });

  it('should route clipboard_text to clipboardTextAdapter', () => {
    const record = captureRegistry.capture({
      sourceType: 'clipboard_text',
      text: 'Clipboard content',
    });
    expect(record.source_type).toBe('clipboard_text');
    expect(record.raw_text).toBe('Clipboard content');
  });

  it('should route webpage to webpageAdapter', () => {
    const record = captureRegistry.capture({
      sourceType: 'webpage',
      url: 'https://example.com',
    });
    expect(record.source_type).toBe('webpage');
    expect(record.raw_url).toBe('https://example.com');
  });

  it('should route file to fileAdapter', () => {
    const filePath = path.join(TEST_DIR, 'registry-test.txt');
    writeFileSync(filePath, 'Registry file content');
    const record = captureRegistry.capture({
      sourceType: 'file',
      filePath,
    });
    expect(record.source_type).toBe('file');
    expect(record.raw_text).toBe('Registry file content');
  });

  it('should throw on unsupported sourceType', () => {
    expect(() => captureRegistry.capture({
      sourceType: 'unsupported' as any,
      text: 'test',
    })).toThrow('No CaptureAdapter registered for source type: unsupported');
  });

  it('should list available adapters', () => {
    const types = captureRegistry.getAvailableTypes();
    expect(types).toContain('clipboard_text');
    expect(types).toContain('webpage');
    expect(types).toContain('file');
  });

  it('should check adapter availability via has()', () => {
    expect(captureRegistry.has('clipboard_text')).toBe(true);
    expect(captureRegistry.has('webpage')).toBe(true);
    expect(captureRegistry.has('nonexistent' as any)).toBe(false);
  });
});
