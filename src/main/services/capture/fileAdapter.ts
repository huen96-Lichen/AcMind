// AcMind FileAdapter
// V2.1 Phase 7.1: Captures a file (PDF, DOCX, etc.) into a CaptureRecord.
// V2.1 Phase 7.5: Enhanced with .txt/.md text reading and richer metadata.
// V2.1 Phase 7.6: Auto-classify source_type by extension + processing_hint for VaultKeeper.

import { createHash } from 'node:crypto';
import { existsSync, statSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { CaptureAdapter, CaptureRecord, SourceType, ComplexFileMetadata } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface FileInput {
  filePath: string;
  title?: string;
  sourceApp?: string;
}

// ---------------------------------------------------------------------------
// Extension → SourceType classification
// ---------------------------------------------------------------------------

const IMAGE_EXTENSIONS = new Set(['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.tiff', '.tif', '.ico', '.avif']);
const AUDIO_EXTENSIONS = new Set(['.mp3', '.wav', '.ogg', '.flac', '.aac', '.wma', '.m4a', '.opus']);
const VIDEO_EXTENSIONS = new Set(['.mp4', '.avi', '.mov', '.mkv', '.webm', '.flv', '.wmv', '.m4v']);
const PDF_EXTENSIONS = new Set(['.pdf']);
const DOCX_EXTENSIONS = new Set(['.docx', '.doc']);
const TEXT_EXTENSIONS = new Set(['.txt', '.md', '.markdown', '.text', '.csv', '.json', '.xml', '.html', '.htm', '.yaml', '.yml', '.toml']);

// ---------------------------------------------------------------------------
// Extension → SourceType mapping
// ---------------------------------------------------------------------------

function classifySourceType(ext: string): SourceType {
  if (IMAGE_EXTENSIONS.has(ext)) return 'image';
  if (AUDIO_EXTENSIONS.has(ext)) return 'audio';
  if (VIDEO_EXTENSIONS.has(ext)) return 'video';
  if (PDF_EXTENSIONS.has(ext)) return 'pdf';
  if (DOCX_EXTENSIONS.has(ext)) return 'docx';
  // .txt/.md and other text files stay as 'file' (they have readable text)
  return 'file';
}

// ---------------------------------------------------------------------------
// Extension → processing_hint
// ---------------------------------------------------------------------------

function determineProcessingHint(ext: string, hasReadableText: boolean): ComplexFileMetadata['processing_hint'] {
  if (hasReadableText) return 'none';
  if (IMAGE_EXTENSIONS.has(ext)) return 'needs_ocr';
  if (AUDIO_EXTENSIONS.has(ext)) return 'needs_transcription';
  if (VIDEO_EXTENSIONS.has(ext)) return 'needs_video_transcription';
  if (PDF_EXTENSIONS.has(ext)) return 'needs_document_parse';
  if (DOCX_EXTENSIONS.has(ext)) return 'needs_document_parse';
  return 'needs_manual_review';
}

// ---------------------------------------------------------------------------
// Extension → external_processor
// ---------------------------------------------------------------------------

function determineExternalProcessor(ext: string, hasReadableText: boolean): ComplexFileMetadata['external_processor'] {
  if (hasReadableText) return 'none';
  if (IMAGE_EXTENSIONS.has(ext)) return 'ocr';
  if (AUDIO_EXTENSIONS.has(ext)) return 'whisper';
  if (VIDEO_EXTENSIONS.has(ext)) return 'vaultkeeper';
  if (PDF_EXTENSIONS.has(ext)) return 'vaultkeeper';
  if (DOCX_EXTENSIONS.has(ext)) return 'vaultkeeper';
  return 'manual';
}

// ---------------------------------------------------------------------------
// FileAdapter
// ---------------------------------------------------------------------------

class FileAdapter implements CaptureAdapter<FileInput> {
  readonly sourceType = 'file' as const;

  capture(input: FileInput): CaptureRecord {
    if (!input.filePath) {
      throw new Error('File path is required');
    }

    if (!existsSync(input.filePath)) {
      throw new Error(`File not found: ${input.filePath}`);
    }

    const stat = statSync(input.filePath);
    const ext = path.extname(input.filePath).toLowerCase();
    const fileName = path.basename(input.filePath);

    // Generate hash from file path + size + mtime for dedup
    const hashInput = `${input.filePath}:${stat.size}:${stat.mtimeMs}`;
    const originalId = createHash('sha256')
      .update(hashInput)
      .digest('hex')
      .slice(0, 16);

    const title = input.title?.trim() || fileName.replace(ext, '');

    // V2.1 Phase 7.5: Try to read text content for .txt/.md files
    let rawText: string | undefined;
    let readableTextAvailable = false;

    if (TEXT_EXTENSIONS.has(ext)) {
      try {
        rawText = readFileSync(input.filePath, 'utf8');
        readableTextAvailable = rawText.trim().length > 0;
      } catch {
        rawText = undefined;
        readableTextAvailable = false;
      }
    }

    // V2.1 Phase 7.6: Classify source_type and set processing hints
    const classifiedSourceType = classifySourceType(ext);
    const processingHint = determineProcessingHint(ext, readableTextAvailable);
    const externalProcessor = determineExternalProcessor(ext, readableTextAvailable);

    const metadata: ComplexFileMetadata & Record<string, unknown> = {
      filename: fileName,
      extension: ext,
      mime_type: this.detectMimeType(ext),
      file_size: stat.size,
      imported_at: new Date().toISOString(),
      readable_text_available: readableTextAvailable,
      processing_hint: processingHint,
      external_processor: externalProcessor,
      external_processing_status: readableTextAvailable ? 'not_required' : 'pending',
    };

    return {
      original_id: originalId,
      source_type: classifiedSourceType,
      created_at: new Date().toISOString(),
      raw_file_path: input.filePath,
      raw_text: rawText,
      title: title.length > 80 ? title.slice(0, 80) + '...' : title,
      preview_text: readableTextAvailable && rawText
        ? (rawText.length > 200 ? rawText.slice(0, 200) + '...' : rawText)
        : `文件: ${fileName} (${(stat.size / 1024).toFixed(1)} KB)`,
      source_app: input.sourceApp,
      metadata,
    };
  }

  private detectMimeType(ext: string): string {
    const mimeMap: Record<string, string> = {
      '.pdf': 'application/pdf',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.doc': 'application/msword',
      '.txt': 'text/plain',
      '.md': 'text/markdown',
      '.markdown': 'text/markdown',
      '.csv': 'text/csv',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.html': 'text/html',
      '.htm': 'text/html',
      '.yaml': 'text/yaml',
      '.yml': 'text/yaml',
      '.toml': 'text/toml',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
      '.bmp': 'image/bmp',
      '.tiff': 'image/tiff',
      '.tif': 'image/tiff',
      '.ico': 'image/x-icon',
      '.avif': 'image/avif',
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.ogg': 'audio/ogg',
      '.flac': 'audio/flac',
      '.aac': 'audio/aac',
      '.wma': 'audio/x-ms-wma',
      '.m4a': 'audio/mp4',
      '.opus': 'audio/opus',
      '.mp4': 'video/mp4',
      '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime',
      '.mkv': 'video/x-matroska',
      '.webm': 'video/webm',
      '.flv': 'video/x-flv',
      '.wmv': 'video/x-ms-wmv',
      '.m4v': 'video/mp4',
    };
    return mimeMap[ext] || 'application/octet-stream';
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const fileAdapter = new FileAdapter();
