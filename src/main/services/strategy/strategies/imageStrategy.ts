// AcMind Image Strategy
// Phase 8.1: 图片占位或 OCR 结果（与 screenshot 类似但语义不同）

import type { SourceType } from '../../../../shared/types';
import { BaseStrategy } from '../baseStrategy';
import type { ProcessedContent, StrategyInput } from '../types';

export class ImageStrategy extends BaseStrategy {
  readonly name = 'image';
  readonly sourceType: SourceType = 'image';

  canHandle(input: StrategyInput): boolean {
    return input.source_type === 'image';
  }

  buildPrompt(input: StrategyInput): string {
    const hasOcr = input.extracted_text && input.extracted_text.trim().length > 0;

    if (hasOcr) {
      return `你是一个笔记整理助手。用户保存了一张图片，已通过 OCR 提取了文本。

## 任务

1. 整理 OCR 提取的文本
2. 保留图片路径信息
3. 不要编造图片中没有的信息

## OCR 提取文本

${input.extracted_text}

## 图片路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题反映图片内容主题
- 摘要一句话概括
- 正文开头标注：> 🖼️ 来源：图片（OCR 提取）
- 整理 OCR 文本，修正明显的识别错误
- 保留原始信息，不要编造

${this.buildOutputFormat()}`;
    }

    return `你是一个笔记整理助手。用户保存了一张图片，但尚未进行 OCR 识别。

## 任务

1. 生成基础图片记录
2. 保留图片路径信息
3. 不要假装看懂图片内容

## 图片路径

${input.raw_file_path || '未知'}

${this.buildFrontmatterHint()}

## 笔记结构要求

- 标题：图片记录 - {日期}
- 摘要：图片已保存，等待 OCR 识别
- 正文包含图片路径
- 明确标注需要后续 OCR 处理

${this.buildOutputFormat()}`;
  }

  /**
   * 覆写后处理：处理无 OCR 的情况
   * Phase 9.5: 当 VaultKeeper 返回 extracted_text 时，移除占位标记并标注 OCR 来源
   */
  postProcess(raw: Record<string, unknown>, input: StrategyInput): ProcessedContent {
    const hasOcr = input.extracted_text && input.extracted_text.trim().length > 0;

    if (!hasOcr) {
      // Phase 9.5: 无 OCR 时生成占位记录，不伪造图片内容
      return {
        title: `图片记录 - ${new Date().toISOString().split('T')[0]}`,
        summary: '图片已保存，等待 OCR 识别',
        tags: ['图片', '待OCR'],
        body_markdown: [
          '---',
          `title: "图片记录"`,
          `date: "${new Date().toISOString().split('T')[0]}"`,
          'tags:',
          '  - 图片',
          '  - 待OCR',
          'source_type: "image"',
          '---',
          '',
          '> 🖼️ 图片已保存，等待 OCR 识别',
          '',
          `**图片路径**：${input.raw_file_path || '未知'}`,
          '',
          '> ⚠️ 此为占位记录，OCR 识别后将自动更新',
        ].join('\n'),
        suggested_folder: 'Inbox/Images',
        quality_flags: ['needs_ocr', 'placeholder'],
      };
    }

    // Phase 9.5: 有 OCR 时正常处理，移除占位标记
    const result = super.postProcess(raw, input);
    result.quality_flags = result.quality_flags.filter(f => f !== 'needs_ocr' && f !== 'placeholder');

    // 在 body_markdown 开头标注 OCR 来源
    if (!result.body_markdown.includes('OCR')) {
      result.body_markdown = `> 🖼️ 来源：图片（OCR 提取）\n\n${result.body_markdown}`;
    }

    return result;
  }
}
