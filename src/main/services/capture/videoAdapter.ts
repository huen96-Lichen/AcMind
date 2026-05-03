// AcMind VideoAdapter (Stub)
// V2.1 Phase 7.1: Placeholder for video capture into a CaptureRecord.
// Will be fully implemented when video capture is integrated.

import { createHash } from 'node:crypto';
import { existsSync, statSync } from 'node:fs';
import path from 'node:path';
import type { CaptureAdapter, CaptureRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface VideoInput {
  filePath: string;
  title?: string;
  sourceApp?: string;
}

// ---------------------------------------------------------------------------
// VideoAdapter
// ---------------------------------------------------------------------------

class VideoAdapter implements CaptureAdapter<VideoInput> {
  readonly sourceType = 'video' as const;

  capture(input: VideoInput): CaptureRecord {
    if (!input.filePath) {
      throw new Error('Video file path is required');
    }

    if (!existsSync(input.filePath)) {
      throw new Error(`Video file not found: ${input.filePath}`);
    }

    const stat = statSync(input.filePath);
    const ext = path.extname(input.filePath).toLowerCase();
    const fileName = path.basename(input.filePath);

    const hashInput = `${input.filePath}:${stat.size}:${stat.mtimeMs}`;
    const originalId = createHash('sha256')
      .update(hashInput)
      .digest('hex')
      .slice(0, 16);

    const title = input.title?.trim() || fileName.replace(ext, '');

    return {
      original_id: originalId,
      source_type: 'video',
      created_at: new Date().toISOString(),
      raw_file_path: input.filePath,
      title: title.length > 80 ? title.slice(0, 80) + '...' : title,
      preview_text: `视频: ${fileName} (${(stat.size / (1024 * 1024)).toFixed(1)} MB)`,
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
      '.mp4': 'video/mp4',
      '.mov': 'video/quicktime',
      '.avi': 'video/x-msvideo',
      '.mkv': 'video/x-matroska',
      '.webm': 'video/webm',
    };
    return mimeMap[ext] || 'video/mp4';
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const videoAdapter = new VideoAdapter();
