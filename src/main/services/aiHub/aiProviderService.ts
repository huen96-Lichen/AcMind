/**
 * AI Provider Service — 统一 AI 模型调用层
 *
 * 支持两种 provider 类型：
 * - Ollama（本地模型，/api/generate 或 /api/chat）
 * - OpenAI-compatible（云端模型，/v1/chat/completions）
 *
 * 职责：
 * 1. 根据 ProviderConfig 发送 HTTP 请求到对应 API
 * 2. 统一返回格式（文本结果 + token 用量 + 延迟）
 * 3. 超时 / 错误处理
 * 4. 不做业务逻辑（路由、prompt 构建等由上层负责）
 */

import type { ProviderConfig } from '../../../shared/types';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface AiCallResult {
  success: boolean;
  text?: string;
  error?: string;
  /** 输入 token 数 */
  promptTokens?: number;
  /** 输出 token 数 */
  completionTokens?: number;
  /** 请求延迟 (ms) */
  latencyMs: number;
  /** 实际使用的模型 ID */
  modelId: string;
}

export interface AiCallOptions {
  /** 超时 (ms)，默认 60000 */
  timeoutMs?: number;
  /** 温度参数 */
  temperature?: number;
  /** 最大输出 token 数 */
  maxTokens?: number;
  /** 系统 prompt */
  systemPrompt?: string;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_TIMEOUT_MS = 60_000;
const DEFAULT_TEMPERATURE = 0.3;
const DEFAULT_MAX_TOKENS = 2048;

// ---------------------------------------------------------------------------
// AiProviderService
// ---------------------------------------------------------------------------

class AiProviderService {
  /**
   * 调用 AI 模型，统一入口。
   * 根据 provider.type 自动选择 Ollama 或 OpenAI-compatible 协议。
   */
  async call(
    provider: ProviderConfig,
    prompt: string,
    options?: AiCallOptions,
  ): Promise<AiCallResult> {
    const timeoutMs = options?.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    const start = Date.now();

    try {
      if (provider.type === 'ollama') {
        return await this.callOllama(provider, prompt, options, timeoutMs, start);
      }
      if (provider.type === 'openai_compatible') {
        return await this.callOpenAICompatible(provider, prompt, options, timeoutMs, start);
      }

      return {
        success: false,
        error: `不支持的 provider 类型: ${provider.type}`,
        latencyMs: Date.now() - start,
        modelId: provider.modelId,
      };
    } catch (error) {
      const latencyMs = Date.now() - start;
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'aiProviderService', 'call', `AI call failed: ${errorMsg}`, {
        providerId: provider.id,
        modelId: provider.modelId,
        latencyMs,
      });
      return {
        success: false,
        error: errorMsg,
        latencyMs,
        modelId: provider.modelId,
      };
    }
  }

  /**
   * 检查 provider 是否可达（健康检查）。
   */
  async healthCheck(provider: ProviderConfig): Promise<{ ok: boolean; latencyMs: number; error?: string }> {
    const start = Date.now();
    try {
      if (provider.type === 'ollama') {
        const url = `${provider.baseUrl.replace(/\/$/, '')}/api/tags`;
        const resp = await fetch(url, { signal: AbortSignal.timeout(5000) });
        return { ok: resp.ok, latencyMs: Date.now() - start };
      }
      if (provider.type === 'openai_compatible') {
        const url = `${provider.baseUrl.replace(/\/$/, '')}/models`;
        const headers: Record<string, string> = { 'Content-Type': 'application/json' };
        if (provider.apiKey) headers['Authorization'] = `Bearer ${provider.apiKey}`;
        const resp = await fetch(url, { headers, signal: AbortSignal.timeout(5000) });
        return { ok: resp.ok, latencyMs: Date.now() - start };
      }
      return { ok: false, latencyMs: Date.now() - start, error: `不支持的类型: ${provider.type}` };
    } catch (error) {
      return {
        ok: false,
        latencyMs: Date.now() - start,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  }

  // ── Ollama ────────────────────────────────────────────────────

  private async callOllama(
    provider: ProviderConfig,
    prompt: string,
    options: AiCallOptions | undefined,
    timeoutMs: number,
    start: number,
  ): Promise<AiCallResult> {
    const url = `${provider.baseUrl.replace(/\/$/, '')}/api/generate`;

    const body: Record<string, unknown> = {
      model: provider.modelId,
      prompt,
      stream: false,
      options: {
        temperature: options?.temperature ?? DEFAULT_TEMPERATURE,
        num_predict: options?.maxTokens ?? DEFAULT_MAX_TOKENS,
      },
    };

    if (options?.systemPrompt) {
      body.system = options.systemPrompt;
    }

    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });

    if (!resp.ok) {
      const errText = await resp.text().catch(() => '');
      return {
        success: false,
        error: `Ollama 返回 ${resp.status}: ${errText.slice(0, 200)}`,
        latencyMs: Date.now() - start,
        modelId: provider.modelId,
      };
    }

    const data = await resp.json() as {
      response?: string;
      eval_count?: number;
      prompt_eval_count?: number;
    };

    return {
      success: true,
      text: data.response ?? '',
      completionTokens: data.eval_count,
      promptTokens: data.prompt_eval_count,
      latencyMs: Date.now() - start,
      modelId: provider.modelId,
    };
  }

  // ── OpenAI-compatible ─────────────────────────────────────────

  private async callOpenAICompatible(
    provider: ProviderConfig,
    prompt: string,
    options: AiCallOptions | undefined,
    timeoutMs: number,
    start: number,
  ): Promise<AiCallResult> {
    const url = `${provider.baseUrl.replace(/\/$/, '')}/chat/completions`;

    const messages: Array<{ role: string; content: string }> = [];
    if (options?.systemPrompt) {
      messages.push({ role: 'system', content: options.systemPrompt });
    }
    messages.push({ role: 'user', content: prompt });

    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (provider.apiKey) {
      headers['Authorization'] = `Bearer ${provider.apiKey}`;
    }

    const body = {
      model: provider.modelId,
      messages,
      temperature: options?.temperature ?? DEFAULT_TEMPERATURE,
      max_tokens: options?.maxTokens ?? DEFAULT_MAX_TOKENS,
      stream: false,
    };

    const resp = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });

    if (!resp.ok) {
      const errText = await resp.text().catch(() => '');
      return {
        success: false,
        error: `OpenAI API 返回 ${resp.status}: ${errText.slice(0, 200)}`,
        latencyMs: Date.now() - start,
        modelId: provider.modelId,
      };
    }

    const data = await resp.json() as {
      choices?: Array<{ message?: { content?: string } }>;
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    };

    const text = data.choices?.[0]?.message?.content ?? '';

    return {
      success: true,
      text,
      promptTokens: data.usage?.prompt_tokens,
      completionTokens: data.usage?.completion_tokens,
      latencyMs: Date.now() - start,
      modelId: provider.modelId,
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const aiProviderService = new AiProviderService();
