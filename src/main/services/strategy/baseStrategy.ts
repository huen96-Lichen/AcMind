// AcMind Base Content Processing Strategy
// Phase 8.1: 所有策略的公共基类，提供默认实现和工具方法

import type { SourceType } from '../../../shared/types';
import type {
  ContentProcessingStrategy,
  ProcessedContent,
  StrategyInput,
} from './types';

// ---------------------------------------------------------------------------
// BaseStrategy
// ---------------------------------------------------------------------------

export abstract class BaseStrategy implements ContentProcessingStrategy {
  abstract readonly name: string;
  abstract readonly sourceType: SourceType;

  canHandle(input: StrategyInput): boolean {
    return input.source_type === this.sourceType;
  }

  abstract buildPrompt(input: StrategyInput): string;

  /**
   * 默认后处理：从 AI 原始输出中提取字段，填充默认值。
   * 子类可覆写此方法以注入策略特有的逻辑。
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const title = this.extractString(raw, 'title', this.generateFallbackTitle(input));
    const summary = this.extractString(raw, 'summary', '等待后续处理');
    const tags = this.extractTags(raw);
    const body_markdown = this.extractString(raw, 'body_markdown', input.content || '等待后续处理');
    const suggested_folder = this.extractString(raw, 'suggested_folder', 'Inbox');
    const quality_flags = this.extractQualityFlags(raw);

    return {
      title,
      summary,
      tags,
      body_markdown,
      suggested_folder,
      quality_flags,
    };
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  protected extractString(
    raw: Record<string, unknown>,
    key: string,
    fallback: string,
  ): string {
    const value = raw[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
    return fallback;
  }

  protected extractTags(raw: Record<string, unknown>): string[] {
    const tags = raw.tags;
    if (Array.isArray(tags)) {
      return tags.filter((t): t is string => typeof t === 'string' && t.trim().length > 0);
    }
    return [];
  }

  protected extractQualityFlags(raw: Record<string, unknown>): string[] {
    const flags = raw.quality_flags;
    if (Array.isArray(flags)) {
      return flags.filter((f): f is string => typeof f === 'string' && f.trim().length > 0);
    }
    return [];
  }

  protected generateFallbackTitle(input: StrategyInput): string {
    const content = input.content || input.extracted_text || input.transcript_text || input.parsed_markdown || '';
    if (!content) return '未命名笔记';
    const firstLine = content.split('\n')[0].trim();
    return firstLine.length > 50 ? firstLine.substring(0, 50) + '…' : firstLine || '未命名笔记';
  }

  /**
   * 构建通用的 Obsidian frontmatter 提示。
   * Phase 8.2: frontmatter 由 MarkdownRenderer 统一生成，不在 AI 输出中。
   */
  protected buildFrontmatterHint(): string {
    return `## 注意

不要在 body_markdown 中生成 YAML frontmatter。
frontmatter 由系统自动处理，你只需要输出纯 Markdown 正文内容。`;
  }

  /**
   * 构建通用的输出格式说明。
   */
  protected buildOutputFormat(): string {
    return `## 输出格式

严格输出 JSON，不要添加任何其他文本：

\`\`\`json
{
  "title": "笔记标题",
  "summary": "一句话摘要",
  "tags": ["标签1", "标签2"],
  "body_markdown": "Obsidian 兼容的 Markdown 正文（不含 frontmatter，frontmatter 由系统生成）",
  "suggested_folder": "Inbox/子文件夹",
  "quality_flags": ["可选的质量标记"]
}
\`\`\`

quality_flags 可选值：
- "needs_review" - 需要人工审核
- "incomplete" - 内容不完整
- "low_quality" - 内容质量较低
- "needs_transcription" - 需要转写
- "needs_ocr" - 需要 OCR
- "placeholder" - 占位记录，等待后续处理`;
  }
}
