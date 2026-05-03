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
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
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

// ─── Phase 3: Local file conversion ─────────────────────────────────────────

const SUPPORTED_EXTENSIONS = new Set([
  '.pdf', '.docx', '.pptx', '.html', '.htm', '.txt', '.md', '.markdown',
]);

const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB

/**
 * Convert a local file to Markdown.
 * Tries markitdown CLI first, falls back to built-in parsers.
 */
export async function convertFileToMarkdown(filePath: string): Promise<MarkItDownResult> {
  // Validate file
  if (!existsSync(filePath)) {
    return { success: false, error: '文件不存在', engine: 'fallback' };
  }

  const ext = path.extname(filePath).toLowerCase();
  if (!SUPPORTED_EXTENSIONS.has(ext)) {
    return { success: false, error: `不支持的文件格式: ${ext}`, engine: 'fallback' };
  }

  // Check file size
  try {
    const stat = require('fs').statSync(filePath);
    if (stat.size > MAX_FILE_SIZE) {
      return { success: false, error: `文件过大 (${Math.round(stat.size / 1024 / 1024)}MB)，最大支持 50MB`, engine: 'fallback' };
    }
  } catch {
    // ignore stat errors, let the parser handle it
  }

  // For plain text / markdown, just read the file
  if (ext === '.txt' || ext === '.md' || ext === '.markdown') {
    try {
      const content = readFileSync(filePath, 'utf-8');
      if (!content.trim()) {
        return { success: false, error: '文件内容为空', engine: 'fallback' };
      }
      const titleMatch = content.match(/^#\s+(.+)$/m);
      const title = titleMatch ? titleMatch[1].trim() : path.basename(filePath, ext);
      return { success: true, markdown: content, title, engine: 'fallback' };
    } catch (err) {
      return { success: false, error: `读取文件失败: ${err instanceof Error ? err.message : String(err)}`, engine: 'fallback' };
    }
  }

  // Try Python markitdown first
  const pythonAvailable = await isMarkItDownAvailable();
  if (pythonAvailable) {
    const result = await convertViaPython(filePath, 60_000); // 60s for local files
    if (result.success) return result;
    logger.warn('app', 'markitdown', 'convertFile', 'Python markitdown failed for file, trying fallback', {
      filePath,
      error: result.error,
    });
  }

  // Fallback to built-in parsers
  return convertFileViaFallback(filePath, ext);
}

/**
 * Fallback: use built-in parsers for local files.
 */
async function convertFileViaFallback(filePath: string, ext: string): Promise<MarkItDownResult> {
  try {
    if (ext === '.pdf') {
      const { parsePdf } = await import('./pdfParser');
      const buffer = readFileSync(filePath);
      const result = await parsePdf(buffer);
      if (!result.success || !result.document) {
        return { success: false, error: result.error || 'PDF 解析失败', engine: 'fallback' };
      }
      return {
        success: true,
        markdown: result.document.content,
        title: result.document.title,
        engine: 'fallback',
      };
    }

    if (ext === '.docx') {
      const { parseDocx } = await import('./docxParser');
      const buffer = readFileSync(filePath);
      const result = await parseDocx(buffer);
      if (!result.success || !result.document) {
        return { success: false, error: result.error || 'DOCX 解析失败', engine: 'fallback' };
      }
      return {
        success: true,
        markdown: result.document.content,
        title: result.document.title,
        engine: 'fallback',
      };
    }

    if (ext === '.html' || ext === '.htm') {
      // Use webParser for local HTML files
      const { parseWebpage } = await import('./webParser');
      const fileUrl = `file://${filePath}`;
      const result = await parseWebpage(fileUrl);
      if (!result.success || !result.document) {
        return { success: false, error: result.error || 'HTML 解析失败', engine: 'fallback' };
      }
      return {
        success: true,
        markdown: result.document.content,
        title: result.document.title,
        engine: 'fallback',
      };
    }

    // PPTX: not supported by built-in parsers
    if (ext === '.pptx') {
      return { success: false, error: 'PPTX 解析需要安装 Python markitdown (pip install markitdown)', engine: 'fallback' };
    }

    return { success: false, error: `不支持的文件格式: ${ext}`, engine: 'fallback' };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logger.error('app', 'markitdown', 'convertFileFallback', 'Fallback file conversion failed', { filePath, error: message });
    return { success: false, error: `文件转换失败: ${message}`, engine: 'fallback' };
  }
}
