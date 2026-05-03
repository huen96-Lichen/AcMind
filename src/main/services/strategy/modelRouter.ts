// PinMind Model Router
// Phase 8.3: 模型分层与路由策略
//
// 职责：
// 1. 根据 source_type、内容长度、用户设置等选择 model_tier
// 2. 根据 model_tier 选择具体的 ProviderConfig
// 3. 隐私模式优先本地或占位处理
// 4. 长文本可建议 cloud_advanced，但不静默升级
// 5. 模型不可用时有 fallback 记录

import type { SourceType, ProviderConfig, AiTier } from '../../../shared/types';
import { logger } from '../../logger';
import type { StrategyInput } from './types';

// ---------------------------------------------------------------------------
// ModelTier 定义
// ---------------------------------------------------------------------------

/** 模型分层 */
export type ModelTier = 'local_light' | 'cloud_standard' | 'cloud_advanced';

/** 路由决策结果 */
export interface RoutingDecision {
  /** 选择的模型层级 */
  tier: ModelTier;
  /** 选择的 provider（如果可用） */
  provider: ProviderConfig | null;
  /** 路由原因 */
  reason: string;
  /** 是否建议升级（不自动升级，仅建议） */
  upgradeSuggestion?: {
    suggestedTier: ModelTier;
    reason: string;
  };
  /** 是否需要隐私确认 */
  needsPrivacyConfirmation?: boolean;
}

/** 路由上下文 */
export interface RoutingContext {
  /** 内容来源类型 */
  sourceType: SourceType;
  /** 策略输入 */
  input: StrategyInput;
  /** 用户设置的默认模型层级 */
  defaultTier: ModelTier;
  /** 是否启用隐私模式 */
  privacyMode: boolean;
  /** 是否允许云端处理 */
  allowCloud: boolean;
  /** 可用的 providers 列表 */
  availableProviders: ProviderConfig[];
  /** 任务复杂度（0-1，由调用方评估） */
  taskComplexity?: number;
}

// ---------------------------------------------------------------------------
// 阈值常量
// ---------------------------------------------------------------------------

/** 长文本阈值（字符数）—— 超过此值建议 cloud_advanced */
const LONG_TEXT_THRESHOLD = 5000;

/** 超长文本阈值（字符数）—— 超过此值强烈建议 cloud_advanced */
const VERY_LONG_TEXT_THRESHOLD = 15000;

/** 简单任务复杂度阈值 */
const SIMPLE_COMPLEXITY_THRESHOLD = 0.3;

/** 复杂任务复杂度阈值 */
const COMPLEX_COMPLEXITY_THRESHOLD = 0.7;

// ---------------------------------------------------------------------------
// ModelRouter
// ---------------------------------------------------------------------------

class ModelRouter {
  /**
   * 根据路由上下文做出模型选择决策。
   */
  route(context: RoutingContext): RoutingDecision {
    const { sourceType, input, defaultTier, privacyMode, allowCloud, availableProviders } = context;

    // Step 1: 隐私模式检查
    if (privacyMode) {
      return this.routePrivacyMode(context);
    }

    // Step 2: 计算内容复杂度
    const complexity = this.estimateComplexity(input, context.taskComplexity);

    // Step 3: 根据 source_type 和复杂度确定理想 tier
    const idealTier = this.determineIdealTier(sourceType, input, complexity, defaultTier);

    // Step 4: 检查云端权限
    if (!allowCloud && (idealTier === 'cloud_standard' || idealTier === 'cloud_advanced')) {
      const localProvider = this.findProvider(availableProviders, 'local_light');
      logger.warn('app', 'modelRouter', 'cloud-blocked',
        `Cloud tier ${idealTier} requested but cloud is disabled, falling back to local`, {
          sourceType,
          idealTier,
        });
      return {
        tier: 'local_light',
        provider: localProvider,
        reason: '云端处理已禁用，回退到本地模型',
      };
    }

    // Step 5: 查找 provider
    const provider = this.findProvider(availableProviders, idealTier);

    if (!provider) {
      // Fallback: 尝试更低层级
      return this.fallbackToLowerTier(idealTier, availableProviders, sourceType);
    }

    // Step 6: 构建路由决策
    const decision: RoutingDecision = {
      tier: idealTier,
      provider,
      reason: this.buildReason(sourceType, idealTier, complexity),
    };

    // Step 7: 长文本升级建议（不自动升级）
    const textLength = this.getTextLength(input);
    if (textLength > LONG_TEXT_THRESHOLD && idealTier !== 'cloud_advanced') {
      decision.upgradeSuggestion = {
        suggestedTier: 'cloud_advanced',
        reason: `文本长度 ${textLength} 字符，建议使用高级模型以获得更好的整理效果`,
      };
    }

    return decision;
  }

  /**
   * 隐私模式路由：优先本地模型，不可用时生成占位。
   */
  private routePrivacyMode(context: RoutingContext): RoutingDecision {
    const localProvider = this.findProvider(context.availableProviders, 'local_light');

    if (localProvider) {
      return {
        tier: 'local_light',
        provider: localProvider,
        reason: '隐私模式：使用本地模型处理',
        needsPrivacyConfirmation: false,
      };
    }

    // 本地模型不可用，需要用户确认是否使用云端
    const cloudProvider = this.findProvider(context.availableProviders, 'cloud_standard');
    if (cloudProvider) {
      return {
        tier: 'cloud_standard',
        provider: cloudProvider,
        reason: '隐私模式：本地模型不可用，需要确认是否使用云端',
        needsPrivacyConfirmation: true,
      };
    }

    // 都不可用，生成占位
    return {
      tier: 'local_light',
      provider: null,
      reason: '隐私模式：无可用模型，将生成占位记录',
    };
  }

  /**
   * 估算内容复杂度。
   */
  private estimateComplexity(input: StrategyInput, explicitComplexity?: number): number {
    if (explicitComplexity !== undefined) return explicitComplexity;

    let complexity = 0.5; // 基线

    const textLength = this.getTextLength(input);

    // 文本长度因素
    if (textLength > VERY_LONG_TEXT_THRESHOLD) complexity += 0.3;
    else if (textLength > LONG_TEXT_THRESHOLD) complexity += 0.15;
    else if (textLength < 200) complexity -= 0.2;

    // 有多种内容源（如同时有 transcript + parsed_markdown）
    const contentSources = [
      input.content, input.extracted_text,
      input.transcript_text, input.parsed_markdown,
    ].filter(s => s && s.trim().length > 0).length;
    if (contentSources > 1) complexity += 0.1;

    return Math.max(0, Math.min(1, complexity));
  }

  /**
   * 根据 source_type 和复杂度确定理想 tier。
   */
  private determineIdealTier(
    sourceType: SourceType,
    input: StrategyInput,
    complexity: number,
    defaultTier: ModelTier,
  ): ModelTier {
    // 占位类型（无内容）→ local_light
    if (this.isPlaceholderType(input)) {
      return 'local_light';
    }

    // 复杂任务 → cloud_advanced
    if (complexity >= COMPLEX_COMPLEXITY_THRESHOLD) {
      return 'cloud_advanced';
    }

    // 简单任务 → local_light 或 cloud_standard
    if (complexity <= SIMPLE_COMPLEXITY_THRESHOLD) {
      return 'local_light';
    }

    // 中等复杂度 → 使用默认 tier
    return defaultTier;
  }

  /**
   * 判断是否为占位类型（无实际内容可处理）。
   */
  private isPlaceholderType(input: StrategyInput): boolean {
    const { source_type } = input;

    // screenshot/image 无 OCR
    if ((source_type === 'screenshot' || source_type === 'image') && !input.extracted_text) {
      return true;
    }

    // audio/video 无转写
    if ((source_type === 'audio' || source_type === 'video') && !input.transcript_text) {
      return true;
    }

    // pdf/docx 无解析内容
    if ((source_type === 'pdf' || source_type === 'docx') && !input.parsed_markdown) {
      return true;
    }

    // unknown_file
    if (source_type === 'unknown_file') {
      return true;
    }

    // file 无内容
    if (source_type === 'file' && !input.content) {
      return true;
    }

    return false;
  }

  /**
   * 获取文本总长度。
   */
  private getTextLength(input: StrategyInput): number {
    return [
      input.content, input.extracted_text,
      input.transcript_text, input.parsed_markdown,
    ]
      .filter(Boolean)
      .join('')
      .length;
  }

  /**
   * 查找匹配 tier 的 provider。
   */
  private findProvider(providers: ProviderConfig[], tier: ModelTier): ProviderConfig | null {
    // 精确匹配
    const exact = providers.find(p => p.tier === tier && p.enabled);
    if (exact) return exact;

    // cloud_advanced 可回退到 cloud_standard
    if (tier === 'cloud_advanced') {
      const standard = providers.find(p => p.tier === 'cloud_standard' && p.enabled);
      if (standard) return standard;
    }

    return null;
  }

  /**
   * 当理想 tier 不可用时，回退到更低层级。
   */
  private fallbackToLowerTier(
    idealTier: ModelTier,
    providers: ProviderConfig[],
    sourceType: SourceType,
  ): RoutingDecision {
    const fallbackOrder: ModelTier[] = ['cloud_standard', 'local_light'];

    for (const tier of fallbackOrder) {
      if (tier === idealTier) continue;
      const provider = this.findProvider(providers, tier);
      if (provider) {
        logger.warn('app', 'modelRouter', 'fallback',
          `No provider for ${idealTier}, falling back to ${tier}`, {
            sourceType,
            idealTier,
            fallbackTier: tier,
          });
        return {
          tier,
          provider,
          reason: `${idealTier} 不可用，回退到 ${tier}`,
        };
      }
    }

    // 无任何可用 provider
    logger.error('error', 'modelRouter', 'no-provider', 'No provider available', {
      sourceType,
      idealTier,
    });
    return {
      tier: idealTier,
      provider: null,
      reason: '无可用的 AI 模型，将生成占位记录',
    };
  }

  /**
   * 构建路由原因说明。
   */
  private buildReason(sourceType: SourceType, tier: ModelTier, complexity: number): string {
    const tierNames: Record<ModelTier, string> = {
      local_light: '本地轻量模型',
      cloud_standard: '标准云端模型',
      cloud_advanced: '高级云端模型',
    };
    return `${sourceType} 内容（复杂度 ${(complexity * 100).toFixed(0)}%）→ ${tierNames[tier]}`;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const modelRouter = new ModelRouter();
