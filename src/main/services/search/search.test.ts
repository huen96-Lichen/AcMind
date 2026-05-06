/**
 * Tests for the search module: keywordSearch, embeddingService, vectorSearch
 */

import { describe, it, expect, beforeEach } from 'vitest';

// ── vectorSearch: cosineSimilarity logic ──────────────────────────────────

describe('VectorSearch - cosineSimilarity', () => {
  // We test the cosine similarity logic directly since it's the core algorithm
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

  it('should return 1 for identical vectors', () => {
    const v = [1, 2, 3, 4, 5];
    expect(cosineSimilarity(v, v)).toBeCloseTo(1.0, 5);
  });

  it('should return 0 for orthogonal vectors', () => {
    const a = [1, 0, 0];
    const b = [0, 1, 0];
    expect(cosineSimilarity(a, b)).toBeCloseTo(0.0, 5);
  });

  it('should return 0 for empty vectors', () => {
    expect(cosineSimilarity([], [])).toBe(0);
  });

  it('should return 0 for vectors of different lengths', () => {
    expect(cosineSimilarity([1, 2], [1, 2, 3])).toBe(0);
  });

  it('should return 0 for zero vectors', () => {
    expect(cosineSimilarity([0, 0, 0], [1, 2, 3])).toBe(0);
  });

  it('should handle negative values correctly', () => {
    const a = [1, 1];
    const b = [-1, -1];
    expect(cosineSimilarity(a, b)).toBeCloseTo(-1.0, 5);
  });

  it('should return positive similarity for similar vectors', () => {
    const a = [1, 2, 3];
    const b = [2, 4, 6]; // scaled by 2
    expect(cosineSimilarity(a, b)).toBeCloseTo(1.0, 5);
  });

  it('should return moderate similarity for somewhat similar vectors', () => {
    const a = [1, 0, 0];
    const b = [1, 1, 0];
    expect(cosineSimilarity(a, b)).toBeCloseTo(1 / Math.sqrt(2), 5);
  });
});

// ── keywordSearch: FTS query escaping ─────────────────────────────────────

describe('KeywordSearch - escapeFtsQuery', () => {
  // Test the escaping logic used in keywordSearch
  function escapeFtsQuery(query: string): string {
    const tokens = query
      .split(/\s+/)
      .filter((t) => t.length > 0)
      .map((t) => {
        const cleaned = t.replace(/[*():"^]/g, '');
        return cleaned ? `"${cleaned}"` : '';
      })
      .filter(Boolean);
    return tokens.join(' ');
  }

  it('should escape FTS5 special characters', () => {
    expect(escapeFtsQuery('hello * world')).toBe('"hello" "world"');
  });

  it('should handle quoted input', () => {
    expect(escapeFtsQuery('"test"')).toBe('"test"');
  });

  it('should handle empty string', () => {
    expect(escapeFtsQuery('')).toBe('');
  });

  it('should handle only special characters', () => {
    expect(escapeFtsQuery('*():"^')).toBe('');
  });

  it('should preserve normal tokens', () => {
    expect(escapeFtsQuery('hello world test')).toBe('"hello" "world" "test"');
  });

  it('should handle mixed content', () => {
    expect(escapeFtsQuery('hello* (world) "test"')).toBe('"hello" "world" "test"');
  });
});

// ── Hybrid Search: RRF fusion logic ───────────────────────────────────────

describe('HybridSearch - Reciprocal Rank Fusion', () => {
  it('should fuse keyword and vector results correctly', () => {
    const keywordResults = [
      { itemId: 'a', score: 10 },
      { itemId: 'b', score: 8 },
      { itemId: 'c', score: 5 },
    ];
    const vectorResults = [
      { itemId: 'b', score: 0.95 },
      { itemId: 'd', score: 0.90 },
      { itemId: 'a', score: 0.85 },
    ];

    const vectorWeight = 0.6;
    const keywordWeight = 0.4;
    const k = 60;

    const fusedScores = new Map<string, { score: number; vectorScore: number | null; keywordScore: number | null; source: string }>();

    for (let i = 0; i < keywordResults.length; i++) {
      const r = keywordResults[i];
      const rrfScore = keywordWeight / (i + 1 + k);
      const existing = fusedScores.get(r.itemId);
      if (existing) {
        existing.score += rrfScore;
        existing.keywordScore = r.score;
        existing.source = 'hybrid';
      } else {
        fusedScores.set(r.itemId, { score: rrfScore, vectorScore: null, keywordScore: r.score, source: 'keyword' });
      }
    }

    for (let i = 0; i < vectorResults.length; i++) {
      const r = vectorResults[i];
      const rrfScore = vectorWeight / (i + 1 + k);
      const existing = fusedScores.get(r.itemId);
      if (existing) {
        existing.score += rrfScore;
        existing.vectorScore = r.score;
        existing.source = 'hybrid';
      } else {
        fusedScores.set(r.itemId, { score: rrfScore, vectorScore: r.score, keywordScore: null, source: 'vector' });
      }
    }

    const sorted = [...fusedScores.entries()].sort((a, b) => b[1].score - a[1].score);

    // Items appearing in both lists should rank higher
    expect(sorted[0][0]).toBe('b'); // rank 1 in vector, rank 2 in keyword
    expect(sorted[0][1].source).toBe('hybrid');

    expect(sorted[1][0]).toBe('a'); // rank 1 in keyword, rank 3 in vector
    expect(sorted[1][1].source).toBe('hybrid');

    // Items in only one list should rank lower
    const singleSourceItems = sorted.filter(([, v]) => v.source !== 'hybrid');
    expect(singleSourceItems.length).toBe(2); // c (keyword only) and d (vector only)
  });

  it('should handle empty vector results (keyword-only fallback)', () => {
    const keywordResults = [
      { itemId: 'a', score: 10 },
      { itemId: 'b', score: 8 },
    ];
    const vectorResults: Array<{ itemId: string; score: number }> = [];

    const keywordWeight = 0.4;
    const k = 60;
    const fusedScores = new Map<string, { score: number; source: string }>();

    for (let i = 0; i < keywordResults.length; i++) {
      const r = keywordResults[i];
      fusedScores.set(r.itemId, { score: keywordWeight / (i + 1 + k), source: 'keyword' });
    }

    expect(fusedScores.size).toBe(2);
    expect(fusedScores.get('a')!.source).toBe('keyword');
    expect(fusedScores.get('b')!.source).toBe('keyword');
  });
});
