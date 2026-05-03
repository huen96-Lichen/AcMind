/**
 * One-time migration: backfill contentPath for legacy SourceItems
 * that were created before Phase 1B fixes.
 *
 * Only runs once, controlled by DB schema version (v18).
 */

import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { storage } from './storage';
import { settings } from './settings';
import { logger } from './logger';

export function migrateLegacyContentPath(): void {
  // Find SourceItems with empty contentPath from clipboard/manual sources
  const allItems = storage.getSourceItems({ source: 'clipboard' });
  const manualItems = storage.getSourceItems({ source: 'manual' });
  const items = [...allItems, ...manualItems].filter(
    item => !item.contentPath || !existsSync(item.contentPath),
  );

  if (items.length === 0) {
    logger.info('app', 'migrateLegacyContent', 'run', 'No legacy items to migrate');
    return;
  }

  logger.info('app', 'migrateLegacyContent', 'run', `Found ${items.length} legacy items to migrate`);

  let migrated = 0;
  let skipped = 0;

  for (const item of items) {
    try {
      // Strategy 1: check asset_files for existing file
      const assets = storage.listAssetFilesBySourceItem(item.id);
      const fallback = assets.find(a => a.localPath && existsSync(a.localPath));

      if (fallback?.localPath) {
        storage.updateSourceItem(item.id, { contentPath: fallback.localPath });
        migrated++;
        continue;
      }

      // Strategy 2: for text items with previewText, materialize content
      if (item.type === 'text' && item.previewText) {
        const storageRoot = settings.getStorageRoot();
        const dateDir = new Date().toISOString().slice(0, 10);
        const sourcesDir = path.join(storageRoot, 'sources', dateDir);
        mkdirSync(sourcesDir, { recursive: true });
        const contentPath = path.join(sourcesDir, `${item.id}.txt`);
        writeFileSync(contentPath, item.previewText, 'utf8');
        storage.updateSourceItem(item.id, { contentPath });
        migrated++;
        continue;
      }

      // Strategy 3: image items without asset — cannot recover, skip
      logger.warn('app', 'migrateLegacyContent', 'skip', 'Cannot recover content for item', {
        id: item.id,
        type: item.type,
        source: item.source,
      });
      skipped++;
    } catch (error) {
      logger.error('app', 'migrateLegacyContent', 'error', 'Migration failed for item', {
        id: item.id,
        error: error instanceof Error ? error.message : String(error),
      });
      skipped++;
    }
  }

  logger.info('app', 'migrateLegacyContent', 'done', `Migration complete: ${migrated} migrated, ${skipped} skipped`);
}
