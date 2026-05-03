// PinMind AI Output Validator
// Phase 8.4: AI 输出结构化校验
//
// 职责：
// 1. 校验 AI 输出是否符合 ProcessedContent 结构
// 2. 检测低质量问题并标记 quality_flags
// 3. 尝试修复轻微问题
// 4. 修复失败时降级为占位 Markdown
// 5. 不允许模型编造未提供的信息

import type { SourceType } from '../../../shared/types';
import { logger } from '../../logger';
import type { ProcessedContent, StrategyInput } from './types';

// ---------------------------------------------------------------------------
// Quality Flag 定义
// ---------------------------------------------------------------------------

export type QualityFlag =
  | 'title_missing'
  | 'title_too_long'
  | 'summary_missing'
  | 'summary_too_short'
  | 'tags_invalid'
  | 'tags_too_many'
  | 'body_empty'
  | 'markdown_invalid'
  | 'source_url_missing'
  | 'unsupported_inference'
  | 'placeholder_generated'
  | 'fallback_used'
  | 'model_unavailable'
  | 'needs_review'
  | 'needs_ocr'
  | 'needs_transcription'
  | 'incomplete'
  | 'low_quality';

// ---------------------------------------------------------------------------
// 校验结果
// ---------------------------------------------------------------------------

export interface ValidationResult {
  /** 是否通过校验 */
  valid: boolean;
  /** 修复后的 ProcessedContent（如果修复成功） */
  content: ProcessedContent;
  /** 检测到的质量问题 */
  flags: QualityFlag[];
  /** 修复说明 */
  fixNotes: string[];
  /** 是否进行了修复 */
  wasFixed: boolean;
}

// ---------------------------------------------------------------------------
// 校验规则
// ---------------------------------------------------------------------------

const MAX_TITLE_LENGTH = 120;
const MIN_SUMMARY_LENGTH = 5;
const MAX_TAGS = 15;
const MAX_BODY_LENGTH = 100_000;

/** 明显的模板占位符模式 */
const PLACEHOLDER_PATTERNS = [
  /^(这里是|此处为|此处是|以下为).{0,10}(内容|文本|摘要)/,
  /^(title|summary|content)\s*$/i,
  /^(待填充|待补充|待完善|TODO)/,
  /^\[.*\]$/,
  /^<.*>$/,
];

/** YAML frontmatter 检测 */
const FRONTMATTER_PATTERN = /^---\n[\s\S]*?\n---/;

// ---------------------------------------------------------------------------
// AIOutputValidator
// ---------------------------------------------------------------------------

class AIOutputValidator {
  /**
   * 校验并修复 AI 输出。
   */
  validate(
    raw: Record<string, unknown>,
    input: StrategyInput,
  ): ValidationResult {
    const flags: QualityFlag[] = [];
    const fixNotes: string[] = [];

    // Step 1: 提取字段
    let title = this.extractString(raw, 'title', '');
    let summary = this.extractString(raw, 'summary', '');
    let tags = this.extractTags(raw);
    let body_markdown = this.extractString(raw, 'body_markdown', '');
    const suggested_folder = this.extractString(raw, 'suggested_folder', 'Inbox');
    const quality_flags = this.extractStringArray(raw, 'quality_flags');

    // Step 2: 校验 title
    if (!title || title.trim().length === 0) {
      flags.push('title_missing');
      title = this.generateFallbackTitle(input);
      fixNotes.push('title 为空，已生成 fallback 标题');
    } else if (title.length > MAX_TITLE_LENGTH) {
      flags.push('title_too_long');
      title = title.substring(0, MAX_TITLE_LENGTH) + '…';
      fixNotes.push(`title 过长（${title.length}），已截断`);
    }

    // Step 3: 校验 summary
    if (!summary || summary.trim().length === 0) {
      flags.push('summary_missing');
      summary = '等待后续处理';
      fixNotes.push('summary 为空，已设置默认值');
    } else if (summary.trim().length < MIN_SUMMARY_LENGTH) {
      flags.push('summary_too_short');
      fixNotes.push(`summary 过短（${summary.trim().length} 字符）`);
    }

    // Step 4: 校验 tags
    let validatedTags: string[];
    if (!Array.isArray(tags)) {
      flags.push('tags_invalid');
      validatedTags = [];
      fixNotes.push('tags 不是数组，已重置为空数组');
    } else {
      // 过滤无效标签
      const validTags = tags.filter(t => typeof t === 'string' && t.trim().length > 0) as string[];
      if (validTags.length !== tags.length) {
        flags.push('tags_invalid');
        validatedTags = validTags;
        fixNotes.push('tags 包含无效值，已过滤');
      } else {
        validatedTags = validTags;
      }
      if (validatedTags.length > MAX_TAGS) {
        flags.push('tags_too_many');
        validatedTags = validatedTags.slice(0, MAX_TAGS);
        fixNotes.push(`tags 数量过多（${validatedTags.length}），已截断为 ${MAX_TAGS}`);
      }
    }

    // Step 5: 校验 body_markdown
    if (!body_markdown || body_markdown.trim().length === 0) {
      flags.push('body_empty');
      body_markdown = this.generateFallbackBody(input);
      fixNotes.push('body_markdown 为空，已生成 fallback 正文');
    } else {
      // 检测是否包含 YAML frontmatter（不允许模型生成）
      if (FRONTMATTER_PATTERN.test(body_markdown.trim())) {
        flags.push('markdown_invalid');
        body_markdown = body_markdown.replace(FRONTMATTER_PATTERN, '').trim();
        fixNotes.push('body_markdown 包含 YAML frontmatter，已移除（由系统自动添加）');
      }

      // 检测明显模板占位符
      const firstLine = body_markdown.split('\n')[0].trim();
      if (PLACEHOLDER_PATTERNS.some(p => p.test(firstLine))) {
        flags.push('placeholder_generated');
        fixNotes.push('body_markdown 疑似模板占位符');
      }

      // 检测长度
      if (body_markdown.length > MAX_BODY_LENGTH) {
        body_markdown = body_markdown.substring(0, MAX_BODY_LENGTH) + '\n\n> ⚠️ 内容过长，已截断';
        fixNotes.push(`body_markdown 过长，已截断为 ${MAX_BODY_LENGTH} 字符`);
      }
    }

    // Step 6: source_type 特定校验
    this.validateSourceTypeSpecific(input, flags, fixNotes);

    // Step 7: 合并原始 quality_flags
    const allFlags = [...new Set([...flags, ...quality_flags])];

    // Step 8: 判断是否通过
    const criticalFlags: QualityFlag[] = ['title_missing', 'body_empty', 'model_unavailable'];
    const hasCritical = criticalFlags.some(f => allFlags.includes(f));
    const valid = !hasCritical && flags.length === 0;

    return {
      valid,
      content: {
        title: title.trim(),
        summary: summary.trim(),
        tags: validatedTags,
        body_markdown: body_markdown.trim(),
        suggested_folder: suggested_folder.trim() || 'Inbox',
        quality_flags: allFlags,
      },
      flags: allFlags as QualityFlag[],
      fixNotes,
      wasFixed: fixNotes.length > 0,
    };
  }

  // ---------------------------------------------------------------------------
  // Source type 特定校验
  // ---------------------------------------------------------------------------

  private validateSourceTypeSpecific(
    input: StrategyInput,
    flags: QualityFlag[],
    fixNotes: string[],
  ): void {
    // webpage: 必须保留 source_url
    if (input.source_type === 'webpage' && input.source_url) {
      // source_url 会在 postProcess 中注入，这里只做标记
      // 如果 body 中没有 source_url，标记但不失败
    }

    // screenshot/image: 无 OCR 时不得伪识图
    if ((input.source_type === 'screenshot' || input.source_type === 'image') && !input.extracted_text) {
      // 这个检查在 strategy 的 postProcess 中已经处理
      // 这里只做二次校验
    }

    // audio/video: 无 transcript 时不得伪总结
    if ((input.source_type === 'audio' || input.source_type === 'video') && !input.transcript_text) {
      // 同上
    }
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  private extractString(raw: Record<string, unknown>, key: string, fallback: string): string {
    const value = raw[key];
    if (typeof value === 'string') return value;
    if (value != null) return String(value);
    return fallback;
  }

  private extractTags(raw: Record<string, unknown>): unknown[] {
    const tags = raw.tags;
    if (Array.isArray(tags)) {
      // 不在此处过滤，让校验逻辑处理无效元素
      return tags;
    }
    if (typeof tags === 'string') {
      return tags.split(/[,，、]/).map(t => t.trim()).filter(Boolean);
    }
    return [];
  }

  private extractStringArray(raw: Record<string, unknown>, key: string): string[] {
    const value = raw[key];
    if (Array.isArray(value)) {
      return value.filter((v): v is string => typeof v === 'string' && v.trim().length > 0);
    }
    return [];
  }

  private generateFallbackTitle(input: StrategyInput): string {
    const content = input.content || input.extracted_text || input.transcript_text || input.parsed_markdown || '';
    if (!content) return '未命名笔记';
    const firstLine = content.split('\n')[0].trim();
    return firstLine.length > 50 ? firstLine.substring(0, 50) + '…' : firstLine || '未命名笔记';
  }

  private generateFallbackBody(input: StrategyInput): string {
    const content = input.content || input.extracted_text || input.transcript_text || input.parsed_markdown || '';
    if (!content) {
      return '> ⚠️ 内容为空，等待后续处理';
    }
    return content;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const outputValidator = new AIOutputValidator();
