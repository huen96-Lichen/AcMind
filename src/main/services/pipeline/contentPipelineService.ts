// PinMind ContentPipelineService
// Phase 1: Orchestrates the minimum viable loop:
//   Manual text input → Auto-organize → Generate Markdown → Write to Obsidian → Return output path
//
// Phase 2: Integrates with ContentStateMachine for state tracking and dedup.

import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { existsSync, mkdirSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import type { SourceItem, ExportRecord, CaptureRecord, SourceType, AiTier } from '../../../shared/types';
import { storage } from '../../storage';
import { logger } from '../../logger';
import { errorService } from '../../errorService';
import { resolveStorageRoot } from '../../settings';
import { DEFAULT_SETTINGS } from '../../../shared/defaultSettings';
import { markdownBuilder } from '../exporter/markdownBuilder';
import { pathResolver } from '../exporter/pathResolver';
import { conflictHandler } from '../exporter/conflictHandler';
import { safeWrite, validateVaultPath } from '../exporter/safeWrite';
import { buildFrontmatterDataFromRaw } from '../exporter/standardFields';
import { outputSpecService } from '../outputSpec';
import { frontmatterParser } from '../importer/frontmatterParser';
import { contentStateMachine } from './contentStateMachine';
import type { ContentState } from './contentStateMachine';
import {
  formatCapturedAt,
  sanitizeFilename,
  normalizePinMindFields,
  PINMIND_SCHEMA_VERSION,
} from '../../../shared/outputSpec';
import type { PinMindStandardFields, PinMindStatus } from '../../../shared/outputSpec';
import { normalizeTags } from '../../../shared/tagNormalizer';
import { captureRegistry } from '../capture';
import type { CaptureInput } from '../capture';
import { strategyProcessor } from '../strategy/strategyProcessor';
import type { ProcessedContent, StrategyInput, ModelCallRecord } from '../strategy/types';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Pipeline processing status for a content item */
export type PipelineStage =
  | 'captured'
  | 'processing'
  | 'structured'
  | 'exporting'
  | 'exported'
  // Failure states
  | 'capture_failed'
  | 'process_failed'
  | 'export_failed'
  | 'conflict_pending'
  | 'permission_required';

/** Result of processing a text input through the pipeline */
export interface PipelineResult {
  success: boolean;
  sourceItemId: string;
  stage: PipelineStage;
  outputPath?: string;         // Absolute path to the .md file in Obsidian vault
  relativePath?: string;       // Relative path within the vault
  exportRecord?: ExportRecord;
  error?: string;
}

/** Options for the pipeline */
export interface PipelineOptions {
  /** Skip the auto-export step (only generate structured data) */
  skipExport?: boolean;
  /** Override the vault config */
  vaultPath?: string;
  /** Override the default folder */
  defaultFolder?: string;
  /** Source type for the content */
  source?: SourceItem['source'];
  /** Project name */
  project?: string;
}

/** Structured content produced by the auto-organize step */
export interface StructuredContent {
  title: string;
  summary: string;
  tags: string[];
  category: string;
  body: string;
  confidence: number;
}

// ---------------------------------------------------------------------------
// SourceType → SourceItem.source mapping
// ---------------------------------------------------------------------------

/** Map SourceType to the legacy SourceItem.source field */
function mapSourceTypeToLegacy(sourceType: SourceType): SourceItem['source'] {
  switch (sourceType) {
    case 'manual_text': return 'manual';
    case 'clipboard_text': return 'clipboard';
    case 'screenshot': return 'screenshot';
    case 'webpage': return 'manual';
    case 'file': return 'vault_import';
    case 'image': return 'vault_import';
    case 'audio': return 'vault_import';
    case 'video': return 'vault_import';
    case 'pdf': return 'vault_import';
    case 'docx': return 'vault_import';
    case 'unknown_file': return 'vault_import';
    default: return 'manual';
  }
}

/** Map SourceType to SourceItem.type */
function mapSourceTypeToItemType(sourceType: SourceType): SourceItem['type'] {
  switch (sourceType) {
    case 'manual_text':
    case 'clipboard_text':
      return 'text';
    case 'screenshot':
    case 'image':
      return 'image';
    case 'webpage':
      return 'url';
    case 'file':
    case 'audio':
    case 'video':
    case 'pdf':
    case 'docx':
    case 'unknown_file':
      return 'text';
    default:
      return 'text';
  }
}

// ---------------------------------------------------------------------------
// ContentPipelineService
// ---------------------------------------------------------------------------

class ContentPipelineService {
  /**
   * Process a text input through the full pipeline:
   *   1. Create SourceItem (captured)
   *   2. Auto-organize: generate title, summary, tags, body structure (processing → structured)
   *   3. Generate Markdown from template (exporting)
   *   4. Write to Obsidian vault (exported)
   *
   * Returns the pipeline result with the output file path.
   */
  async processText(
    text: string,
    options?: PipelineOptions,
  ): Promise<PipelineResult> {
    const startTime = Date.now();

    // Phase 2: Check for duplicate content
    const duplicate = contentStateMachine.findDuplicate(text);
    if (duplicate) {
      const dupState = contentStateMachine.getCurrentState(duplicate.sourceItem.id);
      if (dupState === 'exported') {
        logger.info('app', 'pipeline', 'duplicate_skipped', `Duplicate content detected, already exported`, {
          originalId: duplicate.originalId,
          existingSourceItemId: duplicate.sourceItem.id,
        });
        return {
          success: true,
          sourceItemId: duplicate.sourceItem.id,
          stage: 'exported',
          error: undefined,
        };
      }
    }

    // Step 1: Create SourceItem (captured)
    let sourceItem: SourceItem;
    try {
      sourceItem = this.createSourceItem(text, options?.source ?? 'manual');

      // Phase 2: Set original_id for dedup
      const originalId = contentStateMachine.generateContentHash(text);
      storage.updateSourceItem(sourceItem.id, { originalId });
      sourceItem.originalId = originalId;

      // Phase 2: Record state transition
      contentStateMachine.transition(sourceItem.id, 'captured', {
        actor: 'pipeline',
        reason: 'Text captured via pipeline',
      });

      logger.info('app', 'pipeline', 'captured', `SourceItem created: ${sourceItem.id}`, {
        textLength: text.length,
        originalId,
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'pipeline', 'capture_failed', 'Failed to create SourceItem', {
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'pipeline_capture',
        outputId: contentStateMachine.generateContentHash(text),
        error,
        userMessage: '内容捕获失败，无法创建记录。',
      });
      return {
        success: false,
        sourceItemId: '',
        stage: 'capture_failed',
        error: errorMsg,
      };
    }

    // Step 2: Auto-organize (processing → structured)
    let structured: StructuredContent;
    try {
      // Phase 2: Transition to processing
      contentStateMachine.transition(sourceItem.id, 'processing', {
        actor: 'pipeline',
        reason: 'Starting auto-organize',
      });

      structured = this.autoOrganize(text);
      logger.info('app', 'pipeline', 'structured', `Content organized: ${sourceItem.id}`, {
        title: structured.title,
        category: structured.category,
        tags: structured.tags,
      });

      // Phase 2: Transition to structured
      storage.updateSourceItem(sourceItem.id, {
        status: 'distilled',
        title: structured.title,
        tags: structured.tags,
      });
      contentStateMachine.transition(sourceItem.id, 'structured', {
        actor: 'pipeline',
        reason: 'Auto-organize completed',
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'pipeline', 'process_failed', 'Failed to organize content', {
        error: errorMsg,
        sourceItemId: sourceItem.id,
      });
      contentStateMachine.transition(sourceItem.id, 'process_failed', {
        actor: 'pipeline',
        reason: 'Auto-organize failed',
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'process_failed',
        originalId: sourceItem.originalId,
        stage: 'pipeline_process',
        error,
        userMessage: '内容自动整理失败，请稍后重试或手动编辑。',
      });
      return {
        success: false,
        sourceItemId: sourceItem.id,
        stage: 'process_failed',
        error: errorMsg,
      };
    }

    // Step 3 & 4: Generate Markdown and write to Obsidian (exporting → exported)
    if (options?.skipExport) {
      return {
        success: true,
        sourceItemId: sourceItem.id,
        stage: 'structured',
      };
    }

    try {
      // Phase 2: Transition to exporting
      contentStateMachine.transition(sourceItem.id, 'exporting', {
        actor: 'pipeline',
        reason: 'Starting vault export',
      });

      const exportResult = await this.exportToVault(sourceItem, structured, options);
      const latencyMs = Date.now() - startTime;

      // Phase 2: Transition to exported
      contentStateMachine.transition(sourceItem.id, 'exported', {
        actor: 'pipeline',
        reason: 'Export completed',
      });

      logger.info('export', 'pipeline', 'exported', `Pipeline completed: ${sourceItem.id}`, {
        outputPath: exportResult.outputPath,
        latencyMs,
      });

      return {
        success: true,
        sourceItemId: sourceItem.id,
        stage: 'exported',
        outputPath: exportResult.outputPath,
        relativePath: exportResult.relativePath,
        exportRecord: exportResult.exportRecord,
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'pipeline', 'export_failed', 'Failed to export to vault', {
        error: errorMsg,
        sourceItemId: sourceItem.id,
      });
      contentStateMachine.transition(sourceItem.id, 'export_failed', {
        actor: 'pipeline',
        reason: 'Vault export failed',
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'export_failed',
        originalId: sourceItem.originalId,
        stage: 'pipeline_export',
        error,
        userMessage: '导出到 Obsidian 失败，请检查仓库路径和权限。',
      });
      return {
        success: false,
        sourceItemId: sourceItem.id,
        stage: 'export_failed',
        error: errorMsg,
      };
    }
  }

  /**
   * Process a CaptureRecord through the full pipeline.
   * This is the unified entry point for all capture sources.
   *
   * Flow: CaptureRecord → dedup check → SourceItem → auto-organize → Markdown → Obsidian
   *
   * @param record - A CaptureRecord produced by any CaptureAdapter
   * @param options - Pipeline options
   * @returns PipelineResult with the output file path
   */
  async processCaptureRecord(
    record: CaptureRecord,
    options?: PipelineOptions,
  ): Promise<PipelineResult> {
    const startTime = Date.now();

    // Dedup check using original_id
    const existingByOriginalId = storage.getSourceItemByOriginalId(record.original_id);
    if (existingByOriginalId) {
      const dupState = contentStateMachine.getCurrentState(existingByOriginalId.id);
      if (dupState === 'exported') {
        logger.info('app', 'pipeline', 'duplicate_skipped', 'Duplicate CaptureRecord detected, already exported', {
          originalId: record.original_id,
          existingSourceItemId: existingByOriginalId.id,
          sourceType: record.source_type,
        });
        return {
          success: true,
          sourceItemId: existingByOriginalId.id,
          stage: 'exported',
          error: undefined,
        };
      }
    }

    // Step 1: Create SourceItem from CaptureRecord (captured)
    let sourceItem: SourceItem;
    try {
      sourceItem = this.createSourceItemFromCaptureRecord(record);

      // Set original_id for dedup
      storage.updateSourceItem(sourceItem.id, { originalId: record.original_id });
      sourceItem.originalId = record.original_id;

      // Record state transition
      contentStateMachine.transition(sourceItem.id, 'captured', {
        actor: 'pipeline',
        reason: `Captured via ${record.source_type} adapter`,
      });

      logger.info('app', 'pipeline', 'captured', `SourceItem created from CaptureRecord: ${sourceItem.id}`, {
        sourceType: record.source_type,
        originalId: record.original_id,
      });

      // Phase 9.2: 异步提交 VaultKeeper Job（不阻塞主流程）
      void import('../vaultkeeper/processingJobService').then(({ processingJobService }) => {
        return processingJobService.submitJob(record, sourceItem.id);
      }).then((jobId) => {
        if (jobId) {
          logger.info('app', 'pipeline', 'vk-job-submitted', `VaultKeeper Job 已提交: ${jobId}`, {
            sourceItemId: sourceItem.id,
            originalId: record.original_id,
          });
        }
      }).catch((vkError) => {
        logger.warn('app', 'pipeline', 'vk-job-async-error', 'VaultKeeper 异步提交异常', {
          error: vkError instanceof Error ? vkError.message : String(vkError),
          originalId: record.original_id,
        });
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'pipeline', 'capture_failed', 'Failed to create SourceItem from CaptureRecord', {
        error: errorMsg,
        sourceType: record.source_type,
      });
      errorService.recordError({
        errorType: 'capture_failed',
        stage: 'pipeline_capture',
        outputId: record.original_id,
        error,
        userMessage: '内容捕获失败，无法创建记录。',
      });
      return {
        success: false,
        sourceItemId: '',
        stage: 'capture_failed',
        error: errorMsg,
      };
    }

    // Step 2: Auto-organize (processing → structured)
    // Only auto-organize if we have text content
    const contentText = this.extractContentText(sourceItem, record);
    if (!contentText) {
      // For non-text sources (screenshots, images), skip to structured with minimal info
      storage.updateSourceItem(sourceItem.id, {
        status: 'distilled',
        title: record.title || `未命名 ${record.source_type}`,
      });
      contentStateMachine.transition(sourceItem.id, 'structured', {
        actor: 'pipeline',
        reason: 'Non-text content, skipping auto-organize',
      });

      if (options?.skipExport) {
        return {
          success: true,
          sourceItemId: sourceItem.id,
          stage: 'structured',
        };
      }

      // Still attempt export with minimal structured content
      // V2.1 Phase 7.3: Generate richer description for screenshot/image sources
      const minimalStructured = this.buildNonTextStructured(record);

      try {
        contentStateMachine.transition(sourceItem.id, 'exporting', {
          actor: 'pipeline',
          reason: 'Starting vault export (non-text)',
        });
        const exportResult = await this.exportToVault(sourceItem, minimalStructured, {
          ...options,
          source: mapSourceTypeToLegacy(record.source_type),
        });
        contentStateMachine.transition(sourceItem.id, 'exported', {
          actor: 'pipeline',
          reason: 'Export completed (non-text)',
        });
        return {
          success: true,
          sourceItemId: sourceItem.id,
          stage: 'exported',
          outputPath: exportResult.outputPath,
          relativePath: exportResult.relativePath,
          exportRecord: exportResult.exportRecord,
        };
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        contentStateMachine.transition(sourceItem.id, 'export_failed', {
          actor: 'pipeline',
          reason: 'Vault export failed (non-text)',
          error: errorMsg,
        });
        return {
          success: false,
          sourceItemId: sourceItem.id,
          stage: 'export_failed',
          error: errorMsg,
        };
      }
    }

    // Standard text processing path
    let structured: StructuredContent;
    try {
      contentStateMachine.transition(sourceItem.id, 'processing', {
        actor: 'pipeline',
        reason: 'Starting auto-organize',
      });

      structured = this.autoOrganize(contentText);
      logger.info('app', 'pipeline', 'structured', `Content organized: ${sourceItem.id}`, {
        title: structured.title,
        category: structured.category,
        tags: structured.tags,
      });

      storage.updateSourceItem(sourceItem.id, {
        status: 'distilled',
        title: structured.title,
        tags: structured.tags,
      });
      contentStateMachine.transition(sourceItem.id, 'structured', {
        actor: 'pipeline',
        reason: 'Auto-organize completed',
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'pipeline', 'process_failed', 'Failed to organize content', {
        error: errorMsg,
        sourceItemId: sourceItem.id,
      });
      contentStateMachine.transition(sourceItem.id, 'process_failed', {
        actor: 'pipeline',
        reason: 'Auto-organize failed',
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'process_failed',
        originalId: sourceItem.originalId,
        stage: 'pipeline_process',
        error,
        userMessage: '内容自动整理失败，请稍后重试或手动编辑。',
      });
      return {
        success: false,
        sourceItemId: sourceItem.id,
        stage: 'process_failed',
        error: errorMsg,
      };
    }

    // Step 3 & 4: Generate Markdown and write to Obsidian (exporting → exported)
    if (options?.skipExport) {
      return {
        success: true,
        sourceItemId: sourceItem.id,
        stage: 'structured',
      };
    }

    try {
      contentStateMachine.transition(sourceItem.id, 'exporting', {
        actor: 'pipeline',
        reason: 'Starting vault export',
      });

      const exportResult = await this.exportToVault(sourceItem, structured, {
        ...options,
        source: mapSourceTypeToLegacy(record.source_type),
      });
      const latencyMs = Date.now() - startTime;

      contentStateMachine.transition(sourceItem.id, 'exported', {
        actor: 'pipeline',
        reason: 'Export completed',
      });

      logger.info('export', 'pipeline', 'exported', `Pipeline completed: ${sourceItem.id}`, {
        outputPath: exportResult.outputPath,
        latencyMs,
        sourceType: record.source_type,
      });

      return {
        success: true,
        sourceItemId: sourceItem.id,
        stage: 'exported',
        outputPath: exportResult.outputPath,
        relativePath: exportResult.relativePath,
        exportRecord: exportResult.exportRecord,
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'pipeline', 'export_failed', 'Failed to export to vault', {
        error: errorMsg,
        sourceItemId: sourceItem.id,
      });
      contentStateMachine.transition(sourceItem.id, 'export_failed', {
        actor: 'pipeline',
        reason: 'Vault export failed',
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'export_failed',
        originalId: sourceItem.originalId,
        stage: 'pipeline_export',
        error,
        userMessage: '导出到 Obsidian 失败，请检查仓库路径和权限。',
      });
      return {
        success: false,
        sourceItemId: sourceItem.id,
        stage: 'export_failed',
        error: errorMsg,
      };
    }
  }

  /**
   * Process a CaptureRecord using the strategy system.
   * Phase 8.1: Uses source_type-specific strategies for AI processing.
   *
   * This method:
   * 1. Builds StrategyInput from CaptureRecord
   * 2. Selects the appropriate strategy based on source_type
   * 3. For types that need AI: builds strategy-specific Prompt
   * 4. For types that don't need AI (e.g., unknown_file): generates direct output
   * 5. Post-processes AI output to ensure unified ProcessedContent structure
   *
   * @param record - A CaptureRecord produced by any CaptureAdapter
   * @param aiProcessFn - Optional AI processing function (injected for testability)
   * @returns ProcessedContent with unified structure
   */
  async processWithStrategy(
    record: CaptureRecord,
    aiProcessFn?: (prompt: string) => Promise<Record<string, unknown>>,
  ): Promise<ProcessedContent> {
    const { input, prompt, directOutput, strategyName, routingDecision, profileId } = strategyProcessor.prepareProcessing(record);

    logger.info('app', 'pipeline', 'strategy-prepared', `Strategy: ${strategyName}`, {
      sourceType: input.source_type,
      needsAi: !directOutput,
    });

    // If strategy generates direct output (no AI needed), return it
    if (directOutput) {
      logger.info('app', 'pipeline', 'strategy-direct-output', `Direct output from ${strategyName}`, {
        title: directOutput.title,
        qualityFlags: directOutput.quality_flags,
      });
      return directOutput;
    }

    // If no AI function provided, generate a fallback output
    if (!aiProcessFn) {
      logger.warn('app', 'pipeline', 'no-ai-function', 'No AI function provided, generating fallback', {
        sourceType: input.source_type,
      });
      return this.generateFallbackProcessedContent(input);
    }

    // Call AI with strategy-specific prompt
    try {
      const rawResult = await aiProcessFn(prompt);
      
      // Phase 8: Use processAiOutput for full validation + quality assessment
      const result = strategyProcessor.processAiOutput(rawResult, input, {
        model_tier: routingDecision.tier,
        provider: routingDecision.provider?.name ?? 'unknown',
        model_name: routingDecision.provider?.modelId ?? 'unknown',
        prompt_profile_id: profileId,
        prompt_profile_version: '1.0.0',
        status: 'success',
      });

      logger.info('app', 'pipeline', 'strategy-processed', `AI processed via ${strategyName}`, {
        title: result.content.title,
        tagsCount: result.content.tags.length,
        qualityFlags: result.content.quality_flags,
        qualityScore: result.qualityScore,
        usedFallback: result.usedFallback,
      });

      // Persist model call and quality info to SourceItem metadata
      this.persistModelCallMetadata(record.original_id, result);

      return result.content;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'pipeline', 'strategy-ai-failed', `AI processing failed for ${strategyName}`, {
        error: errorMsg,
        sourceType: input.source_type,
      });

      // Return fallback on AI failure
      return this.generateFallbackProcessedContent(input);
    }
  }

  /**
   * Generate fallback ProcessedContent when AI is unavailable or fails.
   * Ensures no content type causes a hard failure.
   */
  private generateFallbackProcessedContent(input: StrategyInput): ProcessedContent {
    const strategy = strategyProcessor.getStrategy(input.source_type);
    // Use the strategy's postProcess with empty raw to get fallback values
    return strategy.postProcess({}, input);
  }

  /**
   * Persist model call record and quality info to SourceItem metadata.
   * Phase 8.6: Enables processing history to display model tier, provider, profile info.
   */
  private persistModelCallMetadata(originalId: string, result: { modelCall: ModelCallRecord; qualityScore: number; content: ProcessedContent; usedFallback: boolean }): void {
    try {
      // Find the SourceItem by originalId
      const sourceItem = storage.getSourceItemByOriginalId?.(originalId);
      if (!sourceItem) {
        // Try finding via list
        const items = storage.getSourceItems({ limit: 1000 });
        const found = items.find((i: SourceItem) => i.originalId === originalId);
        if (!found) return;
        
        const existingMeta = found.metadata ?? {};
        storage.updateSourceItem(found.id, {
          metadata: {
            ...existingMeta,
            model_call: result.modelCall,
            quality_score: result.qualityScore,
            quality_flags: result.content.quality_flags,
            used_fallback: result.usedFallback,
          },
        });
        return;
      }

      const existingMeta = sourceItem.metadata ?? {};
      storage.updateSourceItem(sourceItem.id, {
        metadata: {
          ...existingMeta,
          model_call: result.modelCall,
          quality_score: result.qualityScore,
          quality_flags: result.content.quality_flags,
          used_fallback: result.usedFallback,
        },
      });
    } catch (err) {
      // Non-critical: log but don't fail the pipeline
      logger.warn('app', 'pipeline', 'persist-model-call-failed', 'Failed to persist model call metadata', {
        error: err instanceof Error ? err.message : String(err),
        originalId,
      });
    }
  }

  /**
   * Regenerate content for a source item using a specified model tier and prompt profile.
   * Phase 8.5: Supports regeneration with different model/prompt while preserving original_id.
   */
  async regenerateContent(
    sourceItemId: string,
    options: {
      regenerationTier?: AiTier;
      regenerationProfileId?: string;
      aiProcessFn?: (prompt: string) => Promise<Record<string, unknown>>;
    },
  ): Promise<{ success: boolean; content?: ProcessedContent; error?: string }> {
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) {
      return { success: false, error: 'SourceItem not found' };
    }

    // Build a CaptureRecord from the existing SourceItem
    const record: CaptureRecord = {
      original_id: sourceItem.originalId || sourceItem.id,
      source_type: (sourceItem.source as SourceType) || 'manual_text',
      created_at: new Date(sourceItem.createdAt * 1000).toISOString(),
      raw_text: sourceItem.previewText || sourceItem.ocrText || '',
      raw_file_path: sourceItem.contentPath || undefined,
      raw_url: sourceItem.originalUrl || undefined,
      title: sourceItem.title || undefined,
      preview_text: sourceItem.previewText || undefined,
      source_app: sourceItem.sourceApp || undefined,
      metadata: {},
    };

    // Use processWithStrategy with the regeneration options
    const content = await this.processWithStrategy(record, options.aiProcessFn);

    // Record regeneration in metadata
    try {
      const existingMeta = sourceItem.metadata ?? {};
      const regenerationHistory = (existingMeta.regeneration_history as Record<string, unknown>[]) ?? [];
      regenerationHistory.push({
        regeneration_id: `regen_${Date.now()}_${sourceItemId.slice(-8)}`,
        original_id: sourceItem.originalId,
        source_item_id: sourceItemId,
        regeneration_tier: options.regenerationTier || 'cloud_standard',
        regeneration_profile_id: options.regenerationProfileId || 'default',
        quality_score: content.quality_flags?.length === 0 ? 80 : 50,
        quality_flags: content.quality_flags,
        created_at: Date.now(),
        status: content.quality_flags?.includes('fallback_used') ? 'fallback' : 'success',
      });
      storage.updateSourceItem(sourceItemId, {
        metadata: {
          ...existingMeta,
          regeneration_history: regenerationHistory,
        },
      });
    } catch {
      // Non-critical
    }

    return { success: true, content };
  }

  /**
   * Get the pipeline status for a source item.
   */
  getStatus(sourceItemId: string): PipelineStage {
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) return 'capture_failed';

    // Check if there's a successful export record
    const exportRecords = storage.getExportRecords({ sourceItemId });
    const successfulExport = exportRecords.find((r: ExportRecord) => r.status === 'success');

    if (successfulExport) return 'exported';
    if (exportRecords.some((r: ExportRecord) => r.status === 'failed')) return 'export_failed';
    if (exportRecords.some((r: ExportRecord) => r.status === 'conflict')) return 'conflict_pending';

    switch (sourceItem.status) {
      case 'inbox': return 'captured';
      case 'distilling': return 'processing';
      case 'distilled': return 'structured';
      case 'exported': return 'exported';
      case 'archived': return 'exported';
      default: return 'captured';
    }
  }

  /**
   * Retry a failed export for a source item.
   */
  async retryExport(sourceItemId: string): Promise<PipelineResult> {
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) {
      return {
        success: false,
        sourceItemId,
        stage: 'capture_failed',
        error: 'SourceItem not found',
      };
    }

    // Phase 2: Check if retry is allowed
    if (!contentStateMachine.canRetry(sourceItemId)) {
      const currentState = contentStateMachine.getCurrentState(sourceItemId);
      return {
        success: false,
        sourceItemId,
        stage: currentState,
        error: `Cannot retry from state: ${currentState}`,
      };
    }

    // Re-organize the content from the source item — read full text from contentPath
    let content = '';
    if (sourceItem.contentPath && existsSync(sourceItem.contentPath)) {
      try {
        content = readFileSync(sourceItem.contentPath, 'utf8');
      } catch {
        // Fallback to previewText if file read fails
        content = sourceItem.previewText ?? sourceItem.ocrText ?? '';
      }
    } else {
      content = sourceItem.previewText ?? sourceItem.ocrText ?? '';
    }
    if (!content) {
      return {
        success: false,
        sourceItemId,
        stage: 'process_failed',
        error: 'No content available to re-export',
      };
    }

    const structured = this.autoOrganize(content);

    try {
      // Phase 2: Transition to exporting
      contentStateMachine.transition(sourceItemId, 'exporting', {
        actor: 'pipeline',
        reason: 'Retry export',
      });

      const exportResult = await this.exportToVault(sourceItem, structured);

      // Phase 2: Transition to exported
      contentStateMachine.transition(sourceItemId, 'exported', {
        actor: 'pipeline',
        reason: 'Retry export completed',
      });

      return {
        success: true,
        sourceItemId,
        stage: 'exported',
        outputPath: exportResult.outputPath,
        relativePath: exportResult.relativePath,
        exportRecord: exportResult.exportRecord,
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      contentStateMachine.transition(sourceItemId, 'export_failed', {
        actor: 'pipeline',
        reason: 'Retry export failed',
        error: errorMsg,
      });
      errorService.recordError({
        errorType: 'export_failed',
        originalId: sourceItem?.originalId,
        stage: 'pipeline_retry_export',
        error,
        userMessage: '重试导出失败，请检查仓库路径和权限后再次尝试。',
      });
      return {
        success: false,
        sourceItemId,
        stage: 'export_failed',
        error: errorMsg,
      };
    }
  }

  // -------------------------------------------------------------------------
  // Internal methods
  // -------------------------------------------------------------------------

  /**
   * Create a SourceItem from raw text input.
   */
  private createSourceItem(text: string, source: SourceItem['source']): SourceItem {
    const id = `src_${Date.now()}_${randomUUID().slice(0, 8)}`;
    const now = Math.floor(Date.now() / 1000);

    // Store the raw text content
    const storageRoot = this.getStorageRoot();
    const contentDir = path.join(storageRoot, 'content');
    if (!existsSync(contentDir)) {
      mkdirSync(contentDir, { recursive: true });
    }
    const contentPath = path.join(contentDir, `${id}.txt`);
    writeFileSync(contentPath, text, 'utf8');

    const sourceItem: SourceItem = {
      id,
      type: 'text',
      source,
      contentPath,
      previewText: text.length > 500 ? text.substring(0, 500) + '...' : text,
      createdAt: now,
      status: 'inbox',
    };

    storage.insertSourceItem(sourceItem);
    return sourceItem;
  }

  /**
   * Create a SourceItem from a CaptureRecord.
   * Handles text, file, and URL content types.
   */
  private createSourceItemFromCaptureRecord(record: CaptureRecord): SourceItem {
    const id = `src_${Date.now()}_${randomUUID().slice(0, 8)}`;
    const now = Math.floor(Date.now() / 1000);
    const storageRoot = this.getStorageRoot();
    const contentDir = path.join(storageRoot, 'content');
    if (!existsSync(contentDir)) {
      mkdirSync(contentDir, { recursive: true });
    }

    let contentPath = '';
    let previewText = record.preview_text;
    const itemType = mapSourceTypeToItemType(record.source_type);
    const legacySource = mapSourceTypeToLegacy(record.source_type);

    // Store content based on what's available in the CaptureRecord
    if (record.raw_text) {
      // Text content → store as .txt
      contentPath = path.join(contentDir, `${id}.txt`);
      writeFileSync(contentPath, record.raw_text, 'utf8');
      if (!previewText) {
        previewText = record.raw_text.length > 500
          ? record.raw_text.substring(0, 500) + '...'
          : record.raw_text;
      }
    } else if (record.raw_file_path) {
      // File content → copy to content directory
      const ext = path.extname(record.raw_file_path) || '.bin';
      contentPath = path.join(contentDir, `${id}${ext}`);
      if (existsSync(record.raw_file_path)) {
        copyFileSync(record.raw_file_path, contentPath);
      } else {
        throw new Error(`Capture file not found: ${record.raw_file_path}`);
      }
      if (!previewText) {
        previewText = record.title || `文件: ${path.basename(record.raw_file_path)}`;
      }
    } else if (record.raw_url) {
      // URL content → store URL as text
      contentPath = path.join(contentDir, `${id}.txt`);
      const urlContent = record.raw_text || record.raw_url;
      writeFileSync(contentPath, urlContent, 'utf8');
      if (!previewText) {
        previewText = record.raw_url;
      }
    }

    const sourceItem: SourceItem = {
      id,
      type: itemType,
      source: legacySource,
      contentPath,
      previewText,
      sourceApp: record.source_app,
      originalUrl: record.raw_url,
      createdAt: now,
      status: 'inbox',
      title: record.title,
    };

    storage.insertSourceItem(sourceItem);
    return sourceItem;
  }

  /**
   * Build StructuredContent for non-text sources (screenshot, image, etc.).
   * V2.1 Phase 7.3: Generates a basic Markdown description when no OCR is available.
   */
  private buildNonTextStructured(record: CaptureRecord): StructuredContent {
    const title = record.title || `未命名 ${record.source_type}`;
    const capturedAt = record.created_at
      ? new Date(record.created_at).toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' })
      : new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
    const meta = record.metadata ?? {};

    // Build a descriptive body for the Markdown based on source type
    const lines: string[] = [];

    if (record.source_type === 'webpage') {
      // V2.1 Phase 7.4: Webpage with failed fetch — generate basic description
      const url = record.raw_url || meta.url || '未知链接';
      const domain = meta.domain || '';
      lines.push(`这是一条由 PinMind 收集的网页链接。`);
      lines.push('');
      lines.push(`- **收集时间**：${capturedAt}`);
      lines.push(`- **原文链接**：[${url}](${url})`);
      if (domain) {
        lines.push(`- **域名**：${domain}`);
      }
      lines.push('');
      lines.push('> 网页内容自动抓取失败，仅保存了链接信息。可稍后重试或手动粘贴正文。');

      return {
        title,
        summary: `网页链接 · ${domain || url}`,
        tags: ['网页'],
        category: '网页',
        body: lines.join('\n'),
        confidence: 0.3,
      };
    }

    // V2.1 Phase 7.5: File type — generate basic file description
    if (record.source_type === 'file') {
      const filePath = record.raw_file_path || '未知路径';
      const fileName = meta.filename || '未知文件';
      const ext = meta.extension || '';
      const fileSize = meta.file_size as number | undefined;
      const readableText = meta.readable_text_available as boolean | undefined;

      lines.push(`这是一份由 PinMind 导入的文件。`);
      lines.push('');
      lines.push(`- **文件名**：${fileName}`);
      lines.push(`- **文件类型**：${ext || '未知'}`);
      lines.push(`- **导入时间**：${capturedAt}`);
      lines.push(`- **原始路径**：\`${filePath}\``);
      if (fileSize) {
        const sizeKB = Math.round(fileSize / 1024);
        lines.push(`- **文件大小**：${sizeKB} KB`);
      }
      if (readableText) {
        lines.push(`- **文本可读**：是`);
      }
      lines.push('');
      lines.push('> 文件解析能力后续接入 VaultKeeper 或解析模块，可自动提取全文内容。');

      return {
        title,
        summary: `文件导入 · ${fileName}`,
        tags: ['文件'],
        category: '文件',
        body: lines.join('\n'),
        confidence: 0.3,
      };
    }

    // V2.1 Phase 7.6: Image file (non-screenshot, e.g. imported via file picker)
    if (record.source_type === 'image') {
      const filePath = record.raw_file_path || '未知路径';
      const fileName = meta.filename || '未知图片';
      const ext = meta.extension || '';
      const fileSize = meta.file_size as number | undefined;
      const processingHint = meta.processing_hint as string | undefined;

      lines.push(`这是一张由 PinMind 导入的图片。`);
      lines.push('');
      lines.push(`- **文件名**：${fileName}`);
      lines.push(`- **文件类型**：${ext || '未知'}`);
      lines.push(`- **导入时间**：${capturedAt}`);
      lines.push(`- **原始路径**：\`${filePath}\``);
      if (fileSize) {
        const sizeKB = Math.round(fileSize / 1024);
        lines.push(`- **文件大小**：${sizeKB} KB`);
      }
      if (processingHint === 'needs_ocr') {
        lines.push(`- **待处理**：OCR 文字识别`);
      }
      lines.push('');
      lines.push('> 后续可通过 VaultKeeper OCR 引擎自动提取图片中的文字内容。');

      return {
        title,
        summary: `图片导入 · ${fileName}`,
        tags: ['图片', '待OCR'],
        category: '图片',
        body: lines.join('\n'),
        confidence: 0.3,
      };
    }

    // V2.1 Phase 7.6/10: Audio file
    if (record.source_type === 'audio') {
      const filePath = record.raw_file_path || '未知路径';
      const fileName = meta.filename || '未知音频';
      const ext = meta.extension || '';
      const fileSize = meta.file_size as number | undefined;
      const transcriptStatus = meta.transcript_status as string | undefined;
      const importedFrom = meta.imported_from as string | undefined;
      const isLongAudio = meta.is_long_audio as boolean | undefined;

      // Phase 10: 如果有 transcript_text，使用语音专用 Prompt 整理
      if (record.raw_text?.trim() && transcriptStatus === 'completed') {
        // 有转写文本时，交给策略处理器使用 voice_note_zh_v1 整理
        // 这里返回一个标记，让上层知道应该走策略处理路径
        return {
          title: record.title || `语音笔记 - ${capturedAt.split(' ')[0]}`,
          summary: '语音转写完成，等待 AI 整理',
          tags: ['语音', '已转写'],
          category: '语音',
          body: record.raw_text,
          confidence: 0.8,
        };
      }

      // 无转写文本时，生成占位记录
      lines.push(`这是一份由 PinMind 导入的音频文件。`);
      lines.push('');
      lines.push(`- **文件名**：${fileName}`);
      lines.push(`- **文件类型**：${ext || '未知'}`);
      lines.push(`- **导入时间**：${capturedAt}`);
      lines.push(`- **原始路径**：\`${filePath}\``);
      if (fileSize) {
        const sizeMB = (fileSize / (1024 * 1024)).toFixed(1);
        lines.push(`- **文件大小**：${sizeMB} MB`);
      }
      if (importedFrom === 'watch_folder') {
        lines.push(`- **导入方式**：文件夹监听`);
      } else {
        lines.push(`- **导入方式**：手动导入`);
      }
      if (isLongAudio) {
        lines.push(`- **⚠️ 长录音**：暂不支持完整自动转写`);
      }
      lines.push(`- **转写状态**：${transcriptStatus === 'unsupported' ? '需要配置转写引擎' : '等待转写'}`);
      lines.push('');
      if (transcriptStatus === 'unsupported') {
        lines.push('> ⚠️ 需要配置转写引擎。请在设置中配置 Whisper 或其他转写服务。');
      } else if (isLongAudio) {
        lines.push('> ⚠️ 长录音暂不支持完整自动转写。请稍后使用分段转写能力，或手动处理。');
      } else {
        lines.push('> 🎤 等待转写完成后将自动整理为知识笔记。');
      }

      return {
        title,
        summary: `音频导入 · ${fileName}`,
        tags: ['音频', '待转写'],
        category: '音频',
        body: lines.join('\n'),
        confidence: 0.3,
      };
    }

    // V2.1 Phase 7.6: Video file
    if (record.source_type === 'video') {
      const filePath = record.raw_file_path || '未知路径';
      const fileName = meta.filename || '未知视频';
      const ext = meta.extension || '';
      const fileSize = meta.file_size as number | undefined;

      lines.push(`这是一份由 PinMind 导入的视频文件。`);
      lines.push('');
      lines.push(`- **文件名**：${fileName}`);
      lines.push(`- **文件类型**：${ext || '未知'}`);
      lines.push(`- **导入时间**：${capturedAt}`);
      lines.push(`- **原始路径**：\`${filePath}\``);
      if (fileSize) {
        const sizeMB = (fileSize / (1024 * 1024)).toFixed(1);
        lines.push(`- **文件大小**：${sizeMB} MB`);
      }
      lines.push(`- **待处理**：视频转写`);
      lines.push('');
      lines.push('> 后续可通过 VaultKeeper 视频转写引擎自动提取视频中的语音内容。');

      return {
        title,
        summary: `视频导入 · ${fileName}`,
        tags: ['视频', '待转写'],
        category: '视频',
        body: lines.join('\n'),
        confidence: 0.3,
      };
    }

    // V2.1 Phase 7.6: PDF file
    if (record.source_type === 'pdf') {
      const filePath = record.raw_file_path || '未知路径';
      const fileName = meta.filename || '未知PDF';
      const fileSize = meta.file_size as number | undefined;

      lines.push(`这是一份由 PinMind 导入的 PDF 文档。`);
      lines.push('');
      lines.push(`- **文件名**：${fileName}`);
      lines.push(`- **导入时间**：${capturedAt}`);
      lines.push(`- **原始路径**：\`${filePath}\``);
      if (fileSize) {
        const sizeKB = Math.round(fileSize / 1024);
        lines.push(`- **文件大小**：${sizeKB} KB`);
      }
      lines.push(`- **待处理**：PDF 全文解析`);
      lines.push('');
      lines.push('> 后续可通过 VaultKeeper 文档解析引擎自动提取 PDF 中的文本和结构化内容。');

      return {
        title,
        summary: `PDF 导入 · ${fileName}`,
        tags: ['PDF', '待解析'],
        category: 'PDF',
        body: lines.join('\n'),
        confidence: 0.3,
      };
    }

    // V2.1 Phase 7.6: DOCX file
    if (record.source_type === 'docx') {
      const filePath = record.raw_file_path || '未知路径';
      const fileName = meta.filename || '未知文档';
      const fileSize = meta.file_size as number | undefined;

      lines.push(`这是一份由 PinMind 导入的 Word 文档。`);
      lines.push('');
      lines.push(`- **文件名**：${fileName}`);
      lines.push(`- **导入时间**：${capturedAt}`);
      lines.push(`- **原始路径**：\`${filePath}\``);
      if (fileSize) {
        const sizeKB = Math.round(fileSize / 1024);
        lines.push(`- **文件大小**：${sizeKB} KB`);
      }
      lines.push(`- **待处理**：DOCX 转 Markdown`);
      lines.push('');
      lines.push('> 后续可通过 VaultKeeper 文档解析引擎自动将 Word 文档转换为 Markdown 格式。');

      return {
        title,
        summary: `文档导入 · ${fileName}`,
        tags: ['文档', '待解析'],
        category: '文档',
        body: lines.join('\n'),
        confidence: 0.3,
      };
    }

    // V2.1 Phase 7.6: Unknown file type
    if (record.source_type === 'unknown_file') {
      const filePath = record.raw_file_path || '未知路径';
      const fileName = meta.filename || '未知文件';
      const ext = meta.extension || '';
      const fileSize = meta.file_size as number | undefined;

      lines.push(`这是一份由 PinMind 导入的未知类型文件。`);
      lines.push('');
      lines.push(`- **文件名**：${fileName}`);
      lines.push(`- **文件类型**：${ext || '未知'}`);
      lines.push(`- **导入时间**：${capturedAt}`);
      lines.push(`- **原始路径**：\`${filePath}\``);
      if (fileSize) {
        const sizeKB = Math.round(fileSize / 1024);
        lines.push(`- **文件大小**：${sizeKB} KB`);
      }
      lines.push(`- **待处理**：人工审查`);
      lines.push('');
      lines.push('> 此文件类型暂不支持自动解析，需人工审查或等待后续处理器支持。');

      return {
        title,
        summary: `未知文件 · ${fileName}`,
        tags: ['未知文件', '待审查'],
        category: '未分类',
        body: lines.join('\n'),
        confidence: 0.2,
      };
    }

    // Default: screenshot type
    const filePath = record.raw_file_path || '未知路径';
    const width = meta.image_width as number | undefined;
    const height = meta.image_height as number | undefined;
    const fileSize = meta.fileSize as number | undefined;

    lines.push(`这是一张由 PinMind 收集的截图。`);
    lines.push('');
    lines.push(`- **收集时间**：${capturedAt}`);
    lines.push(`- **原始文件路径**：\`${filePath}\``);
    if (width && height) {
      lines.push(`- **图片尺寸**：${width} × ${height}`);
    }
    if (fileSize) {
      const sizeKB = Math.round(fileSize / 1024);
      lines.push(`- **文件大小**：${sizeKB} KB`);
    }
    lines.push('');
    lines.push('> 后续可通过 OCR 或图片理解扩展自动提取文字内容。');

    const body = lines.join('\n');

    return {
      title,
      summary: `屏幕截图 · ${capturedAt}`,
      tags: ['截图'],
      category: '截图',
      body,
      confidence: 0.3,
    };
  }

  /**
   * Extract text content from a SourceItem and CaptureRecord for auto-organize.
   */
  private extractContentText(sourceItem: SourceItem, record: CaptureRecord): string {
    // Prefer raw_text from CaptureRecord
    if (record.raw_text?.trim()) {
      return record.raw_text.trim();
    }

    // Try reading from contentPath
    if (sourceItem.contentPath && existsSync(sourceItem.contentPath)) {
      try {
        const content = readFileSync(sourceItem.contentPath, 'utf8');
        if (content.trim()) {
          return content.trim();
        }
      } catch {
        // Fall through
      }
    }

    // Fall back to preview text
    return sourceItem.previewText?.trim() || '';
  }

  /**
   * Auto-organize raw text into structured content.
   * Uses rule-based extraction (no AI dependency for the minimum viable loop).
   * Future versions will integrate with the AI distillation pipeline.
   */
  private autoOrganize(text: string): StructuredContent {
    const normalized = this.normalizeMarkdownInput(text);

    // Extract title: use first non-empty line, truncated
    const rawTitle = normalized.titleHint
      ?? this.extractFirstMeaningfulLine(normalized.content)
      ?? '未命名内容';
    const title = sanitizeFilename(rawTitle.length > 80 ? rawTitle.substring(0, 80) : rawTitle) || '未命名内容';

    // Extract summary: use first few sentences, truncated
    const summary = this.extractSummary(normalized.content);

    // Extract body: the full text as the body
    const body = normalized.content.trim();

    // Simple rule-based categorization
    const category = this.categorizeText(normalized.content);

    // Simple rule-based tagging
    const tags = this.extractTags(normalized.content);

    return {
      title,
      summary,
      tags,
      category,
      body,
      confidence: 0.6, // Rule-based, moderate confidence
    };
  }

  /**
   * Extract a summary from text (first 1-2 sentences, truncated).
   */
  private extractSummary(text: string): string {
    // Try to extract first 1-2 sentences
    const sentences = text
      .replace(/\n+/g, '. ')
      .split(/[.!?。！？]+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 5);

    if (sentences.length === 0) {
      return text.length > 100 ? text.substring(0, 100) + '...' : text;
    }

    const summary = sentences.slice(0, 2).join('. ').trim();
    return summary.length > 200 ? summary.substring(0, 200) + '...' : summary;
  }

  /**
   * Normalize markdown input before organizing.
   * If the text contains YAML frontmatter, strip it from the body and use the
   * frontmatter title as the preferred title hint.
   */
  private normalizeMarkdownInput(text: string): { content: string; titleHint?: string } {
    const parsed = frontmatterParser.parseFile(text);
    const frontmatterTitle = parsed.hasFrontmatter && typeof parsed.frontmatter.title === 'string'
      ? parsed.frontmatter.title.trim()
      : '';
    const headingTitle = this.extractFirstHeading(parsed.content);
    const fallbackTitle = this.extractFirstMeaningfulLine(parsed.content);
    const titleHint = frontmatterTitle || headingTitle || fallbackTitle;

    const content = parsed.hasFrontmatter
      ? this.stripLeadingHeading(parsed.content.trim(), titleHint)
      : this.stripLeadingHeading(text.trim(), titleHint);

    return {
      content,
      titleHint,
    };
  }

  /**
   * Remove the first markdown heading when it duplicates the frontmatter title.
   */
  private stripLeadingHeading(content: string, titleHint?: string): string {
    if (!titleHint) return content;

    const normalizedHint = this.normalizeComparableTitle(titleHint);
    const headingMatch = content.match(/^(#{1,6})\s*(.+?)(\r?\n|$)/);
    if (!headingMatch) return content;

    const headingText = this.normalizeComparableTitle(headingMatch[2]);
    if (headingText !== normalizedHint) return content;

    return content.slice(headingMatch[0].length).replace(/^\s+/, '');
  }

  private normalizeComparableTitle(value: string): string {
    return value.replace(/\s+/g, ' ').trim();
  }

  /**
   * Get the first non-empty, non-YAML-separator line as a title hint.
   */
  private extractFirstMeaningfulLine(text: string): string | undefined {
    const line = text
      .split(/\r?\n/)
      .map((value) => value.trim())
      .find((value) => value && value !== '---');
    if (!line) return undefined;
    return this.normalizeCandidateTitle(line);
  }

  /**
   * Extract the first markdown H1/H2/... heading from text.
   */
  private extractFirstHeading(text: string): string | undefined {
    const lines = text.split(/\r?\n/);
    for (const rawLine of lines) {
      const line = rawLine.trim();
      const match = line.match(/^#{1,6}\s+(.+?)\s*#*$/);
      if (!match) continue;
      const candidate = this.normalizeCandidateTitle(match[1]);
      if (candidate) return candidate;
    }
    return undefined;
  }

  /**
   * Normalize a title candidate by removing common markdown/list prefixes.
   */
  private normalizeCandidateTitle(value: string): string {
    return value
      .replace(/^>\s*/, '')
      .replace(/^#{1,6}\s*/, '')
      .replace(/^[-*+•·]\s+/, '')
      .replace(/^\d+[.)]\s+/, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Simple rule-based text categorization.
   */
  private categorizeText(text: string): string {
    const lower = text.toLowerCase();
    const categoryRules = outputSpecService.getCategoryRules();
    const recommended = categoryRules.recommendedCategories;

    // Simple keyword matching
    if (/bug|error|fix|patch|hotfix|issue/i.test(text)) return '工作资料';
    if (/api|endpoint|database|schema|migration|deploy/i.test(text)) return '技术文档';
    if (/学习|笔记|教程|课程|读书|阅读/i.test(text)) return '学习笔记';
    if (/想法|灵感|创意|brainstorm|idea/i.test(text)) return '灵感想法';
    if (/复盘|总结|周报|月报|review|retro/i.test(text)) return '个人复盘';
    if (/项目|project|milestone|sprint|迭代/i.test(text)) return '项目记录';
    if (/产品|需求|功能|feature|requirement|spec/i.test(text)) return '产品规范';

    return recommended.includes('未分类') ? '未分类' : '未分类';
  }

  /**
   * Simple rule-based tag extraction.
   * Results are passed through TagNormalizer for consistent formatting.
   */
  private extractTags(text: string): string[] {
    const raw: string[] = [];

    // Extract hashtags
    const hashtagMatches = text.match(/#([^\s#]+)/g);
    if (hashtagMatches) {
      for (const tag of hashtagMatches) {
        const clean = tag.slice(1).trim();
        if (clean) raw.push(clean);
      }
    }

    // Normalize through centralized TagNormalizer
    return normalizeTags(raw);
  }

  /**
   * Export structured content to the Obsidian vault.
   *
   * Safety guarantees:
   *   - Vault path validation (exists + is directory + writable)
   *   - original_id dedup check
   *   - Atomic writes (temp file + rename)
   *   - Full ExportRecord with traceability fields
   *   - User-friendly error messages
   *   - Failed ExportRecord on error (preserves original content)
   */
  private async exportToVault(
    sourceItem: SourceItem,
    structured: StructuredContent,
    options?: PipelineOptions,
  ): Promise<{ outputPath: string; relativePath: string; exportRecord: ExportRecord }> {
    // Get vault config
    const vaultConfig = storage.getVaultConfig();
    const vaultPath = options?.vaultPath || vaultConfig.vaultPath;
    const defaultFolder = options?.defaultFolder || vaultConfig.defaultFolder || '';
    const outputId = `out_${Date.now()}_${randomUUID().slice(0, 8)}`;

    // Phase 1: Validate vault path (enhanced: exists + is directory + writable)
    const vaultValidation = validateVaultPath(vaultPath);
    if (!vaultValidation.valid) {
      // Create a failed export record with user-friendly message
      const failedRecord = this.createPipelineExportRecord({
        sourceItem,
        vaultPath,
        relativePath: '',
        status: 'failed',
        outputId,
        frontmatter: { original_id: sourceItem.originalId, output_id: outputId },
        error: vaultValidation.userMessage,
      });
      throw new Error(vaultValidation.userMessage);
    }

    // Phase 2: Dedup check — skip if same original_id already exported
    if (sourceItem.originalId) {
      const existingRecords = storage.getExportRecords({ sourceItemId: sourceItem.id });
      const alreadyExported = existingRecords.some((r) => r.status === 'success');
      if (alreadyExported) {
        logger.info('export', 'exportToVault', 'skip-dedup', 'Skipping: already exported', {
          sourceItemId: sourceItem.id,
          originalId: sourceItem.originalId,
        });
        const conflictRecord = this.createPipelineExportRecord({
          sourceItem,
          vaultPath,
          relativePath: '',
          status: 'conflict',
          outputId,
          frontmatter: { original_id: sourceItem.originalId, output_id: outputId },
          conflictResolution: 'skip',
          error: '内容已导出过，如需重新导出请使用强制模式。',
        });
        throw new Error('内容已导出过，如需重新导出请使用强制模式。');
      }
    }

    try {
      // Build PinMind standard fields
      const now = formatCapturedAt(sourceItem.createdAt);
      const fields: PinMindStandardFields = normalizePinMindFields(
        {
          title: structured.title,
          summary: structured.summary,
          tags: structured.tags,
          category: structured.category,
          body: structured.body,
          source: 'manual',
          captured_at: now,
          project: options?.project ?? '默认',
          status: 'exported',
          confidence: structured.confidence,
        },
        now,
      );

      // Generate Markdown using the template from OutputSpecService
      const updatedNow = new Date().toISOString().replace('T', ' ').replace(/\.\d+Z$/, '');

      // V2.1 Phase 7.4: Extract source_url and domain for webpage sources
      const sourceUrl = sourceItem.originalUrl || undefined;
      let domain: string | undefined;
      if (sourceUrl) {
        try { domain = new URL(sourceUrl).hostname; } catch { /* ignore */ }
      }

      const markdown = markdownBuilder.buildFromFields({
        ...fields,
        original_id: sourceItem.originalId,
        output_id: outputId,
        source_type: sourceItem.source,
        source_app: sourceItem.sourceApp ?? undefined,
        writer_app: 'PinMind',
        created: fields.captured_at,
        updated: updatedNow,
        source_url: sourceUrl,
        domain,
        // Phase 10: Audio-specific frontmatter fields
        ...(sourceItem.source === 'audio' ? {
          transcript_status: (sourceItem.metadata?.transcript_status as string) || undefined,
          audio_file: (sourceItem.metadata?.raw_file_path as string) || undefined,
          quality_flags: structured.tags?.filter(t => t.startsWith('quality:')) || [],
        } : {}),
      });

      // Resolve file path (centralized through PathResolver)
      const fullPath = pathResolver.resolveForPipeline(
        vaultPath,
        defaultFolder,
        structured.title,
        sourceItem.createdAt,
      );

      // Handle conflicts
      const resolution = conflictHandler.resolve(fullPath, vaultConfig.conflictStrategy || 'rename');

      if (resolution.action === 'skip') {
      const conflictRecord = this.createPipelineExportRecord({
        sourceItem,
        vaultPath,
        relativePath: path.relative(vaultPath, resolution.filePath),
        status: 'conflict',
        outputId,
        frontmatter: { original_id: sourceItem.originalId },
        conflictResolution: 'skip',
      });
        throw new Error(`文件已存在且冲突策略为跳过: ${fullPath}`);
      }

      // Phase 3: Atomic write (temp file + rename)
      safeWrite(resolution.filePath, markdown);

      // Phase 4: Create export record with full traceability
      const exportRecord = this.createPipelineExportRecord({
        sourceItem,
        vaultPath,
        relativePath: path.relative(vaultPath, resolution.filePath),
        status: 'success',
        outputId,
        frontmatter: buildFrontmatterDataFromRaw(
          {
            title: fields.title,
            summary: fields.summary,
            tags: fields.tags,
            category: fields.category,
            source: fields.source,
            captured_at: fields.captured_at,
            project: fields.project,
            status: fields.status,
            confidence: fields.confidence,
            schema_version: fields.schema_version,
            original_id: sourceItem.originalId,
            output_id: outputId,
            source_type: sourceItem.source,
            source_app: sourceItem.sourceApp ?? undefined,
            writer_app: 'PinMind',
            created: fields.captured_at,
            updated: updatedNow,
          },
          outputSpecService.getActiveProfile(),
        ),
        conflictResolution: resolution.action === 'overwrite' ? 'overwrite' : resolution.action === 'rename' ? 'rename' : undefined,
      });

      // Update source item status
      storage.updateSourceItem(sourceItem.id, { status: 'exported' });

      return {
        outputPath: resolution.filePath,
        relativePath: path.relative(vaultPath, resolution.filePath),
        exportRecord,
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('export', 'exportToVault', 'write-failed', 'Failed to export', {
        sourceItemId: sourceItem.id,
        error: errorMsg,
      });

      // Create a failed export record to preserve traceability
      const failedRecord = this.createPipelineExportRecord({
        sourceItem,
        vaultPath,
        relativePath: '',
        status: 'failed',
        outputId,
        frontmatter: { original_id: sourceItem.originalId, output_id: outputId },
        error: errorMsg,
      });

      throw error;
    }
  }

  /**
   * Create an ExportRecord for the pipeline path.
   * Includes full traceability: original_id, output_id, source_type, source_app, writer_app, created, updated.
   */
  private createPipelineExportRecord(params: {
    sourceItem: SourceItem;
    vaultPath: string;
    relativePath: string;
    status: ExportRecord['status'];
    outputId: string;
    frontmatter: Record<string, unknown>;
    conflictResolution?: ExportRecord['conflictResolution'];
    error?: string;
  }): ExportRecord {
    const record: ExportRecord = {
      id: `exp_${Date.now()}_${randomUUID().slice(0, 8)}`,
      sourceItemId: params.sourceItem.id,
      distilledOutputId: params.outputId,
      vaultPath: params.vaultPath,
      relativeFilePath: params.relativePath,
      frontmatter: {
        ...params.frontmatter,
        output_id: params.outputId,
      },
      exportedAt: Math.floor(Date.now() / 1000),
      status: params.status,
      conflictResolution: params.conflictResolution,
      error: params.error,
    };

    storage.insertExportRecord(record);
    return record;
  }

  /**
   * Get the storage root path.
   */
  private getStorageRoot(): string {
    return resolveStorageRoot(DEFAULT_SETTINGS.storageRoot);
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const contentPipeline = new ContentPipelineService();
