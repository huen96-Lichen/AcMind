// AcMind ScreenshotAdapter
// V2.1 Phase 7.1: Captures screenshot file into a CaptureRecord.
// V2.1 Phase 7.3: Enhanced with image dimensions and captured_at metadata.

import { createHash } from 'node:crypto';
import { existsSync, statSync, writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { CaptureAdapter, CaptureRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface ScreenshotInput {
  /** Absolute path to an existing screenshot file */
  filePath?: string;
  /** Raw PNG buffer (alternative to filePath — will be saved to a temp file) */
  buffer?: Buffer;
  /** Directory to save buffer-based screenshots (required when buffer is provided) */
  saveDir?: string;
  sourceApp?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Read image dimensions from a PNG buffer.
 * PNG header: bytes 16-19 = width (uint32 BE), bytes 20-23 = height (uint32 BE).
 */
function readPngDimensions(buffer: Buffer): { width: number; height: number } | null {
  // PNG signature: 137 80 78 71 13 10 26 10
  if (buffer.length >= 24 &&
      buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4E && buffer[3] === 0x47) {
    const width = buffer.readUInt32BE(16);
    const height = buffer.readUInt32BE(20);
    return { width, height };
  }
  return null;
}

// ---------------------------------------------------------------------------
// ScreenshotAdapter
// ---------------------------------------------------------------------------

class ScreenshotAdapter implements CaptureAdapter<ScreenshotInput> {
  readonly sourceType = 'screenshot' as const;

  capture(input: ScreenshotInput): CaptureRecord {
    let filePath: string;
    let fileSize: number;
    let imageDimensions: { width: number; height: number } | null = null;

    if (input.buffer) {
      // Buffer mode: save to file first
      const saveDir = input.saveDir ?? path.join(process.cwd(), 'screenshots');
      if (!existsSync(saveDir)) {
        mkdirSync(saveDir, { recursive: true });
      }
      const timestamp = Date.now();
      filePath = path.join(saveDir, `screenshot_${timestamp}.png`);
      writeFileSync(filePath, input.buffer);
      fileSize = input.buffer.length;
      imageDimensions = readPngDimensions(input.buffer);
    } else if (input.filePath) {
      // File path mode
      filePath = input.filePath;
      if (!existsSync(filePath)) {
        throw new Error(`Screenshot file not found: ${filePath}`);
      }
      const stat = statSync(filePath);
      fileSize = stat.size;

      // Try to read dimensions from file header (first 24 bytes)
      try {
        const header = readFileSync(filePath).subarray(0, 24);
        imageDimensions = readPngDimensions(header as Buffer);
      } catch {
        // Ignore — dimensions are optional
      }
    } else {
      throw new Error('ScreenshotInput must provide either filePath or buffer');
    }

    // Generate hash from file path + size for dedup
    const hashInput = `${filePath}:${fileSize}`;
    const originalId = createHash('sha256')
      .update(hashInput)
      .digest('hex')
      .slice(0, 16);

    const now = new Date();

    return {
      original_id: originalId,
      source_type: 'screenshot',
      created_at: now.toISOString(),
      raw_file_path: filePath,
      title: `屏幕截图 · ${now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`,
      preview_text: `屏幕截图 · ${now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`,
      source_app: input.sourceApp ?? 'AcMind',
      metadata: {
        fileSize,
        mimeType: 'image/png',
        image_width: imageDimensions?.width,
        image_height: imageDimensions?.height,
        captured_at: now.toISOString(),
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const screenshotAdapter = new ScreenshotAdapter();
