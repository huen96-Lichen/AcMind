// PinMind Path Resolver
// Resolves file paths for Obsidian vault exports based on path rules
// Centralized path generation — all output paths MUST go through this module.
//
// Filename format: YYYY-MM-DD_HHmm_标题.md
// Example: 2026-04-30_1435_PinMind自动知识流设计.md

import path from 'node:path';
import type { VaultConfig, DistilledOutput, SourceItem } from '../../../shared/types';
import { formatFilenameDate, sanitizeFilename as sanitizePinMindFilename } from '../../../shared/outputSpec';
import { DEFAULT_DISTILLED_CATEGORY } from '../../../shared/markdownSpec';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** Default output subdirectory inside the Obsidian vault */
export const PINMIND_OUTPUT_DIR = '00_Inbox/PinMind';

/** Reserved directory for raw/original content backups (future use) */
export const PINMIND_RAW_DIR = '99_PinMind_Raw';

/** Maximum length for the title portion of a filename (excluding date prefix and extension) */
const MAX_TITLE_LENGTH = 80;

/** Fallback title when no title is available */
const FALLBACK_TITLE = '未命名内容';

// ---------------------------------------------------------------------------
// PathResolver
// ---------------------------------------------------------------------------

class PathResolver {
  /**
   * Build a filename in the standard format: YYYY-MM-DD_HHmm_标题.md
   */
  buildFilename(dateStr: string, title: string): string {
    const sanitized = this.sanitizeFilename(title);
    return `${dateStr}_${sanitized}.md`;
  }

  /**
   * Resolve the full file path for an export based on vault config, distilled output, and source item.
   * Supports three path modes: category_date, category_title, flat.
   */
  resolve(
    vaultConfig: VaultConfig,
    distilledOutput: DistilledOutput,
    sourceItem: SourceItem,
  ): string {
    const { vaultPath, defaultFolder, pathRule } = vaultConfig;

    if (!vaultPath) {
      throw new Error('Vault path is not configured');
    }

    const title = this.sanitizeFilename(
      distilledOutput.suggestedTitle ?? sourceItem.title ?? this.extractTitleFromPreview(sourceItem.previewText) ?? FALLBACK_TITLE,
    );
    const category = this.sanitizeCategoryPath(
      distilledOutput.category ?? DEFAULT_DISTILLED_CATEGORY,
    );
    const dateStr = formatFilenameDate(distilledOutput.createdAt);

    // Use defaultFolder if set, otherwise fall back to PINMIND_OUTPUT_DIR
    const folder = defaultFolder || PINMIND_OUTPUT_DIR;

    let relativePath: string;

    switch (pathRule) {
      case 'category_date':
        // {vaultPath}/{folder}/{category}/{YYYY-MM-DD_HHmm_标题.md}
        relativePath = path.join(folder, category, this.buildFilename(dateStr, title));
        break;

      case 'category_title':
        // {vaultPath}/{folder}/{category}/{YYYY-MM-DD_HHmm_标题.md}
        // Note: always include date prefix for uniqueness
        relativePath = path.join(folder, category, this.buildFilename(dateStr, title));
        break;

      case 'flat':
        // {vaultPath}/{folder}/{YYYY-MM-DD_HHmm_标题.md}
        relativePath = path.join(folder, this.buildFilename(dateStr, title));
        break;

      default:
        throw new Error(`Unknown path rule: ${pathRule}`);
    }

    return path.join(vaultPath, relativePath);
  }

  /**
   * Resolve path for ContentPipeline (minimum loop) exports.
   * Uses the same centralized logic but accepts structured content directly.
   */
  resolveForPipeline(
    vaultPath: string,
    defaultFolder: string,
    title: string,
    createdAt: number,
  ): string {
    if (!vaultPath) {
      throw new Error('Vault path is not configured');
    }

    const dateStr = formatFilenameDate(createdAt);
    const folder = defaultFolder || PINMIND_OUTPUT_DIR;
    const filename = this.buildFilename(dateStr, title);

    return path.join(vaultPath, folder, filename);
  }

  /**
   * Resolve the relative path (without vaultPath prefix) for display purposes.
   */
  resolveRelative(
    vaultConfig: VaultConfig,
    distilledOutput: DistilledOutput,
    sourceItem: SourceItem,
  ): string {
    const fullPath = this.resolve(vaultConfig, distilledOutput, sourceItem);
    const vaultPath = vaultConfig.vaultPath.replace(/\/+$/, '');
    return fullPath.startsWith(vaultPath)
      ? fullPath.substring(vaultPath.length + 1)
      : fullPath;
  }

  /**
   * Sanitize a string for use as a filename.
   * Removes special characters, limits length, handles edge cases.
   */
  sanitizeFilename(name: string): string {
    if (!name) return FALLBACK_TITLE;

    let sanitized = sanitizePinMindFilename(name);

    // Limit title length
    if (sanitized.length > MAX_TITLE_LENGTH) {
      sanitized = sanitized.substring(0, MAX_TITLE_LENGTH).trim();
      const lastSpace = sanitized.lastIndexOf(' ');
      if (lastSpace > 40) {
        sanitized = sanitized.substring(0, lastSpace);
      }
    }

    // Remove trailing dots and spaces
    sanitized = sanitized.replace(/[.\s]+$/, '');

    return sanitized || FALLBACK_TITLE;
  }

  sanitizeCategoryPath(category: string): string {
    const segments = category
      .split(/[\\/]+/)
      .map((segment) => this.sanitizeFilename(this.normalizeCategorySegment(segment)))
      .filter(Boolean);
    return segments.length > 0 ? path.join(...segments) : DEFAULT_DISTILLED_CATEGORY;
  }

  private extractTitleFromPreview(preview?: string): string | undefined {
    const firstLine = preview?.split(/\r?\n/).map((line) => line.trim()).find(Boolean);
    if (!firstLine) return undefined;
    return firstLine.replace(/^#+\s*/, '');
  }

  private normalizeCategorySegment(segment: string): string {
    return segment
      .replace(/[*`#]/g, '')
      .replace(/^(最佳分类|建议分类|分类|category|class)\s*[：:]\s*/i, '')
      .replace(/\(([^)]*)\)/g, '')
      .replace(/（[^）]*）/g, '')
      .trim();
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const pathResolver = new PathResolver();
