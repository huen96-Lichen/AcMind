// PinMind Prompt Profile System
// Phase 8.2: 可维护、可版本化的 Prompt Profile 体系
//
// 职责：
// 1. 定义 PromptProfile 结构
// 2. 管理 profile 注册与查找
// 3. 根据 source_type 选择 profile
// 4. 支持 profile version
// 5. 支持默认 fallback
// 6. 模型不直接生成最终 frontmatter（由 MarkdownRenderer 负责）

import type { SourceType } from '../../../shared/types';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// PromptProfile 类型
// ---------------------------------------------------------------------------

export interface PromptProfile {
  /** Profile 唯一标识 */
  profile_id: string;
  /** 人类可读名称 */
  name: string;
  /** Profile 版本号 */
  version: string;
  /** 适用的 source_type */
  source_type: SourceType | 'default';
  /** Profile 描述 */
  description: string;
  /** 系统级 Prompt（角色设定） */
  system_prompt: string;
  /** 用户 Prompt 模板（支持 {{变量}} 占位符） */
  user_prompt_template: string;
  /** 输出 JSON Schema 描述 */
  output_schema: Record<string, string>;
  /** 约束条件列表 */
  constraints: string[];
}

// ---------------------------------------------------------------------------
// 变量替换
// ---------------------------------------------------------------------------

/**
 * 将模板中的 {{key}} 替换为实际值。
 */
export function renderTemplate(template: string, vars: Record<string, string>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key: string) => vars[key] ?? '');
}

// ---------------------------------------------------------------------------
// 内置 Prompt Profiles
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT_BASE = '你是一个笔记整理助手。请严格按照要求的 JSON 格式输出结果，不要添加任何额外文本。';

const OUTPUT_SCHEMA_STANDARD: Record<string, string> = {
  title: 'string - 笔记标题',
  summary: 'string - 一句话摘要',
  tags: 'string[] - 标签数组',
  body_markdown: 'string - Obsidian 兼容的 Markdown 正文（不含 YAML frontmatter）',
  suggested_folder: 'string - 建议的 Obsidian 文件夹路径',
  quality_flags: 'string[] - 质量标记数组',
};

const CONSTRAINTS_BASE = [
  '只输出 JSON，不要添加任何其他文本',
  '不要生成 YAML frontmatter（由系统自动添加）',
  '不要编造未提供的信息',
  'title 不得为空',
  'summary 不得为空',
  'tags 必须是字符串数组',
  'body_markdown 不得为空',
];

const BUILTIN_PROFILES: PromptProfile[] = [
  // ── manual_text ──────────────────────────────────────────────
  {
    profile_id: 'pinmind.manual_text.v1',
    name: '手动输入整理',
    version: '1.0.0',
    source_type: 'manual_text',
    description: '用户主动输入的想法、笔记、计划',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户主动输入了一段想法、笔记或计划。

## 任务
1. 保留用户原意，不要过度改写
2. 精简表达，去除冗余
3. 提取核心主题
4. 生成适合 Obsidian 的笔记结构

## 用户输入
{{content}}

## 要求
- 标题简洁明了，反映核心主题
- 摘要一句话概括
- 正文保留用户原意，适当分段
- 如果包含待办事项，使用 Obsidian 任务格式 \`- [ ]\`

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: CONSTRAINTS_BASE,
  },

  // ── clipboard_text ───────────────────────────────────────────
  {
    profile_id: 'pinmind.clipboard_text.v1',
    name: '剪贴板摘录整理',
    version: '1.0.0',
    source_type: 'clipboard_text',
    description: '从剪贴板复制的文本片段',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户从剪贴板粘贴了一段文本。

## 任务
1. 判断文本是否为摘录（引用他人内容）还是用户自己的笔记
2. 如果是摘录，保留原文并标注来源
3. 生成摘要和关键信息提取
4. 避免过度改写原文

## 原始文本
{{content}}

## 要求
- 标题反映文本核心主题
- 如果是摘录，正文开头标注：> 📋 以下为摘录内容
- 提取关键观点，使用列表形式
- 不要编造原文没有的信息

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '不要过度改写原文'],
  },

  // ── webpage ──────────────────────────────────────────────────
  {
    profile_id: 'pinmind.webpage.v1',
    name: '网页资料整理',
    version: '1.0.0',
    source_type: 'webpage',
    description: '网页链接和网页正文',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户保存了一个网页。

## 任务
1. 保留 source_url 信息
2. 提取网页摘要
3. 提取关键观点
4. 生成"网页资料笔记"结构
5. 不要编造网页中没有的信息

## 网页信息
- 来源 URL：{{source_url}}
- 网页正文：
{{content}}

## 要求
- 标题反映网页核心主题
- 正文开头包含来源链接：> 🔗 来源：[{{source_url}}]({{source_url}})
- 提取关键观点，使用列表形式

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '必须保留 source_url 信息', '不要伪造网页信息'],
  },

  // ── screenshot ───────────────────────────────────────────────
  {
    profile_id: 'pinmind.screenshot.ocr.v1',
    name: '截图 OCR 整理',
    version: '1.0.0',
    source_type: 'screenshot',
    description: '截图 OCR 提取文本后的整理',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户保存了一张截图，已通过 OCR 提取了文本。

## 任务
1. 整理 OCR 提取的文本
2. 保留图片路径信息
3. 不要编造图片中没有的信息

## OCR 提取文本
{{extracted_text}}

## 图片路径
{{raw_file_path}}

## 要求
- 标题反映截图内容主题
- 正文开头标注：> 📸 来源：截图（OCR 提取）
- 整理 OCR 文本，修正明显的识别错误

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '不要假装看懂图片内容', '只处理 OCR 提供的文本'],
  },

  // ── audio (with transcript) ──────────────────────────────────
  {
    profile_id: 'pinmind.audio.transcript.v1',
    name: '音频转写整理',
    version: '1.0.0',
    source_type: 'audio',
    description: '音频转写文本的整理',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户保存了一段音频，已转写为文本。

## 任务
1. 整理转写文本
2. 保留原始文件路径
3. 生成语音笔记结构

## 转写文本
{{transcript_text}}

## 音频文件路径
{{raw_file_path}}

## 要求
- 标题反映音频内容主题
- 正文开头标注：> 🎤 来源：音频转写
- 整理转写文本，适当分段

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '不要假装总结音频', '只处理转写提供的文本'],
  },

  // ── audio voice note distillation (Phase 10) ─────────────────
  {
    profile_id: 'voice_note_zh_v1',
    name: '语音笔记蒸馏',
    version: '1.0.0',
    source_type: 'audio',
    description: 'Phase 10: 语音转写文本的深度整理，去除口癖、修复断句、提取待办',
    system_prompt: `你是 PinMind 的语音笔记整理助手。
你的任务是把用户的语音转写文本整理成清晰、克制、可长期保存的中文 Markdown 笔记。
你必须遵守：
1. 保留原意，不擅自扩写事实。
2. 去除口癖、重复、无意义停顿。
3. 修复明显口语化断句。
4. 将跳跃想法整理成清晰层级。
5. 提取明确待办。
6. 不要把模糊想法强行改成任务。
7. 对不确定、转写可疑、上下文缺失的内容标记 quality_flags。
8. 输出必须符合指定 JSON schema。
9. 不要输出解释。
10. 不要输出 schema 之外的字段。`,
    user_prompt_template: `请整理以下语音转写内容：

{{transcript_text}}

请输出 JSON：
{
  "title": "不超过 24 个中文字符的标题",
  "summary": "2-4 句摘要",
  "tags": ["3-7 个中文标签"],
  "body_markdown": "整理后的 Markdown 正文",
  "suggested_folder": "建议目录",
  "quality_flags": ["质量标记"]
}

body_markdown 建议结构：
## 核心想法
## 详细整理
## 待办
## 可能关联的项目 / 主题
## 不确定内容

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [
      ...CONSTRAINTS_BASE,
      '保留原意，不擅自扩写事实',
      '去除口癖、重复、无意义停顿',
      '修复明显口语化断句',
      '不要把模糊想法强行改成任务',
      '对不确定内容标记 quality_flags',
    ],
  },

  // ── video (with transcript) ──────────────────────────────────
  {
    profile_id: 'pinmind.video.transcript.v1',
    name: '视频转写整理',
    version: '1.0.0',
    source_type: 'video',
    description: '视频转写文本的整理',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户保存了一段视频，已转写为文本。

## 任务
1. 整理转写文本
2. 保留原始文件路径
3. 生成视频笔记结构

## 转写文本
{{transcript_text}}

## 视频文件路径
{{raw_file_path}}

## 要求
- 标题反映视频内容主题
- 正文开头标注：> 🎬 来源：视频转写
- 整理转写文本，适当分段

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '不要假装总结视频', '只处理转写提供的文本'],
  },

  // ── file (text files) ────────────────────────────────────────
  {
    profile_id: 'pinmind.file.text.v1',
    name: '文本文件整理',
    version: '1.0.0',
    source_type: 'file',
    description: '可直接解析的文本文件（.txt/.md）',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户导入了一个文本文件（{{file_ext}}）。

## 任务
1. 直接整理文件正文内容
2. 保留原始文件路径
3. 生成适合 Obsidian 的笔记结构

## 文件信息
- 文件路径：{{raw_file_path}}
- 文件类型：{{file_ext}}

## 文件内容
{{content}}

## 要求
- 标题反映文件核心主题
- 正文整理文件内容
- 保留原始信息

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: CONSTRAINTS_BASE,
  },

  // ── pdf (with parsed markdown) ───────────────────────────────
  {
    profile_id: 'pinmind.pdf.parsed.v1',
    name: 'PDF 文档整理',
    version: '1.0.0',
    source_type: 'pdf',
    description: '已解析为 Markdown 的 PDF 文档',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户保存了一个 PDF 文档，已解析为 Markdown。

## 任务
1. 整理解析后的 Markdown 内容
2. 保留原始文件路径
3. 生成文档笔记结构

## 解析内容
{{parsed_markdown}}

## PDF 文件路径
{{raw_file_path}}

## 要求
- 标题反映文档核心主题
- 正文开头标注：> 📄 来源：PDF 文档
- 整理解析内容，保持结构清晰

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '不要强行解析复杂内容'],
  },

  // ── docx (with parsed markdown) ──────────────────────────────
  {
    profile_id: 'pinmind.docx.parsed.v1',
    name: 'Word 文档整理',
    version: '1.0.0',
    source_type: 'docx',
    description: '已解析为 Markdown 的 Word 文档',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户保存了一个 Word 文档，已解析为 Markdown。

## 任务
1. 整理解析后的 Markdown 内容
2. 保留原始文件路径
3. 生成文档笔记结构

## 解析内容
{{parsed_markdown}}

## DOCX 文件路径
{{raw_file_path}}

## 要求
- 标题反映文档核心主题
- 正文开头标注：> 📝 来源：Word 文档
- 整理解析内容，保持结构清晰

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '不要强行解析复杂内容'],
  },

  // ── image (with OCR) ─────────────────────────────────────────
  {
    profile_id: 'pinmind.image.ocr.v1',
    name: '图片 OCR 整理',
    version: '1.0.0',
    source_type: 'image',
    description: '图片 OCR 提取文本后的整理',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `用户保存了一张图片，已通过 OCR 提取了文本。

## 任务
1. 整理 OCR 提取的文本
2. 保留图片路径信息
3. 不要编造图片中没有的信息

## OCR 提取文本
{{extracted_text}}

## 图片路径
{{raw_file_path}}

## 要求
- 标题反映图片内容主题
- 正文开头标注：> 🖼️ 来源：图片（OCR 提取）
- 整理 OCR 文本，修正明显的识别错误

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: [...CONSTRAINTS_BASE, '不要假装看懂图片内容'],
  },

  // ── default fallback ─────────────────────────────────────────
  {
    profile_id: 'pinmind.default.v1',
    name: '通用内容整理',
    version: '1.0.0',
    source_type: 'default',
    description: '通用 fallback profile，用于未匹配到专用 profile 的情况',
    system_prompt: SYSTEM_PROMPT_BASE,
    user_prompt_template: `请整理以下内容。

## 内容
{{content}}

## 要求
- 生成简洁的标题
- 生成一句话摘要
- 提取标签
- 整理为 Obsidian 笔记格式

{{output_format}}`,
    output_schema: OUTPUT_SCHEMA_STANDARD,
    constraints: CONSTRAINTS_BASE,
  },
];

// ---------------------------------------------------------------------------
// PromptProfileRegistry
// ---------------------------------------------------------------------------

class PromptProfileRegistry {
  private profiles = new Map<string, PromptProfile>();
  /** source_type → profile_id 的最新版本映射 */
  private sourceTypeMap = new Map<SourceType | 'default', string>();

  constructor() {
    for (const profile of BUILTIN_PROFILES) {
      this.register(profile);
    }
  }

  register(profile: PromptProfile): void {
    this.profiles.set(profile.profile_id, profile);

    // 更新 source_type 映射（后注册的覆盖先注册的，实现版本升级）
    this.sourceTypeMap.set(profile.source_type, profile.profile_id);

    logger.debug('app', 'promptProfile', 'registered',
      `Profile registered: ${profile.profile_id}`, {
        sourceType: profile.source_type,
        version: profile.version,
      });
  }

  /**
   * 根据 source_type 获取最新的 PromptProfile。
   * 如果没有匹配的 profile，返回 default fallback。
   */
  getProfile(sourceType: SourceType): PromptProfile {
    const profileId = this.sourceTypeMap.get(sourceType);
    if (profileId) {
      const profile = this.profiles.get(profileId);
      if (profile) return profile;
    }

    // Fallback to default
    const defaultId = this.sourceTypeMap.get('default');
    if (defaultId) {
      const defaultProfile = this.profiles.get(defaultId);
      if (defaultProfile) return defaultProfile;
    }

    // Should never happen with builtin profiles
    throw new Error(`No prompt profile found for source_type: ${sourceType}`);
  }

  /**
   * 根据 profile_id 获取特定版本的 profile。
   */
  getProfileById(profileId: string): PromptProfile | undefined {
    return this.profiles.get(profileId);
  }

  /**
   * 获取所有已注册的 profiles。
   */
  getAllProfiles(): PromptProfile[] {
    return Array.from(this.profiles.values());
  }

  /**
   * 构建完整的 Prompt（system + user）。
   * 将 output_format 变量注入到模板中。
   */
  buildFullPrompt(
    sourceType: SourceType,
    vars: Record<string, string>,
  ): { systemPrompt: string; userPrompt: string; profileId: string } {
    const profile = this.getProfile(sourceType);

    // 构建 output_format 变量
    const outputFormat = this.buildOutputFormatHint(profile);
    const mergedVars = { ...vars, output_format: outputFormat };

    const userPrompt = renderTemplate(profile.user_prompt_template, mergedVars);

    return {
      systemPrompt: profile.system_prompt,
      userPrompt,
      profileId: profile.profile_id,
    };
  }

  /**
   * 根据 profile 的 output_schema 和 constraints 构建输出格式提示。
   */
  private buildOutputFormatHint(profile: PromptProfile): string {
    const schemaLines = Object.entries(profile.output_schema)
      .map(([key, desc]) => `  "${key}": ${desc}`)
      .join('\n');

    const constraintLines = profile.constraints
      .map((c, i) => `${i + 1}. ${c}`)
      .join('\n');

    return `## 输出格式

严格输出以下 JSON，不要添加任何其他文本：

\`\`\`json
{
${schemaLines}
}
\`\`\`

## 约束条件
${constraintLines}`;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const promptProfileRegistry = new PromptProfileRegistry();
