/**
 * QuickCommandTemplates — 快捷命令模板
 *
 * 预定义的常用 Agent 指令，帮助用户快速发起对话
 */

export interface QuickCommand {
  id: string;
  label: string;
  prompt: string;
  icon?: string;
  description?: string;
}

export const QUICK_COMMANDS: QuickCommand[] = [
  {
    id: 'organize-pins',
    label: '整理暂存',
    prompt: '帮我整理暂存池中的所有内容，给出蒸馏建议',
    icon: 'duplicate',
    description: '分析暂存内容并提供整理建议',
  },
  {
    id: 'summarize-content',
    label: '总结内容',
    prompt: '总结我最近收集的内容，生成一份简要报告',
    icon: 'edit',
    description: '生成近期收集内容的摘要报告',
  },
  {
    id: 'generate-todos',
    label: '生成待办',
    prompt: '根据当前暂存内容，帮我生成待办事项清单',
    icon: 'filled-flag',
    description: '从暂存内容提取待办任务',
  },
  {
    id: 'distill-inbox',
    label: '蒸馏收集箱',
    prompt: '帮我蒸馏收集箱中的所有条目，提取关键信息',
    icon: 'ai-workspace',
    description: '对收集箱内容进行 AI 蒸馏',
  },
  {
    id: 'export-ready',
    label: '导出就绪项',
    prompt: '帮我导出所有已蒸馏完成的内容到知识库',
    icon: 'act-output',
    description: '批量导出已完成的蒸馏内容',
  },
  {
    id: 'search-knowledge',
    label: '搜索知识库',
    prompt: '帮我搜索知识库中与当前话题相关的内容',
    icon: 'search',
    description: '在知识库中搜索相关信息',
  },
];

/**
 * 根据 ID 获取快捷命令
 */
export function getQuickCommandById(id: string): QuickCommand | undefined {
  return QUICK_COMMANDS.find((cmd) => cmd.id === id);
}

/**
 * 根据标签获取对应的 prompt
 */
export function getPromptByLabel(label: string): string | undefined {
  const cmd = QUICK_COMMANDS.find((c) => c.label === label);
  return cmd?.prompt;
}

/**
 * 获取所有快捷命令标签（用于兼容性）
 */
export function getQuickCommandLabels(): string[] {
  return QUICK_COMMANDS.map((cmd) => cmd.label);
}
