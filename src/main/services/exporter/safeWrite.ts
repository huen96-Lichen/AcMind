// AcMind Safe Write Utility
// Provides atomic file writes to prevent corruption from interrupted writes.
// Pattern: write to temp file → rename to target path.

import path from 'node:path';
import { existsSync, mkdirSync, renameSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import crypto from 'node:crypto';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SafeWriteResult {
  /** Final file path (may differ from input if rename was needed) */
  filePath: string;
  /** Whether a new file was created (vs overwritten) */
  created: boolean;
  /** Whether the file was renamed due to conflict */
  renamed: boolean;
}

// ---------------------------------------------------------------------------
// safeWrite
// ---------------------------------------------------------------------------

/**
 * Write content to a file atomically using temp-file + rename pattern.
 * This prevents file corruption if the process crashes mid-write.
 *
 * @param targetPath - The desired final file path
 * @param content - The content to write (string)
 * @param options.encoding - File encoding (default: 'utf8')
 * @returns The final file path and metadata
 */
export function safeWrite(
  targetPath: string,
  content: string,
  options?: { encoding?: BufferEncoding },
): SafeWriteResult {
  const encoding = options?.encoding ?? 'utf8';
  if (!content.trim()) {
    throw new Error('Refusing to write empty Markdown content');
  }

  // Ensure parent directory exists
  const parentDir = path.dirname(targetPath);
  if (!existsSync(parentDir)) {
    mkdirSync(parentDir, { recursive: true });
  }

  // Generate temp file path in the same directory (ensures same filesystem for rename)
  const tempFileName = `.acmind_tmp_${crypto.randomBytes(8).toString('hex')}`;
  const tempPath = path.join(parentDir, tempFileName);

  try {
    // Write to temp file
    writeFileSync(tempPath, content, encoding);

    // Atomic rename from temp to target
    renameSync(tempPath, targetPath);

    return { filePath: targetPath, created: true, renamed: false };
  } catch (error) {
    // Clean up temp file on failure
    try {
      if (existsSync(tempPath)) {
        unlinkSync(tempPath);
      }
    } catch {
      // Ignore cleanup errors
    }

    throw error;
  }
}

// ---------------------------------------------------------------------------
// validateVaultPath
// ---------------------------------------------------------------------------

export interface VaultValidationResult {
  valid: boolean;
  error?: string;
  userMessage: string;
}

/**
 * Validate that a vault path is usable for writing.
 * Checks: non-empty, exists, is directory, writable.
 *
 * Returns a user-friendly message suitable for display in the UI.
 */
export function validateVaultPath(vaultPath: string): VaultValidationResult {
  if (!vaultPath || !vaultPath.trim()) {
    return {
      valid: false,
      error: 'VAULT_NOT_CONFIGURED',
      userMessage: 'Obsidian 仓库路径未配置，请在设置中设置仓库路径。',
    };
  }

  if (!existsSync(vaultPath)) {
    return {
      valid: false,
      error: 'VAULT_NOT_FOUND',
      userMessage: `Obsidian 仓库路径不存在: ${vaultPath}。请检查路径是否正确。`,
    };
  }

  try {
    const stat = statSync(vaultPath);
    if (!stat.isDirectory()) {
      return {
        valid: false,
        error: 'VAULT_NOT_DIRECTORY',
        userMessage: `路径不是文件夹: ${vaultPath}。请选择一个有效的 Obsidian 仓库目录。`,
      };
    }
  } catch {
    return {
      valid: false,
      error: 'VAULT_ACCESS_ERROR',
      userMessage: `无法访问路径: ${vaultPath}。请检查权限设置。`,
    };
  }

  // Check write permission by testing a temp file
  try {
    const testFile = path.join(vaultPath, `.acmind_write_test_${Date.now()}`);
    writeFileSync(testFile, 'test');
    unlinkSync(testFile);
  } catch {
    return {
      valid: false,
      error: 'VAULT_NOT_WRITABLE',
      userMessage: `无法写入 Obsidian 仓库: ${vaultPath}。请检查文件夹权限。`,
    };
  }

  return { valid: true, userMessage: '仓库路径验证通过。' };
}
