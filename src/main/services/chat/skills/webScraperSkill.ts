/**
 * webScraperSkill — Web Scraper Skill
 *
 * 抓取网页内容并转换为 Markdown 格式。
 * 只读操作，安全等级 safe。
 */

import type { AgentSkill, SkillContext, SkillResult } from '../skillRegistry';

const webScraperSkill: AgentSkill = {
  name: 'web_scraper',
  description: '抓取网页内容并转换为 Markdown 格式',
  parameters: {
    type: 'object',
    properties: {
      url: { type: 'string', description: '要抓取的网页 URL' },
      format: { type: 'string', enum: ['markdown', 'text'], default: 'markdown', description: '输出格式' },
    },
    required: ['url'],
  },
  category: 'web',
  requiresConfirmation: false,

  async execute(params: Record<string, unknown>, _context: SkillContext): Promise<SkillResult> {
    const url = params.url as string;
    const format = (params.format as string) ?? 'markdown';

    if (!url) {
      return {
        success: false,
        content: '',
        error: 'URL 参数缺失',
      };
    }

    try {
      // 使用 fetch 获取网页内容
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; AcMind/1.0)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      });

      if (!response.ok) {
        return {
          success: false,
          content: '',
          error: `HTTP 错误: ${response.status} ${response.statusText}`,
        };
      }

      const contentType = response.headers.get('content-type') ?? '';
      if (!contentType.includes('text/html') && !contentType.includes('text/plain')) {
        return {
          success: false,
          content: '',
          error: `不支持的内容类型: ${contentType}`,
        };
      }

      const html = await response.text();

      // 简单的 HTML 到 Markdown 转换
      let content = html;

      // 移除 script 和 style 标签
      content = content.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
      content = content.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');
      content = content.replace(/<nav\b[^<]*(?:(?!<\/nav>)<[^<]*)*<\/nav>/gi, '');
      content = content.replace(/<footer\b[^<]*(?:(?!<\/footer>)<[^<]*)*<\/footer>/gi, '');
      content = content.replace(/<header\b[^<]*(?:(?!<\/header>)<[^<]*)*<\/header>/gi, '');

      // 提取 title
      const titleMatch = content.match(/<title[^>]*>([^<]+)<\/title>/i);
      const title = titleMatch ? titleMatch[1].trim() : url;

      // 提取 body 内容
      const bodyMatch = content.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
      let bodyContent = bodyMatch ? bodyMatch[1] : content;

      if (format === 'markdown') {
        // 转换标题
        bodyContent = bodyContent.replace(/<h1[^>]*>([^<]+)<\/h1>/gi, '# $1\n\n');
        bodyContent = bodyContent.replace(/<h2[^>]*>([^<]+)<\/h2>/gi, '## $1\n\n');
        bodyContent = bodyContent.replace(/<h3[^>]*>([^<]+)<\/h3>/gi, '### $1\n\n');
        bodyContent = bodyContent.replace(/<h4[^>]*>([^<]+)<\/h4>/gi, '#### $1\n\n');
        bodyContent = bodyContent.replace(/<h5[^>]*>([^<]+)<\/h5>/gi, '##### $1\n\n');
        bodyContent = bodyContent.replace(/<h6[^>]*>([^<]+)<\/h6>/gi, '###### $1\n\n');

        // 转换段落
        bodyContent = bodyContent.replace(/<p[^>]*>([\s\S]*?)<\/p>/gi, '$1\n\n');

        // 转换链接
        bodyContent = bodyContent.replace(/<a[^>]*href="([^"]+)"[^>]*>([^<]+)<\/a>/gi, '[$2]($1)');

        // 转换粗体和斜体
        bodyContent = bodyContent.replace(/<strong[^>]*>([^<]+)<\/strong>/gi, '**$1**');
        bodyContent = bodyContent.replace(/<b[^>]*>([^<]+)<\/b>/gi, '**$1**');
        bodyContent = bodyContent.replace(/<em[^>]*>([^<]+)<\/em>/gi, '*$1*');
        bodyContent = bodyContent.replace(/<i[^>]*>([^<]+)<\/i>/gi, '*$1*');

        // 转换代码块
        bodyContent = bodyContent.replace(/<pre[^>]*><code[^>]*>([\s\S]*?)<\/code><\/pre>/gi, '```\n$1\n```\n\n');
        bodyContent = bodyContent.replace(/<code[^>]*>([^<]+)<\/code>/gi, '`$1`');

        // 转换列表
        bodyContent = bodyContent.replace(/<li[^>]*>([^<]+)<\/li>/gi, '- $1\n');
        bodyContent = bodyContent.replace(/<\/?ul[^>]*>/gi, '\n');
        bodyContent = bodyContent.replace(/<\/?ol[^>]*>/gi, '\n');

        // 转换换行
        bodyContent = bodyContent.replace(/<br\s*\/?>/gi, '\n');

        // 移除剩余的 HTML 标签
        bodyContent = bodyContent.replace(/<[^>]+>/g, '');

        // 清理多余空白
        bodyContent = bodyContent.replace(/\n{3,}/g, '\n\n');
        bodyContent = bodyContent.trim();

        const result = `# ${title}\n\n来源: ${url}\n\n---\n\n${bodyContent}`;

        return {
          success: true,
          content: result,
          metadata: {
            url,
            title,
            format,
            contentLength: result.length,
          },
        };
      } else {
        // 纯文本格式
        bodyContent = bodyContent.replace(/<[^>]+>/g, '');
        bodyContent = bodyContent.replace(/\s+/g, ' ').trim();

        return {
          success: true,
          content: bodyContent,
          metadata: {
            url,
            title,
            format,
            contentLength: bodyContent.length,
          },
        };
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      return {
        success: false,
        content: '',
        error: `抓取失败: ${errorMsg}`,
      };
    }
  },
};

export default webScraperSkill;
