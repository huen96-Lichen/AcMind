// PinMind Audio Strategy
// Phase 10: 语音笔记蒸馏策略
// 使用 transcript_text 作为输入，通过 voice_note_zh_v1 Prompt Profile 生成语音笔记
//
// 核心约束：
// 1. 没有 transcript_text 不得进入 AI 整理
// 2. audio 不复用 manual_text prompt
// 3. 输入必须是 transcript_text
// 4. 输出必须符合 Phase 8 统一结构

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { ProcessedContent, StrategyInput } from '../types';

export class AudioStrategy extends BaseStrategy {
  readonly name = 'audio';
  readonly sourceType: SourceType = 'audio';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'audio';
  }

  buildPrompt(input: StrategyInput): string {
    const hasTranscript = input.transcript_text && input.transcript_text.trim().length > 0;

    if (hasTranscript) {
      // Phase 10: 语音专用 Prompt - 使用 voice_note_distillation 策略
      return `你是 PinMind 的语音笔记整理助手。
你的任务是把用户的语音转写文本整理成清晰、克制、可长期保存的中文 Markdown 笔记。

## 你必须遵守的规则

1. 保留原意，不擅自扩写事实。
2. 去除口癖、重复、无意义停顿。
3. 修复明显口语化断句。
4. 将跳跃想法整理成清晰层级。
5. 提取明确待办。
6. 不要把模糊想法强行改成任务。
7. 对不确定、转写可疑、上下文缺失的内容标记 quality_flags。
8. 输出必须符合指定 JSON schema。
9. 不要输出解释。
10. 不要输出 schema 之外的字段。

## 转写文本

${input.transcript_text}

## 音频文件路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题：不超过 24 个中文字符，反映语音内容核心主题
- 摘要：2-4 句话概括语音内容
- 正文结构：
  - ## 核心想法
  - ## 详细整理
  - ## 待办（如有明确待办）
  - ## 可能关联的项目 / 主题（如有）
  - ## 不确定内容（如有转写可疑或上下文缺失）
- 标签：3-7 个中文标签

${this.buildOutputFormat()}`;
    }

    // Phase 10: 无转写时生成占位记录，绝不伪造 transcript
    return `你是 PinMind 的笔记助手。用户保存了一段音频，但尚未完成转写。

## 任务

1. 生成占位记录
2. 保留原始文件路径
3. 标记需要转写

## 音频文件路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题：音频记录 - {日期}
- 摘要：音频已保存，等待转写
- 正文包含文件路径
- 明确标注需要后续转写处理

${this.buildOutputFormat()}`;
  }

  /**
   * 覆写预处理：校验 transcript_text
   * Phase 10: 没有 transcript_text 不得进入 AI 整理
   */
  preprocess(input: StrategyInput): StrategyInput {
    const hasTranscript = input.transcript_text && input.transcript_text.trim().length > 0;

    if (!hasTranscript) {
      // 无转写文本时，不进入 AI 整理，直接返回占位结果
      // 通过 metadata 标记，让 postProcess 生成占位记录
      return {
        ...input,
        metadata: {
          ...input.metadata,
          skip_ai_processing: true,
        },
      };
    }

    // 检查 transcript_text 是否过短
    if (input.transcript_text && input.transcript_text.trim().length < 20) {
      return {
        ...input,
        metadata: {
          ...input.metadata,
          low_content: true,
        },
      };
    }

    return input;
  }

  /**
   * 覆写后处理：处理无转写的情况和质量标记
   * Phase 10: 语音笔记专用后处理
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const hasTranscript = input.transcript_text && input.transcript_text.trim().length > 0;
    const metadata = input.metadata as Record<string, unknown> | undefined;

    // 无转写时生成占位记录
    if (!hasTranscript || metadata?.skip_ai_processing) {
      return {
        title: `音频记录 - ${new Date().toISOString().split('T')[0]}`,
        summary: '音频已保存，等待转写',
        tags: ['音频', '待转写'],
        body_markdown: [
          '---',
          `title: "音频记录"`,
          `date: "${new Date().toISOString().split('T')[0]}"`,
          'tags:',
          '  - 音频',
          '  - 待转写',
          'source_type: "audio"',
          '---',
          '',
          '> 🎤 音频已保存，等待转写',
          '',
          `**音频路径**：${input.raw_file_path || '未知'}`,
          '',
          '> ⚠️ 此为占位记录，转写完成后将自动更新',
        ].join('\n'),
        suggested_folder: 'Inbox/Audio',
        quality_flags: ['needs_transcription', 'placeholder'],
      };
    }

    // 有转写时正常处理
    const result = super.postProcess(raw, input);

    // 移除占位标记
    result.quality_flags = result.quality_flags.filter(
      (f) => f !== 'needs_transcription' && f !== 'placeholder',
    );

    // 添加语音相关质量标记
    if (metadata?.low_content) {
      result.quality_flags.push('low_content');
    }

    // 在 body_markdown 开头标注转写来源
    if (!result.body_markdown.includes('转写')) {
      result.body_markdown = `> 🎤 来源：语音转写\n\n${result.body_markdown}`;
    }

    // 确保 suggested_folder 为语音笔记目录
    if (!result.suggested_folder || result.suggested_folder === 'Inbox') {
      result.suggested_folder = 'Voice Notes';
    }

    return result;
  }
}
