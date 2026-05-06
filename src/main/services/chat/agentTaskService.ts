/**
 * Agent Task Service — Agent 任务执行服务
 *
 * 职责：
 * 1. 任务 CRUD
 * 2. 任务生命周期管理（pending → running → completed/failed/cancelled）
 * 3. 通过 SkillRegistry 执行技能
 * 4. 事件记录与通知
 */

import { randomUUID } from 'node:crypto';
import { BrowserWindow } from 'electron';
import type { AgentTask, AgentTaskEvent } from '../../../shared/types';
import { AGENT_TASKS_IPC_CHANNELS, DEFAULT_AGENT_PERMISSION_POLICY } from '../../../shared/types';
import { storage } from '../../storage';
import { logger } from '../../logger';
import { skillRegistry } from './skillRegistry';
import { permissionGuard } from './permissionGuard';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface CreateTaskParams {
  sessionId: string;
  name: string;
  skillName?: string;
  inputParams?: Record<string, unknown>;
}

// ---------------------------------------------------------------------------
// AgentTaskService
// ---------------------------------------------------------------------------

class AgentTaskService {
  private abortControllers: Map<string, AbortController> = new Map();

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------

  createTask(params: CreateTaskParams): AgentTask {
    const now = Math.floor(Date.now() / 1000);

    const task: AgentTask = {
      id: `task_${now}_${randomUUID().slice(0, 8)}`,
      sessionId: params.sessionId,
      name: params.name,
      status: 'pending',
      skillName: params.skillName,
      inputParams: params.inputParams ?? {},
      createdAt: now,
      updatedAt: now,
    };

    storage.insertAgentTask(task);
    this.addTaskEvent(task.id, 'started', `任务已创建: ${task.name}`);
    this.emitTaskChanged(task);

    logger.info('ai', 'agentTaskService', 'createTask', `Created task: ${task.id}`);
    return task;
  }

  getTask(id: string): AgentTask | null {
    return storage.getAgentTask(id);
  }

  listTasks(filter?: { status?: string; limit?: number; offset?: number }): AgentTask[] {
    return storage.listAllAgentTasks(filter);
  }

  updateTask(id: string, updates: Partial<AgentTask>): void {
    const existing = this.getTask(id);
    if (!existing) return;

    storage.updateAgentTask(id, updates);
    const updated = this.getTask(id);
    if (updated) {
      this.emitTaskChanged(updated);
    }
  }

  deleteTask(id: string): boolean {
    const existing = this.getTask(id);
    if (!existing) return false;

    // Cancel if running
    if (existing.status === 'running') {
      this.cancelTask(id);
    }

    storage.deleteAgentTask(id);
    logger.info('ai', 'agentTaskService', 'deleteTask', `Deleted task: ${id}`);
    return true;
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  async runTask(taskId: string): Promise<void> {
    const task = this.getTask(taskId);
    if (!task) {
      throw new Error(`任务不存在: ${taskId}`);
    }

    if (task.status === 'running') {
      throw new Error('任务正在运行中');
    }

    if (task.status === 'cancelled') {
      throw new Error('任务已被取消');
    }

    // Update status to running
    const now = Math.floor(Date.now() / 1000);
    storage.updateAgentTask(taskId, {
      status: 'running',
      startedAt: now,
      updatedAt: now,
    });

    this.addTaskEvent(taskId, 'started', `任务开始执行: ${task.name}`);
    const updatedTask = this.getTask(taskId)!;
    this.emitTaskChanged(updatedTask);

    // Create abort controller
    const abortController = new AbortController();
    this.abortControllers.set(taskId, abortController);

    try {
      await this.executeSkill(updatedTask);
    } catch (error) {
      // Check if cancelled
      if (abortController.signal.aborted) {
        storage.updateAgentTask(taskId, {
          status: 'cancelled',
          completedAt: Math.floor(Date.now() / 1000),
        });
        this.addTaskEvent(taskId, 'error', '任务已取消');
        const cancelledTask = this.getTask(taskId)!;
        this.emitTaskChanged(cancelledTask);
        return;
      }

      // Error
      const errorMsg = error instanceof Error ? error.message : String(error);
      storage.updateAgentTask(taskId, {
        status: 'failed',
        error: errorMsg,
        completedAt: Math.floor(Date.now() / 1000),
      });
      this.addTaskEvent(taskId, 'error', `任务执行失败: ${errorMsg}`);
      const failedTask = this.getTask(taskId)!;
      this.emitTaskChanged(failedTask);
      logger.error('ai', 'agentTaskService', 'runTask', `Task failed: ${taskId}`, { error: errorMsg });
    } finally {
      this.abortControllers.delete(taskId);
    }
  }

  cancelTask(taskId: string): void {
    const controller = this.abortControllers.get(taskId);
    if (controller) {
      controller.abort();
    }
  }

  // -------------------------------------------------------------------------
  // Events
  // -------------------------------------------------------------------------

  addTaskEvent(
    taskId: string,
    eventType: AgentTaskEvent['eventType'],
    description: string,
    metadata?: Record<string, unknown>,
  ): void {
    const now = Math.floor(Date.now() / 1000);
    const event: AgentTaskEvent = {
      id: `evt_${now}_${randomUUID().slice(0, 8)}`,
      taskId,
      eventType,
      description,
      metadata: metadata ?? {},
      createdAt: now,
    };

    storage.insertAgentTaskEvent(event);
  }

  getTaskEvents(taskId: string): AgentTaskEvent[] {
    return storage.listAgentTaskEvents(taskId);
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  private async executeSkill(task: AgentTask): Promise<void> {
    if (!task.skillName) {
      // No skill specified — just mark as completed
      storage.updateAgentTask(task.id, {
        status: 'completed',
        result: '任务完成（无关联技能）',
        completedAt: Math.floor(Date.now() / 1000),
      });
      this.addTaskEvent(task.id, 'result', '任务完成（无关联技能）');
      const completedTask = this.getTask(task.id)!;
      this.emitTaskChanged(completedTask);
      return;
    }

    const skill = skillRegistry.get(task.skillName);
    if (!skill) {
      throw new Error(`技能不存在: ${task.skillName}`);
    }

    // Permission check
    const proposal = {
      id: `auto_${task.id}`,
      type: 'run_skill' as const,
      label: `执行技能: ${skill.name}`,
      description: skill.description,
      riskLevel: (skill.requiresConfirmation ? 'confirm' : 'safe') as 'safe' | 'confirm' | 'danger',
      requiresConfirmation: skill.requiresConfirmation,
      target: skill.name,
      params: task.inputParams,
      createdAt: task.createdAt,
      status: 'proposed' as const,
    };

    const permissionCheck = permissionGuard.checkPermission(
      proposal,
      DEFAULT_AGENT_PERMISSION_POLICY,
    );

    if (!permissionCheck.allowed) {
      throw new Error(`权限不足: ${permissionCheck.reason}`);
    }

    // Execute skill
    const abortController = this.abortControllers.get(task.id);
    const context = {
      taskId: task.id,
      sessionId: task.sessionId,
      abortSignal: abortController?.signal ?? new AbortController().signal,
    };

    this.addTaskEvent(task.id, 'step', `开始执行技能: ${skill.name}`);

    const result = await skill.execute(task.inputParams, context);

    if (result.success) {
      storage.updateAgentTask(task.id, {
        status: 'completed',
        result: result.content,
        completedAt: Math.floor(Date.now() / 1000),
      });
      this.addTaskEvent(task.id, 'result', `技能执行成功: ${skill.name}`, result.metadata);
    } else {
      throw new Error(result.error || `技能 ${skill.name} 执行失败`);
    }

    const completedTask = this.getTask(task.id)!;
    this.emitTaskChanged(completedTask);
    logger.info('ai', 'agentTaskService', 'executeSkill', `Skill completed: ${skill.name}`);
  }

  private emitTaskChanged(task: AgentTask): void {
    const timestamp = Date.now();
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_TASKS_IPC_CHANNELS.TASK_CHANGED, {
          task,
          timestamp,
        });
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const agentTaskService = new AgentTaskService();
