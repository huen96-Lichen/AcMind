/**
 * scanObsidianInboxSkill — 扫描 Obsidian Inbox
 *
 * 读取 Obsidian vault 中 inbox 目录的未处理文件。
 * 只读操作，安全等级 safe。
 */

import fs from 'node:fs';
import path from 'node:path';
import type { AgentSkill, SkillContext, SkillResult } from '../skillRegistry';
import { storage } from '../../../storage';

const scanObsidianInboxSkill: AgentSkill = {
  name: 'scan_obsidian_inbox',
  description: '扫描 Obsidian vault 的 inbox 目录，列出未处理的文件',
  parameters: {
    type: 'object',
    properties: {
      limit: {
        type: 'number',
        description: '最大返回文件数，默认 20',
      },
    },
  },
  category: 'read',
  requiresConfirmation: false,

  async execute(params: Record<string, unknown>, _context: SkillContext): Promise<SkillResult> {
    try {
      const limit = (params.limit as number) ?? 20;

      // Get vault config
      const vaultConfig = storage.getVaultConfig();
      if (!vaultConfig || !vaultConfig.vaultPath) {
        return {
          success: true,
          content: '未配置 Obsidian vault 路径，无法扫描 inbox。',
          metadata: { configured: false },
        };
      }

      const vaultPath = vaultConfig.vaultPath;
      const inboxDir = path.join(vaultPath, 'inbox');

      // Check if inbox directory exists
      if (!fs.existsSync(inboxDir)) {
        return {
          success: true,
          content: `Inbox 目录不存在: ${inboxDir}\n请先在 Obsidian vault 中创建 inbox 文件夹。`,
          metadata: { configured: true, inboxExists: false },
        };
      }

      // List files in inbox
      const entries = fs.readdirSync(inboxDir, { withFileTypes: true })
        .filter(entry => entry.isFile())
        .map(entry => ({
          name: entry.name,
          path: path.join(inboxDir, entry.name),
          size: fs.statSync(path.join(inboxDir, entry.name)).size,
          mtime: fs.statSync(path.join(inboxDir, entry.name)).mtimeMs,
        }))
        .sort((a, b) => b.mtime - a.mtime)
        .slice(0, limit);

      if (entries.length === 0) {
        return {
          success: true,
          content: 'Obsidian inbox 为空，没有未处理的文件。',
          metadata: { configured: true, inboxExists: true, count: 0 },
        };
      }

      const summary = entries.map((entry, idx) => {
        const sizeStr = entry.size > 1024 ? `${(entry.size / 1024).toFixed(1)}KB` : `${entry.size}B`;
        const dateStr = new Date(entry.mtime).toLocaleDateString('zh-CN');
        return `${idx + 1}. ${entry.name} (${sizeStr}, ${dateStr})`;
      }).join('\n');

      return {
        success: true,
        content: `Obsidian inbox 中有 ${entries.length} 个文件：\n\n${summary}`,
        metadata: { configured: true, inboxExists: true, count: entries.length },
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

export default scanObsidianInboxSkill;
