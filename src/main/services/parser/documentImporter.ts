import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { logger } from '../../logger';
import { storage } from '../../storage';
import type { ImportResult, ParsedDocument, ParseResult } from './types';

// ─── Helpers ──────────────────────────────────────────────────

function generateId(): string {
  return crypto.randomUUID();
}

function detectSourceType(filePath: string): 'pdf' | 'docx' | null {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.pdf') return 'pdf';
  if (ext === '.docx') return 'docx';
  return null;
}

/**
 * Map internal source format to a descriptive sourceApp value.
 */
function mapSourceApp(sourceType: 'pdf' | 'docx' | 'webpage'): string {
  switch (sourceType) {
    case 'pdf': return 'pdf_import';
    case 'docx': return 'docx_import';
    case 'webpage': return 'web_import';
  }
}

/**
 * Insert a parsed document into the source_items table via storage.
 */
function insertParsedDocument(doc: ParsedDocument, sourceType: 'pdf' | 'docx' | 'webpage'): ImportResult {
  const id = generateId();

  try {
    storage.insertSourceItem({
      id,
      type: 'text',
      source: 'vault_import',
      sourceApp: mapSourceApp(sourceType),
      contentPath: doc.metadata.originalPath || doc.metadata.originalUrl || '',
      previewText: doc.previewText || undefined,
      originalUrl: doc.metadata.originalUrl || undefined,
      createdAt: Date.now(),
      status: 'inbox',
      title: doc.title || undefined,
      vaultImportPath: doc.metadata.originalPath || undefined,
    });

    logger.info('app', 'importer', 'insert', 'SourceItem created', {
      id,
      type: sourceType,
      title: doc.title,
    });

    return { success: true, sourceItemId: id, title: doc.title };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error('app', 'importer', 'insert', 'Failed to insert SourceItem', {
      error: message,
    });
    return { success: false, error: `Failed to insert into storage: ${message}` };
  }
}

/**
 * Lazy-load parsers at runtime to avoid esbuild bundling browser-only deps
 * (pdfjs-dist uses DOMMatrix, jsdom uses browser APIs) into the main process.
 */
async function loadPdfParser(): Promise<(buffer: Buffer) => Promise<ParseResult>> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const mod = require('./pdfParser') as { parsePdf: (buffer: Buffer) => Promise<ParseResult> };
  return mod.parsePdf;
}

async function loadDocxParser(): Promise<(buffer: Buffer) => Promise<ParseResult>> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const mod = require('./docxParser') as { parseDocx: (buffer: Buffer) => Promise<ParseResult> };
  return mod.parseDocx;
}

async function loadWebParser(): Promise<(url: string) => Promise<ParseResult>> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const mod = require('./webParser') as { parseWebpage: (url: string) => Promise<ParseResult> };
  return mod.parseWebpage;
}

// ─── Public API ───────────────────────────────────────────────

/**
 * Import a local file (PDF or DOCX) into the source_items table.
 *
 * Auto-detects format by file extension, reads the file, parses it,
 * and inserts a new SourceItem with status 'inbox'.
 */
export async function importDocument(filePath: string): Promise<ImportResult> {
  const resolvedPath = path.resolve(filePath);
  const sourceType = detectSourceType(resolvedPath);

  if (!sourceType) {
    logger.warn('app', 'importer', 'importDocument', 'Unsupported file format', {
      filePath: resolvedPath,
    });
    return { success: false, error: `Unsupported file format: ${path.extname(resolvedPath)}` };
  }

  // Read file
  let buffer: Buffer;
  try {
    buffer = fs.readFileSync(resolvedPath);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error('app', 'importer', 'importDocument', 'Failed to read file', {
      filePath: resolvedPath,
      error: message,
    });
    return { success: false, error: `Failed to read file: ${message}` };
  }

  logger.info('app', 'importer', 'importDocument', 'Importing document', {
    filePath: resolvedPath,
    sourceType,
    size: buffer.length,
  });

  // Parse (lazy-load the appropriate parser)
  let parseResult: ParseResult;
  if (sourceType === 'pdf') {
    const parsePdf = await loadPdfParser();
    parseResult = await parsePdf(buffer);
  } else {
    const parseDocx = await loadDocxParser();
    parseResult = await parseDocx(buffer);
  }

  if (!parseResult.success || !parseResult.document) {
    logger.warn('app', 'importer', 'importDocument', 'Parsing failed', {
      filePath: resolvedPath,
      error: parseResult.error,
    });
    return { success: false, error: parseResult.error || 'Parsing failed' };
  }

  // Enrich metadata with file path
  parseResult.document.metadata.originalPath = resolvedPath;

  // Insert into storage
  return insertParsedDocument(parseResult.document, sourceType);
}

/**
 * Import a web page into the source_items table.
 *
 * Fetches the URL, parses the content with Readability, and inserts
 * a new SourceItem with status 'inbox'.
 */
export async function importWebpage(url: string): Promise<ImportResult> {
  logger.info('app', 'importer', 'importWebpage', 'Importing webpage', { url });

  const parseWebpage = await loadWebParser();
  const parseResult = await parseWebpage(url);

  if (!parseResult.success || !parseResult.document) {
    logger.warn('app', 'importer', 'importWebpage', 'Parsing failed', {
      url,
      error: parseResult.error,
    });
    return { success: false, error: parseResult.error || 'Parsing failed' };
  }

  // Insert into storage
  return insertParsedDocument(parseResult.document, 'webpage');
}

/**
 * Batch import multiple local files.
 *
 * Processes files sequentially and returns an array of results,
 * one per file, in the same order as the input.
 */
export async function importBatch(filePaths: string[]): Promise<ImportResult[]> {
  logger.info('app', 'importer', 'importBatch', 'Starting batch import', {
    count: filePaths.length,
  });

  const results: ImportResult[] = [];

  for (let i = 0; i < filePaths.length; i++) {
    const filePath = filePaths[i];
    logger.info('app', 'importer', 'importBatch', `Processing file ${i + 1}/${filePaths.length}`, {
      filePath,
    });

    const result = await importDocument(filePath);
    results.push(result);
  }

  const succeeded = results.filter((r) => r.success).length;
  const failed = results.length - succeeded;

  logger.info('app', 'importer', 'importBatch', 'Batch import complete', {
    total: results.length,
    succeeded,
    failed,
  });

  return results;
}

// ─── Singleton object ─────────────────────────────────────────

export const documentImporter = {
  importDocument,
  importWebpage,
  importBatch,
} as const;
