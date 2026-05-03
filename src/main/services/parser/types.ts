export interface ParsedDocument {
  title: string;
  content: string; // Full text content (Markdown preferred)
  previewText: string; // First 500 chars for preview
  sections: ParsedSection[];
  metadata: {
    sourceType: 'pdf' | 'docx' | 'webpage';
    originalPath?: string;
    originalUrl?: string;
    pageCount?: number;
    wordCount?: number;
    author?: string;
    createdAt?: string;
  };
}

export interface ParsedSection {
  heading?: string;
  level?: number;
  content: string;
}

export interface ParseResult {
  success: boolean;
  document?: ParsedDocument;
  error?: string;
}

export interface ImportResult {
  success: boolean;
  sourceItemId?: string;
  title?: string;
  error?: string;
}
