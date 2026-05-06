/**
 * fileSearchSkill — File Search Skill
 *
 * 在指定目录中搜索文件。
 * 只读操作，安全等级 safe。
 */

import fg from 'fast-glob';
import fs from 'node:fs/promises';
import path from 'node:path';
import type { AgentSkill, SkillContext, SkillResult } from '../skillRegistry';

const fileSearchSkill: AgentSkill = {
  name: 'file_search',
  description: '在指定目录中搜索文件',
  parameters: {
    type: 'object',
    properties: {
      directory: { type: 'string', description: '搜索目录' },
      pattern: { type: 'string', description: '文件名模式（支持 glob）' },
      content: { type: 'string', description: '内容搜索关键词（可选）' },
      maxResults: { type: 'number', default: 50, description: '最大结果数' },
    },
    required: ['directory', 'pattern'],
  },
  category: 'file_system',
  requiresConfirmation: false,

  async execute(params: Record<string, unknown>, _context: SkillContext): Promise<SkillResult> {
    const directory = params.directory as string;
    const pattern = params.pattern as string;
    const contentSearch = params.content as string | undefined;
    const maxResults = (params.maxResults as number) ?? 50;

    if (!directory || !pattern) {
      return {
        success: false,
        content: '',
        error: 'directory 和 pattern 参数缺失',
      };
    }

    try {
      // 构建完整的 glob 模式
      const fullPattern = path.join(directory, pattern);

      // 使用 fast-glob 搜索文件
      const files = await fg(fullPattern, {
        onlyFiles: true,
        absolute: true,
        deep: 10,
      });

      const results: Array<{
        path: string;
        relativePath: string;
        size?: number;
        modified?: string;
        matchedContent?: string;
      }> = [];

      // 限制结果数量
      const limitedFiles = files.slice(0, maxResults);

      for (const filePath of limitedFiles) {
        const relativePath = path.relative(directory, filePath);

        const result: {
          path: string;
          relativePath: string;
          size?: number;
          modified?: string;
          matchedContent?: string;
        } = {
          path: filePath,
          relativePath,
        };

        try {
          const stat = await fs.stat(filePath);
          result.size = stat.size;
          result.modified = stat.mtime.toISOString();

          // 如果有内容搜索，读取文件并搜索
          if (contentSearch) {
            // 只搜索文本文件（小于 1MB）
            if (stat.size < 1024 * 1024) {
              try {
                const fileContent = await fs.readFile(filePath, 'utf-8');
                const lines = fileContent.split('\n');
                const matchedLines: Array<{ line: number; content: string }> = [];

                lines.forEach((line, index) => {
                  if (line.toLowerCase().includes(contentSearch.toLowerCase())) {
                    matchedLines.push({
                      line: index + 1,
                      content: line.trim().slice(0, 200),
                    });
                  }
                });

                if (matchedLines.length > 0) {
                  result.matchedContent = matchedLines
                    .slice(0, 5)
                    .map((m) => `L${m.line}: ${m.content}`)
                    .join('\n');
                }
              } catch {
                // 忽略读取错误（可能是二进制文件）
              }
            }
          }
        } catch {
          // 忽略 stat 错误
        }

        // 如果有内容搜索但没有匹配，跳过
        if (contentSearch && !result.matchedContent) {
          continue;
        }

        results.push(result);
      }

      // 构建输出
      const lines: string[] = [];
      lines.push(`# 文件搜索结果`);
      lines.push('');
      lines.push(`**搜索目录**: ${directory}`);
      lines.push(`**模式**: ${pattern}`);
      if (contentSearch) {
        lines.push(`**内容搜索**: "${contentSearch}"`);
      }
      lines.push(`**找到文件**: ${results.length} 个`);
      lines.push('');

      if (results.length === 0) {
        lines.push('未找到匹配的文件。');
      } else {
        for (const result of results) {
          lines.push(`## ${result.relativePath}`);
          lines.push(`- 路径: ${result.path}`);
          if (result.size !== undefined) {
            lines.push(`- 大小: ${formatBytes(result.size)}`);
          }
          if (result.modified) {
            lines.push(`- 修改时间: ${result.modified}`);
          }
          if (result.matchedContent) {
            lines.push('');
            lines.push('**匹配内容**:');
            lines.push('```');
            lines.push(result.matchedContent);
            lines.push('```');
          }
          lines.push('');
        }
      }

      return {
        success: true,
        content: lines.join('\n'),
        metadata: {
          directory,
          pattern,
          contentSearch,
          totalFiles: files.length,
          resultCount: results.length,
        },
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      return {
        success: false,
        content: '',
        error: `搜索失败: ${errorMsg}`,
      };
    }
  },
};

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}

export default fileSearchSkill;
