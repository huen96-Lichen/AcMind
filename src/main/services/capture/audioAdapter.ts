// PinMind AudioAdapter (Stub)
// V2.1 Phase 7.1: Placeholder for audio capture into a CaptureRecord.
// Will be fully implemented when audio capture is integrated.

import { createHash } from 'node:crypto';
import { existsSync, statSync } from 'node:fs';
import path from 'node:path';
import type { CaptureAdapter, CaptureRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface AudioInput {
  filePath: string;
  title?: string;
  sourceApp?: string;
}

// ---------------------------------------------------------------------------
// AudioAdapter
// ---------------------------------------------------------------------------

class AudioAdapter implements CaptureAdapter<AudioInput> {
  readonly sourceType = 'audio' as const;

  capture(input: AudioInput): CaptureRecord {
    if (!input.filePath) {
      throw new Error('Audio file path is required');
    }

    if (!existsSync(input.filePath)) {
      throw new Error(`Audio file not found: ${input.filePath}`);
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
      source_type: 'audio',
      created_at: new Date().toISOString(),
      raw_file_path: input.filePath,
      title: title.length > 80 ? title.slice(0, 80) + '...' : title,
      preview_text: `音频: ${fileName} (${(stat.size / 1024).toFixed(1)} KB)`,
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
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.m4a': 'audio/mp4',
      '.ogg': 'audio/ogg',
      '.flac': 'audio/flac',
      '.aac': 'audio/aac',
    };
    return mimeMap[ext] || 'audio/mpeg';
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const audioAdapter = new AudioAdapter();
