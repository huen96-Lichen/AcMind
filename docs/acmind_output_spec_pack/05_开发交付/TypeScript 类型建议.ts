export const PINMIND_SCHEMA_VERSION = '0.2' as const;

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

export const DEFAULT_PINMIND_FIELDS: Partial<AcMindStandardFields> = {
  schema_version: PINMIND_SCHEMA_VERSION,
  tags: [],
  category: '未分类',
  source: 'manual',
  project: '默认',
  status: 'collected',
  confidence: 0.5,
};

export function normalizeAcMindFields(
  input: Partial<AcMindStandardFields>,
  now: string,
): AcMindStandardFields {
  return {
    schema_version: input.schema_version ?? PINMIND_SCHEMA_VERSION,
    title: input.title?.trim() || '未命名内容',
    summary: input.summary?.trim() || '暂无总结。',
    tags: Array.isArray(input.tags) ? input.tags : [],
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

export function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function sanitizeFilename(input: string): string {
  return input
    .replace(/[\\/:*?"<>|]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
}

export function validateAcMindFields(fields: AcMindStandardFields): string[] {
  const errors: string[] = [];

  if (!fields.title.trim()) errors.push('title 不能为空');
  if (!fields.summary.trim()) errors.push('summary 不能为空');
  if (!fields.body.trim()) errors.push('body 不能为空');
  if (!Array.isArray(fields.tags)) errors.push('tags 必须是数组');
  if (fields.confidence < 0 || fields.confidence > 1) errors.push('confidence 必须在 0 到 1 之间');
  if (!fields.schema_version) errors.push('schema_version 不能为空');

  const allowedStatus: AcMindStatus[] = [
    'collected',
    'cleaned',
    'reviewing',
    'reviewed',
    'exported',
    'failed',
  ];

  if (!allowedStatus.includes(fields.status)) {
    errors.push('status 不是合法枚举值');
  }

  return errors;
}
