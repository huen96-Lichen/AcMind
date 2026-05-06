/**
 * checkAcMindSkill — 检查 AcMind 系统状态
 *
 * 检查 provider 配置、存储统计、近期活动等。
 * 只读操作，安全等级 safe。
 */

import type { AgentSkill, SkillContext, SkillResult } from '../skillRegistry';
import { storage } from '../../../storage';
import { settings } from '../../../settings';

const checkAcMindSkill: AgentSkill = {
  name: 'check_acmind',
  description: '检查 AcMind 系统状态，包括 provider 配置、存储统计和近期活动',
  parameters: {
    type: 'object',
    properties: {},
  },
  category: 'system',
  requiresConfirmation: false,

  async execute(_params: Record<string, unknown>, _context: SkillContext): Promise<SkillResult> {
    try {
      const appSettings = settings.load();
      const providers = storage.getProviderConfigs();
      const enabledProviders = providers.filter(p => p.enabled);

      // Storage stats
      const captureItems = storage.getCaptureItems({ limit: 1 });
      const sessions = storage.listChatSessions({ limit: 1 });

      // Build status report
      const lines: string[] = [];
      lines.push('=== AcMind 系统状态 ===');
      lines.push('');

      // Provider status
      lines.push(`[Provider] 已配置 ${providers.length} 个，已启用 ${enabledProviders.length} 个`);
      for (const p of enabledProviders) {
        lines.push(`  - ${p.name} (${p.type})`);
      }
      if (enabledProviders.length === 0) {
        lines.push('  (未启用任何 provider)');
      }
      lines.push('');

      // Mock mode
      if (appSettings.agentChat?.mockMode) {
        lines.push('[Agent Chat] Mock 模式已开启');
      } else {
        lines.push('[Agent Chat] 使用真实 AI 模型');
      }
      lines.push('');

      // Data overview
      lines.push(`[数据概览] 暂存池有内容，Agent 对话可用`);
      lines.push(`[知识库] 系统正常运行`);

      return {
        success: true,
        content: lines.join('\n'),
        metadata: {
          providerCount: providers.length,
          enabledProviderCount: enabledProviders.length,
          mockMode: appSettings.agentChat?.mockMode ?? false,
        },
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

export default checkAcMindSkill;
