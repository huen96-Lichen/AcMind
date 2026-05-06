// AcMind Webpage Strategy
// Phase 8.1: 网页链接和网页正文

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { ProcessedContent, StrategyInput } from '../types';

export class WebpageStrategy extends BaseStrategy {
  readonly name = 'webpage';
  readonly sourceType: SourceType = 'webpage';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'webpage';
  }

  buildPrompt(input: StrategyInput): string {
    const sourceUrl = input.source_url || '未知来源';
    const content = input.content || '（无正文内容）';

    return `你是一个笔记整理助手。用户保存了一个网页。

## 任务

1. 保留 source_url 信息
2. 提取网页摘要
3. 提取关键观点
4. 生成"网页资料笔记"结构
5. 不要编造网页中没有的信息

## 网页信息

- 来源 URL：${sourceUrl}
- 网页正文：

${content}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题反映网页核心主题
- 摘要一句话概括网页内容
- 正文开头包含来源链接：> 🔗 来源：[${sourceUrl}](${sourceUrl})
- 提取关键观点，使用列表形式
- 如果网页内容为空或无法解析，生成占位记录

${this.buildOutputFormat()}`;
  }

  /**
   * 覆写后处理：确保 source_url 保留在 body_markdown 中
   * Phase 9.4: 当外部处理服务返回 parsed_markdown 时，确保来源信息保留并移除占位标记
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const result = super.postProcess(raw, input);

    // 确保 source_url 信息保留在 body_markdown 中
    if (input.source_url && !result.body_markdown.includes(input.source_url)) {
      const urlLine = `> 🔗 来源：[${input.source_url}](${input.source_url})\n\n`;
      result.body_markdown = result.body_markdown.replace(
        /^(---\n[\s\S]*?---\n)/,
        `$1${urlLine}`,
      );
    }

    // Phase 9.4: 提取 domain 作为标签
    if (input.source_url) {
      try {
        const domain = new URL(input.source_url).hostname;
        if (!result.tags.includes(domain)) {
          result.tags.push(domain);
        }
      } catch { /* invalid URL, skip */ }
    }

    // Phase 9.4: 如果有 parsed_markdown（VK 解析结果），移除占位标记
    if (input.parsed_markdown && input.parsed_markdown.trim().length > 0) {
      result.quality_flags = result.quality_flags.filter(f => f !== 'placeholder');
    } else if (!input.content || input.content.trim().length === 0) {
      // 如果没有内容且没有 VK 解析结果，标记为占位
      result.quality_flags.push('placeholder');
      result.summary = '网页内容为空，等待后续处理';
      result.body_markdown += '\n\n> ⚠️ 网页内容为空，等待后续处理';
    }

    return result;
  }
}
