// ============================================================
// 规则模板蒸馏引擎 — 基于规则的 fallback 引擎
// ============================================================
// 该引擎基于规则模板生成蒸馏结果，不依赖任何 AI 模型。
// 所有输出均基于输入内容的实际文本分析。
// Markdown 模板由 OutputSpecService 统一管理，本模块只负责"拿到模板后渲染"。
// ============================================================

export interface DistillConfig {
  format: 'obsidian' | 'markdown' | 'summary';
  includeFrontmatter: boolean;
  includeBacklinks: boolean;
  includeTags: boolean;
  includeActionItems: boolean;
}

export interface DistillResult {
  markdown: string;
  title: string;
  summary: string;
  tags: string[];
  category: string;
  processingTimeMs: number;
}

// ---------------------------------------------------------------------------
// Template provider interface (injected to decouple from Electron IPC)
// ---------------------------------------------------------------------------

/** Abstraction over OutputSpecService for renderer-side use */
export interface TemplateProvider {
  getDistillTemplate(name: 'obsidian' | 'plain' | 'summary'): Promise<string>;
  getSnippet(name: 'rawContentSection' | 'frontmatterBlock'): Promise<string>;
}

/** Default template provider using window.acmind.outputSpec IPC bridge */
class IpcTemplateProvider implements TemplateProvider {
  async getDistillTemplate(name: 'obsidian' | 'plain' | 'summary'): Promise<string> {
    return window.acmind.outputSpec.getDistillTemplate(name);
  }
  async getSnippet(name: 'rawContentSection' | 'frontmatterBlock'): Promise<string> {
    return window.acmind.outputSpec.getSnippet(name);
  }
}

// ---------------------------------------------------------------------------
// Module-level template provider (can be overridden for testing)
// ---------------------------------------------------------------------------

let templateProvider: TemplateProvider = new IpcTemplateProvider();

/**
 * Set a custom template provider (for testing or custom backends).
 */
export function setTemplateProvider(provider: TemplateProvider): void {
  templateProvider = provider;
}

/**
 * Get the current template provider.
 */
export function getTemplateProvider(): TemplateProvider {
  return templateProvider;
}

// ============================================================
// 工具函数
// ============================================================

/** 按句子分割文本（支持中英文句号、感叹号、问号） */
function splitSentences(text: string): string[] {
  return text
    .split(/(?<=[。！？.!?])\s*/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/** 提取标题：优先取第一行，否则取前50个字符 */
function extractTitle(text: string): string {
  const lines = text.split('\n').map((l) => l.trim()).filter(Boolean);
  if (lines.length === 0) return '未命名笔记';

  const firstLine = lines[0];
  // 如果第一行以 # 开头，去掉 # 前缀
  const cleaned = firstLine.replace(/^#+\s*/, '');
  if (cleaned.length <= 60) return cleaned;

  return firstLine.slice(0, 50).replace(/[\\/:*?"<>|\n]/g, ' ').trim() + '...';
}

/** 生成摘要：提取关键句子 */
function extractSummary(text: string, maxLen: number = 200): string {
  const sentences = splitSentences(text);
  if (sentences.length === 0) return text.trim().slice(0, maxLen);

  // 策略：首句 + 尾句，或包含关键词的句子
  const keywords = ['核心', '关键', '重要', '结论', '总结', '发现', '结果', '表明', '认为', '建议', '意义', '本质', '原理', '方法', '步骤', '目标', '问题', '解决'];
  const scored = sentences.map((s, i) => {
    let score = 0;
    // 首句加分
    if (i === 0) score += 3;
    // 尾句加分
    if (i === sentences.length - 1) score += 2;
    // 关键词匹配加分
    for (const kw of keywords) {
      if (s.includes(kw)) score += 2;
    }
    // 较长句子略加分（信息量更大）
    if (s.length > 20) score += 1;
    return { sentence: s, score };
  });

  scored.sort((a, b) => b.score - a.score);
  const topSentences = scored.slice(0, 3).map((s) => s.sentence);

  // 按原始顺序排列
  const ordered: string[] = [];
  for (const s of sentences) {
    if (topSentences.includes(s)) ordered.push(s);
  }

  let result = ordered.join('');
  if (result.length > maxLen) {
    result = result.slice(0, maxLen);
    const lastPunct = Math.max(
      result.lastIndexOf('。'),
      result.lastIndexOf('！'),
      result.lastIndexOf('？'),
      result.lastIndexOf('.'),
    );
    if (lastPunct > maxLen * 0.3) {
      result = result.slice(0, lastPunct + 1);
    } else {
      result += '...';
    }
  }

  return result;
}

/** 分类：基于关键词匹配 */
function classifyContent(text: string): string {
  const lower = text.toLowerCase();
  const categories: { name: string; keywords: string[] }[] = [
    {
      name: '技术',
      keywords: ['代码', '编程', 'api', '框架', '函数', 'bug', '部署', '数据库', '服务器', '前端', '后端', '算法', '架构', '组件', 'react', 'vue', 'typescript', 'python', 'javascript', 'css', 'html', 'docker', 'git', 'linux', 'npm', 'node', '接口', '缓存', '性能', '优化', '重构', '测试', 'debug', 'http', 'sql', 'json', 'xml'],
    },
    {
      name: '设计',
      keywords: ['设计', 'ui', 'ux', '配色', '排版', '字体', '图标', '布局', '交互', '原型', 'figma', 'sketch', '视觉', '品牌', 'logo', '插画', '动效', '响应式', '用户体验', '界面', '组件库', '设计系统'],
    },
    {
      name: '产品',
      keywords: ['产品', '需求', '用户', '功能', '迭代', '版本', '上线', '反馈', '体验', '增长', '转化', '留存', '活跃', 'mvp', '优先级', '路线图', '里程碑', '验收', '场景', '痛点'],
    },
    {
      name: '学习',
      keywords: ['学习', '笔记', '课程', '教程', '读书', '阅读', '理解', '概念', '理论', '知识', '思考', '总结', '归纳', '复习', '考试', '论文', '研究', '实验', '数据', '分析'],
    },
    {
      name: '日常',
      keywords: ['今天', '明天', '昨天', '早上', '下午', '晚上', '周末', '计划', '待办', '日记', '心情', '运动', '饮食', '睡眠', '旅行', '购物', '生活', '家务', '聚会'],
    },
    {
      name: '参考',
      keywords: ['链接', '网址', '资源', '工具', '推荐', '收藏', '参考', '文档', '手册', '指南', '教程', '文章', '博客', '视频', '书籍', '资料', '下载'],
    },
  ];

  let bestCategory = '日常';
  let bestScore = 0;

  for (const cat of categories) {
    let score = 0;
    for (const kw of cat.keywords) {
      if (lower.includes(kw)) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      bestCategory = cat.name;
    }
  }

  return bestCategory;
}

/** 从内容中提取标签 */
function extractTags(text: string, category: string): string[] {
  const tags: string[] = [];

  // 始终包含分类标签
  tags.push(category);

  // 基于内容关键词提取标签
  const tagKeywords: Record<string, string[]> = {
    '技术': ['编程', '前端', '后端', '架构', '算法', '数据库', 'DevOps', 'API'],
    '设计': ['UI设计', 'UX', '视觉设计', '交互设计', '品牌设计'],
    '产品': ['产品管理', '需求分析', '用户研究', '项目管理'],
    '学习': ['知识管理', '读书笔记', '课程学习', '研究笔记'],
    '日常': ['生活记录', '日程管理', '个人成长'],
    '参考': ['资源收藏', '工具推荐', '学习资源'],
  };

  const categoryKeywords = tagKeywords[category] || [];
  for (const kw of categoryKeywords) {
    if (text.includes(kw.replace(/管理|分析|研究|笔记|学习|记录|推荐|收藏|资源/g, ''))) {
      tags.push(kw);
    }
  }

  // 从文本中提取高频词作为标签
  const words = text
    .replace(/[^\u4e00-\u9fa5a-zA-Z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length >= 2 && w.length <= 8);

  const freq = new Map<string, number>();
  for (const w of words) {
    freq.set(w, (freq.get(w) || 0) + 1);
  }

  const sorted = [...freq.entries()]
    .filter(([w]) => !['的', '了', '在', '是', '我', '有', '和', '就', '不', '人', '都', '一', '一个', '上', '也', '很', '到', '说', '要', '去', '你', '会', '着', '没有', '看', '好', '自己', '这'].includes(w))
    .sort((a, b) => b[1] - a[1]);

  for (const [word] of sorted) {
    if (tags.length >= 5) break;
    if (!tags.includes(word)) {
      tags.push(word);
    }
  }

  // 确保至少有3个标签
  if (tags.length < 3) {
    tags.push('AcMind');
    tags.push('蒸馏笔记');
  }

  return tags.slice(0, 5);
}

/** 生成双链建议：基于检测到的主题 */
function extractBacklinks(text: string, category: string): string[] {
  const links: string[] = [];

  const categoryLinks: Record<string, string[]> = {
    '技术': ['[[技术笔记]]', '[[编程知识]]', '[[问题解决方案]]'],
    '设计': ['[[设计灵感]]', '[[设计规范]]', '[[配色方案]]'],
    '产品': ['[[产品文档]]', '[[需求池]]', '[[用户反馈]]'],
    '学习': ['[[学习笔记]]', '[[知识图谱]]', '[[待深入研究]]'],
    '日常': ['[[生活记录]]', '[[年度目标]]', '[[习惯追踪]]'],
    '参考': ['[[资源收藏]]', '[[工具箱]]', '[[阅读清单]]'],
  };

  const baseLinks = categoryLinks[category] || [];
  links.push(...baseLinks);

  // 从文本中提取可能的双链（括号内的内容、引号内的专有名词）
  const quotedPattern = /「([^」]+)」|"([^"]+)"|'([^']+)'/g;
  let match;
  while ((match = quotedPattern.exec(text)) !== null && links.length < 6) {
    const term = match[1] || match[2] || match[3];
    if (term && term.length >= 2 && term.length <= 20) {
      const link = `[[${term}]]`;
      if (!links.includes(link)) {
        links.push(link);
      }
    }
  }

  return links.slice(0, 5);
}

/** 提取行动项：以动词开头或包含特定关键词的句子 */
function extractActionItems(text: string): string[] {
  const sentences = splitSentences(text);
  const actionItems: string[] = [];

  const actionKeywords = ['需要', '应该', '必须', '待办', '记得', '别忘了', '别忘了', '计划', '准备', '打算', '要', '尽快', '务必', '记得', '下一步', 'TODO', 'todo', 'FIXME', 'fixme'];
  const verbStarters = ['实现', '完成', '修复', '优化', '更新', '添加', '删除', '修改', '创建', '部署', '测试', '检查', '确认', '整理', '编写', '设计', '重构', '迁移', '升级', '配置', '安装', '设置', '提交', '发布', '评审', '审核', '调研', '学习', '阅读', '复习'];

  for (const s of sentences) {
    let isAction = false;

    // 检查是否包含行动关键词
    for (const kw of actionKeywords) {
      if (s.includes(kw)) {
        isAction = true;
        break;
      }
    }

    // 检查是否以动词开头
    if (!isAction) {
      const trimmed = s.replace(/^[-*•#\d]+\.\s*/, '');
      for (const v of verbStarters) {
        if (trimmed.startsWith(v)) {
          isAction = true;
          break;
        }
      }
    }

    if (isAction && s.length > 4 && s.length < 100) {
      actionItems.push(s);
    }
  }

  return actionItems.slice(0, 8);
}

/** 获取今天的日期字符串 */
function todayStr(): string {
  return new Date().toISOString().slice(0, 10);
}

// ============================================================
// 核心蒸馏函数
// ============================================================

/**
 * 使用规则模板引擎进行蒸馏。
 * 该引擎基于文本分析规则生成输出，不依赖任何 AI 模型。
 * Markdown 模板从 OutputSpecService 获取，本函数只负责填充变量。
 */
export async function distillWithRules(
  content: string,
  config: DistillConfig,
): Promise<DistillResult> {
  const startTime = performance.now();

  // 输入校验
  if (!content || content.trim().length === 0) {
    throw new Error('输入内容为空，请粘贴需要蒸馏的原始材料。');
  }

  const trimmed = content.trim();

  // 1. 提取标题
  const title = extractTitle(trimmed);

  // 2. 生成摘要
  const summary = extractSummary(trimmed);

  // 3. 分类
  const category = classifyContent(trimmed);

  // 4. 生成标签
  const tags = extractTags(trimmed, category);

  // 5. 提取双链建议
  const backlinks = extractBacklinks(trimmed, category);

  // 6. 提取行动项
  const actionItems = extractActionItems(trimmed);

  // 7. 提取关键要点
  const keyPoints = extractKeyPoints(trimmed);

  // 8. 从 OutputSpecService 获取模板并渲染
  const markdown = await renderDistillMarkdown({
    title,
    summary,
    category,
    tags,
    backlinks,
    actionItems,
    keyPoints,
    config,
    rawContent: trimmed,
  });

  const processingTimeMs = Math.round(performance.now() - startTime);

  return {
    markdown,
    title,
    summary,
    tags,
    category,
    processingTimeMs,
  };
}

// ============================================================
// 辅助函数
// ============================================================

/** 提取关键要点 */
function extractKeyPoints(text: string, maxPoints: number = 5): string[] {
  const lines = text
    .split(/\n+/)
    .map((l) => l.trim().replace(/^[-*•#\d]+\.\s*/, ''))
    .filter((l) => l.length > 8);

  if (lines.length === 0) {
    // 从句子中提取
    const sentences = splitSentences(text);
    return sentences.slice(0, maxPoints).filter((s) => s.length > 8);
  }

  const unique = [...new Set(lines)];
  return unique.slice(0, maxPoints);
}

// ============================================================
// Markdown 渲染器 — 使用 OutputSpecService 模板
// ============================================================

interface MarkdownContext {
  title: string;
  summary: string;
  category: string;
  tags: string[];
  backlinks: string[];
  actionItems: string[];
  keyPoints: string[];
  config: DistillConfig;
  rawContent?: string;
}

/**
 * 从 OutputSpecService 获取模板并渲染蒸馏结果。
 * 本函数不持有任何 Markdown 模板，只负责"拿到模板后填充变量"。
 */
async function renderDistillMarkdown(ctx: MarkdownContext): Promise<string> {
  const { config } = ctx;
  const date = todayStr();

  // 映射 format 到模板名称
  const templateNameMap: Record<string, 'obsidian' | 'plain' | 'summary'> = {
    obsidian: 'obsidian',
    markdown: 'plain',
    summary: 'summary',
  };
  const templateName = templateNameMap[config.format] ?? 'obsidian';

  // 从 OutputSpecService 获取模板
  const template = await templateProvider.getDistillTemplate(templateName);

  // 构建模板变量
  const frontmatter = config.includeFrontmatter
    ? await buildFrontmatterBlock(ctx, date)
    : '';

  const keyPoints = ctx.keyPoints.length > 0
    ? `\n## 关键要点\n\n${ctx.keyPoints.map((p) => `- ${p}`).join('\n')}\n`
    : '';

  const backlinks = config.includeBacklinks && ctx.backlinks.length > 0
    ? `\n## 双链建议\n\n${ctx.backlinks.map((l) => `- ${l}`).join('\n')}\n`
    : '';

  const tags = config.includeTags && ctx.tags.length > 0
    ? `\n## 标签\n\n${ctx.tags.map((t) => `\`${t}\``).join(' ')}\n`
    : '';

  const actionItems = config.includeActionItems && ctx.actionItems.length > 0
    ? `\n## 行动项\n\n${ctx.actionItems.map((item) => `- [ ] ${item}`).join('\n')}\n`
    : '';

  const rawExcerpt = ctx.rawContent
    ? buildRawExcerpt(ctx.rawContent)
    : '';

  // 渲染模板：替换 {{variable}} 占位符
  return template
    .replace(/\{\{frontmatter\}\}/g, frontmatter)
    .replace(/\{\{title\}\}/g, ctx.title)
    .replace(/\{\{date\}\}/g, date)
    .replace(/\{\{category\}\}/g, ctx.category)
    .replace(/\{\{summary\}\}/g, ctx.summary)
    .replace(/\{\{keyPoints\}\}/g, keyPoints)
    .replace(/\{\{backlinks\}\}/g, backlinks)
    .replace(/\{\{tags\}\}/g, tags)
    .replace(/\{\{actionItems\}\}/g, actionItems)
    .replace(/\{\{rawExcerpt\}\}/g, rawExcerpt);
}

/**
 * 构建 frontmatter 块。
 * 从 OutputSpecService 获取 frontmatter 片段模板并填充变量。
 */
async function buildFrontmatterBlock(ctx: MarkdownContext, date: string): Promise<string> {
  const snippet = await templateProvider.getSnippet('frontmatterBlock');
  const tagsYaml = ctx.tags.map((t) => `  - ${t}`).join('\n');
  return snippet
    .replace(/\{\{title\}\}/g, ctx.title.replace(/"/g, '\\"'))
    .replace(/\{\{date\}\}/g, date)
    .replace(/\{\{category\}\}/g, ctx.category)
    .replace(/\{\{tags\}\}/g, tagsYaml);
}

/**
 * 构建原始摘录片段（截取前几行）。
 */
function buildRawExcerpt(rawContent: string): string {
  const rawLines = rawContent.split('\n').slice(0, 8);
  let excerpt = `\n## 原始摘录\n\n`;
  excerpt += `> ${rawLines.join('\n> ')}`;
  if (rawContent.split('\n').length > 8) {
    excerpt += `\n> ...（共 ${rawContent.split('\n').length} 行）`;
  }
  excerpt += '\n';
  return excerpt;
}
