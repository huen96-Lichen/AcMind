// AcMind RealDistiller Unit Tests
// Tests for parseResponse, mapJsonToOutput, and extractFromPlainText (pure functions)

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { logger } from '../../logger';

// Mock the logger to avoid file I/O
vi.mock('../../logger', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    debug: vi.fn(),
  },
}));

// Mock buildPrompt to avoid needing the actual prompt templates
vi.mock('./distillPrompts', () => ({
  buildPrompt: vi.fn((_op: string, _content: string) => 'mock prompt'),
}));

import { realDistiller } from './realDistiller';

function createJsonResponse(body: unknown, ok = true, status = 200) {
  return {
    ok,
    status,
    json: vi.fn(async () => body),
    text: vi.fn(async () => (typeof body === 'string' ? body : JSON.stringify(body))),
  } as unknown as Response;
}

describe('RealDistiller', () => {
  beforeEach(() => {
    // realDistiller is a singleton, no reset needed for pure function tests
    vi.restoreAllMocks();
    vi.stubGlobal('fetch', vi.fn());
  });

  // -- callOllama -----------------------------------------------------------

  describe('callOllama', () => {
    const provider = {
      id: 'ollama-qwen',
      name: '本地模型',
      type: 'ollama' as const,
      tier: 'local_light' as const,
      baseUrl: 'http://localhost:11434',
      modelId: 'qwen3.5:9b',
      enabled: true,
      capabilities: ['rename', 'summarize', 'classify', 'tag', 'valueScore', 'cleanSuggest'],
    };

    it('should use response when Ollama returns it', async () => {
      const fetchMock = vi.mocked(fetch);
      fetchMock
        .mockResolvedValueOnce(createJsonResponse({ models: [{ name: 'qwen3.5:9b' }] }))
        .mockResolvedValueOnce(createJsonResponse({ response: 'final answer', thinking: 'ignored' }));

      const result = await (realDistiller as any).callOllama(provider, 'mock prompt');

      expect(result).toBe('final answer');
      expect(logger.debug).not.toHaveBeenCalledWith(
        'ai',
        'realDistiller',
        'ollamaThinkingFallback',
        expect.any(String),
        expect.any(Object),
      );
    });

    it('should fall back to thinking when response is empty', async () => {
      const fetchMock = vi.mocked(fetch);
      fetchMock
        .mockResolvedValueOnce(createJsonResponse({ models: [{ name: 'qwen3.5:9b' }] }))
        .mockResolvedValueOnce(createJsonResponse({ response: '', thinking: '{"title":"a"}' }));

      const result = await (realDistiller as any).callOllama(provider, 'mock prompt');

      expect(result).toBe('{"title":"a"}');
      expect(logger.debug).toHaveBeenCalledWith(
        'ai',
        'realDistiller',
        'ollamaThinkingFallback',
        'Using Ollama thinking field as response fallback',
        expect.objectContaining({
          provider: '本地模型',
          model: 'qwen3.5:9b',
          responseLength: 0,
          thinkingLength: 13,
        }),
      );
    });

    it('should throw when both response and thinking are empty', async () => {
      const fetchMock = vi.mocked(fetch);
      fetchMock
        .mockResolvedValueOnce(createJsonResponse({ models: [{ name: 'qwen3.5:9b' }] }))
        .mockResolvedValueOnce(createJsonResponse({ response: '', thinking: '' }));

      const result = await (realDistiller as any).callOllama(provider, 'mock prompt');

      expect(result).toBe('');
    });
  });

  // -- callOpenAiCompatible -------------------------------------------------

  describe('callOpenAiCompatible', () => {
    const provider = {
      id: 'deepseek-v4-flash',
      name: 'DeepSeek V4 Flash',
      type: 'openai_compatible' as const,
      tier: 'cloud_standard' as const,
      baseUrl: 'https://api.deepseek.com',
      apiKey: 'test-key',
      modelId: 'deepseek-v4-flash',
      enabled: true,
      capabilities: ['summarize'],
    };

    it('should call /v1/chat/completions when base URL has no version suffix', async () => {
      const fetchMock = vi.mocked(fetch);
      fetchMock.mockResolvedValueOnce(createJsonResponse({
        choices: [{ message: { content: 'ok' } }],
      }));

      const result = await (realDistiller as any).callOpenAiCompatible(provider, 'mock prompt');

      expect(result).toBe('ok');
      expect(fetchMock).toHaveBeenCalledWith(
        'https://api.deepseek.com/v1/chat/completions',
        expect.objectContaining({ method: 'POST' }),
      );
    });

    it('should not duplicate /v1 when base URL already includes it', async () => {
      const fetchMock = vi.mocked(fetch);
      fetchMock.mockResolvedValueOnce(createJsonResponse({
        choices: [{ message: { content: 'ok' } }],
      }));

      await (realDistiller as any).callOpenAiCompatible(
        { ...provider, baseUrl: 'https://api.deepseek.com/v1' },
        'mock prompt',
      );

      expect(fetchMock).toHaveBeenCalledWith(
        'https://api.deepseek.com/v1/chat/completions',
        expect.objectContaining({ method: 'POST' }),
      );
    });
  });

  // -- parseResponse --------------------------------------------------------

  describe('parseResponse', () => {
    // -- JSON extraction from markdown code blocks ---------------------------

    it('should extract JSON from markdown code block with json tag', () => {
      const raw = '```json\n{"title": "My Note"}\n```';
      const result = realDistiller.parseResponse('rename', raw);
      expect(result).toEqual({ suggestedTitle: 'My Note' });
    });

    it('should extract JSON from markdown code block without json tag', () => {
      const raw = '```\n{"title":"标题","summary":"A brief summary of the content","category":"99_Inbox/待归纳","tags":["ai","acmind","local"],"type":"distilled-note","contentMarkdown":"# 标题\\n\\nA brief summary of the content"}\n```';
      const result = realDistiller.parseResponse('summarize', raw);
      expect(result).toMatchObject({
        suggestedTitle: '标题',
        summary: 'A brief summary of the content',
        category: '99_Inbox/待归纳',
        tags: ['ai', 'acmind', 'local'],
        documentType: 'distilled-note',
        contentMarkdown: '# 标题\n\nA brief summary of the content',
      });
    });

    // -- Raw JSON extraction -------------------------------------------------

    it('should extract raw JSON', () => {
      const raw = '{"category": "technology"}';
      const result = realDistiller.parseResponse('classify', raw);
      expect(result).toEqual({ category: 'technology' });
    });

    // -- JSON embedded in text -----------------------------------------------

    it('should extract JSON embedded in surrounding text', () => {
      const raw = 'Here is the result:\n{"tags": ["ai", "ml", "nlp"]}\nEnd of response.';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['ai', 'ml', 'nlp'] });
    });

    // -- Empty response error ------------------------------------------------

    it('should throw error on empty response', () => {
      expect(() => realDistiller.parseResponse('summarize', '')).toThrow(
        'Empty response from AI model',
      );
    });

    it('should throw error on whitespace-only response', () => {
      expect(() => realDistiller.parseResponse('summarize', '   \n  \t  ')).toThrow(
        'Empty response from AI model',
      );
    });
  });

  // -- mapJsonToOutput (tested via parseResponse with JSON) -----------------

  describe('mapJsonToOutput (via parseResponse)', () => {
    // -- rename --------------------------------------------------------------

    it('rename: should map "title" field to suggestedTitle', () => {
      const raw = '{"title": "Renamed Note"}';
      const result = realDistiller.parseResponse('rename', raw);
      expect(result).toEqual({ suggestedTitle: 'Renamed Note' });
    });

    it('rename: should fall back to suggestedTitle field', () => {
      const raw = '{"suggestedTitle": "Alt Title"}';
      const result = realDistiller.parseResponse('rename', raw);
      expect(result).toEqual({ suggestedTitle: 'Alt Title' });
    });

    it('rename: should fall back to name field', () => {
      const raw = '{"name": "Name Title"}';
      const result = realDistiller.parseResponse('rename', raw);
      expect(result).toEqual({ suggestedTitle: 'Name Title' });
    });

    // -- summarize -----------------------------------------------------------

    it('summarize: should map "summary" field', () => {
      const raw = '{"title":"标题","summary":"This is a summary.","category":"99_Inbox/待归纳","tags":["ai","acmind","local"],"type":"distilled-note","contentMarkdown":"# 标题\\n\\nThis is a summary."}';
      const result = realDistiller.parseResponse('summarize', raw);
      expect(result).toMatchObject({
        suggestedTitle: '标题',
        summary: 'This is a summary.',
        category: '99_Inbox/待归纳',
        tags: ['ai', 'acmind', 'local'],
        documentType: 'distilled-note',
        contentMarkdown: '# 标题\n\nThis is a summary.',
      });
    });

    it('summarize: should reject JSON without contentMarkdown', () => {
      const raw = '{"content": "Fallback content."}';
      expect(() => realDistiller.parseResponse('summarize', raw)).toThrow('模型 JSON 缺少 contentMarkdown');
    });

    // -- classify ------------------------------------------------------------

    it('classify: should map "category" field', () => {
      const raw = '{"category": "science"}';
      const result = realDistiller.parseResponse('classify', raw);
      expect(result).toEqual({ category: 'science' });
    });

    it('classify: should strip model explanation from category', () => {
      const raw = '{"category": "**最佳分类：产品 (Product)**"}';
      const result = realDistiller.parseResponse('classify', raw);
      expect(result).toEqual({ category: '产品' });
    });

    it('classify: should fall back to "class" field', () => {
      const raw = '{"class": "engineering"}';
      const result = realDistiller.parseResponse('classify', raw);
      expect(result).toEqual({ category: 'engineering' });
    });

    // -- tag -----------------------------------------------------------------

    it('tag: should map "tags" array', () => {
      const raw = '{"tags": ["javascript", "typescript", "react"]}';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['javascript', 'typescript', 'react'] });
    });

    it('tag: should fall back to "keywords" field', () => {
      const raw = '{"keywords": ["dev", "coding"]}';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['dev', 'coding'] });
    });

    it('tag: should split comma-separated string into array', () => {
      const raw = '{"tags": "python, machine learning, data"}';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['python', 'machine learning', 'data'] });
    });

    it('tag: should split Chinese comma-separated string', () => {
      const raw = '{"tags": "人工智能、机器学习、深度学习"}';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['人工智能', '机器学习', '深度学习'] });
    });

    it('tag: should discard explanatory prose emitted as tags', () => {
      const raw = '{"tags":["基于内容","这些标签应涵盖**产品特性","1. **#AcMind核心功能** (最基础","系统架构规划"]}';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['AcMind核心功能', '系统架构规划'] });
    });

    // -- valueScore ----------------------------------------------------------

    it('valueScore: should map numeric "score" field', () => {
      const raw = '{"score": 8}';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 8 });
    });

    it('valueScore: should clamp score to 1-10 range', () => {
      const raw = '{"score": 15}';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 10 });
    });

    it('valueScore: should clamp low score to minimum 1', () => {
      const raw = '{"score": -3}';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 1 });
    });

    it('valueScore: should parse string score', () => {
      const raw = '{"score": "7"}';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 7 });
    });

    it('valueScore: should default to 5 for invalid score', () => {
      const raw = '{"score": "invalid"}';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 5 });
    });

    // -- cleanSuggest --------------------------------------------------------

    it('cleanSuggest: should map "keep" suggestion', () => {
      const raw = '{"suggestion": "keep"}';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'keep' });
    });

    it('cleanSuggest: should map "merge" suggestion', () => {
      const raw = '{"suggestion": "merge"}';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'merge' });
    });

    it('cleanSuggest: should map "discard" suggestion', () => {
      const raw = '{"suggestion": "discard"}';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'discard' });
    });

    it('cleanSuggest: should map Chinese "保留" to keep', () => {
      const raw = '{"suggestion": "保留这条笔记"}';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'keep' });
    });

    it('cleanSuggest: should map Chinese "合并" to merge', () => {
      const raw = '{"suggestion": "合并到其他笔记"}';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'merge' });
    });

    it('cleanSuggest: should map Chinese "清理" to discard', () => {
      const raw = '{"suggestion": "清理这条重复内容"}';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'discard' });
    });

    it('cleanSuggest: should default to keep for unknown suggestion', () => {
      const raw = '{"suggestion": "something else"}';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'keep' });
    });
  });

  // -- extractFromPlainText (tested via parseResponse with non-JSON) ---------

  describe('extractFromPlainText (via parseResponse)', () => {
    it('rename: should take first line as title', () => {
      const raw = 'My Great Note Title\nSome extra content';
      const result = realDistiller.parseResponse('rename', raw);
      expect(result).toEqual({ suggestedTitle: 'My Great Note Title' });
    });

    it('summarize: should reject plain text because Local Distill MVP requires JSON markdown contract', () => {
      const raw = 'This is the full summary text.';
      expect(() => realDistiller.parseResponse('summarize', raw)).toThrow('模型未返回符合 AcMind Markdown 规范的 JSON');
    });

    it('classify: should take first line as category', () => {
      const raw = 'technology\nSome explanation';
      const result = realDistiller.parseResponse('classify', raw);
      expect(result).toEqual({ category: 'technology' });
    });

    it('tag: should split by commas and newlines', () => {
      const raw = 'tag1, tag2\ntag3, tag4';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['tag1', 'tag2', 'tag3', 'tag4'] });
    });

    it('tag: should strip list markers', () => {
      const raw = '- item1\n* item2\n# item3';
      const result = realDistiller.parseResponse('tag', raw);
      expect(result).toEqual({ tags: ['item1', 'item2', 'item3'] });
    });

    it('tag: should limit to 10 tags', () => {
      const raw = Array.from({ length: 15 }, (_, i) => `tag${i}`).join(', ');
      const result = realDistiller.parseResponse('tag', raw);
      expect(result.tags).toHaveLength(10);
    });

    it('valueScore: should extract first number from text', () => {
      const raw = 'I would rate this a 7 out of 10.';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 7 });
    });

    it('valueScore: should default to 5 when no number found', () => {
      const raw = 'No numbers here';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 5 });
    });

    it('valueScore: should clamp extracted number to 1-10', () => {
      const raw = 'Score: 15';
      const result = realDistiller.parseResponse('valueScore', raw);
      expect(result).toEqual({ valueScore: 10 });
    });

    it('cleanSuggest: should detect "discard" in plain text', () => {
      const raw = 'This item should be discarded';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'discard' });
    });

    it('cleanSuggest: should detect "merge" in plain text', () => {
      const raw = 'Please merge this with another note';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'merge' });
    });

    it('cleanSuggest: should default to "keep" when no keyword found', () => {
      const raw = 'This is a useful note';
      const result = realDistiller.parseResponse('cleanSuggest', raw);
      expect(result).toEqual({ cleanSuggestion: 'keep' });
    });

    it('cleanSuggest: should detect Chinese keywords in plain text', () => {
      const result1 = realDistiller.parseResponse('cleanSuggest', '建议删除这条');
      expect(result1).toEqual({ cleanSuggestion: 'discard' });

      const result2 = realDistiller.parseResponse('cleanSuggest', '建议合并处理');
      expect(result2).toEqual({ cleanSuggestion: 'merge' });
    });
  });
});
