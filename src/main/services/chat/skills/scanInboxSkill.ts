/**
 * scanInboxSkill — 扫描暂存池/收集箱
 *
 * 读取 capture_items 表，返回待处理条目摘要。
 * 只读操作，安全等级 safe。
 */

import type { AgentSkill, SkillContext, SkillResult } from '../skillRegistry';
import { storage } from '../../../storage';

const scanInboxSkill: AgentSkill = {
  name: 'scan_inbox',
  description: '扫描暂存池/收集箱，返回待处理条目的摘要信息',
  parameters: {
    type: 'object',
    properties: {
      limit: {
        type: 'number',
        description: '最大返回条目数，默认 20',
      },
    },
  },
  category: 'read',
  requiresConfirmation: false,

  async execute(params: Record<string, unknown>, _context: SkillContext): Promise<SkillResult> {
    try {
      const limit = (params.limit as number) ?? 20;
      const items = storage.getCaptureItems({ limit, status: 'pending' });

      if (items.length === 0) {
        return {
          success: true,
          content: '暂存池为空，没有待处理的条目。',
          metadata: { count: 0 },
        };
      }

      const summary = items.map((item, idx) => {
        const preview = item.rawText
          ? (item.rawText.length > 80 ? item.rawText.slice(0, 80) + '...' : item.rawText)
          : '(无预览)';
        return `${idx + 1}. [${item.type}] ${item.title || preview}`;
      }).join('\n');

      return {
        success: true,
        content: `暂存池共有 ${items.length} 条待处理条目：\n\n${summary}`,
        metadata: { count: items.length, types: [...new Set(items.map(i => i.type))] },
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      return {
        success: false,
        content: '',
        error: errorMsg,
      };
    }
  },
};

export default scanInboxSkill;
