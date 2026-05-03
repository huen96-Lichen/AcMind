// PinMind Vault Scanner
// Recursively scans Obsidian Vault directories for .md files

import { readdirSync, statSync, readFileSync } from 'node:fs';
import path from 'node:path';
import type { ScannedVaultFile, ImportOptions } from '../../../shared/types';
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
