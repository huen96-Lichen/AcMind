// PinMind Manual Text Strategy
// Phase 8.1: 用户主动输入的想法、笔记、计划

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { StrategyInput } from '../types';

export class ManualTextStrategy extends BaseStrategy {
  readonly name = 'manual_text';
  readonly sourceType: SourceType = 'manual_text';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'manual_text' && input.content.trim().length > 0;
  }

  buildPrompt(input: StrategyInput): string {
    return `你是一个笔记整理助手。用户主动输入了一段想法、笔记或计划。

## 任务

1. 保留用户原意，不要过度改写
2. 精简表达，去除冗余
3. 提取核心主题
4. 生成适合 Obsidian 的笔记结构

## 用户输入

${input.content}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题简洁明了，反映核心主题
- 摘要一句话概括
- 正文保留用户原意，适当分段
- 如果包含待办事项，使用 Obsidian 任务格式 \`- [ ]\`
- 如果包含时间相关内容，添加 \`📅\` 标记

${this.buildOutputFormat()}`;
  }
}
