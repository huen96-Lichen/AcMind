/**
 * actionHandlers — Agent Action Proposal 执行处理器
 *
 * 职责：
 * 1. 处理各类 action proposal 的执行
 * 2. 与 AcMind 主应用交互（导航、蒸馏、导出等）
 * 3. 提供统一的错误处理和反馈
 *
 * 注意：本文件使用可选链操作符访问 window.acmind API，因为 Phase B
 * 部分 API 可能尚未在主进程中实现。这些调用会优雅降级为导航操作。
 */

import type { AgentActionProposal } from '../../../shared/types';

export interface ActionResult {
  success: boolean;
  message?: string;
  error?: string;
  data?: Record<string, unknown>;
}

/**
 * 处理导航操作
 */
export function handleNavigate(target: string, params?: Record<string, unknown>): ActionResult {
  try {
    // 使用 acmind:navigate 事件系统
    window.dispatchEvent(
      new CustomEvent('acmind:navigate', {
        detail: { view: target, params },
      }),
    );
    return { success: true, message: `已导航到 ${target}` };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : '导航失败',
    };
  }
}

/**
 * 处理蒸馏操作
 */
export async function handleDistill(params?: Record<string, unknown>): Promise<ActionResult> {
  try {
    const sourceItemIds = params?.sourceItemIds as string[] | undefined;

    if (!sourceItemIds || sourceItemIds.length === 0) {
      // 导航到蒸馏页面
      handleNavigate('capture-inbox', { autoDistill: true });
      return { success: true, message: '已打开蒸馏页面' };
    }

    // 调用主进程执行批量蒸馏（使用可选链，API 可能尚未实现）
    const result = await window.acmind.distill?.bridgeAndRunBatch?.(sourceItemIds);

    if (result && 'batchId' in result) {
      return {
        success: true,
        message: `已启动蒸馏任务，共 ${sourceItemIds.length} 个条目`,
        data: { batchId: result.batchId },
      };
    } else {
      // API 未实现时，降级为导航操作
      handleNavigate('capture-inbox', { autoDistill: true, sourceItemIds });
      return {
        success: true,
        message: '已打开蒸馏页面（批量蒸馏 API 准备中）',
      };
    }
  } catch (error) {
    // 出错时降级为导航
    handleNavigate('capture-inbox', { autoDistill: true });
    return {
      success: true,
      message: '已打开蒸馏页面',
    };
  }
}

/**
 * 处理导出操作
 */
export async function handleExport(params?: Record<string, unknown>): Promise<ActionResult> {
  try {
    const sourceItemIds = params?.sourceItemIds as string[] | undefined;
    const knowledgeCardIds = params?.knowledgeCardIds as string[] | undefined;

    if (!sourceItemIds && !knowledgeCardIds) {
      // 导航到导出页面
      handleNavigate('knowledge-cards', { autoExport: true });
      return { success: true, message: '已打开知识库页面' };
    }

    // 调用主进程执行批量导出（使用可选链，API 可能尚未实现）
    // export.batch 只接受 distilledOutputIds 参数
    const distilledOutputIds = sourceItemIds ?? knowledgeCardIds ?? [];
    const result = distilledOutputIds.length > 0 ? await window.acmind.export?.batch?.(distilledOutputIds) : null;

    if (Array.isArray(result) && result.length > 0) {
      return {
        success: true,
        message: `已启动导出任务，共 ${result.length} 个条目`,
        data: { exportCount: result.length },
      };
    } else {
      // API 未实现时，降级为导航操作
      handleNavigate('knowledge-cards', { autoExport: true, sourceItemIds, knowledgeCardIds });
      return {
        success: true,
        message: '已打开知识库页面（批量导出 API 准备中）',
      };
    }
  } catch (error) {
    // 出错时降级为导航
    handleNavigate('knowledge-cards', { autoExport: true });
    return {
      success: true,
      message: '已打开知识库页面',
    };
  }
}

/**
 * 处理扫描操作
 */
export async function handleScan(params?: Record<string, unknown>): Promise<ActionResult> {
  try {
    const scanType = (params?.scanType as string) ?? 'inbox';

    switch (scanType) {
      case 'inbox':
        handleNavigate('capture-inbox');
        return { success: true, message: '已打开收集箱' };

      case 'knowledge':
        handleNavigate('knowledge-cards');
        return { success: true, message: '已打开知识库' };

      case 'staging':
        handleNavigate('staging-pool');
        return { success: true, message: '已打开暂存池' };

      default:
        return {
          success: false,
          error: `未知的扫描类型: ${scanType}`,
        };
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : '扫描操作失败',
    };
  }
}

/**
 * 处理打开文件操作
 */
export function handleOpenFile(filePath: string, params?: Record<string, unknown>): ActionResult {
  try {
    window.dispatchEvent(
      new CustomEvent('acmind:openFile', {
        detail: { filePath, params },
      }),
    );
    return { success: true, message: `已打开文件 ${filePath}` };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : '打开文件失败',
    };
  }
}

/**
 * 处理运行技能操作
 */
export async function handleRunSkill(skillName: string, params?: Record<string, unknown>): Promise<ActionResult> {
  try {
    // 调用主进程执行技能（使用可选链，API 可能尚未实现）
    const runSkillFn = (
      window.acmind.agentChat as unknown as Record<
        string,
        (
          name: string,
          params?: Record<string, unknown>,
        ) => Promise<{ success: boolean; data?: unknown; error?: string }>
      >
    )?.runSkill;
    const result = await runSkillFn?.(skillName, params);

    if (result?.success) {
      return {
        success: true,
        message: `技能 "${skillName}" 执行成功`,
        data: result.data as Record<string, unknown> | undefined,
      };
    } else {
      // API 未实现时，降级为提示
      return {
        success: false,
        error: result?.error || `技能 "${skillName}" 执行功能准备中`,
      };
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : '技能执行失败',
    };
  }
}

/**
 * 处理创建任务操作
 */
export async function handleCreateTask(params?: Record<string, unknown>): Promise<ActionResult> {
  try {
    const taskName = params?.name as string | undefined;
    const taskDescription = params?.description as string | undefined;

    if (!taskName) {
      return {
        success: false,
        error: '任务名称不能为空',
      };
    }

    // 调用主进程创建任务（使用可选链，API 可能尚未实现）
    const createTaskFn = (
      window.acmind.agentChat as unknown as Record<
        string,
        (params: Record<string, unknown>) => Promise<{ success: boolean; taskId?: string; error?: string }>
      >
    )?.createTask;
    const result = await createTaskFn?.({
      name: taskName,
      description: taskDescription,
      ...params,
    });

    if (result?.success) {
      return {
        success: true,
        message: `任务 "${taskName}" 创建成功`,
        data: { taskId: result.taskId },
      };
    } else {
      // API 未实现时，降级为提示
      return {
        success: false,
        error: result?.error || '任务创建功能准备中',
      };
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : '创建任务失败',
    };
  }
}

/**
 * 统一的 action 执行入口
 */
export async function executeAction(proposal: AgentActionProposal): Promise<ActionResult> {
  switch (proposal.type) {
    case 'navigate':
      if (!proposal.target) {
        return { success: false, error: '导航目标不能为空' };
      }
      return handleNavigate(proposal.target, proposal.params);

    case 'open_file':
      if (!proposal.target) {
        return { success: false, error: '文件路径不能为空' };
      }
      return handleOpenFile(proposal.target, proposal.params);

    case 'distill':
      return handleDistill(proposal.params);

    case 'export':
      return handleExport(proposal.params);

    case 'scan':
      return handleScan(proposal.params);

    case 'run_skill':
      if (!proposal.target) {
        return { success: false, error: '技能名称不能为空' };
      }
      return handleRunSkill(proposal.target, proposal.params);

    case 'create_task':
      return handleCreateTask(proposal.params);

    default:
      return {
        success: false,
        error: `未知的操作类型: ${(proposal as AgentActionProposal).type}`,
      };
  }
}
