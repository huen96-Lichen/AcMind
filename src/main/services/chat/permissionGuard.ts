/**
 * PermissionGuard — Agent 操作权限守卫
 *
 * 职责：
 * 1. 检查 AgentActionProposal 是否符合权限策略
 * 2. 根据 action type 和 riskLevel 判断是否需要确认
 * 3. 提供标准化的权限检查结果
 */

import type { AgentActionProposal, AgentPermissionPolicy } from '../../../shared/types';

export interface PermissionCheckResult {
  allowed: boolean;
  reason?: string;
  requiresConfirmation: boolean;
  riskLevel: 'safe' | 'confirm' | 'danger';
}

export class PermissionGuard {
  /**
   * 检查操作是否被允许
   */
  checkPermission(
    action: AgentActionProposal,
    policy: AgentPermissionPolicy
  ): PermissionCheckResult {
    // 1. 检查 action type 是否被允许
    const typeAllowed = this.isActionAllowed(action.type, policy);
    if (!typeAllowed) {
      return {
        allowed: false,
        reason: `操作类型 "${action.type}" 已被权限策略禁止`,
        requiresConfirmation: false,
        riskLevel: action.riskLevel,
      };
    }

    // 2. 根据 riskLevel 判断是否需要确认
    const requiresConfirmation = action.requiresConfirmation || action.riskLevel !== 'safe';

    // 3. 对于危险操作，即使策略允许也需要确认
    if (action.riskLevel === 'danger' && !policy.allowRunShell) {
      // danger 操作通常需要 shell 权限或其他高风险权限
      // 如果策略禁止了相关权限，则拒绝
      if (action.type === 'run_skill' || action.type === 'create_task') {
        // 这些操作可能涉及系统级变更，需要额外检查
        return {
          allowed: false,
          reason: '危险操作需要启用高级权限（allowRunShell）',
          requiresConfirmation: false,
          riskLevel: 'danger',
        };
      }
    }

    return {
      allowed: true,
      requiresConfirmation,
      riskLevel: action.riskLevel,
    };
  }

  /**
   * 检查特定 action type 是否被策略允许
   */
  isActionAllowed(type: AgentActionProposal['type'], policy: AgentPermissionPolicy): boolean {
    switch (type) {
      case 'navigate':
        return policy.allowNavigate;

      case 'open_file':
        // open_file 需要读权限
        return policy.allowReadInbox || policy.allowReadObsidianInbox;

      case 'distill':
        // distill 需要读权限和写权限（生成蒸馏结果）
        return policy.allowReadInbox && policy.allowWriteMarkdown;

      case 'export':
        // export 需要写权限
        return policy.allowWriteMarkdown;

      case 'scan':
        // scan 需要读权限
        return policy.allowReadInbox || policy.allowReadObsidianInbox;

      case 'run_skill':
        // run_skill 可能需要 shell 权限
        return policy.allowRunShell;

      case 'create_task':
        // create_task 需要写权限
        return policy.allowWriteMarkdown;

      default:
        // 未知类型默认拒绝
        return false;
    }
  }

  /**
   * 获取 risk level 对应的颜色
   */
  getRiskLevelColor(riskLevel: AgentActionProposal['riskLevel']): string {
    switch (riskLevel) {
      case 'safe':
        return 'green';
      case 'confirm':
        return 'yellow';
      case 'danger':
        return 'red';
      default:
        return 'gray';
    }
  }

  /**
   * 获取 risk level 对应的描述
   */
  getRiskLevelDescription(riskLevel: AgentActionProposal['riskLevel']): string {
    switch (riskLevel) {
      case 'safe':
        return '安全操作';
      case 'confirm':
        return '需要确认';
      case 'danger':
        return '危险操作';
      default:
        return '未知风险';
    }
  }
}

// 单例导出
export const permissionGuard = new PermissionGuard();
