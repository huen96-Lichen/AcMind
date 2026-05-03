// AcMind Conflict Handler
// Handles file conflicts when exporting to Obsidian vault

import path from 'node:path';
import { existsSync, readdirSync } from 'node:fs';
import type { VaultConfig } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ConflictCheckResult {
  exists: boolean;
  existingFiles: string[];
}

export interface ConflictResolution {
  filePath: string;
  action: 'create' | 'rename' | 'skip' | 'overwrite';
}

// ---------------------------------------------------------------------------
// ConflictHandler
// ---------------------------------------------------------------------------

class ConflictHandler {
  /**
   * Check if a file already exists at the given path.
   * Also returns a list of existing files with the same base name (for rename detection).
   */
  check(filePath: string): ConflictCheckResult {
    const exists = existsSync(filePath);

    if (!exists) {
      return { exists: false, existingFiles: [] };
    }

    // Find files with the same base name pattern
    const dir = path.dirname(filePath);
    const ext = path.extname(filePath);
    const baseName = path.basename(filePath, ext);

    let existingFiles: string[] = [];

    try {
      if (existsSync(dir)) {
        const files = readdirSync(dir);
        existingFiles = files.filter((f) => {
          const fBase = path.basename(f, path.extname(f));
          // Match base name and variations like "title-2", "title-3"
          return fBase === baseName || fBase.startsWith(`${baseName}-`);
        });
      }
    } catch {
      existingFiles = [path.basename(filePath)];
    }

    return { exists: true, existingFiles };
  }

  /**
   * Resolve a file conflict using the specified strategy.
   * - rename: Append " - N" suffix to find a unique filename
   * - skip: Return the original path but mark action as 'skip'
   * - overwrite: Return the original path and mark action as 'overwrite'
   */
  resolve(filePath: string, strategy: VaultConfig['conflictStrategy']): ConflictResolution {
    const checkResult = this.check(filePath);

    if (!checkResult.exists) {
      return { filePath, action: 'create' };
    }

    switch (strategy) {
      case 'overwrite':
        return { filePath, action: 'overwrite' };

      case 'skip':
        return { filePath, action: 'skip' };

      case 'rename':
        return this.findUniqueName(filePath, checkResult.existingFiles);

      default:
        return this.findUniqueName(filePath, checkResult.existingFiles);
    }
  }

  /**
   * Find a unique filename by appending " - N" suffix.
   */
  private findUniqueName(filePath: string, existingFiles: string[]): ConflictResolution {
    const dir = path.dirname(filePath);
    const ext = path.extname(filePath);
    const baseName = path.basename(filePath, ext);

    // Extract existing suffix numbers (pattern: basename-2, basename-3, etc.)
    const existingNumbers = new Set<number>();
    for (const file of existingFiles) {
      const fBase = path.basename(file, path.extname(file));
      const suffixMatch = fBase.match(/-(\d+)$/);
      if (suffixMatch) {
        existingNumbers.add(parseInt(suffixMatch[1], 10));
      }
    }

    // Find the next available number starting from 2
    // (the original file is implicitly "-1", duplicates start at "-2")
    let counter = 2;
    while (existingNumbers.has(counter)) {
      counter++;
    }

    const newFileName = `${baseName}-${counter}${ext}`;
    const newFilePath = path.join(dir, newFileName);

    // Recursively check if the new name also exists (unlikely but possible)
    if (existsSync(newFilePath)) {
      return this.findUniqueName(newFilePath, [...existingFiles, newFileName]);
    }

    return { filePath: newFilePath, action: 'rename' };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const conflictHandler = new ConflictHandler();
