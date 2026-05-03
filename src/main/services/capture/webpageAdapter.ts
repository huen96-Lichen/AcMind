// AcMind WebpageAdapter
// V2.1 Phase 7.1: Captures webpage URL and content into a CaptureRecord.
// V2.1 Phase 7.4: Enhanced with domain and input_mode metadata.

import { createHash } from 'node:crypto';
import type { CaptureAdapter, CaptureRecord } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Input type
// ---------------------------------------------------------------------------

export interface WebpageInput {
  url: string;
  title?: string;
  rawText?: string;
  sourceApp?: string;
  /** How the content was provided: 'url_fetch' (auto-extracted) or 'paste' (user pasted) */
  inputMode?: 'url_fetch' | 'paste';
}

// ---------------------------------------------------------------------------
// WebpageAdapter
// ---------------------------------------------------------------------------

class WebpageAdapter implements CaptureAdapter<WebpageInput> {
  readonly sourceType = 'webpage' as const;

  capture(input: WebpageInput): CaptureRecord {
    if (!input.url?.trim()) {
      throw new Error('Webpage URL is required');
    }

    // Normalize URL for dedup
    let normalizedUrl = input.url.trim();
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://' + normalizedUrl;
    }

    const originalId = createHash('sha256')
      .update(normalizedUrl)
      .digest('hex')
      .slice(0, 16);

    const rawText = input.rawText?.trim() || '';
    const title = input.title?.trim() || normalizedUrl;

    // Extract domain from URL
    let domain = '';
    try {
      domain = new URL(normalizedUrl).hostname;
    } catch {
      // Ignore — domain is optional
    }

    return {
      original_id: originalId,
      source_type: 'webpage',
      created_at: new Date().toISOString(),
      raw_url: normalizedUrl,
      raw_text: rawText || undefined,
      title: title.length > 80 ? title.slice(0, 80) + '...' : title,
      preview_text: rawText
        ? (rawText.length > 200 ? rawText.slice(0, 200) + '...' : rawText)
        : normalizedUrl,
      source_app: input.sourceApp,
      metadata: {
        url: normalizedUrl,
        pageTitle: input.title,
        textLength: rawText.length,
        domain,
        input_mode: input.inputMode ?? (rawText ? 'paste' : 'url_fetch'),
        captured_at: new Date().toISOString(),
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const webpageAdapter = new WebpageAdapter();
