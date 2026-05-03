// PinMind File Strategy
// Phase 8.1: 本地文件导入

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { ProcessedContent, StrategyInput } from '../types';

/** 可直接整理正文的文本文件扩展名 */
const TEXT_FILE_EXTS = new Set(['.txt', '.md', '.markdown', '.text']);

export class FileStrategy extends BaseStrategy {
  readonly name = 'file';
  readonly sourceType: SourceType = 'file';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'file';
  }

  buildPrompt(input: StrategyInput): string {
    const ext = input.file_ext || '未知';
    const isTextFile = TEXT_FILE_EXTS.has(ext.toLowerCase());

    if (isTextFile && input.content.trim().length > 0) {
      return `你是一个笔记整理助手。用户导入了一个文本文件（${ext}）。

## 任务

1. 直接整理文件正文内容
2. 保留原始文件路径
3. 生成适合 Obsidian 的笔记结构

## 文件信息

- 文件路径：${input.raw_file_path || '未知'}
- 文件类型：${ext}

## 文件内容

${input.content}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题反映文件核心主题
- 摘要一句话概括
- 正文整理文件内容
- 保留原始信息，不要编造

${this.buildOutputFormat()}`;
    }

    return `你是一个笔记整理助手。用户导入了一个文件，但无法直接解析其内容。

## 任务

1. 生成占位记录
2. 保留原始文件路径
3. 标记后续处理建议

## 文件信息

- 文件路径：${input.raw_file_path || '未知'}
- 文件类型：${ext}
- 文件内容：${input.content || '（无法解析）'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题：文件记录 - {文件名}
- 摘要：文件已导入，等待后续处理
- 正文包含文件路径和类型信息
- 明确标注需要后续处理

${this.buildOutputFormat()}`;
  }

  /**
   * 覆写后处理：处理不可解析文件的情况
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const ext = input.file_ext || '';
    const isTextFile = TEXT_FILE_EXTS.has(ext.toLowerCase());
    const hasContent = input.content && input.content.trim().length > 0;

    if (!isTextFile || !hasContent) {
      // 不可解析文件生成占位记录
      const fileName = input.raw_file_path?.split('/').pop() || '未知文件';
      return {
        title: `文件记录 - ${fileName}`,
        summary: `文件已导入（${ext || '未知类型'}），等待后续处理`,
        tags: ['文件', '待处理'],
        body_markdown: [
          '---',
          `title: "文件记录 - ${fileName}"`,
          `date: "${new Date().toISOString().split('T')[0]}"`,
          'tags:',
          '  - 文件',
          '  - 待处理',
          'source_type: "file"',
          '---',
          '',
          `> 📄 文件已导入，等待后续处理`,
          '',
          `**文件路径**：${input.raw_file_path || '未知'}`,
          `**文件类型**：${ext || '未知'}`,
          '',
          '> ⚠️ 此为占位记录，内容解析后将自动更新',
          '',
          '## 后续处理建议',
          '',
          `- 如果是文本文件，请使用文件导入功能重新处理`,
          `- 如果是二进制文件，可能需要专用工具解析`,
        ].join('\n'),
        suggested_folder: 'Inbox/Files',
        quality_flags: ['placeholder', 'incomplete'],
      };
    }

    // 可解析文件正常处理
    return super.postProcess(raw, input);
  }
}
