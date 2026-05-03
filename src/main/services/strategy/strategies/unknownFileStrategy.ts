// PinMind Unknown File Strategy
// Phase 8.1: 未知文件类型的兜底策略

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { ProcessedContent, StrategyInput } from '../types';

export class UnknownFileStrategy extends BaseStrategy {
  readonly name = 'unknown_file';
  readonly sourceType: SourceType = 'unknown_file';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'unknown_file';
  }

  buildPrompt(_input: StrategyInput): string {
    // 未知文件类型不调用 AI，直接在 postProcess 中生成占位记录
    return '';
  }

  /**
   * 覆写：未知文件类型直接生成占位记录，不调用 AI
   */
  postProcess(_raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const fileName = input.raw_file_path?.split('/').pop() || '未知文件';
    const ext = input.file_ext || '未知';

    return {
      title: `未知文件 - ${fileName}`,
      summary: `文件已导入（${ext}），类型未知，等待后续处理`,
      tags: ['文件', '未知类型', '待处理'],
      body_markdown: [
        '---',
        `title: "未知文件 - ${fileName}"`,
        `date: "${new Date().toISOString().split('T')[0]}"`,
        'tags:',
        '  - 文件',
        '  - 未知类型',
        '  - 待处理',
        'source_type: "unknown_file"',
        '---',
        '',
        '> ❓ 未知类型文件已导入，等待后续处理',
        '',
        `**文件路径**：${input.raw_file_path || '未知'}`,
        `**文件类型**：${ext}`,
        '',
        '> ⚠️ 此为占位记录，文件类型确认后将自动更新',
      ].join('\n'),
      suggested_folder: 'Inbox/Unknown',
      quality_flags: ['placeholder', 'incomplete'],
    };
  }
}
