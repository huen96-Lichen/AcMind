// PinMind ClipboardTextAdapter
// V2.1 Phase 7.1: Captures clipboard text content into a CaptureRecord.

import { createHash } from 'node:crypto';
import type { CaptureAdapter, CaptureRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface ClipboardTextInput {
  text: string;
  sourceApp?: string;
  contentHash?: string;
}

// ---------------------------------------------------------------------------
// ClipboardTextAdapter
// ---------------------------------------------------------------------------

class ClipboardTextAdapter implements CaptureAdapter<ClipboardTextInput> {
  readonly sourceType = 'clipboard_text' as const;

  capture(input: ClipboardTextInput): CaptureRecord {
    const trimmed = input.text.trim();
    if (!trimmed) {
      throw new Error('Clipboard text content is empty');
    }

    // Use provided content hash or generate one
    const originalId = input.contentHash
      ?? createHash('sha256')
        .update(trimmed.replace(/\s+/g, ' '))
        .digest('hex')
        .slice(0, 16);

    return {
      original_id: originalId,
      source_type: 'clipboard_text',
      created_at: new Date().toISOString(),
      raw_text: trimmed,
      title: trimmed.split('\n')[0]?.slice(0, 80) || undefined,
      preview_text: trimmed.length > 200 ? trimmed.slice(0, 200) + '...' : trimmed,
      source_app: input.sourceApp,
      metadata: {
        textLength: trimmed.length,
        lineCount: trimmed.split('\n').length,
        contentHash: input.contentHash,
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const clipboardTextAdapter = new ClipboardTextAdapter();
