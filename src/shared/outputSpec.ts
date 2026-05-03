import type { DistilledOutput, SourceItem } from './types';
import { normalizeTags } from './tagNormalizer';

export const ACMIND_SCHEMA_VERSION = '0.2' as const;

export type AcMindSource =
  | 'clipboard'
  | 'screenshot'
  | 'webpage'
  | 'manual'
  | 'file'
  | 'transcript'
  | 'image_ocr'
  | 'other';

export type AcMindStatus =
  | 'collected'
  | 'cleaned'
  | 'reviewing'
  | 'reviewed'
  | 'exported'
  | 'failed';

export type AcMindStandardFields = {
  schema_version: string;
  title: string;
  summary: string;
  tags: string[];
  category: string;
  body: string;
  raw_content?: string;
  source: AcMindSource;
  captured_at: string;
  project: string;
  status: AcMindStatus;
  confidence: number;
};

export type AcMindFormatProfile = {
  id: string;
  name: string;
  schema_version: string;
  description?: string;
  frontmatter_style: 'yaml';
  field_mapping: Record<keyof Omit<AcMindStandardFields, 'raw_content' | 'body'>, string>;
  filename_pattern: string;
  date_format: string;
  filename_date_format: string;
  show_summary_quote: boolean;
  show_raw_content: boolean;
  title_heading_level: 1 | 2 | 3;
  sanitize_filename: boolean;
  forbidden_filename_chars: string[];
  default_values: Partial<AcMindStandardFields>;
};

export const DEFAULT_ACMIND_FIELDS: Partial<AcMindStandardFields> = {
  schema_version: ACMIND_SCHEMA_VERSION,
  tags: [],
  category: '未分类',
  source: 'manual',
  project: '默认',
  status: 'collected',
  confidence: 0.5,
};

export const DEFAULT_ACMIND_FORMAT_PROFILE: AcMindFormatProfile = {
  id: 'acmind-default',
  name: 'AcMind Default Markdown',
  schema_version: ACMIND_SCHEMA_VERSION,
  description: 'AcMind 默认 Markdown 输出格式，适合 Obsidian 和长期本地知识库维护。',
  frontmatter_style: 'yaml',
  field_mapping: {
    schema_version: 'schema_version',
    title: 'title',
    summary: 'summary',
    tags: 'tags',
    category: 'category',
    source: 'source',
    captured_at: 'captured_at',
    project: 'project',
    status: 'status',
    confidence: 'confidence',
  },
  filename_pattern: '{{captured_at_filename}}_{{title}}.md',
  date_format: 'YYYY-MM-DD HH:mm',
  filename_date_format: 'YYYY-MM-DD_HHmm',
  show_summary_quote: true,
  show_raw_content: false,
  title_heading_level: 1,
  sanitize_filename: true,
  forbidden_filename_chars: ['/', '\\', ':', '*', '?', '"', '<', '>', '|', '#'],
  default_values: {
    schema_version: ACMIND_SCHEMA_VERSION,
    tags: [],
    category: '未分类',
    source: 'manual',
    project: '默认',
    status: 'collected',
    confidence: 0.5,
  },
};

export function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function sanitizeFilename(input: string): string {
  return input
    .replace(/^[\s>*#\-–—•·]+/, '')
    .replace(/[\\/:*?"<>|#]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
}

export function formatCapturedAt(timestampSeconds: number): string {
  const date = new Date(timestampSeconds * 1000);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hour = String(date.getHours()).padStart(2, '0');
  const minute = String(date.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day} ${hour}:${minute}`;
}

export function formatFilenameDate(timestampSeconds: number): string {
  const date = new Date(timestampSeconds * 1000);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hour = String(date.getHours()).padStart(2, '0');
  const minute = String(date.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}_${hour}${minute}`;
}

export function normalizeAcMindFields(
  input: Partial<AcMindStandardFields>,
  now: string,
): AcMindStandardFields {
  return {
    schema_version: input.schema_version ?? ACMIND_SCHEMA_VERSION,
    title: input.title?.trim() || '未命名内容',
    summary: input.summary?.trim() || '暂无总结。',
    tags: normalizeTags(input.tags),
    category: input.category?.trim() || '未分类',
    body: input.body?.trim() || '',
    raw_content: input.raw_content ?? '',
    source: input.source ?? 'manual',
    captured_at: input.captured_at ?? now,
    project: input.project?.trim() || '默认',
    status: input.status ?? 'collected',
    confidence: typeof input.confidence === 'number' ? clamp(input.confidence, 0, 1) : 0.5,
  };
}

export function buildAcMindFieldsFromContent(params: {
  distilledOutput: DistilledOutput;
  sourceItem: SourceItem;
  project?: string;
  status?: AcMindStatus;
  includeRawContent?: boolean;
}): AcMindStandardFields {
  const { distilledOutput, sourceItem } = params;
  const title = (distilledOutput.suggestedTitle ?? sourceItem.previewText ?? '未命名内容').trim() || '未命名内容';
  const summary = (distilledOutput.summary ?? sourceItem.previewText ?? '暂无总结。').trim() || '暂无总结。';
  const body = stripFrontmatter(distilledOutput.contentMarkdown ?? sourceItem.previewText ?? sourceItem.ocrText ?? sourceItem.originalUrl ?? summary);
  const rawContent = params.includeRawContent
    ? (sourceItem.previewText ?? sourceItem.ocrText ?? sourceItem.originalUrl ?? '')
    : '';

  return normalizeAcMindFields(
    {
      schema_version: ACMIND_SCHEMA_VERSION,
      title,
      summary,
      tags: distilledOutput.tags ?? [],
      category: distilledOutput.category ?? '未分类',
      body: body.trim() || summary,
      raw_content: rawContent,
      source: mapSourceToAcMindSource(sourceItem.source),
      captured_at: formatCapturedAt(sourceItem.createdAt),
      project: params.project ?? '默认',
      status: params.status ?? 'exported',
      confidence: typeof distilledOutput.confidence === 'number' ? distilledOutput.confidence : 0.5,
    },
    formatCapturedAt(sourceItem.createdAt),
  );
}

export function buildAcMindFrontmatterData(fields: AcMindStandardFields, profile: AcMindFormatProfile = DEFAULT_ACMIND_FORMAT_PROFILE): Record<string, unknown> {
  const frontmatter: Record<string, unknown> = {};

  for (const [fieldName, frontmatterKey] of Object.entries(profile.field_mapping) as Array<[
    keyof Omit<AcMindStandardFields, 'raw_content' | 'body'>,
    string,
  ]>) {
    frontmatter[frontmatterKey] = fields[fieldName];
  }

  return frontmatter;
}

export function mapSourceToAcMindSource(source: string): AcMindSource {
  switch (source) {
    case 'clipboard':
    case 'screenshot':
    case 'webpage':
    case 'manual':
    case 'file':
    case 'transcript':
    case 'image_ocr':
    case 'other':
      return source;
    default:
      return 'other';
  }
}

export function stripFrontmatter(markdown: string): string {
  return markdown.replace(/^---\n[\s\S]*?\n---\n?/, '').trim();
}
