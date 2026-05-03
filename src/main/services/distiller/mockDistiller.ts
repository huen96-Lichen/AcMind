// PinMind Mock Distiller
// Returns fixed-format results after a simulated delay for testing
// [Mock Fallback] Phase 1: 所有操作均返回结构化结果，确保业务链路可闭环

import type { AiOperation } from '../../../shared/types';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Mock delay
// ---------------------------------------------------------------------------

const MOCK_DELAY_MS = 500;

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// Helper: generate a mock title from content
// ---------------------------------------------------------------------------

function mockTitle(content: string): string {
  const firstLine = content.split('\n')[0].trim();
  return firstLine.length > 40 ? firstLine.substring(0, 40) + '…' : firstLine || '未命名笔记';
}

function mockSummary(content: string): string {
  const sentences = content.replace(/\n+/g, '。').split(/[。！？.!?]/).filter(Boolean);
  const keyPoints = sentences.slice(0, 3).map(s => s.trim()).filter(Boolean);
  return keyPoints.join('；') || `这是对以下内容的模拟摘要：${content.substring(0, 80)}…`;
}

function mockContentMarkdown(content: string, title: string): string {
  const body = content.length > 200
    ? content.substring(0, 200) + '\n\n...(内容已截断，Mock 模式)'
    : content;
  return `# ${title}\n\n## 原始内容\n\n${body}`;
}

// ---------------------------------------------------------------------------
// mockDistiller
// ---------------------------------------------------------------------------

export const mockDistiller = {
  /**
   * Run a mock distillation task. Returns a fixed-format result after a
   * simulated delay. Always logs a "Mock 模式" warning.
   */
  async runTask(operation: AiOperation, input: Record<string, unknown>): Promise<Record<string, unknown>> {
    const content = String(input.content ?? '');

    logger.warn('ai', 'mockDistiller', 'runTask', '[Mock Fallback] 当前为 Mock 模式', {
      operation,
      contentLength: content.length,
    });

    await delay(MOCK_DELAY_MS);

    let output: Record<string, unknown>;

    switch (operation) {
      case 'rename':
        output = {
          suggestedTitle: '[Mock] ' + mockTitle(content),
        };
        break;

      case 'summarize':
        output = {
          suggestedTitle: '[Mock] ' + mockTitle(content),
          summary: '[Mock] ' + mockSummary(content),
          category: '参考',
          tags: ['mock', '待整理'],
          documentType: 'note',
          contentMarkdown: mockContentMarkdown(content, mockTitle(content)),
          valueScore: 5,
          cleanSuggestion: 'keep',
        };
        break;

      case 'classify':
        output = {
          category: '参考',
        };
        break;

      case 'tag':
        output = {
          tags: ['mock', '测试', '待整理'],
        };
        break;

      case 'valueScore':
        output = {
          valueScore: 5,
        };
        break;

      case 'cleanSuggest':
        output = {
          cleanSuggestion: 'keep',
        };
        break;

      default:
        throw new Error(`Mock distiller does not support operation: ${operation}`);
    }

    logger.info('ai', 'mockDistiller', 'result', `[Mock Fallback] Mock result for ${operation}`, output);

    return output;
  },
};
