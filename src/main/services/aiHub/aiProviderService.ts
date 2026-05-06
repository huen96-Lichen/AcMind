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

/** Message format for chat completions */
export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/** Stream chunk result */
export interface StreamChunk {
  content: string;
  done: boolean;
  promptTokens?: number;
  completionTokens?: number;
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

  /**
   * 流式调用 AI 模型，返回 AsyncGenerator 用于实时获取 chunks。
   * 支持 OpenAI-compatible SSE 和 Ollama NDJSON 格式。
   */
  async *callStream(
    provider: ProviderConfig,
    messages: ChatMessage[],
    options?: AiCallOptions,
    signal?: AbortSignal,
  ): AsyncGenerator<StreamChunk> {
    const timeoutMs = options?.timeoutMs ?? DEFAULT_TIMEOUT_MS;

    try {
      if (provider.type === 'ollama') {
        yield* this.callOllamaStream(provider, messages, options, signal);
      } else if (provider.type === 'openai_compatible') {
        yield* this.callOpenAICompatibleStream(provider, messages, options, signal);
      } else {
        yield { content: '', done: true, error: `不支持的 provider 类型: ${provider.type}` } as StreamChunk;
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'aiProviderService', 'callStream', `AI stream call failed: ${errorMsg}`, {
        providerId: provider.id,
        modelId: provider.modelId,
      });
      yield { content: '', done: true };
    }
  }

  // ── Ollama Stream ─────────────────────────────────────────────

  private async *callOllamaStream(
    provider: ProviderConfig,
    messages: ChatMessage[],
    options: AiCallOptions | undefined,
    signal?: AbortSignal,
  ): AsyncGenerator<StreamChunk> {
    const url = `${provider.baseUrl.replace(/\/$/, '')}/api/chat`;

    // Convert messages to Ollama format
    const ollamaMessages = messages.map(m => ({
      role: m.role,
      content: m.content,
    }));

    const body: Record<string, unknown> = {
      model: provider.modelId,
      messages: ollamaMessages,
      stream: true,
      options: {
        temperature: options?.temperature ?? DEFAULT_TEMPERATURE,
        num_predict: options?.maxTokens ?? DEFAULT_MAX_TOKENS,
      },
    };

    // M6: systemPrompt 由 chatService 统一处理（已加入 messages 数组），此处不再重复添加

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), options?.timeoutMs ?? DEFAULT_TIMEOUT_MS);

    // Link external signal if provided
    if (signal) {
      signal.addEventListener('abort', () => controller.abort(), { once: true });
    }

    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!resp.ok) {
        const errText = await resp.text().catch(() => '');
        yield { content: `Ollama 返回 ${resp.status}: ${errText.slice(0, 200)}`, done: true };
        return;
      }

      if (!resp.body) {
        yield { content: '', done: true };
        return;
      }

      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          if (!line.trim()) continue;
          try {
            const data = JSON.parse(line) as {
              message?: { content?: string };
              done?: boolean;
              eval_count?: number;
              prompt_eval_count?: number;
            };
            const content = data.message?.content ?? '';
            const isDone = data.done === true;
            yield {
              content,
              done: isDone,
              completionTokens: data.eval_count,
              promptTokens: data.prompt_eval_count,
            };
            if (isDone) return;
          } catch {
            // Skip invalid JSON lines
          }
        }
      }

      // Process remaining buffer
      if (buffer.trim()) {
        try {
          const data = JSON.parse(buffer) as {
            message?: { content?: string };
            done?: boolean;
            eval_count?: number;
            prompt_eval_count?: number;
          };
          yield {
            content: data.message?.content ?? '',
            done: data.done === true,
            completionTokens: data.eval_count,
            promptTokens: data.prompt_eval_count,
          };
        } catch {
          // Ignore parse error on final buffer
        }
      }
    } finally {
      clearTimeout(timeoutId);
    }

    yield { content: '', done: true };
  }

  // ── OpenAI-compatible Stream ──────────────────────────────────

  private async *callOpenAICompatibleStream(
    provider: ProviderConfig,
    messages: ChatMessage[],
    options: AiCallOptions | undefined,
    signal?: AbortSignal,
  ): AsyncGenerator<StreamChunk> {
    const url = `${provider.baseUrl.replace(/\/$/, '')}/chat/completions`;

    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (provider.apiKey) {
      headers['Authorization'] = `Bearer ${provider.apiKey}`;
    }

    const body = {
      model: provider.modelId,
      messages,
      temperature: options?.temperature ?? DEFAULT_TEMPERATURE,
      max_tokens: options?.maxTokens ?? DEFAULT_MAX_TOKENS,
      stream: true,
    };

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), options?.timeoutMs ?? DEFAULT_TIMEOUT_MS);

    // Link external signal if provided
    if (signal) {
      signal.addEventListener('abort', () => controller.abort(), { once: true });
    }

    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!resp.ok) {
        const errText = await resp.text().catch(() => '');
        yield { content: `OpenAI API 返回 ${resp.status}: ${errText.slice(0, 200)}`, done: true };
        return;
      }

      if (!resp.body) {
        yield { content: '', done: true };
        return;
      }

      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          if (!line.trim()) continue;
          // SSE format: data: {...}
          if (line.startsWith('data: ')) {
            const dataStr = line.slice(6).trim();
            if (dataStr === '[DONE]') {
              yield { content: '', done: true };
              return;
            }
            try {
              const data = JSON.parse(dataStr) as {
                choices?: Array<{ delta?: { content?: string }; finish_reason?: string }>;
                usage?: { prompt_tokens?: number; completion_tokens?: number };
              };
              const content = data.choices?.[0]?.delta?.content ?? '';
              const isDone = data.choices?.[0]?.finish_reason != null;
              yield {
                content,
                done: isDone,
                promptTokens: data.usage?.prompt_tokens,
                completionTokens: data.usage?.completion_tokens,
              };
            } catch {
              // Skip invalid JSON
            }
          }
        }
      }

      // Process remaining buffer
      if (buffer.trim()) {
        if (buffer.startsWith('data: ')) {
          const dataStr = buffer.slice(6).trim();
          if (dataStr === '[DONE]') {
            yield { content: '', done: true };
            return;
          }
          try {
            const data = JSON.parse(dataStr) as {
              choices?: Array<{ delta?: { content?: string }; finish_reason?: string }>;
            };
            yield {
              content: data.choices?.[0]?.delta?.content ?? '',
              done: data.choices?.[0]?.finish_reason != null,
            };
          } catch {
            // Ignore parse error
          }
        }
      }
    } finally {
      clearTimeout(timeoutId);
    }

    yield { content: '', done: true };
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

    // M6: systemPrompt 由 chatService 统一处理，此处不再重复添加

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
  /**
   * 调用 embedding API，返回向量。
   * 支持 Ollama (/api/embeddings) 和 OpenAI-compatible (/v1/embeddings)。
   */
  async callEmbedding(
    provider: ProviderConfig,
    texts: string[],
    options?: { timeoutMs?: number },
  ): Promise<{ success: boolean; embeddings: number[][]; error?: string; latencyMs: number }> {
    const timeoutMs = options?.timeoutMs ?? 30_000;
    const start = Date.now();

    try {
      const baseUrl = provider.baseUrl.replace(/\/$/, '');

      if (provider.type === 'ollama') {
        // Ollama: /api/embeddings (one at a time)
        const embeddings: number[][] = [];
        for (const text of texts) {
          const resp = await fetch(`${baseUrl}/api/embeddings`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ model: provider.modelId, prompt: text }),
            signal: AbortSignal.timeout(timeoutMs),
          });
          if (!resp.ok) {
            const errText = await resp.text().catch(() => '');
            return { success: false, embeddings: [], error: `Ollama embedding ${resp.status}: ${errText.slice(0, 200)}`, latencyMs: Date.now() - start };
          }
          const data = await resp.json() as { embedding?: number[] };
          if (!data.embedding) {
            return { success: false, embeddings: [], error: 'Ollama 返回空 embedding', latencyMs: Date.now() - start };
          }
          embeddings.push(data.embedding);
        }
        return { success: true, embeddings, latencyMs: Date.now() - start };
      }

      if (provider.type === 'openai_compatible') {
        // OpenAI-compatible: /v1/embeddings (batch)
        const headers: Record<string, string> = { 'Content-Type': 'application/json' };
        if (provider.apiKey) headers['Authorization'] = `Bearer ${provider.apiKey}`;

        const resp = await fetch(`${baseUrl}/v1/embeddings`, {
          method: 'POST',
          headers,
          body: JSON.stringify({ model: provider.modelId, input: texts }),
          signal: AbortSignal.timeout(timeoutMs),
        });
        if (!resp.ok) {
          const errText = await resp.text().catch(() => '');
          return { success: false, embeddings: [], error: `OpenAI embedding ${resp.status}: ${errText.slice(0, 200)}`, latencyMs: Date.now() - start };
        }
        const data = await resp.json() as { data?: Array<{ embedding: number[] }> };
        if (!data.data || data.data.length === 0) {
          return { success: false, embeddings: [], error: 'OpenAI 返回空 embeddings', latencyMs: Date.now() - start };
        }
        const embeddings = data.data.map((d) => d.embedding);
        return { success: true, embeddings, latencyMs: Date.now() - start };
      }

      return { success: false, embeddings: [], error: `不支持的 provider 类型: ${provider.type}`, latencyMs: Date.now() - start };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'aiProviderService', 'callEmbedding', `Embedding call failed: ${errorMsg}`, {
        providerId: provider.id,
        modelId: provider.modelId,
      });
      return { success: false, embeddings: [], error: errorMsg, latencyMs: Date.now() - start };
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const aiProviderService = new AiProviderService();
