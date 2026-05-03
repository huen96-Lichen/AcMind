/**
 * MarkItDown Service — converts web pages / files to Markdown via Python subprocess.
 *
 * Uses Microsoft's `markitdown` Python package:
 *   pip install markitdown
 *
 * Falls back to the built-in webParser (JSDOM + Readability) when Python
 * is not available on the host.
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { logger } from '../../logger';

const execFileAsync = promisify(execFile);

// ─── Types ────────────────────────────────────────────────────────────────────

export interface MarkItDownResult {
  success: boolean;
  markdown?: string;
  title?: string;
  error?: string;
  /** 'markitdown' | 'fallback' */
  engine: 'markitdown' | 'fallback';
}

// ─── Internal helpers ─────────────────────────────────────────────────────────

/** Check whether `markitdown` CLI is available on PATH. */
async function isMarkItDownAvailable(): Promise<boolean> {
  try {
    await execFileAsync('markitdown', ['--version'], {
      timeout: 5_000,
      windowsHide: true,
    });
    return true;
  } catch {
    return false;
  }
}

/**
 * Run `markitdown <url>` and capture stdout.
 * The CLI prints converted Markdown to stdout.
 */
async function convertViaPython(url: string, timeoutMs = 30_000): Promise<MarkItDownResult> {
  try {
    logger.info('app', 'markitdown', 'convert', 'Converting via Python markitdown', { url });

    const { stdout, stderr } = await execFileAsync(
      'markitdown',
      [url],
      {
        timeout: timeoutMs,
        maxBuffer: 10 * 1024 * 1024, // 10 MB
        windowsHide: true,
      },
    );

    const markdown = (stdout || '').trim();

    if (!markdown) {
      const errMsg = stderr?.trim() || 'No output from markitdown';
      logger.warn('app', 'markitdown', 'convert', 'Empty output', { url, error: errMsg });
      return { success: false, error: `markitdown returned empty output: ${errMsg}`, engine: 'markitdown' };
    }

    // Extract title from first H1 if present
    const titleMatch = markdown.match(/^#\s+(.+)$/m);
    const title = titleMatch ? titleMatch[1].trim() : undefined;

    logger.info('app', 'markitdown', 'convert', 'Conversion successful', {
      url,
      title,
      charCount: markdown.length,
    });

    return { success: true, markdown, title, engine: 'markitdown' };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error('app', 'markitdown', 'convert', 'Python markitdown failed', { url, error: message });
    return { success: false, error: `markitdown error: ${message}`, engine: 'markitdown' };
  }
}

/**
 * Fallback: use the built-in webParser (JSDOM + Readability).
 * Lazy-imported to avoid circular deps and allow DOMMatrix polyfill to run.
 */
async function convertViaFallback(url: string): Promise<MarkItDownResult> {
  try {
    logger.info('app', 'markitdown', 'fallback', 'Using built-in web parser', { url });

    // Dynamic import to avoid loading jsdom/readability at module level
    const { parseWebpage } = await import('./webParser');
    const result = await parseWebpage(url);

    if (!result.success || !result.document) {
      return {
        success: false,
        error: result.error || 'Built-in parser failed',
        engine: 'fallback',
      };
    }

    const doc = result.document;

    // Build Markdown from parsed sections
    let markdown = '';
    if (doc.sections.length > 0) {
      for (const section of doc.sections) {
        if (section.heading) {
          const level = section.level ?? 2;
          markdown += `${'#'.repeat(Math.min(level, 6))} ${section.heading}\n\n`;
        }
        markdown += `${section.content}\n\n`;
      }
    } else {
      markdown = doc.content;
    }

    // Prepend title if not already in content
    if (!markdown.startsWith(`# ${doc.title}`)) {
      markdown = `# ${doc.title}\n\n${markdown}`;
    }

    return {
      success: true,
      markdown: markdown.trim(),
      title: doc.title,
      engine: 'fallback',
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error('app', 'markitdown', 'fallback', 'Fallback parser failed', { url, error: message });
    return { success: false, error: `Fallback error: ${message}`, engine: 'fallback' };
  }
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Convert a URL to Markdown.
 * Tries markitdown CLI first, falls back to built-in webParser.
 */
export async function convertUrlToMarkdown(url: string): Promise<MarkItDownResult> {
  // Validate URL
  try {
    new URL(url); // eslint-disable-line no-new
  } catch {
    return { success: false, error: '无效的 URL 格式', engine: 'fallback' };
  }

  // Try Python markitdown first
  const pythonAvailable = await isMarkItDownAvailable();
  if (pythonAvailable) {
    const result = await convertViaPython(url);
    if (result.success) return result;
    // If markitdown failed, fall through to built-in parser
    logger.warn('app', 'markitdown', 'convert', 'Python markitdown failed, falling back', {
      url,
      error: result.error,
    });
  } else {
    logger.info('app', 'markitdown', 'convert', 'Python markitdown not available, using fallback', { url });
  }

  return convertViaFallback(url);
}

/**
 * Check if markitdown Python package is available.
 */
export async function checkMarkItDownAvailability(): Promise<boolean> {
  return isMarkItDownAvailable();
}
