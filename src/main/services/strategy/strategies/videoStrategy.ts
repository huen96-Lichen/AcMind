// AcMind Video Strategy
// Phase 8.1: 视频占位或转写结果

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { ProcessedContent, StrategyInput } from '../types';

export class VideoStrategy extends BaseStrategy {
  readonly name = 'video';
  readonly sourceType: SourceType = 'video';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'video';
  }

  buildPrompt(input: StrategyInput): string {
    const hasTranscript = input.transcript_text && input.transcript_text.trim().length > 0;

    if (hasTranscript) {
      return `你是一个笔记整理助手。用户保存了一段视频，已转写为文本。

## 任务

1. 整理转写文本
2. 保留原始文件路径
3. 生成视频笔记结构

## 转写文本

${input.transcript_text}

## 视频文件路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题反映视频内容主题
- 摘要一句话概括
- 正文开头标注：> 🎬 来源：视频转写
- 整理转写文本，适当分段
- 保留原始信息，不要编造

${this.buildOutputFormat()}`;
    }

    return `你是一个笔记整理助手。用户保存了一段视频，但尚未转写。

## 任务

1. 生成占位记录
2. 保留原始文件路径
3. 标记需要转写

## 视频文件路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题：视频记录 - {日期}
- 摘要：视频已保存，等待转写
- 正文包含文件路径
- 明确标注需要后续转写处理

${this.buildOutputFormat()}`;
  }

  /**
   * 覆写后处理：处理无转写的情况
   * Phase 9.6: 当外部处理服务返回 transcript_text 时，移除占位标记并标注转写来源
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const hasTranscript = input.transcript_text && input.transcript_text.trim().length > 0;

    if (!hasTranscript) {
      // Phase 9.6: 无转写时生成占位记录，不伪总结视频内容
      return {
        title: `视频记录 - ${new Date().toISOString().split('T')[0]}`,
        summary: '视频已保存，等待转写',
        tags: ['视频', '待转写'],
        body_markdown: [
          '---',
          `title: "视频记录"`,
          `date: "${new Date().toISOString().split('T')[0]}"`,
          'tags:',
          '  - 视频',
          '  - 待转写',
          'source_type: "video"',
          '---',
          '',
          '> 🎬 视频已保存，等待转写',
          '',
          `**视频路径**：${input.raw_file_path || '未知'}`,
          '',
          '> ⚠️ 此为占位记录，转写完成后将自动更新',
        ].join('\n'),
        suggested_folder: 'Inbox/Video',
        quality_flags: ['needs_transcription', 'placeholder'],
      };
    }

    // Phase 9.6: 有转写时正常处理，移除占位标记
    const result = super.postProcess(raw, input);
    result.quality_flags = result.quality_flags.filter(f => f !== 'needs_transcription' && f !== 'placeholder');

    // 在 body_markdown 开头标注转写来源
    if (!result.body_markdown.includes('转写')) {
      result.body_markdown = `> 🎬 来源：视频转写\n\n${result.body_markdown}`;
    }

    return result;
  }
}
