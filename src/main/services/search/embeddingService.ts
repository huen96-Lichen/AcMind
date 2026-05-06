/**
 * Embedding Service — 向量嵌入生成与管理
 *
 * 职责：
 * 1. 为 source_items 和 distilled_outputs 生成向量嵌入
 * 2. 将嵌入存储在 SQLite 表中（JSON 序列化）
 * 3. 提供嵌入的 CRUD 操作
 * 4. 批量重建嵌入索引
 */

import Database from 'better-sqlite3';
import { logger } from '../../logger';
import { aiProviderService } from '../aiHub/aiProviderService';
import type { ProviderConfig } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface EmbeddingRecord {
  itemType: 'source_item' | 'distilled_output';
  itemId: string;
  embedding: number[];
  modelId: string;
  createdAt: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const TABLE_NAME = 'embeddings';
const BATCH_SIZE = 20; // 每批处理的文档数

// ---------------------------------------------------------------------------
// SQL
// ---------------------------------------------------------------------------

const CREATE_TABLE_SQL = `
CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  embedding TEXT NOT NULL,
  model_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (item_type, item_id)
);
CREATE INDEX IF NOT EXISTS idx_embeddings_item_type ON ${TABLE_NAME}(item_type);
`;

// ---------------------------------------------------------------------------
// EmbeddingService
// ---------------------------------------------------------------------------

class EmbeddingService {
  private initialized = false;

  /**
   * Initialize the embeddings table.
   */
  initTable(db: Database.Database): void {
    db.exec(CREATE_TABLE_SQL);
    this.initialized = true;
    logger.info('search', 'embeddingService', 'initTable', 'Embeddings table ensured');
  }

  /**
   * Store an embedding for an item.
   */
  upsert(db: Database.Database, record: EmbeddingRecord): void {
    db.prepare(`
      INSERT INTO ${TABLE_NAME} (item_type, item_id, embedding, model_id, created_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(item_type, item_id) DO UPDATE SET
        embedding = excluded.embedding,
        model_id = excluded.model_id,
        created_at = excluded.created_at
    `).run(
      record.itemType,
      record.itemId,
      JSON.stringify(record.embedding),
      record.modelId,
      record.createdAt,
    );
  }

  /**
   * Get an embedding for an item.
   */
  get(db: Database.Database, itemType: string, itemId: string): EmbeddingRecord | null {
    const row = db.prepare(
      `SELECT item_type, item_id, embedding, model_id, created_at FROM ${TABLE_NAME} WHERE item_type = ? AND item_id = ?`,
    ).get(itemType, itemId) as { item_type: string; item_id: string; embedding: string; model_id: string; created_at: number } | undefined;

    if (!row) return null;

    return {
      itemType: row.item_type as EmbeddingRecord['itemType'],
      itemId: row.item_id,
      embedding: JSON.parse(row.embedding) as number[],
      modelId: row.model_id,
      createdAt: row.created_at,
    };
  }

  /**
   * Delete an embedding.
   */
  delete(db: Database.Database, itemType: string, itemId: string): void {
    db.prepare(`DELETE FROM ${TABLE_NAME} WHERE item_type = ? AND item_id = ?`).run(itemType, itemId);
  }

  /**
   * Get all embeddings (for vector search).
   */
  getAll(db: Database.Database): EmbeddingRecord[] {
    const rows = db.prepare(
      `SELECT item_type, item_id, embedding, model_id, created_at FROM ${TABLE_NAME}`,
    ).all() as Array<{ item_type: string; item_id: string; embedding: string; model_id: string; created_at: number }>;

    return rows.map((row) => ({
      itemType: row.item_type as EmbeddingRecord['itemType'],
      itemId: row.item_id,
      embedding: JSON.parse(row.embedding) as number[],
      modelId: row.model_id,
      createdAt: row.created_at,
    }));
  }

  /**
   * Get count of stored embeddings.
   */
  count(db: Database.Database): number {
    const row = db.prepare(`SELECT COUNT(*) as cnt FROM ${TABLE_NAME}`).get() as { cnt: number };
    return row.cnt;
  }

  /**
   * Generate embedding for a single text using the given provider.
   */
  async embedText(provider: ProviderConfig, text: string): Promise<number[] | null> {
    const result = await aiProviderService.callEmbedding(provider, [text]);
    if (!result.success || result.embeddings.length === 0) {
      logger.error('search', 'embeddingService', 'embedText', 'Failed to generate embedding', {
        error: result.error,
        providerId: provider.id,
      });
      return null;
    }
    return result.embeddings[0];
  }

  /**
   * Batch generate embeddings for multiple texts.
   * Processes in batches of BATCH_SIZE to avoid overwhelming the provider.
   */
  async embedBatch(
    provider: ProviderConfig,
    items: Array<{ itemType: string; itemId: string; text: string }>,
    onProgress?: (done: number, total: number) => void,
  ): Promise<Array<{ itemType: string; itemId: string; embedding: number[] }>> {
    const results: Array<{ itemType: string; itemId: string; embedding: number[] }> = [];
    const total = items.length;

    for (let i = 0; i < items.length; i += BATCH_SIZE) {
      const batch = items.slice(i, i + BATCH_SIZE);
      const texts = batch.map((item) => item.text);

      const result = await aiProviderService.callEmbedding(provider, texts);

      if (result.success && result.embeddings.length === batch.length) {
        for (let j = 0; j < batch.length; j++) {
          results.push({
            itemType: batch[j].itemType,
            itemId: batch[j].itemId,
            embedding: result.embeddings[j],
          });
        }
      } else {
        // Fallback: try one by one
        for (const item of batch) {
          const singleResult = await aiProviderService.callEmbedding(provider, [item.text]);
          if (singleResult.success && singleResult.embeddings.length > 0) {
            results.push({
              itemType: item.itemType,
              itemId: item.itemId,
              embedding: singleResult.embeddings[0],
            });
          } else {
            logger.warn('search', 'embeddingService', 'embedBatch', `Failed to embed item ${item.itemId}`, {
              error: singleResult.error,
            });
          }
        }
      }

      onProgress?.(Math.min(i + BATCH_SIZE, total), total);
    }

    return results;
  }

  /**
   * Rebuild embeddings for all items that don't have one yet.
   * Returns the number of new embeddings created.
   */
  async rebuildMissing(
    db: Database.Database,
    provider: ProviderConfig,
    sourceItems: Array<{ id: string; title?: string; content?: string; preview_text?: string }>,
    distilledOutputs: Array<{ id: string; title?: string; summary?: string; content_markdown?: string }>,
    onProgress?: (done: number, total: number) => void,
  ): Promise<number> {
    const now = Date.now();
    let created = 0;

    // Collect items that need embeddings
    const toEmbed: Array<{ itemType: string; itemId: string; text: string }> = [];

    for (const item of sourceItems) {
      const existing = this.get(db, 'source_item', item.id);
      if (!existing) {
        const text = [item.title, item.content, item.preview_text].filter(Boolean).join('\n\n').slice(0, 8000);
        if (text.trim()) {
          toEmbed.push({ itemType: 'source_item', itemId: item.id, text });
        }
      }
    }

    for (const item of distilledOutputs) {
      const existing = this.get(db, 'distilled_output', item.id);
      if (!existing) {
        const text = [item.title, item.summary, item.content_markdown].filter(Boolean).join('\n\n').slice(0, 8000);
        if (text.trim()) {
          toEmbed.push({ itemType: 'distilled_output', itemId: item.id, text });
        }
      }
    }

    if (toEmbed.length === 0) {
      logger.info('search', 'embeddingService', 'rebuildMissing', 'All items already have embeddings');
      return 0;
    }

    logger.info('search', 'embeddingService', 'rebuildMissing', `Generating embeddings for ${toEmbed.length} items`, {
      providerId: provider.id,
      modelId: provider.modelId,
    });

    const embeddings = await this.embedBatch(provider, toEmbed, onProgress);

    const upsert = db.transaction(() => {
      for (const emb of embeddings) {
        this.upsert(db, {
          itemType: emb.itemType as EmbeddingRecord['itemType'],
          itemId: emb.itemId,
          embedding: emb.embedding,
          modelId: provider.modelId,
          createdAt: now,
        });
        created++;
      }
    });
    upsert();

    logger.info('search', 'embeddingService', 'rebuildMissing', `Created ${created} embeddings`);
    return created;
  }
}

export const embeddingService = new EmbeddingService();
