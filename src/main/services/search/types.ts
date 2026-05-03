// Search types for the keyword search module

export interface HybridSearchOptions {
  query: string;
  topK?: number; // default 20
  vectorWeight?: number; // default 0.6 (unused, kept for API compat)
  keywordWeight?: number; // default 0.4 (unused, kept for API compat)
  minScore?: number; // default 0.0
  searchTargets?: ('source_items' | 'distilled_outputs')[];
}

export interface SearchResult {
  id: string;
  type: 'source_item' | 'distilled_output';
  title: string;
  preview: string;
  score: number;
  vectorScore: number | null;
  keywordScore: number | null;
  rank: number;
  source: 'vector' | 'keyword' | 'hybrid';
  metadata: {
    category?: string;
    tags?: string[];
    createdAt: number;
    status?: string;
  };
}
