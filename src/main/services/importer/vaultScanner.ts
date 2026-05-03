// AcMind Vault Scanner
// Recursively scans Obsidian Vault directories for .md files

import { readdirSync, statSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { ScannedVaultFile, ImportOptions, VaultSearchResult } from '../../../shared/types';
import { frontmatterParser } from './frontmatterParser';

const DEFAULT_EXCLUDE_DIRS = ['.obsidian', '.trash', '.git', 'node_modules'];

export class VaultScanner {
  scan(vaultPath: string, options?: Partial<ImportOptions>): ScannedVaultFile[] {
    const excludePatterns = options?.excludePatterns ?? [];
    const includePatterns = options?.includePatterns;
    const folderPath = options?.folderPath ?? '';
    const scanRoot = path.join(vaultPath, folderPath);

    const files: ScannedVaultFile[] = [];
    this.scanDir(scanRoot, vaultPath, excludePatterns, includePatterns, files);
    return files;
  }

  getSummary(files: ScannedVaultFile[]): {
    total: number;
    withFrontmatter: number;
    totalSize: number;
    willImport: number;
    willSkip: number;
  } {
    return {
      total: files.length,
      withFrontmatter: files.filter(f => f.hasFrontmatter).length,
      totalSize: files.reduce((sum, f) => sum + f.fileSize, 0),
      willImport: files.filter(f => !f.willSkip).length,
      willSkip: files.filter(f => f.willSkip).length,
    };
  }

  private scanDir(
    dir: string,
    vaultRoot: string,
    excludePatterns: string[],
    includePatterns: string[] | undefined,
    results: ScannedVaultFile[],
  ): void {
    let entries: string[];
    try {
      entries = readdirSync(dir, { withFileTypes: true })
        .filter(e => !e.name.startsWith('.'))
        .map(e => path.join(dir, e.name));
    } catch {
      return; // Permission denied or other error, skip
    }

    for (const entry of entries) {
      const relativePath = path.relative(vaultRoot, entry);
      const stat = statSync(entry);

      if (stat.isDirectory()) {
        const dirName = path.basename(entry);
        // Check exclude patterns
        if (DEFAULT_EXCLUDE_DIRS.includes(dirName)) continue;
        if (excludePatterns.some(p => this.matchGlob(relativePath, p))) continue;
        this.scanDir(entry, vaultRoot, excludePatterns, includePatterns, results);
      } else if (entry.endsWith('.md')) {
        // Check include patterns if specified
        if (includePatterns && includePatterns.length > 0) {
          if (!includePatterns.some(p => this.matchGlob(relativePath, p))) continue;
        }
        results.push(this.createScannedFile(entry, relativePath, stat));
      }
    }
  }

  private createScannedFile(filePath: string, relativePath: string, stat: { size: number; mtimeMs: number }): ScannedVaultFile {
    let frontmatter: Record<string, unknown> = {};
    let hasFrontmatter = false;
    let title = '';
    let tags: string[] = [];

    try {
      const content = readFileSync(filePath, 'utf8');
      // Only read first 2KB for frontmatter detection
      const head = content.slice(0, 2048);
      const parsed = frontmatterParser.parseFile(head);
      frontmatter = parsed.frontmatter;
      hasFrontmatter = parsed.hasFrontmatter;
      title = frontmatterParser.extractTitle(frontmatter, path.basename(filePath));
      tags = frontmatterParser.extractTags(frontmatter);
    } catch {
      title = path.basename(filePath).replace(/\.md$/, '');
    }

    return {
      relativePath,
      fileName: path.basename(filePath),
      fileSize: stat.size,
      modifiedAt: Math.floor(stat.mtimeMs / 1000),
      frontmatter,
      hasFrontmatter,
      title,
      tags,
      willSkip: false,
    };
  }

  /**
   * Keyword search across vault .md files.
   * Returns matching files with context snippets.
   */
  search(vaultPath: string, keyword: string, options?: { limit?: number; folderPath?: string }): VaultSearchResult[] {
    const limit = options?.limit ?? 50;
    const folderPath = options?.folderPath ?? '';
    const scanRoot = path.join(vaultPath, folderPath);
    const lowerKeyword = keyword.toLowerCase();
    const results: VaultSearchResult[] = [];

    this.searchDir(scanRoot, vaultPath, lowerKeyword, keyword.length, limit, results);
    return results;
  }

  private searchDir(
    dir: string,
    vaultRoot: string,
    lowerKeyword: string,
    keywordLen: number,
    limit: number,
    results: VaultSearchResult[],
  ): void {
    if (results.length >= limit) return;

    let entries: string[];
    try {
      entries = readdirSync(dir, { withFileTypes: true })
        .filter(e => !e.name.startsWith('.'))
        .map(e => path.join(dir, e.name));
    } catch {
      return;
    }

    for (const entry of entries) {
      if (results.length >= limit) return;
      const stat = statSync(entry);

      if (stat.isDirectory()) {
        const dirName = path.basename(entry);
        if (DEFAULT_EXCLUDE_DIRS.includes(dirName)) continue;
        this.searchDir(entry, vaultRoot, lowerKeyword, keywordLen, limit, results);
      } else if (entry.endsWith('.md')) {
        try {
          const content = readFileSync(entry, 'utf8');
          const lowerContent = content.toLowerCase();
          const idx = lowerContent.indexOf(lowerKeyword);
          if (idx === -1) continue;

          const relativePath = path.relative(vaultRoot, entry);
          // Extract context snippet around match
          const snippetStart = Math.max(0, idx - 60);
          const snippetEnd = Math.min(content.length, idx + keywordLen + 60);
          const snippet = (snippetStart > 0 ? '...' : '') +
            content.slice(snippetStart, snippetEnd).replace(/\n/g, ' ').trim() +
            (snippetEnd < content.length ? '...' : '');

          // Count total matches
          let matchCount = 0;
          let searchIdx = 0;
          while ((searchIdx = lowerContent.indexOf(lowerKeyword, searchIdx)) !== -1) {
            matchCount++;
            searchIdx += lowerKeyword.length;
          }

          results.push({
            relativePath,
            fileName: path.basename(entry),
            title: path.basename(entry).replace(/\.md$/, ''),
            snippet,
            matchCount,
            fileSize: stat.size,
            modifiedAt: Math.floor(stat.mtimeMs / 1000),
          });
        } catch {
          // Skip unreadable files
        }
      }
    }
  }

  private matchGlob(filePath: string, pattern: string): boolean {
    // Simple glob matching: ** matches any path, * matches within a segment
    const regexStr = pattern
      .replace(/\*\*/g, '{{GLOBSTAR}}')
      .replace(/\*/g, '[^/]*')
      .replace(/\{\{GLOBSTAR\}\}/g, '.*')
      .replace(/\?/g, '[^/]');
    try {
      return new RegExp(`^${regexStr}$`).test(filePath);
    } catch {
      return false;
    }
  }
}

export const vaultScanner = new VaultScanner();
