// AcMind Content Processing Strategy Types
// Phase 8.1-8.6: 定义策略接口、统一输出结构、模型追踪

import type { SourceType, ProcessedContent } from '../../../shared/types';

// Re-export ProcessedContent from shared for backward compatibility
export type { ProcessedContent };

// ---------------------------------------------------------------------------
// 策略输入
// ---------------------------------------------------------------------------

export interface StrategyInput {
  /** 内容来源类型 */
  source_type: SourceType;
  /** 主要文本内容 */
  content: string;
  /** 原始文件路径（如有） */
  raw_file_path?: string;
  /** 来源 URL（如有） */
  source_url?: string;
  /** OCR 提取的文本（如有） */
  extracted_text?: string;
  /** 转写文本（如有） */
  transcript_text?: string;
  /** 解析后的 Markdown（如有） */
  parsed_markdown?: string;
  /** 文件扩展名（如有） */
  file_ext?: string;
  /** 附加元数据 */
  metadata?: Record<string, unknown>;
}

// ---------------------------------------------------------------------------
// 模型调用记录 (Phase 8.6)
// ---------------------------------------------------------------------------

export interface ModelCallRecord {
  /** 模型层级 */
  model_tier: 'local_light' | 'cloud_standard' | 'cloud_advanced';
  /** 模型提供商 */
  provider: string;
  /** 模型名称 */
  model_name: string;
  /** 使用的 Prompt Profile ID */
  prompt_profile_id: string;
  /** 使用的 Prompt Profile 版本 */
  prompt_profile_version: string;
  /** 调用时间 */
  created_at: number;
  /** 调用状态 */
  status: 'success' | 'failed' | 'fallback' | 'skipped';
  /** 错误信息（如果失败） */
  error?: string;
}

// ---------------------------------------------------------------------------
// 处理上下文 (Phase 8.3-8.6)
// ---------------------------------------------------------------------------

export interface ProcessingContext {
  /** 原始内容 ID */
  original_id: string;
  /** 模型调用记录 */
  modelCall?: ModelCallRecord;
  /** 是否为重新生成 */
  isRegeneration?: boolean;
  /** 重新生成时选择的模型层级 */
  regenerationTier?: 'local_light' | 'cloud_standard' | 'cloud_advanced';
  /** 重新生成时选择的 Prompt Profile ID */
  regenerationProfileId?: string;
}

// ---------------------------------------------------------------------------
// 策略接口
// ---------------------------------------------------------------------------

export interface ContentProcessingStrategy {
  /** 策略名称 */
  readonly name: string;
  /** 支持的 source_type */
  readonly sourceType: SourceType;

  /**
   * 判断当前输入是否可以被此策略处理。
   * 用于在策略注册表中做运行时校验。
   */
  canHandle(input: StrategyInput): boolean;

  /**
   * 构建发送给 AI 的 Prompt。
   * 不同策略应有不同的 Prompt 逻辑。
   */
  buildPrompt(input: StrategyInput): string;

  /**
   * 后处理 AI 返回的原始结果，确保符合 ProcessedContent 结构。
   * 可在此处注入策略特有的元数据（如 source_url、quality_flags）。
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent;
}

// ---------------------------------------------------------------------------
// 策略注册表接口
// ---------------------------------------------------------------------------

export interface StrategyRegistry {
  /** 根据 source_type 获取策略 */
  getStrategy(sourceType: SourceType): ContentProcessingStrategy;
  /** 注册新策略 */
  register(strategy: ContentProcessingStrategy): void;
  /** 检查是否支持某 source_type */
  hasStrategy(sourceType: SourceType): boolean;
}
