import Database from 'better-sqlite3';
import { logger } from '../../logger';

interface KeywordSearchResult {
  itemType: string;
  itemId: string;
  title: string;
  snippet: string;
  score: number;
}

/**
 * Keyword search using SQLite FTS5 with BM25 ranking.
 */
class KeywordSearch {
  /**
   * Create the FTS5 virtual table if it does not exist.
   */
  initTable(db: Database.Database): void {
    db.exec(`
      CREATE VIRTUAL TABLE IF NOT EXISTS search_fts
        USING fts5(
          item_type,
          item_id,
          title,
          content,
          tags
        )
    `);
    logger.info('search', 'keywordSearch', 'initTable', 'FTS5 table ensured');
  }

  /**
   * Rebuild the FTS index from existing source_items and distilled_outputs.
   *
   * @param db - Database instance
   * @param sourceItems - Array of source item records
   * @param distilledOutputs - Array of distilled output records
   */
  rebuildIndex(
    db: Database.Database,
    sourceItems: Array<{
      id: string;
      title?: string;
      content?: string;
      tags?: string;
      category?: string;
      created_at?: number;
    }>,
    distilledOutputs: Array<{
      id: string;
      title?: string;
      content?: string;
      tags?: string;
      status?: string;
      created_at?: number;
    }>,
  ): void {
    // Ensure table exists
    this.initTable(db);

    // Clear existing index
    db.exec('DELETE FROM search_fts');

    const insert = db.prepare(`
      INSERT INTO search_fts (item_type, item_id, title, content, tags)
      VALUES (?, ?, ?, ?, ?)
    `);

    const rebuild = db.transaction(() => {
      // Index source items
      for (const item of sourceItems) {
        insert.run(
          'source_item',
          item.id,
          item.title ?? '',
          item.content ?? '',
          item.tags ?? '',
        );
      }

      // Index distilled outputs
      for (const item of distilledOutputs) {
        insert.run(
          'distilled_output',
          item.id,
          item.title ?? '',
          item.content ?? '',
          item.tags ?? '',
        );
      }
    });

    rebuild();
    logger.info('search', 'keywordSearch', 'rebuildIndex', 'index rebuilt', {
      sourceItems: sourceItems.length,
      distilledOutputs: distilledOutputs.length,
    });
  }

  /**
   * Perform a keyword search using FTS5 MATCH.
   * Uses BM25 ranking built into FTS5.
   *
   * @param db - Database instance
   * @param query - Search query string
   * @param topK - Maximum number of results
   * @param itemType - Optional filter by item type
   * @returns Array of search results sorted by BM25 score
   */
  search(
    db: Database.Database,
    query: string,
    topK: number = 20,
    itemType?: string,
  ): KeywordSearchResult[] {
    // Escape special FTS5 characters in the query
    const safeQuery = this.escapeFtsQuery(query);
    if (!safeQuery) {
      return [];
    }

    let sql = `
      SELECT
        item_type,
        item_id,
        title,
        snippet(search_fts, 2, '<mark>', '</mark>', '...', 32) as snippet,
        bm25(search_fts) as score
      FROM search_fts
      WHERE search_fts MATCH ?
    `;
    const params: unknown[] = [safeQuery];

    if (itemType) {
      sql += ' AND item_type = ?';
      params.push(itemType);
    }

    sql += ' ORDER BY score LIMIT ?';
    params.push(topK);

    try {
      const rows = db.prepare(sql).all(...params) as Array<{
        item_type: string;
        item_id: string;
        title: string;
        snippet: string;
        score: number;
      }>;

      const results: KeywordSearchResult[] = rows.map((row) => ({
        itemType: row.item_type,
        itemId: row.item_id,
        title: row.title,
        snippet: row.snippet,
        score: -row.score, // FTS5 bm25 returns negative values (more negative = better match)
      }));

      logger.info('search', 'keywordSearch', 'search', 'complete', {
        query,
        results: results.length,
        topK,
        itemType: itemType ?? 'all',
      });

      return results;
    } catch (err) {
      // FTS5 can throw on malformed queries even after escaping
      logger.error('search', 'keywordSearch', 'search', 'FTS query error', {
        query: safeQuery,
        error: err instanceof Error ? err.message : String(err),
      });
      return [];
    }
  }

  /**
   * Escape special FTS5 query characters to prevent syntax errors.
   * Wraps each token in double quotes to handle special characters.
   */
  private escapeFtsQuery(query: string): string {
    // Remove or escape FTS5 special characters: " * ( ) : ^
    // Simple approach: wrap the whole query in quotes for a phrase search,
    // but also support AND/OR by splitting on whitespace.
    const tokens = query
      .split(/\s+/)
      .filter((t) => t.length > 0)
      .map((t) => {
        // Remove FTS5 operators from the token
        const cleaned = t.replace(/[*():"^]/g, '');
        return cleaned ? `"${cleaned}"` : '';
      })
      .filter(Boolean);

    return tokens.join(' ');
  }
}

export const keywordSearch = new KeywordSearch();
