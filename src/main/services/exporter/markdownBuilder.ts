// AcMind Markdown Builder
// Builds complete Markdown documents from DistilledOutput + SourceItem
// Phase 0: Now reads templates from OutputSpecService (with fallback)

import type { DistilledOutput, SourceItem, VaultConfig } from '../../../shared/types';
import { frontmatterGenerator } from './frontmatter';
import { buildFrontmatterData, buildFrontmatterDataFromRaw, buildStandardFields, type FrontmatterExtras } from './standardFields';
import { outputSpecService } from '../outputSpec';

// ---------------------------------------------------------------------------
// Template variable replacements
// ---------------------------------------------------------------------------

interface TemplateContext {
  schema_version: string;
  title: string;
  summary: string;
  category: string;
  body: string;
  content: string;
  raw_content: string;
  raw_content_section: string;
  tags: string;
  source: string;
  captured_at: string;
  project: string;
  status: string;
  confidence: string;
  original_id: string;
  frontmatter: string;
  links: string;
}

// ---------------------------------------------------------------------------
// MarkdownBuilder
// ---------------------------------------------------------------------------

class MarkdownBuilder {
  /**
   * Build a complete Markdown document from a DistilledOutput and SourceItem.
   * Template priority:
   *   1. Explicitly passed template string
   *   2. VaultConfig.template (user custom template)
   *   3. OutputSpecService.getDefaultTemplate() (from spec pack or built-in fallback)
   */
  build(
    distilledOutput: DistilledOutput,
    sourceItem: SourceItem,
    vaultConfig?: Partial<VaultConfig>,
    template?: string,
  ): string {
    const context = this.buildContext(distilledOutput, sourceItem, vaultConfig);
    const effectiveTemplate = this.resolveTemplate(template, vaultConfig);
    return this.renderTemplate(effectiveTemplate, context);
  }

  /**
   * Build a preview Markdown document (truncated content for display).
   */
  buildPreview(distilledOutput: DistilledOutput, sourceItem: SourceItem): string {
    const context = this.buildContext(distilledOutput, sourceItem);
    // Truncate content for preview
    context.body = context.body.length > 500
      ? context.body.substring(0, 500) + '...'
      : context.body;
    context.summary = context.summary.length > 200
      ? context.summary.substring(0, 200) + '...'
      : context.summary;
    const template = outputSpecService.getDefaultTemplate();
    return this.renderTemplate(template, context);
  }

  /**
   * Build a Markdown document directly from AcMindStandardFields data.
   * Used by ContentPipelineService when we don't have DistilledOutput/SourceItem.
   */
  buildFromFields(
    fields: {
      title: string;
      summary: string;
      body: string;
      tags: string[];
      category: string;
      source: string;
      captured_at: string;
      project: string;
      status: string;
      confidence: number;
      raw_content?: string;
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
    template?: string,
  ): string {
    const profile = outputSpecService.getActiveProfile();
    const frontmatterData = buildFrontmatterDataFromRaw(fields, profile);
    const frontmatter = frontmatterGenerator.generate(frontmatterData);

    const rawContentSection = outputSpecService.getRawContentSection(fields.raw_content);

    const context: TemplateContext = {
      schema_version: fields.schema_version ?? '',
      title: fields.title,
      summary: fields.summary,
      category: fields.category,
      body: fields.body,
      content: fields.body,
      raw_content: fields.raw_content ?? '',
      raw_content_section: rawContentSection,
      tags: formatTagsForTemplate(fields.tags),
      source: fields.source,
      captured_at: fields.captured_at,
      project: fields.project,
      status: fields.status,
      confidence: String(fields.confidence),
      original_id: fields.original_id ?? '',
      frontmatter,
      links: '',
    };

    const effectiveTemplate = template
      ?? outputSpecService.getDefaultTemplate();

    return this.renderTemplate(effectiveTemplate, context);
  }

  // -------------------------------------------------------------------------
  // Internal methods
  // -------------------------------------------------------------------------

  /**
   * Resolve the effective template string with priority chain.
   */
  private resolveTemplate(template?: string, vaultConfig?: Partial<VaultConfig>): string {
    if (template && template.trim()) return template;
    if (vaultConfig?.template && vaultConfig.template.trim()) return vaultConfig.template;
    return outputSpecService.getDefaultTemplate();
  }

  /**
   * Build the template context from distilled output and source item.
   */
  private buildContext(
    distilledOutput: DistilledOutput,
    sourceItem: SourceItem,
    vaultConfig?: Partial<VaultConfig>,
  ): TemplateContext {
    const profile = outputSpecService.getActiveProfile();

    const fields = buildStandardFields(distilledOutput, sourceItem, {
      project: '默认',
      status: 'exported',
      includeRawContent: false,
    });

    // Build extras for traceability fields
    const now = new Date().toISOString().replace('T', ' ').replace(/\.\d+Z$/, '');

    // V2.1 Phase 7.4: Extract source_url and domain for webpage sources
    const sourceUrl = sourceItem.originalUrl || undefined;
    let domain: string | undefined;
    if (sourceUrl) {
      try { domain = new URL(sourceUrl).hostname; } catch { /* ignore */ }
    }

    const extras: FrontmatterExtras = {
      original_id: sourceItem.originalId,
      output_id: distilledOutput.id,
      source_type: sourceItem.source,
      source_app: sourceItem.sourceApp ?? undefined,
      writer_app: 'AcMind',
      created: fields.captured_at,
      updated: now,
      source_url: sourceUrl,
      domain,
    };

    const frontmatterData = buildFrontmatterData(fields, profile, extras);
    const frontmatter = frontmatterGenerator.generate(frontmatterData);
    const rawContentSection = outputSpecService.getRawContentSection(fields.raw_content);

    return {
      schema_version: fields.schema_version,
      title: fields.title,
      summary: fields.summary,
      category: fields.category,
      body: fields.body,
      content: fields.body,
      raw_content: fields.raw_content ?? '',
      raw_content_section: rawContentSection,
      tags: formatTagsForTemplate(fields.tags),
      source: fields.source,
      captured_at: fields.captured_at,
      project: fields.project,
      status: fields.status,
      confidence: String(fields.confidence),
      original_id: sourceItem.originalId ?? '',
      frontmatter,
      links: '',
    };
  }

  /**
   * Render a template by replacing {{variable}} placeholders.
   */
  private renderTemplate(template: string, context: TemplateContext): string {
    return template.replace(/\{\{(\w+)\}\}/g, (match, key: string) => {
      const value = context[key as keyof TemplateContext];
      return value !== undefined ? value : match;
    });
  }
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/**
 * Format tags array for template insertion.
 * If the template uses {{tags}} inside a YAML frontmatter block, output as YAML array.
 * Otherwise, output as newline-separated list.
 */
function formatTagsForTemplate(tags: string[]): string {
  if (!tags || tags.length === 0) return '[]';
  return tags.map((t) => `  - ${t}`).join('\n');
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const markdownBuilder = new MarkdownBuilder();
