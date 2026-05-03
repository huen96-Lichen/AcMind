// AcMind DOCX Strategy
// Phase 8.1: DOCX 占位或解析后内容

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { ProcessedContent, StrategyInput } from '../types';

export class DocxStrategy extends BaseStrategy {
  readonly name = 'docx';
  readonly sourceType: SourceType = 'docx';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'docx';
  }

  buildPrompt(input: StrategyInput): string {
    const hasParsed = input.parsed_markdown && input.parsed_markdown.trim().length > 0;

    if (hasParsed) {
      return `你是一个笔记整理助手。用户保存了一个 Word 文档，已解析为 Markdown。

## 任务

1. 整理解析后的 Markdown 内容
2. 保留原始文件路径
3. 生成文档笔记结构

## 解析内容

${input.parsed_markdown}

## DOCX 文件路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题反映文档核心主题
- 摘要一句话概括
- 正文开头标注：> 📝 来源：Word 文档
- 整理解析内容，保持结构清晰
- 保留原始信息，不要编造

${this.buildOutputFormat()}`;
    }

    return `你是一个笔记整理助手。用户保存了一个 Word 文档，但尚未解析。

## 任务

1. 生成占位记录
2. 保留原始文件路径
3. 标记需要解析

## DOCX 文件路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题：Word 文档 - {文件名}
- 摘要：Word 文档已保存，等待解析
- 正文包含文件路径
- 明确标注需要后续解析处理

${this.buildOutputFormat()}`;
  }

  /**
   * 覆写后处理：处理无解析内容的情况
   * Phase 9.4: 当 VaultKeeper 返回 parsed_markdown 时，移除占位标记
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const hasParsed = input.parsed_markdown && input.parsed_markdown.trim().length > 0;

    if (!hasParsed) {
      // 无解析内容时生成占位记录，不强行解析
      const fileName = input.raw_file_path?.split('/').pop() || '未知文档';
      return {
        title: `Word 文档 - ${fileName}`,
        summary: 'Word 文档已保存，等待解析',
        tags: ['Word', '待解析'],
        body_markdown: [
          '---',
          `title: "Word 文档 - ${fileName}"`,
          `date: "${new Date().toISOString().split('T')[0]}"`,
          'tags:',
          '  - Word',
          '  - 待解析',
          'source_type: "docx"',
          '---',
          '',
          '> 📝 Word 文档已保存，等待解析',
          '',
          `**文件路径**：${input.raw_file_path || '未知'}`,
          '',
          '> ⚠️ 此为占位记录，文档解析后将自动更新',
        ].join('\n'),
        suggested_folder: 'Inbox/Docs',
        quality_flags: ['placeholder', 'incomplete'],
      };
    }

    // Phase 9.4: 有解析内容时正常处理，移除占位标记
    const result = super.postProcess(raw, input);
    result.quality_flags = result.quality_flags.filter(f => f !== 'placeholder' && f !== 'incomplete');
    return result;
  }
}
