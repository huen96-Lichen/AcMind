// AcMind Clipboard Text Strategy
// Phase 8.1: 复制来的文本片段

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { StrategyInput } from '../types';

export class ClipboardTextStrategy extends BaseStrategy {
  readonly name = 'clipboard_text';
  readonly sourceType: SourceType = 'clipboard_text';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'clipboard_text' && input.content.trim().length > 0;
  }

  buildPrompt(input: StrategyInput): string {
    return `你是一个笔记整理助手。用户从剪贴板粘贴了一段文本。

## 任务

1. 判断文本是否为摘录（引用他人内容）还是用户自己的笔记
2. 如果是摘录，保留原文并标注来源
3. 生成摘要和关键信息提取
4. 避免过度改写原文

## 原始文本

${input.content}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题反映文本核心主题
- 摘要一句话概括
- 如果是摘录，正文开头标注：> 📋 以下为摘录内容
- 提取关键观点，使用列表形式
- 不要编造原文没有的信息

${this.buildOutputFormat()}`;
  }
}
