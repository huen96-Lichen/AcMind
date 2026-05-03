// AcMind Real Distiller
// Calls actual AI models (Ollama / OpenAI-compatible) for distillation

import type { AiOperation, ProviderConfig } from '../../../shared/types';
import { normalizeTags as sharedNormalizeTags } from '../../../shared/tagNormalizer';
import {
  DEFAULT_DISTILLED_CATEGORY,
  DEFAULT_DISTILLED_TYPE,
  DISTILLED_DOCUMENT_TYPES,
  type DistilledDocumentType,
} from '../../../shared/markdownSpec';
import { logger } from '../../logger';
import { buildPrompt } from './distillPrompts';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const REQUEST_TIMEOUT_MS = 30_000;
const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 1_000;

function buildOpenAiCompatibleUrl(baseUrl: string, endpoint: 'chat/completions'): string {
  const normalizedBase = baseUrl.replace(/\/+$/, '');
  const baseWithVersion = normalizedBase.endsWith('/v1') ? normalizedBase : `${normalizedBase}/v1`;
  return `${baseWithVersion}/${endpoint}`;
}

// ---------------------------------------------------------------------------
// RealDistiller
// ---------------------------------------------------------------------------

class RealDistiller {
  /**
   * Run a distillation task against a real AI provider.
   * Handles Ollama and OpenAI-compatible APIs with retry and timeout.
   */
  async runTask(
    provider: ProviderConfig,
    operation: AiOperation,
    content: string,
  ): Promise<Record<string, unknown>> {
    const prompt = buildPrompt(operation, content);
    const startTime = Date.now();

    logger.info('ai', 'realDistiller', 'runTask', `Starting API call: ${operation}`, {
      provider: provider.name,
      providerType: provider.type,
      model: provider.modelId,
      operation,
      contentLength: content.length,
    });

    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        logger.warn('ai', 'realDistiller', 'retry', `Retrying (attempt ${attempt + 1}/${MAX_RETRIES + 1})`, {
          provider: provider.name,
          operation,
        });
        await this.delay(RETRY_DELAY_MS * attempt);
      }

      try {
        const rawResponse = await this.callApi(provider, prompt);
        const parsed = this.parseResponse(operation, rawResponse);
        const latencyMs = Date.now() - startTime;

        logger.info('ai', 'realDistiller', 'success', `API call succeeded: ${operation}`, {
          provider: provider.name,
          model: provider.modelId,
          operation,
          latencyMs,
        });

        return parsed;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        logger.warn('ai', 'realDistiller', 'attemptFailed', `API call failed (attempt ${attempt + 1})`, {
          provider: provider.name,
          operation,
          error: lastError.message,
        });
      }
    }

    // All retries exhausted
    const errorMsg = `Real distiller failed after ${MAX_RETRIES + 1} attempts: ${lastError?.message ?? 'unknown error'}`;
    logger.error('ai', 'realDistiller', 'exhausted', errorMsg, {
      provider: provider.name,
      operation,
    });
    throw new Error(errorMsg);
  }

  // -------------------------------------------------------------------------
  // API call dispatch
  // -------------------------------------------------------------------------

  /**
   * Call the appropriate API based on provider type.
   */
  private async callApi(provider: ProviderConfig, prompt: string): Promise<string> {
    if (provider.type === 'ollama') {
      return this.callOllama(provider, prompt);
    } else if (provider.type === 'openai_compatible') {
      return this.callOpenAiCompatible(provider, prompt);
    } else {
      throw new Error(`Unsupported provider type: ${provider.type}`);
    }
  }

  /**
   * Call Ollama /api/generate endpoint.
   */
  private async callOllama(provider: ProviderConfig, prompt: string): Promise<string> {
    const url = `${provider.baseUrl.replace(/\/+$/, '')}/api/generate`;
    await this.ensureOllamaModelAvailable(provider);

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: provider.modelId,
        prompt,
        stream: false,
        format: 'json',
        options: {
          temperature: 0.2,
        },
      }),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`Ollama API returned HTTP ${response.status}: ${body}`);
    }

    const data = (await response.json()) as {
      response?: string;
      thinking?: string;
      error?: string;
    };
    if (data.error) {
      throw new Error(`Ollama API error: ${data.error}`);
    }

    const responseText = data.response?.trim() ?? '';
    const thinkingText = data.thinking?.trim() ?? '';

    if (!responseText && thinkingText) {
      logger.debug('ai', 'realDistiller', 'ollamaThinkingFallback', 'Using Ollama thinking field as response fallback', {
        provider: provider.name,
        model: provider.modelId,
        responseLength: 0,
        thinkingLength: thinkingText.length,
      });
    }

    return responseText || thinkingText || '';
  }

  /**
   * Call OpenAI-compatible /v1/chat/completions endpoint.
   */
  private async callOpenAiCompatible(provider: ProviderConfig, prompt: string): Promise<string> {
    const url = buildOpenAiCompatibleUrl(provider.baseUrl, 'chat/completions');

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (provider.apiKey) {
      headers['Authorization'] = `Bearer ${provider.apiKey}`;
    }

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        model: provider.modelId,
        messages: [
          {
            role: 'system',
            content: '你是一个内容分析助手。请严格按照用户要求的格式输出结果，只输出结果内容，不要添加额外解释。',
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: 0.3,
      }),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`OpenAI-compatible API returned HTTP ${response.status}: ${body}`);
    }

    const data = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
      error?: { message?: string };
    };
    if (data.error) {
      throw new Error(`OpenAI-compatible API error: ${data.error.message}`);
    }

    return data.choices?.[0]?.message?.content ?? '';
  }

  // -------------------------------------------------------------------------
  // Response parsing
  // -------------------------------------------------------------------------

  /**
   * Parse the raw model response into a structured output based on operation type.
   * Tries JSON extraction first, then falls back to regex-based extraction.
   */
  parseResponse(operation: AiOperation, rawResponse: string): Record<string, unknown> {
    const text = rawResponse.trim();

    if (!text) {
      throw new Error('Empty response from AI model');
    }

    // Try JSON extraction first
    const jsonResult = this.tryExtractJson(text);
    if (jsonResult) {
      return this.mapJsonToOutput(operation, jsonResult);
    }

    if (operation === 'summarize') {
      throw new Error('模型未返回符合 AcMind Markdown 规范的 JSON');
    }

    // Fall back to plain-text extraction
    return this.extractFromPlainText(operation, text);
  }

  /**
   * Try to extract a JSON object from the response text.
   * Handles markdown code blocks, raw JSON, etc.
   */
  private tryExtractJson(text: string): Record<string, unknown> | null {
    // Try to find JSON in markdown code block
    const codeBlockMatch = text.match(/```(?:json)?\s*\n?([\s\S]*?)\n?\s*```/);
    if (codeBlockMatch) {
      try {
        return JSON.parse(codeBlockMatch[1].trim()) as Record<string, unknown>;
      } catch {
        // Fall through
      }
    }

    // Try raw JSON parse
    try {
      const parsed = JSON.parse(text);
      if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      // Fall through
    }

    // Try to find JSON object in text
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        return JSON.parse(jsonMatch[0]) as Record<string, unknown>;
      } catch {
        // Fall through
      }
    }

    return null;
  }

  /**
   * Map a parsed JSON object to the expected output format for the operation.
   */
  private mapJsonToOutput(
    operation: AiOperation,
    json: Record<string, unknown>,
  ): Record<string, unknown> {
    switch (operation) {
      case 'rename': {
        const title = json.title ?? json.suggestedTitle ?? json.name ?? String(json);
        return { suggestedTitle: this.normalizeTitle(title) };
      }
      case 'summarize': {
        return this.mapDistilledNoteJson(json);
      }
      case 'classify': {
        const category = json.category ?? json.class ?? String(json);
        return { category: this.normalizeCategory(category) };
      }
      case 'tag': {
        const tags = json.tags ?? json.keywords;
        if (Array.isArray(tags)) {
          return { tags: this.normalizeLooseTags(tags) };
        }
        if (typeof tags === 'string') {
          return { tags: this.normalizeLooseTags(tags.split(/[,，、]/)) };
        }
        return { tags: this.normalizeLooseTags([String(json)]) };
      }
      case 'valueScore': {
        const score = json.score ?? json.valueScore ?? json.value ?? json.rating;
        const num = typeof score === 'number' ? score : parseInt(String(score), 10);
        return { valueScore: isNaN(num) ? 5 : Math.max(1, Math.min(10, num)) };
      }
      case 'cleanSuggest': {
        const suggestion = json.suggestion ?? json.cleanSuggestion ?? json.action ?? String(json);
        const normalized = String(suggestion).trim().toLowerCase();
        let cleanSuggestion: 'keep' | 'merge' | 'discard';
        if (normalized.includes('keep') || normalized.includes('保留')) {
          cleanSuggestion = 'keep';
        } else if (normalized.includes('merge') || normalized.includes('合并')) {
          cleanSuggestion = 'merge';
        } else if (normalized.includes('discard') || normalized.includes('清理') || normalized.includes('删除')) {
          cleanSuggestion = 'discard';
        } else {
          cleanSuggestion = 'keep';
        }
        return { cleanSuggestion };
      }
      case 'prefilter': {
        return json; // Pass through — caller validates individual fields
      }
      default:
        return json;
    }
  }

  private async ensureOllamaModelAvailable(provider: ProviderConfig): Promise<void> {
    const tagsUrl = `${provider.baseUrl.replace(/\/+$/, '')}/api/tags`;
    const response = await fetch(tagsUrl, {
      method: 'GET',
      signal: AbortSignal.timeout(5_000),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`Ollama model check failed HTTP ${response.status}: ${body}`);
    }

    const data = (await response.json()) as { models?: Array<{ name?: string; model?: string }> };
    const models = data.models ?? [];
    const exists = models.some((item) => item.name === provider.modelId || item.model === provider.modelId);
    if (!exists) {
      throw new Error(`Ollama model not found: ${provider.modelId}`);
    }
  }

  private mapDistilledNoteJson(json: Record<string, unknown>): Record<string, unknown> {
    const title = this.normalizeTitle(json.title ?? json.suggestedTitle);
    const summary = this.cleanString(json.summary, '不确定').slice(0, 120);
    const category = this.normalizeCategory(json.category);
    const documentType = this.normalizeDocumentType(json.type ?? json.documentType);
    const tags = this.normalizeTags(json.tags);
    const contentMarkdown = this.cleanString(json.contentMarkdown ?? json.content_markdown, '');

    if (!contentMarkdown) {
      throw new Error('模型 JSON 缺少 contentMarkdown');
    }

    return {
      suggestedTitle: title,
      summary,
      category,
      tags,
      documentType,
      contentMarkdown: this.ensureMarkdownTitle(contentMarkdown, title),
    };
  }

  private cleanString(value: unknown, fallback: string): string {
    const text = typeof value === 'string' ? value : value == null ? '' : String(value);
    return text.trim() || fallback;
  }

  private normalizeTitle(value: unknown): string {
    return this.cleanString(value, '未命名清洗稿')
      .replace(/[*_`#]/g, '')
      .replace(/^(标题|建议标题|文件名|名称)\s*[：:]\s*/i, '')
      .replace(/[\\/:*?"<>|#]/g, '-')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 80) || '未命名清洗稿';
  }

  private normalizeCategory(value: unknown): string {
    const raw = this.cleanString(value, DEFAULT_DISTILLED_CATEGORY)
      .replace(/[*`#]/g, '')
      .replace(/^(最佳分类|建议分类|分类|category|class)\s*[：:]\s*/i, '')
      .replace(/\(([^)]*)\)/g, '')
      .replace(/（[^）]*）/g, '')
      .replace(/[\\:*?"<>|#]/g, '-')
      .replace(/\s+/g, ' ')
      .trim();

    if (!raw) return DEFAULT_DISTILLED_CATEGORY;
    if (raw.includes('/')) return raw;
    return raw.slice(0, 40);
  }

  private normalizeTags(value: unknown): string[] {
    const raw = Array.isArray(value)
      ? value
      : typeof value === 'string'
        ? value.split(/[,，、\n]/)
        : [];
    const tags = raw
      .map((item) => String(item).trim().replace(/^#/, ''))
      .filter((item) => !/^(基于内容|以下是|这些标签|标签|关键词|供您选择)/.test(item))
      .filter((item) => !/(指明了|强调了|维度|性质|最基础|列表|选择)/.test(item))
      .map((item) => item.replace(/^\d+\.\s*/, '').replace(/\s*\([^)]*\)\s*$/, '').replace(/\s*[(（].*$/, ''))
      .filter(Boolean);
    // Delegate to centralized TagNormalizer for consistent formatting
    return sharedNormalizeTags(tags);
  }

  private normalizeLooseTags(value: unknown[]): string[] {
    const tags = value
      .map((item) => String(item).trim().replace(/^#/, ''))
      .map((item) => item.replace(/^\d+\.\s*/, '').replace(/\s*\([^)]*\)\s*$/, '').replace(/\s*[(（].*$/, ''))
      .filter((item) => !/^(基于内容|以下是|这些标签|标签|关键词|供您选择)/.test(item))
      .filter((item) => !/(指明了|强调了|维度|性质|最基础|列表|选择)/.test(item))
      .map((item) => item.replace(/[*_`#]/g, '').trim())
      .filter(Boolean);

    return [...new Set(tags)].slice(0, 10);
  }

  private normalizeDocumentType(value: unknown): DistilledDocumentType {
    const text = this.cleanString(value, DEFAULT_DISTILLED_TYPE);
    return (DISTILLED_DOCUMENT_TYPES as readonly string[]).includes(text)
      ? (text as DistilledDocumentType)
      : DEFAULT_DISTILLED_TYPE;
  }

  private ensureMarkdownTitle(markdown: string, title: string): string {
    const trimmed = markdown.trim();
    return trimmed.startsWith('# ') ? trimmed : `# ${title}\n\n${trimmed}`;
  }

  /**
   * Extract structured output from plain text when JSON parsing fails.
   */
  private extractFromPlainText(
    operation: AiOperation,
    text: string,
  ): Record<string, unknown> {
    switch (operation) {
      case 'rename':
        return { suggestedTitle: this.normalizeTitle(text.split('\n')[0]) };
      case 'summarize':
        return { summary: text.trim() };
      case 'classify':
        return { category: this.normalizeCategory(text.split('\n')[0]) };
      case 'tag': {
        const tags = text
          .split(/[,，、\n]/)
          .map((t) => t.trim().replace(/^[-*#]\s*/, ''))
          .filter(Boolean);
        return { tags: this.normalizeLooseTags(tags) };
      }
      case 'valueScore': {
        const match = text.match(/(\d+)/);
        const num = match ? parseInt(match[1], 10) : 5;
        return { valueScore: Math.max(1, Math.min(10, num)) };
      }
      case 'cleanSuggest': {
        const lower = text.toLowerCase();
        if (lower.includes('discard') || lower.includes('清理') || lower.includes('删除')) {
          return { cleanSuggestion: 'discard' as const };
        }
        if (lower.includes('merge') || lower.includes('合并')) {
          return { cleanSuggestion: 'merge' as const };
        }
        return { cleanSuggestion: 'keep' as const };
      }
      case 'prefilter': {
        return { suggestedTitle: text.split('\n')[0].slice(0, 35), valueScore: 50, duplicateScore: 0, suggestedAction: 'keep_pinned', reason: '无法解析模型输出', tags: [] };
      }
      default:
        return { raw: text };
    }
  }

  // -------------------------------------------------------------------------
  // Utility
  // -------------------------------------------------------------------------

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const realDistiller = new RealDistiller();
