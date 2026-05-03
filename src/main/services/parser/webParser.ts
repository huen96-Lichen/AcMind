import { logger } from '../../logger';
import type { ParseResult, ParsedDocument, ParsedSection } from './types';

const FETCH_TIMEOUT_MS = 10_000;

/**
 * Fetch a web page and parse it into a structured ParsedDocument.
 *
 * Uses Node.js native `fetch` to retrieve the HTML, JSDOM to build a DOM,
 * and Mozilla Readability to extract the main readable content.
 *
 * jsdom and @mozilla/readability are lazy-loaded inside the function
 * so that the DOMMatrix polyfill in index.ts runs first.
 */
export async function parseWebpage(url: string): Promise<ParseResult> {
  try {
    logger.info('app', 'webpage', 'parse', 'Fetching webpage', { url });

    // --- Fetch with timeout ---
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    let response: Response;
    try {
      response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      });
    } catch (fetchErr: unknown) {
      const msg = fetchErr instanceof Error ? fetchErr.message : String(fetchErr);
      if (msg.includes('abort') || msg.includes('timeout')) {
        logger.warn('app', 'webpage', 'parse', 'Fetch timed out', { url });
        return { success: false, error: `Request timed out after ${FETCH_TIMEOUT_MS / 1000}s` };
      }
      logger.warn('app', 'webpage', 'parse', 'Network error', { url, error: msg });
      return { success: false, error: `Network error: ${msg}` };
    } finally {
      clearTimeout(timeoutId);
    }

    if (!response.ok) {
      logger.warn('app', 'webpage', 'parse', 'HTTP error', {
        url,
        status: response.status,
        statusText: response.statusText,
      });
      return {
        success: false,
        error: `HTTP error: ${response.status} ${response.statusText}`,
      };
    }

    const html = await response.text();

    if (!html || html.length < 50) {
      logger.warn('app', 'webpage', 'parse', 'Empty or too-short response', { url });
      return { success: false, error: 'Received empty or too-short response' };
    }

    // --- Lazy-load jsdom + Readability (after DOMMatrix polyfill) ---
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { JSDOM } = require('jsdom') as { JSDOM: new (html: string, opts?: Record<string, unknown>) => { window: { document: Document } } };
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { Readability } = require('@mozilla/readability') as { Readability: new (doc: Document) => { parse(): { title?: string; content?: string; textContent?: string; byline?: string } | null } };

    // --- Parse with JSDOM + Readability ---
    const dom = new JSDOM(html, { url });
    const reader = new Readability(dom.window.document);
    const article = reader.parse();

    if (!article) {
      logger.warn('app', 'webpage', 'parse', 'Readability could not extract content', { url });
      return { success: false, error: 'Could not extract readable content from the page' };
    }

    const content = (article.content || '').trim();
    const textContent = (article.textContent || '').trim();

    if (!textContent) {
      logger.warn('app', 'webpage', 'parse', 'Extracted content is empty', { url });
      return { success: false, error: 'Extracted content is empty' };
    }

    // --- Title ---
    const title = article.title || dom.window.document.title || new URL(url).hostname || 'Untitled Web Page';

    // --- Sections ---
    const sections: ParsedSection[] = [];
    const contentDom = new JSDOM(`<!DOCTYPE html><html><body>${content}</body></html>`);
    const body = contentDom.window.document.body;

    let currentHeading: string | undefined;
    let currentLevel: number | undefined;
    let currentParts: string[] = [];

    const flushSection = () => {
      const sectionText = currentParts.join('\n\n').trim();
      if (sectionText) {
        sections.push({
          heading: currentHeading,
          level: currentLevel,
          content: sectionText,
        });
      }
      currentParts = [];
    };

    for (const child of Array.from(body.children)) {
      const tagName = child.tagName.toLowerCase();
      if (/^h[1-6]$/.test(tagName)) {
        flushSection();
        currentHeading = (child.textContent || '').trim();
        currentLevel = parseInt(tagName[1], 10);
      } else {
        currentParts.push((child.textContent || '').trim());
      }
    }
    flushSection();

    if (sections.length === 0) {
      sections.push({ content: textContent });
    }

    const wordCount = textContent.split(/\s+/).filter(Boolean).length;
    const previewText = textContent.slice(0, 500);
    const author = article.byline || undefined;

    const document: ParsedDocument = {
      title,
      content: textContent,
      previewText,
      sections,
      metadata: {
        sourceType: 'webpage',
        originalUrl: url,
        wordCount,
        author,
        createdAt: (article as Record<string, unknown>).publishedTime as string | undefined,
      },
    };

    logger.info('app', 'webpage', 'parse', 'Webpage parsed successfully', {
      url,
      title,
      wordCount,
      sectionCount: sections.length,
    });

    return { success: true, document };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error('app', 'webpage', 'parse', 'Failed to parse webpage', { url, error: message });
    return { success: false, error: `Failed to parse webpage: ${message}` };
  }
}
