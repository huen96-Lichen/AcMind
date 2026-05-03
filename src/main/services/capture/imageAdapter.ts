// AcMind ImageAdapter
// V2.1 Phase 7.1: Captures an image file into a CaptureRecord.

import { createHash } from 'node:crypto';
import { existsSync, statSync } from 'node:fs';
import path from 'node:path';
import type { CaptureAdapter, CaptureRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface ImageInput {
  filePath: string;
  sourceApp?: string;
}

// ---------------------------------------------------------------------------
// ImageAdapter
// ---------------------------------------------------------------------------

class ImageAdapter implements CaptureAdapter<ImageInput> {
  readonly sourceType = 'image' as const;

  capture(input: ImageInput): CaptureRecord {
    if (!input.filePath) {
      throw new Error('Image file path is required');
    }

    if (!existsSync(input.filePath)) {
      throw new Error(`Image file not found: ${input.filePath}`);
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

    return {
      original_id: originalId,
      source_type: 'image',
      created_at: new Date().toISOString(),
      raw_file_path: input.filePath,
      title: fileName,
      preview_text: `图片: ${fileName} (${(stat.size / 1024).toFixed(1)} KB)`,
      source_app: input.sourceApp,
      metadata: {
        fileName,
        fileSize: stat.size,
        extension: ext,
        mimeType: this.detectMimeType(ext),
      },
    };
  }

  private detectMimeType(ext: string): string {
    const mimeMap: Record<string, string> = {
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
      '.bmp': 'image/bmp',
      '.ico': 'image/x-icon',
    };
    return mimeMap[ext] || 'image/png';
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const imageAdapter = new ImageAdapter();
