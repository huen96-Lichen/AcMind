// PinMind ManualTextAdapter
// V2.1 Phase 7.1: Captures manually entered text into a CaptureRecord.

import { createHash } from 'node:crypto';
import type { CaptureAdapter, CaptureRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface ManualTextInput {
  text: string;
  sourceApp?: string;
}

// ---------------------------------------------------------------------------
// ManualTextAdapter
// ---------------------------------------------------------------------------

class ManualTextAdapter implements CaptureAdapter<ManualTextInput> {
  readonly sourceType = 'manual_text' as const;

  capture(input: ManualTextInput): CaptureRecord {
    const trimmed = input.text.trim();
    if (!trimmed) {
      throw new Error('Manual text content is empty');
    }

    const originalId = createHash('sha256')
      .update(trimmed.replace(/\s+/g, ' '))
      .digest('hex')
      .slice(0, 16);

    return {
      original_id: originalId,
      source_type: 'manual_text',
      created_at: new Date().toISOString(),
      raw_text: trimmed,
      title: trimmed.split('\n')[0]?.slice(0, 80) || undefined,
      preview_text: trimmed.length > 200 ? trimmed.slice(0, 200) + '...' : trimmed,
      source_app: input.sourceApp ?? 'PinMind',
      metadata: {
        textLength: trimmed.length,
        lineCount: trimmed.split('\n').length,
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const manualTextAdapter = new ManualTextAdapter();
