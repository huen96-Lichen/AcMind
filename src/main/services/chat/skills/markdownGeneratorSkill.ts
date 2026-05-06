/**
 * markdownGeneratorSkill — Markdown Generator Skill
 *
 * 根据内容生成 Markdown 文档。
 * 如果提供 outputPath 则写入文件，需要确认。
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import type { AgentSkill, SkillContext, SkillResult } from '../skillRegistry';

const markdownGeneratorSkill: AgentSkill = {
  name: 'markdown_generator',
  description: '根据内容生成 Markdown 文档',
  parameters: {
    type: 'object',
    properties: {
      title: { type: 'string', description: '文档标题' },
      content: { type: 'string', description: '文档内容' },
      outputPath: { type: 'string', description: '输出路径（可选，不提供则返回内容）' },
      tags: { type: 'array', items: { type: 'string' }, description: '标签列表（可选）' },
      frontmatter: { type: 'object', description: '自定义 frontmatter 字段（可选）' },
    },
    required: ['title', 'content'],
  },
  category: 'document',
  requiresConfirmation: true, // 写入文件需要确认

  async execute(params: Record<string, unknown>, _context: SkillContext): Promise<SkillResult> {
    const title = params.title as string;
    const content = params.content as string;
    const outputPath = params.outputPath as string | undefined;
    const tags = params.tags as string[] | undefined;
    const customFrontmatter = params.frontmatter as Record<string, unknown> | undefined;

    if (!title || !content) {
      return {
        success: false,
        content: '',
        error: 'title 和 content 参数缺失',
      };
    }

    try {
      // 构建 frontmatter
      const now = new Date();
      const frontmatter: Record<string, unknown> = {
        title,
        created: now.toISOString(),
        ...customFrontmatter,
      };

      if (tags && tags.length > 0) {
        frontmatter.tags = tags;
      }

      // 生成 YAML frontmatter
      const yamlLines: string[] = ['---'];
      for (const [key, value] of Object.entries(frontmatter)) {
        if (value === undefined || value === null) continue;
        if (Array.isArray(value)) {
          yamlLines.push(`${key}:`);
          for (const item of value) {
            yamlLines.push(`  - ${item}`);
          }
        } else if (typeof value === 'object') {
          yamlLines.push(`${key}: ${JSON.stringify(value)}`);
        } else {
          yamlLines.push(`${key}: ${value}`);
        }
      }
      yamlLines.push('---');
      yamlLines.push('');

      // 构建完整的 Markdown 内容
      const markdown = `${yamlLines.join('\n')}${content}`;

      // 如果提供了输出路径，写入文件
      if (outputPath) {
        // 确保目录存在
        const dir = path.dirname(outputPath);
        await fs.mkdir(dir, { recursive: true });

        // 写入文件
        await fs.writeFile(outputPath, markdown, 'utf-8');

        return {
          success: true,
          content: `文档已生成并保存到: ${outputPath}`,
          metadata: {
            title,
            outputPath,
            size: markdown.length,
            tags,
          },
        };
      }

      // 否则返回内容
      return {
        success: true,
        content: markdown,
        metadata: {
          title,
          size: markdown.length,
          tags,
        },
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      return {
        success: false,
        content: '',
        error: `生成文档失败: ${errorMsg}`,
      };
    }
  },
};

export default markdownGeneratorSkill;
