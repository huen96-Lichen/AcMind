// PinMind Vault Importer
// Unified entry point for Vault import functionality

import type { ImportOptions, ImportTask, ScannedVaultFile } from '../../../shared/types';
import { vaultScanner } from './vaultScanner';
import { importQueue } from './importQueue';

export class VaultImporter {
  scan(vaultPath: string, options?: Partial<ImportOptions>): ScannedVaultFile[] {
    return vaultScanner.scan(vaultPath, options);
  }

  getScanSummary(files: ScannedVaultFile[]) {
    return vaultScanner.getSummary(files);
  }

  startImport(options: ImportOptions): string {
    return importQueue.startImport(options);
  }

  getTaskStatus(taskId: string): ImportTask | null {
    return importQueue.getStatus(taskId);
  }

  cancelImport(taskId: string): boolean {
    return importQueue.cancel(taskId);
  }

  getImportHistory(limit?: number): ImportTask[] {
    return importQueue.getHistory(limit);
  }
}

export const vaultImporter = new VaultImporter();
