/**
 * AI Action Runner — 执行 AI Action 的完整管线
 *
 * 流程：
 * 1. 从 AIAction + input 构建 StrategyInput
 * 2. 通过 PromptProfile 构建 Prompt
 * 3. 通过 ModelRouter 选择模型
 * 4. 调用 aiProviderService 发送请求
 * 5. 通过 OutputValidator 校验 + QualityFallback 兜底
 * 6. 返回结构化结果
 *
 * 同时负责将执行过程记录到 ai_tasks 表。
 */

import { randomUUID } from 'node:crypto';
import type {
  AIAction,
  AiTask,
  AiTaskStatus,
  ProviderConfig,
  SourceType,
} from '../../../shared/types';
import { storage } from '../../storage';
import { logger } from '../../logger';
import { strategyProcessor } from '../strategy/strategyProcessor';
import { aiProviderService, type AiCallResult } from './aiProviderService';
import type { ProcessedContent } from '../strategy/types';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ActionRunResult {
  success: boolean;
  taskId: string;
  /** 结构化处理结果 */
  content?: ProcessedContent;
  /** AI 原始输出文本 */
  rawText?: string;
  /** 模型调用信息 */
  modelCall?: {
    providerId: string;
    modelId: string;
    latencyMs: number;
    promptTokens?: number;
    completionTokens?: number;
  };
  /** 路由决策原因 */
  routingReason?: string;
  /** 质量分数 (0-100) */
  qualityScore?: number;
  /** 是否使用了 fallback */
  usedFallback?: boolean;
  error?: string;
}

// ---------------------------------------------------------------------------
// AiActionRunner
// ---------------------------------------------------------------------------

class AiActionRunner {
  /**
   * 执行一个 AI Action。
   *
   * @param action - AI Action 定义
   * @param input - 用户输入文本（可以是原始内容、Markdown 等）
   * @param sourceType - 内容来源类型（默认 'manual_text'）
   * @param options - 可选参数
   */
  async run(
    action: AIAction,
    input: string,
    sourceType?: SourceType,
    options?: {
      defaultTier?: 'local_light' | 'cloud_standard' | 'cloud_advanced';
      privacyMode?: boolean;
      allowCloud?: boolean;
      availableProviders?: ProviderConfig[];
    },
  ): Promise<ActionRunResult> {
    const taskId = randomUUID();
    const effectiveSourceType: SourceType = sourceType ?? (action.inputTypes[0] || 'manual_text');
    const providers = options?.availableProviders ?? storage.getProviderConfigs().filter((p) => p.enabled);

    // 创建 AiTask 记录
    const task: AiTask = {
      id: taskId,
      sourceItemId: '',
      tier: options?.defaultTier ?? 'cloud_standard',
      operation: this.mapActionTypeToOperation(action.actionType),
      status: 'running',
      provider: '',
      model: '',
      input: { actionId: action.id, actionName: action.name, text: input.slice(0, 500) },
      createdAt: Date.now(),
      updatedAt: Date.now(),
      startedAt: Date.now(),
    };

    try {
      storage.insertAiTask(task);
    } catch (err) {
      logger.warn('app', 'aiActionRunner', 'insert-task-fail', 'Failed to insert AiTask', {
        error: err instanceof Error ? err.message : String(err),
      });
    }

    try {
      // Step 1: 构建 CaptureRecord 用于 strategyProcessor
      const mockRecord = this.buildMockRecord(input, effectiveSourceType);

      // Step 2: strategyProcessor.prepareProcessing
      const prepared = strategyProcessor.prepareProcessing(mockRecord, {
        defaultTier: options?.defaultTier,
        privacyMode: options?.privacyMode,
        allowCloud: options?.allowCloud,
        availableProviders: providers,
      });

      // 如果有 directOutput（占位），直接返回
      if (prepared.directOutput) {
        this.finishTask(taskId, 'done', prepared.directOutput);
        return {
          success: true,
          taskId,
          content: prepared.directOutput,
          routingReason: '占位内容，无需 AI 处理',
          qualityScore: 100,
          usedFallback: false,
        };
      }

      // Step 3: 选择 provider
      const provider = prepared.routingDecision.provider;
      if (!provider) {
        const fallbackContent = strategyProcessor.processAiOutput(
          {}, prepared.input, { provider: 'none', model_name: 'none', model_tier: 'local_light', prompt_profile_id: 'default', prompt_profile_version: '1.0', status: 'fallback' },
        );
        this.finishTask(taskId, 'done', fallbackContent.content);
        return {
          success: true,
          taskId,
          content: fallbackContent.content,
          routingReason: prepared.routingDecision.reason,
          qualityScore: fallbackContent.qualityScore,
          usedFallback: true,
        };
      }

      // Step 4: 调用 AI
      const systemPrompt = '你是一个知识整理助手。请根据用户的要求处理以下内容。返回 JSON 格式的结果。';
      const aiResult = await aiProviderService.call(provider, prepared.prompt, {
        systemPrompt,
        temperature: 0.3,
        maxTokens: 2048,
      });

      if (!aiResult.success) {
        this.finishTask(taskId, 'failed', undefined, aiResult.error);
        return {
          success: false,
          taskId,
          error: aiResult.error,
          routingReason: prepared.routingDecision.reason,
        };
      }

      // Step 5: 解析 AI 输出 + 校验 + 质量兜底
      const rawParsed = this.tryParseJson(aiResult.text ?? '');
      const processingResult = strategyProcessor.processAiOutput(
        rawParsed,
        prepared.input,
        {
          provider: provider.id,
          model_name: provider.modelId,
          model_tier: prepared.routingDecision.tier,
          prompt_profile_id: 'default',
          prompt_profile_version: '1.0',
          status: 'success',
        },
      );

      // 更新 task
      this.finishTask(taskId, 'done', processingResult.content);

      return {
        success: true,
        taskId,
        content: processingResult.content,
        rawText: aiResult.text,
        modelCall: {
          providerId: provider.id,
          modelId: provider.modelId,
          latencyMs: aiResult.latencyMs,
          promptTokens: aiResult.promptTokens,
          completionTokens: aiResult.completionTokens,
        },
        routingReason: prepared.routingDecision.reason,
        qualityScore: processingResult.qualityScore,
        usedFallback: processingResult.usedFallback,
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'aiActionRunner', 'run', `Action failed: ${errorMsg}`, {
        actionId: action.id,
        taskId,
      });
      this.finishTask(taskId, 'failed', undefined, errorMsg);
      return { success: false, taskId, error: errorMsg };
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  /**
   * 构建 mock CaptureRecord 供 strategyProcessor 使用。
   * strategyProcessor 期望 CaptureRecord，但 AI Action 的输入是纯文本。
   */
  private buildMockRecord(
    input: string,
    sourceType: SourceType,
  ): import('../../../shared/types').CaptureRecord {
    return {
      original_id: randomUUID(),
      source_type: sourceType,
      raw_text: input,
      created_at: new Date().toISOString(),
      metadata: {},
    } as import('../../../shared/types').CaptureRecord;
  }

  /**
   * 尝试将 AI 输出解析为 JSON 对象。
   * 如果不是合法 JSON，包装为 { body_markdown: text }。
   */
  private tryParseJson(text: string): Record<string, unknown> {
    // 尝试提取 ```json ... ``` 代码块
    const codeBlockMatch = text.match(/```(?:json)?\s*\n?([\s\S]*?)\n?```/);
    const raw = codeBlockMatch ? codeBlockMatch[1].trim() : text.trim();

    try {
      return JSON.parse(raw) as Record<string, unknown>;
    } catch {
      // 不是 JSON，包装为 body_markdown
      return { body_markdown: text };
    }
  }

  /**
   * 将 AIActionType 映射到 AiOperation。
   */
  private mapActionTypeToOperation(actionType: AIAction['actionType']): import('../../../shared/types').AiOperation {
    const mapping: Record<string, import('../../../shared/types').AiOperation> = {
      summarize: 'summarize',
      rewrite: 'rename',
      translate: 'rename',
      extract_todos: 'classify',
      to_markdown: 'rename',
      save_to_inbox: 'rename',
      custom: 'summarize',
    };
    return mapping[actionType] ?? 'summarize';
  }

  /**
   * 更新 AiTask 状态。
   */
  private finishTask(
    taskId: string,
    status: AiTaskStatus,
    output?: ProcessedContent,
    error?: string,
  ): void {
    try {
      storage.updateAiTask(taskId, {
        status,
        output: output as unknown as Record<string, unknown>,
        error,
        finishedAt: Date.now(),
        updatedAt: Date.now(),
      });
    } catch (err) {
      logger.warn('app', 'aiActionRunner', 'update-task-fail', 'Failed to update AiTask', {
        taskId,
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const aiActionRunner = new AiActionRunner();
