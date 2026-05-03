import { logger } from '../../logger';
import type { ParseResult, ParsedDocument, ParsedSection } from './types';

/**
 * Parse a PDF buffer into a structured ParsedDocument.
 *
 * Extracts text from all pages, attempts to determine a title from
 * PDF metadata or the first page content, and splits the body into
 * per-page sections.
 *
 * pdf-parse is lazy-loaded via require() to avoid esbuild bundling
 * pdfjs-dist (which uses browser-only DOMMatrix API) into the main process.
 */
export async function parsePdf(buffer: Buffer): Promise<ParseResult> {
  try {
    logger.info('app', 'pdf', 'parse', 'Starting PDF parsing', {
      size: buffer.length,
    });

    // Lazy-load pdf-parse at runtime (external to esbuild bundle)
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { PDFParse } = require('pdf-parse') as { PDFParse: new (opts: { data: Buffer }) => PDFParseInstance };

    const parser = new PDFParse({ data: buffer });
    const textResult = await parser.getText();
    const infoResult = await parser.getInfo();
    const text = (textResult.text || '').trim();

    if (!text) {
      logger.warn('app', 'pdf', 'parse', 'PDF contains no extractable text');
      return { success: false, error: 'PDF contains no extractable text' };
    }

    // --- Title ---
    const metaTitle = infoResult.info?.Title?.trim();
    const title = metaTitle || text.split('\n')[0].trim().slice(0, 200) || 'Untitled PDF';

    // --- Sections (one per page) ---
    const rawPages = textResult.pages;
    const pages: string[] = Array.isArray(rawPages) && rawPages.length > 0
      ? rawPages.map((p: { text: string }) => p.text)
      : [text];
    const sections: ParsedSection[] = pages.map((pageText: string, idx: number) => ({
      heading: `Page ${idx + 1}`,
      level: 2,
      content: pageText.trim(),
    }));

    // --- Word count ---
    const wordCount = text.split(/\s+/).filter(Boolean).length;

    // --- Preview (first 500 chars) ---
    const previewText = text.slice(0, 500);

    const document: ParsedDocument = {
      title,
      content: text,
      previewText,
      sections,
      metadata: {
        sourceType: 'pdf',
        pageCount: textResult.pages?.length || 0,
        wordCount,
        author: infoResult.info?.Author?.trim() || undefined,
        createdAt: infoResult.info?.CreationDate?.trim() || undefined,
      },
    };

    logger.info('app', 'pdf', 'parse', 'PDF parsed successfully', {
      title,
      pageCount: textResult.pages?.length || 0,
      wordCount,
    });

    await parser.destroy();
    return { success: true, document };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);

    if (message.includes('encrypted') || message.includes('password')) {
      logger.warn('app', 'pdf', 'parse', 'PDF is encrypted or password-protected');
      return { success: false, error: 'PDF is encrypted or password-protected' };
    }

    if (message.includes('Invalid PDF') || message.includes('corrupted')) {
      logger.warn('app', 'pdf', 'parse', 'PDF is corrupted or invalid');
      return { success: false, error: 'PDF is corrupted or invalid' };
    }

    logger.error('app', 'pdf', 'parse', 'Failed to parse PDF', { error: message });
    return { success: false, error: `Failed to parse PDF: ${message}` };
  }
}

interface PDFParseInstance {
  getText(): Promise<{ text: string; pages?: Array<{ text: string }> }>;
  getInfo(): Promise<{ info?: Record<string, string | undefined> }>;
  destroy(): Promise<void>;
}
