import type { DistilledOutput, SourceItem } from '../../../shared/types';
import type {
  AcMindFormatProfile,
  AcMindStandardFields,
} from '../../../shared/outputSpec';
import {
  DEFAULT_ACMIND_FORMAT_PROFILE,
  buildAcMindFieldsFromContent,
  buildAcMindFrontmatterData,
  formatCapturedAt,
} from '../../../shared/outputSpec';

// ---------------------------------------------------------------------------
// Extended frontmatter options (beyond AcMindStandardFields)
// ---------------------------------------------------------------------------

export interface FrontmatterExtras {
  /** SourceItem.originalId — deduplication traceability */
  original_id?: string;
  /** Export batch ID — DistilledOutput.id or out_xxx for pipeline path */
  output_id?: string;
  /** SourceItem.source — e.g. clipboard, screenshot, manual */
  source_type?: string;
  /** SourceItem.sourceApp — the real origin app (e.g. ChatGPT, Finder, pdf_import) */
  source_app?: string;
  /** Fixed value: 'AcMind' — the tool that wrote this file */
  writer_app?: string;
  /** ISO date string for created time */
  created?: string;
  /** ISO date string for last updated time */
  updated?: string;
  /** V2.1 Phase 7.4: Original URL for webpage sources */
  source_url?: string;
  /** V2.1 Phase 7.4: Domain extracted from URL */
  domain?: string;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export function buildStandardFields(
  distilledOutput: DistilledOutput,
  sourceItem: SourceItem,
  options?: {
    project?: string;
    status?: AcMindStandardFields['status'];
    includeRawContent?: boolean;
  },
): AcMindStandardFields {
  return buildAcMindFieldsFromContent({
    distilledOutput,
    sourceItem,
    project: options?.project ?? DEFAULT_ACMIND_FORMAT_PROFILE.default_values.project ?? '默认',
    status: options?.status ?? 'exported',
    includeRawContent: options?.includeRawContent ?? false,
  });
}

/**
 * Build frontmatter data from AcMindStandardFields + extras.
 * This is the centralized entry point — ALL frontmatter generation MUST go through here.
 *
 * Standard fields come from the profile's field_mapping.
 * Extra fields (original_id, output_id, source_type, source_app, writer_app, created, updated)
 * are always appended after the mapped fields.
 */
export function buildFrontmatterData(
  fields: AcMindStandardFields,
  profile: AcMindFormatProfile = DEFAULT_ACMIND_FORMAT_PROFILE,
  extras?: FrontmatterExtras,
): Record<string, unknown> {
  // 1. Standard fields from profile's field_mapping
  const data = buildAcMindFrontmatterData(fields, profile);

  // 2. Append extra traceability fields (always written, not controlled by field_mapping)
  if (extras) {
    if (extras.original_id) {
      data['original_id'] = extras.original_id;
    }
    if (extras.output_id) {
      data['output_id'] = extras.output_id;
    }
    if (extras.source_type) {
      data['source_type'] = extras.source_type;
    }
    if (extras.source_app) {
      data['source_app'] = extras.source_app;
    }
    // writer_app is always 'AcMind' — the tool that wrote this file
    data['writer_app'] = extras.writer_app ?? 'AcMind';
    if (extras.created) {
      data['created'] = extras.created;
    }
    if (extras.updated) {
      data['updated'] = extras.updated;
    }
    // V2.1 Phase 7.4: source_url and domain for webpage sources
    if (extras.source_url) {
      data['source_url'] = extras.source_url;
    }
    if (extras.domain) {
      data['domain'] = extras.domain;
    }
  }

  return data;
}

/**
 * Build frontmatter data from raw fields (ContentPipeline path).
 * Includes original_id, output_id, source_type, source_app, writer_app, created, updated.
 */
export function buildFrontmatterDataFromRaw(
  fields: {
    title: string;
    summary: string;
    tags: string[];
    category: string;
    source: string;
    captured_at: string;
    project: string;
    status: string;
    confidence: number;
    schema_version?: string;
    original_id?: string;
    output_id?: string;
    source_type?: string;
    source_app?: string;
    writer_app?: string;
    created?: string;
    updated?: string;
    source_url?: string;
    domain?: string;
    // Phase 10: Audio-specific fields
    transcript_status?: string;
    audio_file?: string;
    quality_flags?: string[];
  },
  profile: { field_mapping: Record<string, string> },
): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  const mapping = profile.field_mapping;

  // Map fields according to profile's field_mapping
  if (mapping.schema_version) data[mapping.schema_version] = fields.schema_version ?? '0.2';
  if (mapping.title) data[mapping.title] = fields.title;
  if (mapping.summary) data[mapping.summary] = fields.summary;
  if (mapping.tags) data[mapping.tags] = fields.tags;
  if (mapping.category) data[mapping.category] = fields.category;
  if (mapping.source) data[mapping.source] = fields.source;
  if (mapping.captured_at) data[mapping.captured_at] = fields.captured_at;
  if (mapping.project) data[mapping.project] = fields.project;
  if (mapping.status) data[mapping.status] = fields.status;
  if (mapping.confidence) data[mapping.confidence] = fields.confidence;

  // Always include traceability fields
  if (fields.original_id) {
    data['original_id'] = fields.original_id;
  }
  if (fields.output_id) {
    data['output_id'] = fields.output_id;
  }
  if (fields.source_type) {
    data['source_type'] = fields.source_type;
  }
  // source_app = the real origin app (e.g. ChatGPT, Finder, pdf_import)
  if (fields.source_app) {
    data['source_app'] = fields.source_app;
  }
  // writer_app is always 'AcMind' — the tool that wrote this file
  data['writer_app'] = fields.writer_app ?? 'AcMind';
  if (fields.created) {
    data['created'] = fields.created;
  }
  if (fields.updated) {
    data['updated'] = fields.updated;
  }
  // V2.1 Phase 7.4: source_url and domain for webpage sources
  if (fields.source_url) {
    data['source_url'] = fields.source_url;
  }
  if (fields.domain) {
    data['domain'] = fields.domain;
  }
  // Phase 10: Audio-specific frontmatter fields
  if (fields.transcript_status) {
    data['transcript_status'] = fields.transcript_status;
  }
  if (fields.audio_file) {
    data['audio_file'] = fields.audio_file;
  }
  if (fields.quality_flags && fields.quality_flags.length > 0) {
    data['quality_flags'] = fields.quality_flags;
  }

  return data;
}

export function buildFilenameDate(timestampSeconds: number): string {
  return formatCapturedAt(timestampSeconds).replace(':', '-');
}
