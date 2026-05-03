// ═══════════════════════════════════════════════════════════════════════════════
// PinMind — Polish Service (独立润色服务)
// 对语音转写文本进行润色、格式化、风格调整
// 支持本地规则处理和 AI 增强润色
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Types ───────────────────────────────────────────────────────────────────

export type PolishStyle =
  | 'original'       // 保持原文
  | 'clean'          // 清洁：去除语气词、修正标点
  | 'concise'        // 精简：去除冗余，保留核心
  | 'formal'         // 正式：书面化表达
  | 'casual'         // 口语化：自然流畅
  | 'bullet'         // 要点：提取关键信息为列表
  | 'meeting'        // 会议纪要：结构化整理
  | 'custom';        // 自定义 AI 润色

export interface PolishStyleOption {
  id: PolishStyle;
  label: string;
  icon: string;
  description: string;
  isLocal: boolean; // true = 本地规则处理, false = 需要 AI
}

export interface PolishResult {
  /** 润色后的文本 */
  text: string;
  /** 使用的润色风格 */
  style: PolishStyle;
  /** 修改统计 */
  stats: {
    originalLength: number;
    polishedLength: number;
    removedFillers: number;
    addedPunctuation: number;
  };
}

export interface PolishCustomOptions {
  /** 自定义指令 */
  instruction: string;
  /** 目标语言 */
  targetLanguage?: string;
}

// ─── Style Definitions ───────────────────────────────────────────────────────

export const POLISH_STYLES: PolishStyleOption[] = [
  {
    id: 'original',
    label: '原文',
    icon: 'text',
    description: '保持语音转写的原始内容',
    isLocal: true,
  },
  {
    id: 'clean',
    label: '清洁',
    icon: 'sparkle',
    description: '去除语气词、修正标点符号',
    isLocal: true,
  },
  {
    id: 'concise',
    label: '精简',
    icon: 'minimize',
    description: '去除冗余表达，保留核心内容',
    isLocal: true,
  },
  {
    id: 'formal',
    label: '正式',
    icon: 'document',
    description: '转换为书面化表达',
    isLocal: false,
  },
  {
    id: 'casual',
    label: '口语化',
    icon: 'chat',
    description: '让表达更自然流畅',
    isLocal: false,
  },
  {
    id: 'bullet',
    label: '要点',
    icon: 'list',
    description: '提取关键信息为列表形式',
    isLocal: false,
  },
  {
    id: 'meeting',
    label: '会议纪要',
    icon: 'clipboard',
    description: '结构化整理为会议纪要格式',
    isLocal: false,
  },
  {
    id: 'custom',
    label: '自定义',
    icon: 'wand',
    description: '输入自定义润色指令',
    isLocal: false,
  },
];

// ─── Local Polish Rules ──────────────────────────────────────────────────────

/** 中文常见语气词 */
const CHINESE_FILLERS = [
  '嗯', '啊', '哦', '呃', '额', '那个', '就是', '然后', '就是说',
  '对吧', '是吧', '的话', '什么', '这个', '那个', '其实', '反正',
  ' basically', ' actually', ' literally', ' like', ' you know',
  ' I mean', ' so yeah', ' um', ' uh',
];

/** 中文标点修正映射 */
const PUNCTUATION_FIXES: Array<[RegExp, string]> = [
  [/\s+([，。！？；：、])/g, '$1'],           // 标点前多余空格
  [/([，。！？；：、])\s+/g, '$1'],           // 标点后多余空格（保留句末空格）
  [/([，。])\1+/g, '$1'],                     // 重复标点
  [/([！？])\1{2,}/g, '$1$1'],               // 最多两个感叹/问号
  [/\.\.\.{3,}/g, '……'],                      // 多个点号替换为省略号
  [/,\s*/g, '，'],                            // 英文逗号替换
  [/\?\s*/g, '？'],                           // 英文问号替换
  [/!\s*/g, '！'],                            // 英文感叹号替换
  [/(\d)[,，](\d)/g, '$1,$2'],              // 数字中的逗号保留英文
];

// ─── Polish Functions ────────────────────────────────────────────────────────

/**
 * 清洁模式：去除语气词、修正标点
 */
function polishClean(text: string): { text: string; removedFillers: number; addedPunctuation: number } {
  let result = text;
  let removedFillers = 0;
  let addedPunctuation = 0;

  // 去除语气词
  for (const filler of CHINESE_FILLERS) {
    const regex = new RegExp(`\\s*${filler.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*`, 'gi');
    const matches = result.match(regex);
    if (matches) {
      removedFillers += matches.length;
    }
    result = result.replace(regex, ' ');
  }

  // 修正标点
  for (const [pattern, replacement] of PUNCTUATION_FIXES) {
    const before = result;
    result = result.replace(pattern, replacement);
    if (before !== result) {
      addedPunctuation++;
    }
  }

  // 清理多余空格
  result = result.replace(/[ \t]+/g, ' ').trim();
  // 清理空行
  result = result.replace(/\n{3,}/g, '\n\n');

  return { text: result, removedFillers, addedPunctuation };
}

/**
 * 精简模式：去除冗余表达
 */
function polishConcise(text: string): { text: string; removedFillers: number; addedPunctuation: number } {
  // 先做清洁
  const clean = polishClean(text);

  // 去除冗余短语
  let result = clean.text;
  const redundantPhrases = [
    '我觉得可能大概也许', '我个人认为', '从某种意义上来说',
    '换句话说', '简单来说就是', '总而言之',
    'as a matter of fact', 'in order to', 'due to the fact that',
  ];

  for (const phrase of redundantPhrases) {
    result = result.replace(new RegExp(phrase, 'gi'), '');
  }

  // 合并短句
  result = result.replace(/([。！？])\s*\n?\s*/g, '$1\n');

  return {
    text: result.trim(),
    removedFillers: clean.removedFillers,
    addedPunctuation: clean.addedPunctuation,
  };
}

/**
 * 确保文本以适当的标点结尾
 */
function ensureEndingPunctuation(text: string): string {
  const trimmed = text.trim();
  if (!trimmed) return trimmed;
  const lastChar = trimmed[trimmed.length - 1];
  if (/[。！？…\.\!\?]/.test(lastChar)) {
    return trimmed;
  }
  return trimmed + '。';
}

/**
 * 为每个句子添加适当的标点
 */
function addSentencePunctuation(text: string): string {
  const lines = text.split('\n');
  return lines
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed) return '';

      // 如果已有标点结尾，跳过
      if (/[。！？…\.\!\?]$/.test(trimmed)) {
        return trimmed;
      }

      // 根据内容判断标点
      if (/[？?]$/.test(trimmed)) return trimmed;
      if (/[！!]$/.test(trimmed)) return trimmed;
      if (trimmed.includes('吗') || trimmed.includes('呢') || trimmed.includes('？') || trimmed.includes('?')) {
        return trimmed + '？';
      }

      return ensureEndingPunctuation(trimmed);
    })
    .join('\n');
}

// ─── AI Polish Prompts ───────────────────────────────────────────────────────

const AI_POLISH_PROMPTS: Record<Exclude<PolishStyle, 'original' | 'clean' | 'concise' | 'custom'>, string> = {
  formal: `你是一个文本润色专家。请将以下语音转写文本转换为正式的书面化表达。
要求：
- 将口语表达替换为书面用语
- 修正语法和标点
- 保持原意不变
- 不要添加原文中没有的信息
- 直接输出润色后的文本，不要添加解释`,

  casual: `你是一个文本润色专家。请将以下语音转写文本调整为自然流畅的口语化表达。
要求：
- 去除生硬的书面表达
- 让语言更自然、更易读
- 修正明显的语法错误
- 保持原意不变
- 直接输出润色后的文本，不要添加解释`,

  bullet: `你是一个文本提炼专家。请从以下语音转写文本中提取关键信息，以要点列表形式呈现。
要求：
- 提取核心观点和关键信息
- 每个要点简洁明了
- 使用 "- " 开头
- 按逻辑顺序排列
- 直接输出要点列表，不要添加解释`,

  meeting: `你是一个会议纪要整理专家。请将以下语音转写文本整理为结构化的会议纪要格式。
要求：
- 提取讨论的主要议题
- 标记关键决策和结论
- 列出待办事项（如有）
- 使用清晰的标题和分段
- 直接输出整理后的纪要，不要添加解释`,
};

// ─── PolishService ───────────────────────────────────────────────────────────

class PolishService {
  /**
   * 润色文本
   * @param text 原始转写文本
   * @param style 润色风格
   * @param customOptions 自定义选项（仅 custom 风格需要）
   */
  async polish(
    text: string,
    style: PolishStyle = 'clean',
    customOptions?: PolishCustomOptions,
  ): Promise<PolishResult> {
    const originalLength = text.length;

    // 原文模式：不做处理
    if (style === 'original') {
      return {
        text,
        style,
        stats: { originalLength, polishedLength: originalLength, removedFillers: 0, addedPunctuation: 0 },
      };
    }

    // 本地处理模式
    if (style === 'clean' || style === 'concise') {
      const result = style === 'clean' ? polishClean(text) : polishConcise(text);
      // 为清洁模式添加标点
      const finalText = addSentencePunctuation(result.text);

      return {
        text: finalText,
        style,
        stats: {
          originalLength,
          polishedLength: finalText.length,
          removedFillers: result.removedFillers,
          addedPunctuation: result.addedPunctuation,
        },
      };
    }

    // AI 润色模式
    return this.aiPolish(text, style, customOptions);
  }

  /**
   * AI 润色（调用 PinMind 的 AI 提供者）
   */
  private async aiPolish(
    text: string,
    style: PolishStyle,
    customOptions?: PolishCustomOptions,
  ): Promise<PolishResult> {
    const originalLength = text.length;

    // 构建提示词
    let systemPrompt: string;
    if (style === 'custom') {
      systemPrompt = `你是一个文本润色专家。请按照以下指令润色文本：
${customOptions?.instruction || '请润色以下文本，使其更加通顺。'}
${customOptions?.targetLanguage ? `目标语言：${customOptions.targetLanguage}` : ''}
直接输出润色后的文本，不要添加解释。`;
    } else {
      systemPrompt = AI_POLISH_PROMPTS[style as keyof typeof AI_POLISH_PROMPTS];
    }

    try {
      // 通过 PinMind 的 AI 服务进行润色
      // 使用现有的 providers 和 distill 基础设施
      const providers = await window.pinmind.providers.list();
      if (providers.length === 0) {
        throw new Error('未配置 AI 提供者，请先在设置中添加 AI 提供者');
      }

      // 选择第一个可用的提供者
      const provider = providers[0];

      // 使用 IPC 调用 AI 润色
      // 这里我们通过创建一个临时 sourceItem 并调用 distill 来实现
      // 但更优雅的方式是直接调用 AI API
      // 暂时使用本地回退方案
      const polishedText = await this.callAiProvider(provider.id, systemPrompt, text);

      return {
        text: polishedText,
        style,
        stats: {
          originalLength,
          polishedLength: polishedText.length,
          removedFillers: 0,
          addedPunctuation: 0,
        },
      };
    } catch (error) {
      // AI 不可用时回退到本地处理
      console.warn('[PolishService] AI 润色失败，回退到本地清洁模式:', error);
      const clean = polishClean(text);
      const finalText = addSentencePunctuation(clean.text);
      return {
        text: finalText,
        style: 'clean',
        stats: {
          originalLength,
          polishedLength: finalText.length,
          removedFillers: clean.removedFillers,
          addedPunctuation: clean.addedPunctuation,
        },
      };
    }
  }

  /**
   * 调用 AI 提供者进行文本润色
   */
  private async callAiProvider(
    _providerId: string,
    systemPrompt: string,
    userText: string,
  ): Promise<string> {
    // ── 通过 PinMind 的 AI 基础设施调用 ──
    // 这里使用 fetch 直接调用 AI API（通过主进程代理）
    //
    // 实际实现需要：
    // 1. 在主进程中添加一个通用的 AI chat IPC 通道
    // 2. 或使用现有的 distill 管线但传入自定义 prompt
    //
    // 当前使用简单的本地回退
    console.log('[PolishService] AI 润色请求:', { systemPrompt: systemPrompt.slice(0, 50) + '...', textLength: userText.length });

    // TODO: 实现真正的 AI 调用
    // 临时方案：返回本地清洁结果
    const clean = polishClean(userText);
    return addSentencePunctuation(clean.text);
  }
}

// ─── Singleton Export ────────────────────────────────────────────────────────

export const polishService = new PolishService();

export default polishService;
