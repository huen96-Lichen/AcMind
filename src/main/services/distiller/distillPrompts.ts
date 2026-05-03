// PinMind Distillation Prompt Templates
// Prompt templates for each distillation operation

import type { AiOperation } from '../../../shared/types';
import {
  DEFAULT_DISTILLED_CATEGORY,
  DEFAULT_DISTILLED_LINKS,
  DEFAULT_DISTILLED_TYPE,
  PINMIND_MARKDOWN_SPEC_DIR,
} from '../../../shared/markdownSpec';

// ---------------------------------------------------------------------------
// Prompt templates (Chinese)
// ---------------------------------------------------------------------------

const PROMPT_TEMPLATES: Record<AiOperation, string> = {
  rename: '为以下内容生成一个简洁清晰的标题：\n\n{content}',
  summarize: `你是 PinMind 的本地蒸馏器。请严格遵守 Markdown 中文规范包：${PINMIND_MARKDOWN_SPEC_DIR}

请把用户原始内容整理为可导入 Obsidian 的结构化结果。只输出 JSON，不要输出解释、Markdown 代码围栏或额外文字。

JSON 结构必须是：
{
  "title": "15-35 个中文字符的标题，适合作为文件名",
  "summary": "不超过 80 个中文字符的一句话摘要",
  "category": "建议归档目录，不确定时使用 ${DEFAULT_DISTILLED_CATEGORY}",
  "tags": ["3-8 个中文标签，不要带 #"],
  "type": "${DEFAULT_DISTILLED_TYPE}",
  "contentMarkdown": "# 标题\\n\\n## 一句话结论\\n\\n...\\n\\n## 原始来源\\n\\n...\\n\\n## AI 整理内容\\n\\n...\\n\\n## 待人工确认点\\n\\n...\\n\\n## 建议标签\\n\\n...\\n\\n## 建议归档位置\\n\\n...\\n\\n## 关联链接\\n\\n- [[${DEFAULT_DISTILLED_LINKS[0]}]]\\n- [[${DEFAULT_DISTILLED_LINKS[1]}]]"
}

要求：
- 使用中文。
- 不编造用户没有提供的事实。
- 不确定内容明确写“不确定”。
- type 必须使用固定文档类型，不确定时使用 ${DEFAULT_DISTILLED_TYPE}。
- category 不确定时必须使用 ${DEFAULT_DISTILLED_CATEGORY}。
- contentMarkdown 不要包含 YAML frontmatter。

原始内容：

{content}`,
  classify: '将以下内容分类到最合适的类别中（如：技术、设计、产品、日常、参考）：\n\n{content}',
  tag: '为以下内容生成3-5个标签：\n\n{content}',
  valueScore: '评估以下内容的价值分数（1-10分），1=低价值可清理，10=高价值需保留：\n\n{content}',
  cleanSuggest: '判断以下内容是否应该保留、合并或清理：\n\n{content}',
};

// ---------------------------------------------------------------------------
// buildPrompt
// ---------------------------------------------------------------------------

/**
 * Build a prompt string for the given operation and content.
 * Replaces {content} placeholder in the template with actual content.
 */
export function buildPrompt(operation: AiOperation, content: string): string {
  const template = PROMPT_TEMPLATES[operation];
  if (!template) {
    throw new Error(`Unknown distillation operation: ${operation}`);
  }
  return template.replace('{content}', content);
}
