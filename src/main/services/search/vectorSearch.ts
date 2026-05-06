/**
 * Vector Search — 基于余弦相似度的向量搜索
 *
 * 职责：
 * 1. 从 SQLite 读取存储的嵌入向量
 * 2. 对查询文本生成嵌入
 * 3. 计算余弦相似度并返回 top-K 结果
 */

import Database from 'better-sqlite3';
import { logger } from '../../logger';
import { embeddingService } from './embeddingService';
import type { ProviderConfig } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface VectorSearchResult {
  itemType: string;
  itemId: string;
  score: number; // cosine similarity, 0-1
}

// ---------------------------------------------------------------------------
// VectorSearch
// ---------------------------------------------------------------------------

class VectorSearch {
  /**
   * Perform vector similarity search.
   *
   * @param db - Database instance
   * @param queryEmbedding - The query vector
   * @param topK - Maximum number of results
   * @param itemType - Optional filter by item type
   * @returns Array of results sorted by cosine similarity (descending)
   */
  search(
    db: Database.Database,
    queryEmbedding: number[],
    topK: number = 20,
    itemType?: string,
  ): VectorSearchResult[] {
    const allEmbeddings = embeddingService.getAll(db);

    // Filter by type if specified
    const candidates = itemType
      ? allEmbeddings.filter((e) => e.itemType === itemType)
      : allEmbeddings;

    if (candidates.length === 0) {
      return [];
    }

    // Compute cosine similarity for each candidate
    const scored: VectorSearchResult[] = candidates.map((record) => {
      const score = cosineSimilarity(queryEmbedding, record.embedding);
      return {
        itemType: record.itemType,
        itemId: record.itemId,
        score,
      };
    });

    // Sort by score descending and take top-K
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, topK);
  }

  /**
   * Convenience method: embed a query and search in one call.
   */
  async searchByQuery(
    db: Database.Database,
    provider: ProviderConfig,
    query: string,
    topK: number = 20,
    itemType?: string,
  ): Promise<VectorSearchResult[]> {
    const queryEmbedding = await embeddingService.embedText(provider, query);
    if (!queryEmbedding) {
      logger.warn('search', 'vectorSearch', 'searchByQuery', 'Failed to embed query');
      return [];
    }

    return this.search(db, queryEmbedding, topK, itemType);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Compute cosine similarity between two vectors.
 * Returns a value between -1 and 1 (1 = identical, 0 = orthogonal, -1 = opposite).
 */
function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length || a.length === 0) return 0;

  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  const denominator = Math.sqrt(normA) * Math.sqrt(normB);
  if (denominator === 0) return 0;

  return dotProduct / denominator;
}

export const vectorSearch = new VectorSearch();
