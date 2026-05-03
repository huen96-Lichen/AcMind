// PinMind Strategy Processor
// Phase 8.1-8.6: 桥接策略系统与内容处理管线
//
// 职责：
// 1. 从 CaptureRecord 构建 StrategyInput
// 2. 根据 source_type 选择策略
// 3. 通过 PromptProfile 构建 Prompt（Phase 8.2）
// 4. 通过 ModelRouter 选择模型（Phase 8.3）
// 5. 调用 AI 并通过 OutputValidator 校验（Phase 8.4）
// 6. 低质量结果兜底（Phase 8.5）
// 7. 记录模型调用信息（Phase 8.6）

import type { CaptureRecord, SourceType, ProviderConfig } from '../../../shared/types';
import { logger } from '../../logger';
import { strategyRegistry } from './strategyRegistry';
import { promptProfileRegistry } from './promptProfile';
import { modelRouter, type ModelTier, type RoutingContext } from './modelRouter';
import { outputValidator } from './outputValidator';
import { qualityFallback } from './qualityFallback';
import type { ProcessedContent, StrategyInput, ModelCallRecord } from './types';

// ---------------------------------------------------------------------------
// 完整处理结果
// ---------------------------------------------------------------------------

export interface ProcessingResult {
  /** 处理后的内容 */
  content: ProcessedContent;
  /** 模型调用记录 */
  modelCall: ModelCallRecord;
  /** 路由决策原因 */
  routingReason: string;
  /** 质量评估分数 (0-100) */
  qualityScore: number;
  /** 是否使用了 fallback */
  usedFallback: boolean;
}

// ---------------------------------------------------------------------------
// StrategyProcessor
// ---------------------------------------------------------------------------

class StrategyProcessor {
  /**
   * 从 CaptureRecord 构建 StrategyInput。
   */
  buildStrategyInput(record: CaptureRecord): StrategyInput {
    const meta = record.metadata ?? {};

    return {
      source_type: record.source_type,
      content: record.raw_text || '',
      raw_file_path: record.raw_file_path || undefined,
      source_url: record.raw_url || undefined,
      extracted_text: (meta.extracted_text as string) || undefined,
      transcript_text: (meta.transcript_text as string) || undefined,
      parsed_markdown: (meta.parsed_markdown as string) || undefined,
      file_ext: (meta.extension as string) || undefined,
      metadata: meta,
    };
  }

  /**
   * 获取指定 source_type 的策略。
   */
  getStrategy(sourceType: SourceType) {
    return strategyRegistry.getStrategy(sourceType);
  }

  /**
   * 检查是否有策略支持指定的 source_type。
   */
  hasStrategy(sourceType: SourceType): boolean {
    return strategyRegistry.hasStrategy(sourceType);
  }

  /**
   * 构建 AI Prompt（使用 PromptProfile 体系）。
   * Phase 8.2: Prompt 不散落在业务代码中，统一由 profile 管理。
   */
  buildPrompt(input: StrategyInput): string {
    const strategy = this.getStrategy(input.source_type);

    if (!strategy.canHandle(input)) {
      logger.warn('app', 'strategyProcessor', 'cannot-handle',
        `Strategy ${strategy.name} cannot handle input`, {
          sourceType: input.source_type,
          hasContent: !!input.content,
        });
      return '';
    }

    // 使用 PromptProfile 构建 Prompt
    const vars = this.buildTemplateVars(input);
    const { userPrompt } = promptProfileRegistry.buildFullPrompt(input.source_type, vars);
    return userPrompt;
  }

  /**
   * 构建 PromptProfile 模板变量。
   */
  private buildTemplateVars(input: StrategyInput): Record<string, string> {
    return {
      content: input.content || '',
      source_url: input.source_url || '',
      extracted_text: input.extracted_text || '',
      transcript_text: input.transcript_text || '',
      parsed_markdown: input.parsed_markdown || '',
      raw_file_path: input.raw_file_path || '',
      file_ext: input.file_ext || '',
    };
  }

  /**
   * 后处理 AI 原始输出（Phase 8.4: 带结构化校验）。
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const strategy = this.getStrategy(input.source_type);

    // 先用策略的 postProcess 处理
    const processed = strategy.postProcess(raw, input);

    // 再用 OutputValidator 校验和修复
    const validation = outputValidator.validate(
      { ...raw, ...processed },
      input,
    );

    if (validation.wasFixed) {
      logger.warn('app', 'strategyProcessor', 'output-fixed',
        `AI output was fixed for ${input.source_type}`, {
          fixNotes: validation.fixNotes,
          flags: validation.flags,
        });
    }

    return validation.content;
  }

  /**
   * 对于不需要 AI 的策略（如 unknown_file），直接生成占位记录。
   * 返回 null 表示需要调用 AI 处理。
   */
  generateDirectOutput(input: StrategyInput): ProcessedContent | null {
    // 检查是否应该自动 fallback
    if (qualityFallback.shouldAutoFallback(input)) {
      logger.info('app', 'strategyProcessor', 'auto-fallback',
        `Auto-fallback for ${input.source_type}`, {
          sourceType: input.source_type,
        });
      return qualityFallback.generateFallback(input);
    }

    return null;
  }

  /**
   * 完整处理流程（Phase 8.3: 带模型路由）。
   * 返回路由决策信息，由调用方负责实际 AI 调用。
   */
  prepareProcessing(record: CaptureRecord, options?: {
    defaultTier?: ModelTier;
    privacyMode?: boolean;
    allowCloud?: boolean;
    availableProviders?: ProviderConfig[];
  }): {
    input: StrategyInput;
    prompt: string;
    directOutput: ProcessedContent | null;
    strategyName: string;
    routingDecision: {
      tier: ModelTier;
      provider: ProviderConfig | null;
      reason: string;
      upgradeSuggestion?: { suggestedTier: ModelTier; reason: string };
      needsPrivacyConfirmation?: boolean;
    };
    profileId: string;
  } {
    const input = this.buildStrategyInput(record);
    const strategy = this.getStrategy(input.source_type);
    const directOutput = this.generateDirectOutput(input);

    // 获取 Prompt Profile 信息
    const profile = promptProfileRegistry.getProfile(input.source_type);

    // 如果不需要 AI，跳过路由
    if (directOutput) {
      logger.info('app', 'strategyProcessor', 'prepared',
        `Strategy prepared: ${strategy.name} (direct output)`, {
          sourceType: input.source_type,
          profileId: profile.profile_id,
        });
      return {
        input,
        prompt: '',
        directOutput,
        strategyName: strategy.name,
        routingDecision: {
          tier: 'local_light',
          provider: null,
          reason: '占位内容，无需 AI 处理',
        },
        profileId: profile.profile_id,
      };
    }

    // 构建 Prompt
    const prompt = this.buildPrompt(input);

    // 模型路由
    const routingContext: RoutingContext = {
      sourceType: input.source_type,
      input,
      defaultTier: options?.defaultTier || 'cloud_standard',
      privacyMode: options?.privacyMode ?? false,
      allowCloud: options?.allowCloud ?? true,
      availableProviders: options?.availableProviders || [],
    };
    const routingDecision = modelRouter.route(routingContext);

    logger.info('app', 'strategyProcessor', 'prepared',
      `Strategy prepared: ${strategy.name}`, {
        sourceType: input.source_type,
        tier: routingDecision.tier,
        profileId: profile.profile_id,
        promptLength: prompt.length,
        routingReason: routingDecision.reason,
      });

    return {
      input,
      prompt,
      directOutput: null,
      strategyName: strategy.name,
      routingDecision,
      profileId: profile.profile_id,
    };
  }

  /**
   * 完整处理流程：从 AI 原始输出到最终 ProcessedContent。
   * Phase 8.4: 带校验 + Phase 8.5: 带质量兜底。
   */
  processAiOutput(
    raw: Record<string, unknown>,
    input: StrategyInput,
    modelCall: Omit<ModelCallRecord, 'created_at'>,
  ): ProcessingResult {
    // Step 1: 策略后处理 + 校验
    const processed = this.postProcess(raw, input);

    // Step 2: 质量评估
    const assessment = qualityFallback.assess(processed, input);

    const fullModelCall: ModelCallRecord = {
      ...modelCall,
      created_at: Date.now(),
    };

    // Step 3: 如果质量太差，使用 fallback
    if (assessment.level === 'critical') {
      logger.warn('app', 'strategyProcessor', 'quality-critical',
        `Quality critical for ${input.source_type}, using fallback`, {
          score: assessment.score,
          issues: assessment.issues.map(i => i.flag),
        });

      const fallbackContent = qualityFallback.generateFallback(input);
      return {
        content: fallbackContent,
        modelCall: { ...fullModelCall, status: 'fallback' },
        routingReason: '质量评估为 critical，使用 fallback',
        qualityScore: assessment.score,
        usedFallback: true,
      };
    }

    return {
      content: processed,
      modelCall: fullModelCall,
      routingReason: '',
      qualityScore: assessment.score,
      usedFallback: false,
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const strategyProcessor = new StrategyProcessor();
