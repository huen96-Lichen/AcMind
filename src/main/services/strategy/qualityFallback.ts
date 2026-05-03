// PinMind Quality Fallback & Regeneration
// Phase 8.5: 低质量结果兜底与重新生成机制
//
// 职责：
// 1. 识别低质量结果
// 2. 严重问题自动 fallback
// 3. 记录质量标记到处理历史
// 4. 支持用户手动重新生成
// 5. 重新生成可选择更高等级模型或不同 Prompt Profile
// 6. 重新生成保留 original_id
// 7. 不默认覆盖旧 Obsidian 文件

import type { SourceType } from '../../../shared/types';
import { logger } from '../../logger';
import type { ProcessedContent, StrategyInput } from './types';
import type { QualityFlag } from './outputValidator';

// ---------------------------------------------------------------------------
// 质量等级
// ---------------------------------------------------------------------------

export type QualityLevel = 'good' | 'acceptable' | 'poor' | 'critical';

/** 质量评估结果 */
export interface QualityAssessment {
  /** 质量等级 */
  level: QualityLevel;
  /** 质量分数 (0-100) */
  score: number;
  /** 检测到的问题 */
  issues: QualityIssue[];
  /** 是否建议重新生成 */
  shouldRegenerate: boolean;
  /** 重新生成建议 */
  regenerationSuggestion?: RegenerationSuggestion;
}

/** 质量问题 */
export interface QualityIssue {
  /** 问题标记 */
  flag: QualityFlag;
  /** 严重程度 */
  severity: 'critical' | 'major' | 'minor';
  /** 问题描述 */
  message: string;
}

/** 重新生成建议 */
export interface RegenerationSuggestion {
  /** 建议的模型层级 */
  suggestedTier?: 'local_light' | 'cloud_standard' | 'cloud_advanced';
  /** 建议的 Prompt Profile ID */
  suggestedProfileId?: string;
  /** 建议原因 */
  reason: string;
}

/** 重新生成记录 */
export interface RegenerationRecord {
  /** 记录 ID */
  id: string;
  /** 原始内容 ID */
  original_id: string;
  /** source_type */
  source_type: SourceType;
  /** 重新生成前的质量评估 */
  beforeAssessment: QualityAssessment;
  /** 使用的模型信息 */
  modelInfo: {
    tier: string;
    provider: string;
    model_name: string;
  };
  /** 使用的 Prompt Profile */
  promptProfileId: string;
  promptProfileVersion: string;
  /** 重新生成时间 */
  created_at: number;
  /** 状态 */
  status: 'pending' | 'completed' | 'failed';
}

// ---------------------------------------------------------------------------
// 质量评分规则
// ---------------------------------------------------------------------------

/** flag → 扣分映射 */
const FLAG_PENALTIES: Record<QualityFlag, { score: number; severity: QualityIssue['severity'] }> = {
  title_missing: { score: 30, severity: 'critical' },
  title_too_long: { score: 5, severity: 'minor' },
  summary_missing: { score: 20, severity: 'major' },
  summary_too_short: { score: 10, severity: 'minor' },
  tags_invalid: { score: 10, severity: 'major' },
  tags_too_many: { score: 3, severity: 'minor' },
  body_empty: { score: 40, severity: 'critical' },
  markdown_invalid: { score: 15, severity: 'major' },
  source_url_missing: { score: 15, severity: 'major' },
  unsupported_inference: { score: 20, severity: 'major' },
  placeholder_generated: { score: 15, severity: 'major' },
  fallback_used: { score: 10, severity: 'minor' },
  model_unavailable: { score: 35, severity: 'critical' },
  needs_review: { score: 5, severity: 'minor' },
  needs_ocr: { score: 0, severity: 'minor' },
  needs_transcription: { score: 0, severity: 'minor' },
  incomplete: { score: 10, severity: 'minor' },
  low_quality: { score: 15, severity: 'major' },
};

// ---------------------------------------------------------------------------
// QualityFallback
// ---------------------------------------------------------------------------

class QualityFallback {
  /**
   * 评估 ProcessedContent 的质量。
   */
  assess(content: ProcessedContent, input: StrategyInput): QualityAssessment {
    const issues: QualityIssue[] = [];
    let totalPenalty = 0;

    // 从 quality_flags 中评估
    for (const flag of content.quality_flags) {
      const penalty = FLAG_PENALTIES[flag as QualityFlag];
      if (penalty) {
        issues.push({
          flag: flag as QualityFlag,
          severity: penalty.severity,
          message: this.describeFlag(flag as QualityFlag),
        });
        totalPenalty += penalty.score;
      }
    }

    // 额外的内容质量检查
    const extraIssues = this.checkContentQuality(content, input);
    for (const issue of extraIssues) {
      issues.push(issue);
      const penalty = FLAG_PENALTIES[issue.flag];
      if (penalty) totalPenalty += penalty.score;
    }

    const score = Math.max(0, 100 - totalPenalty);
    const level = this.scoreToLevel(score);

    const assessment: QualityAssessment = {
      level,
      score,
      issues,
      shouldRegenerate: level === 'poor' || level === 'critical',
    };

    // 生成重新生成建议
    if (assessment.shouldRegenerate) {
      assessment.regenerationSuggestion = this.buildRegenerationSuggestion(
        issues, input, content,
      );
    }

    return assessment;
  }

  /**
   * 生成兜底的 ProcessedContent。
   * 当 AI 处理完全失败时使用。
   */
  generateFallback(input: StrategyInput): ProcessedContent {
    const fileName = input.raw_file_path?.split('/').pop() || '';

    return {
      title: this.generateFallbackTitle(input, fileName),
      summary: '等待后续处理',
      tags: this.generateFallbackTags(input),
      body_markdown: this.generateFallbackBody(input, fileName),
      suggested_folder: this.getSuggestedFolder(input.source_type),
      quality_flags: ['fallback_used', 'placeholder_generated'],
    };
  }

  /**
   * 判断是否需要自动 fallback（不尝试 AI 处理）。
   */
  shouldAutoFallback(input: StrategyInput): boolean {
    // unknown_file 始终自动 fallback
    if (input.source_type === 'unknown_file') return true;

    // 无任何可处理内容
    const hasContent = [
      input.content, input.extracted_text,
      input.transcript_text, input.parsed_markdown,
    ].some(s => s && s.trim().length > 0);

    return !hasContent;
  }

  // ---------------------------------------------------------------------------
  // 内容质量检查
  // ---------------------------------------------------------------------------

  private checkContentQuality(
    content: ProcessedContent,
    input: StrategyInput,
  ): QualityIssue[] {
    const issues: QualityIssue[] = [];

    // 检查 body_markdown 是否只是重复了输入内容
    if (input.content && content.body_markdown === input.content) {
      // 对于 manual_text 这可能是正常的，但对于其他类型可能表示 AI 没有处理
      if (input.source_type !== 'manual_text' && input.source_type !== 'clipboard_text') {
        issues.push({
          flag: 'low_quality',
          severity: 'major',
          message: 'body_markdown 与输入内容完全相同，AI 可能未进行处理',
        });
      }
    }

    // 检查 tags 是否为空
    if (content.tags.length === 0) {
      issues.push({
        flag: 'tags_invalid',
        severity: 'minor',
        message: 'tags 为空数组',
      });
    }

    return issues;
  }

  // ---------------------------------------------------------------------------
  // 重新生成建议
  // ---------------------------------------------------------------------------

  private buildRegenerationSuggestion(
    issues: QualityIssue[],
    input: StrategyInput,
    content: ProcessedContent,
  ): RegenerationSuggestion {
    const hasCritical = issues.some(i => i.severity === 'critical');
    const hasModelIssue = content.quality_flags.includes('model_unavailable');

    if (hasModelIssue) {
      return {
        suggestedTier: 'cloud_standard',
        reason: '模型不可用，建议切换到云端标准模型重新生成',
      };
    }

    if (hasCritical) {
      return {
        suggestedTier: 'cloud_advanced',
        reason: '存在严重质量问题，建议使用高级模型重新生成',
      };
    }

    // 检查是否是 Prompt 问题
    const hasUnsupportedInference = content.quality_flags.includes('unsupported_inference');
    if (hasUnsupportedInference) {
      return {
        reason: 'AI 编造了未提供的信息，建议使用更严格的 Prompt Profile 重新生成',
      };
    }

    return {
      suggestedTier: 'cloud_standard',
      reason: '质量不达标，建议使用标准云端模型重新生成',
    };
  }

  // ---------------------------------------------------------------------------
  // Fallback 内容生成
  // ---------------------------------------------------------------------------

  private generateFallbackTitle(input: StrategyInput, fileName: string): string {
    const typeNames: Record<string, string> = {
      manual_text: '手动笔记',
      clipboard_text: '剪贴板摘录',
      screenshot: '截图记录',
      webpage: '网页资料',
      file: '文件记录',
      image: '图片记录',
      audio: '音频记录',
      video: '视频记录',
      pdf: 'PDF 文档',
      docx: 'Word 文档',
      unknown_file: '未知文件',
    };

    const typeName = typeNames[input.source_type] || '笔记';
    const date = new Date().toISOString().split('T')[0];

    if (fileName) return `${typeName} - ${fileName} - ${date}`;
    return `${typeName} - ${date}`;
  }

  private generateFallbackTags(input: StrategyInput): string[] {
    const typeTags: Record<string, string[]> = {
      manual_text: ['笔记'],
      clipboard_text: ['摘录'],
      screenshot: ['截图', '待OCR'],
      webpage: ['网页'],
      file: ['文件', '待处理'],
      image: ['图片', '待OCR'],
      audio: ['音频', '待转写'],
      video: ['视频', '待转写'],
      pdf: ['PDF', '待解析'],
      docx: ['文档', '待解析'],
      unknown_file: ['未知文件', '待处理'],
    };
    return typeTags[input.source_type] || ['笔记'];
  }

  private generateFallbackBody(input: StrategyInput, fileName: string): string {
    const lines: string[] = [];
    const date = new Date().toISOString().split('T')[0];

    lines.push(`> ⚠️ 此为占位记录，等待后续处理`);
    lines.push('');

    if (input.raw_file_path) {
      lines.push(`**文件路径**：${input.raw_file_path}`);
    }
    if (input.source_url) {
      lines.push(`**来源链接**：[${input.source_url}](${input.source_url})`);
    }

    lines.push(`**收集时间**：${date}`);
    lines.push(`**来源类型**：${input.source_type}`);
    lines.push('');
    lines.push('> 此记录由系统自动生成，内容待补充。');

    return lines.join('\n');
  }

  private getSuggestedFolder(sourceType: SourceType): string {
    const folderMap: Record<string, string> = {
      manual_text: 'Inbox',
      clipboard_text: 'Inbox/Clippings',
      screenshot: 'Inbox/Screenshots',
      webpage: 'Inbox/Web',
      file: 'Inbox/Files',
      image: 'Inbox/Images',
      audio: 'Inbox/Audio',
      video: 'Inbox/Video',
      pdf: 'Inbox/PDF',
      docx: 'Inbox/Docs',
      unknown_file: 'Inbox/Unknown',
    };
    return folderMap[sourceType] || 'Inbox';
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  private scoreToLevel(score: number): QualityLevel {
    if (score >= 80) return 'good';
    if (score >= 60) return 'acceptable';
    if (score >= 30) return 'poor';
    return 'critical';
  }

  private describeFlag(flag: QualityFlag): string {
    const descriptions: Record<QualityFlag, string> = {
      title_missing: '标题缺失',
      title_too_long: '标题过长',
      summary_missing: '摘要缺失',
      summary_too_short: '摘要过短',
      tags_invalid: '标签无效',
      tags_too_many: '标签过多',
      body_empty: '正文为空',
      markdown_invalid: 'Markdown 格式无效',
      source_url_missing: '来源 URL 缺失',
      unsupported_inference: 'AI 编造了未提供的信息',
      placeholder_generated: '生成了占位内容',
      fallback_used: '使用了 fallback 处理',
      model_unavailable: '模型不可用',
      needs_review: '需要人工审核',
      needs_ocr: '需要 OCR 识别',
      needs_transcription: '需要音频转写',
      incomplete: '内容不完整',
      low_quality: '内容质量较低',
    };
    return descriptions[flag] || flag;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const qualityFallback = new QualityFallback();
