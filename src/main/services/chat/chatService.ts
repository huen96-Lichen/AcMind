/**
 * Chat Service — Agent 对话服务
 *
 * 职责：
 * 1. 管理会话和消息的 CRUD
 * 2. 处理消息发送和流式响应
 * 3. 支持 Mock 模式（无需 LLM 配置）
 * 4. 通过 IPC 推送流式 chunks 到渲染进程
 */

import { randomUUID } from 'node:crypto';
import { BrowserWindow } from 'electron';
import type {
  ChatSession,
  ChatMessage,
  ChatSessionMetadata,
  AgentChatConfig,
  ProviderConfig,
  AgentActionProposal,
  AgentPermissionPolicy,
} from '../../../shared/types';
import { AGENT_CHAT_IPC_CHANNELS } from '../../../shared/types';
import { storage } from '../../storage';
import { settings } from '../../settings';
import { aiProviderService, type ChatMessage as AiChatMessage } from '../aiHub/aiProviderService';
import { logger } from '../../logger';
import { permissionGuard, type PermissionCheckResult } from './permissionGuard';
import { agentTaskService } from './agentTaskService';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SendMessageOptions {
  sessionId: string;
  content: string;
  provider?: ProviderConfig;
  systemPrompt?: string;
}

export interface ChatServiceStatus {
  isGenerating: boolean;
  currentSessionId: string | null;
  currentMessageId: string | null;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MOCK_RESPONSES = [
  '这是一个 Mock 响应。在设置中关闭 Mock 模式以使用真实 AI 模型。',
  '收到！这是一个模拟回复，用于测试 UI 功能。',
  'Mock Mode: 我可以帮你整理暂存内容、总结知识库、生成待办事项等。',
  '（模拟回复）你可以尝试发送"整理暂存"、"总结内容"或"生成待办"等快捷指令。',
];

const QUICK_COMMAND_RESPONSES: Record<string, string> = {
  '整理暂存': '我来帮你整理暂存池中的内容...\n\n发现 3 条暂存内容：\n1. 截图笔记 - 建议归档到知识库\n2. 语音备忘录 - 建议提取关键任务\n3. 网页链接 - 建议稍后阅读\n\n需要我执行这些操作吗？',
  '总结内容': '根据你最近收集的内容，我来生成一份总结...\n\n**本周收集摘要**\n- 共收集 12 条内容\n- 3 条已完成整理\n- 2 条待归档\n- 主要主题：AI 工具、项目管理、读书笔记\n\n建议：将 AI 工具相关内容整理成一个专题。',
  '生成待办': '根据你的暂存内容，我提取了以下待办事项：\n\n1. [ ] 整理截图笔记到知识库\n2. [ ] 回复客户邮件（来自语音备忘录）\n3. [ ] 阅读并总结网页文章\n4. [ ] 更新项目进度文档\n\n需要我将这些添加到任务系统吗？',
};

// ---------------------------------------------------------------------------
// ChatService
// ---------------------------------------------------------------------------

class ChatService {
  private abortController: AbortController | null = null;
  private status: ChatServiceStatus = {
    isGenerating: false,
    currentSessionId: null,
    currentMessageId: null,
  };

  // -------------------------------------------------------------------------
  // Session CRUD
  // -------------------------------------------------------------------------

  listSessions(filter?: { status?: 'active' | 'archived' | 'deleted'; limit?: number; offset?: number }): ChatSession[] {
    return storage.listChatSessions(filter);
  }

  getSession(id: string): ChatSession | null {
    return storage.getChatSession(id);
  }

  createSession(params?: { title?: string; metadata?: ChatSessionMetadata; providerId?: string; modelId?: string }): ChatSession {
    const now = Math.floor(Date.now() / 1000);
    const config = this.getConfig();

    const session: ChatSession = {
      id: `session_${now}_${randomUUID().slice(0, 8)}`,
      title: params?.title?.trim() || '新对话',
      providerId: params?.providerId ?? config.defaultProviderId,
      modelId: params?.modelId ?? config.defaultModelId,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      metadata: params?.metadata ?? { contextType: 'none' },
    };

    storage.insertChatSession(session);
    this.emitSessionChanged('created', session.id);
    return session;
  }

  updateSession(id: string, patch: Partial<ChatSession>): ChatSession | null {
    const existing = this.getSession(id);
    if (!existing) return null;

    storage.updateChatSession(id, patch);
    this.emitSessionChanged('updated', id);
    return this.getSession(id);
  }

  deleteSession(id: string): boolean {
    const existing = this.getSession(id);
    if (!existing) return false;

    // Soft delete: mark as deleted
    storage.updateChatSession(id, { status: 'deleted' });
    this.emitSessionChanged('deleted', id);
    return true;
  }

  // -------------------------------------------------------------------------
  // Message CRUD
  // -------------------------------------------------------------------------

  listMessages(sessionId: string, filter?: { limit?: number }): ChatMessage[] {
    return storage.listChatMessages(sessionId, filter);
  }

  getMessage(id: string): ChatMessage | null {
    return storage.getChatMessage(id);
  }

  createMessage(params: {
    sessionId: string;
    role: ChatMessage['role'];
    content: string;
    status?: ChatMessage['status'];
    modelId?: string | null;
    providerId?: string | null;
  }): ChatMessage {
    const now = Math.floor(Date.now() / 1000);

    const message: ChatMessage = {
      id: `msg_${now}_${randomUUID().slice(0, 8)}`,
      sessionId: params.sessionId,
      role: params.role,
      content: params.content,
      status: params.status ?? 'pending',
      modelId: params.modelId ?? null,
      providerId: params.providerId ?? null,
      promptTokens: null,
      completionTokens: null,
      latencyMs: null,
      error: null,
      createdAt: now,
    };

    storage.insertChatMessage(message);

    // Update session updatedAt
    storage.updateChatSession(params.sessionId, { updatedAt: now });

    this.emitMessageChanged('created', message.id, params.sessionId);
    return message;
  }

  updateMessage(id: string, patch: Partial<ChatMessage>): ChatMessage | null {
    const existing = this.getMessage(id);
    if (!existing) return null;

    storage.updateChatMessage(id, patch);
    this.emitMessageChanged('updated', id, existing.sessionId);
    return this.getMessage(id);
  }

  createSystemMessage(sessionId: string, content: string): ChatMessage {
    return this.createMessage({
      sessionId,
      role: 'system',
      content,
      status: 'completed',
    });
  }

  /** M1: 静默更新消息（不触发 message.changed 事件），用于流式期间避免不必要的 IPC 通知 */
  private updateMessageSilent(id: string, patch: Partial<ChatMessage>): void {
    storage.updateChatMessage(id, patch);
  }

  // -------------------------------------------------------------------------
  // Send Message (with streaming)
  // -------------------------------------------------------------------------

  async sendMessage(options: SendMessageOptions): Promise<{ success: boolean; messageId?: string; error?: string }> {
    // C1: 并发锁 — 防止重复发送
    if (this.status.isGenerating) {
      return { success: false, error: '正在生成中，请等待完成或中断' };
    }

    const config = this.getConfig();

    // Create user message
    const userMessage = this.createMessage({
      sessionId: options.sessionId,
      role: 'user',
      content: options.content,
      status: 'completed',
    });

    // Create assistant message (pending)
    const assistantMessage = this.createMessage({
      sessionId: options.sessionId,
      role: 'assistant',
      content: '',
      status: 'streaming',
      modelId: options.provider?.modelId ?? config.defaultModelId,
      providerId: options.provider?.id ?? config.defaultProviderId,
    });

    this.status = {
      isGenerating: true,
      currentSessionId: options.sessionId,
      currentMessageId: assistantMessage.id,
    };

    // C2: AbortController 在 mock/real 分支之前创建，确保 stopGeneration 对两种路径都有效
    this.abortController = new AbortController();
    const { signal } = this.abortController;

    try {
      if (config.mockMode) {
        await this.runMockResponse(assistantMessage.id, options.content, signal);
      } else {
        await this.runLLMResponse(assistantMessage.id, options, signal);
      }

      return { success: true, messageId: assistantMessage.id };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'chatService', 'sendMessage', errorMsg);

      this.updateMessage(assistantMessage.id, {
        status: 'error',
        error: errorMsg,
      });

      this.emitStreamError(assistantMessage.id, errorMsg);

      return { success: false, messageId: assistantMessage.id, error: errorMsg };
    } finally {
      this.status = {
        isGenerating: false,
        currentSessionId: null,
        currentMessageId: null,
      };
      this.abortController = null;
    }
  }

  // -------------------------------------------------------------------------
  // Mock Response
  // -------------------------------------------------------------------------

  private async runMockResponse(messageId: string, userContent: string, signal?: AbortSignal): Promise<void> {
    // Check for quick command responses
    let responseText = QUICK_COMMAND_RESPONSES[userContent];

    if (!responseText) {
      // Check if content contains quick command keywords
      if (userContent.includes('整理暂存') || userContent.includes('整理')) {
        responseText = QUICK_COMMAND_RESPONSES['整理暂存'];
      } else if (userContent.includes('总结') || userContent.includes('摘要')) {
        responseText = QUICK_COMMAND_RESPONSES['总结内容'];
      } else if (userContent.includes('待办') || userContent.includes('任务')) {
        responseText = QUICK_COMMAND_RESPONSES['生成待办'];
      } else {
        // Random mock response
        responseText = MOCK_RESPONSES[Math.floor(Math.random() * MOCK_RESPONSES.length)];
      }
    }

    // Simulate streaming with chunks
    const chunks = responseText.split('');
    let accumulatedContent = '';

    for (let i = 0; i < chunks.length; i++) {
      // Check if aborted (via signal or legacy abortController)
      if (signal?.aborted || this.abortController?.signal.aborted) {
        this.updateMessage(messageId, {
          status: 'interrupted',
          content: accumulatedContent,
        });
        this.emitStreamDone(messageId, true);
        return;
      }

      // Simulate network delay
      await this.delay(20);

      accumulatedContent += chunks[i];

      // Emit chunk every few characters
      if (i % 3 === 0 || i === chunks.length - 1) {
        this.updateMessageSilent(messageId, { content: accumulatedContent });
        this.emitStreamChunk(messageId, chunks[i], accumulatedContent);
      }
    }

    // Generate action proposals based on content
    const actionProposals = this.generateActionProposals(userContent);

    this.updateMessage(messageId, {
      status: 'completed',
      content: accumulatedContent,
      actionProposals,
    });

    this.emitStreamDone(messageId, false);
  }

  // -------------------------------------------------------------------------
  // LLM Response (real streaming)
  // -------------------------------------------------------------------------

  private async runLLMResponse(messageId: string, options: SendMessageOptions, signal?: AbortSignal): Promise<void> {
    const config = this.getConfig();

    if (!options.provider) {
      throw new Error('未配置 AI Provider，请在设置中配置或开启 Mock 模式');
    }

    // Build message history
    const history = this.buildMessageHistory(options.sessionId, config.maxContextMessages);

    // Add current user message
    const messages: AiChatMessage[] = [
      ...history,
      { role: 'user', content: options.content },
    ];

    // Add system prompt if provided
    if (options.systemPrompt) {
      messages.unshift({ role: 'system', content: options.systemPrompt });
    }

    const startTime = Date.now();
    let accumulatedContent = '';
    let promptTokens: number | undefined;
    let completionTokens: number | undefined;

    try {
      for await (const chunk of aiProviderService.callStream(
        options.provider,
        messages,
        {
          timeoutMs: config.timeoutMs,
          temperature: 0.7,
        },
        signal ?? this.abortController?.signal
      )) {
        if (chunk.promptTokens) promptTokens = chunk.promptTokens;
        if (chunk.completionTokens) completionTokens = chunk.completionTokens;

        if (chunk.content) {
          accumulatedContent += chunk.content;
          this.updateMessageSilent(messageId, { content: accumulatedContent });
          this.emitStreamChunk(messageId, chunk.content, accumulatedContent);
        }

        if (chunk.done) break;
      }

      const latencyMs = Date.now() - startTime;

      // Generate action proposals
      const actionProposals = this.generateActionProposals(options.content);

      this.updateMessage(messageId, {
        status: 'completed',
        content: accumulatedContent,
        promptTokens: promptTokens ?? null,
        completionTokens: completionTokens ?? null,
        latencyMs,
        actionProposals,
      });

      this.emitStreamDone(messageId, false);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);

      // Check if aborted
      if (this.abortController?.signal.aborted) {
        this.updateMessage(messageId, {
          status: 'interrupted',
          content: accumulatedContent,
        });
        this.emitStreamDone(messageId, true);
        return;
      }

      throw error;
    }
  }

  // -------------------------------------------------------------------------
  // Stop Generation
  // -------------------------------------------------------------------------

  stopGeneration(): boolean {
    if (this.abortController) {
      this.abortController.abort();
      return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  private getConfig(): AgentChatConfig {
    const appSettings = settings.load();
    return appSettings.agentChat;
  }

  private buildMessageHistory(sessionId: string, maxMessages: number): AiChatMessage[] {
    const messages = this.listMessages(sessionId, { limit: maxMessages });

    return messages
      .filter(m => m.status === 'completed' && m.role !== 'system')
      .map(m => ({
        role: m.role as AiChatMessage['role'],
        content: m.content,
      }));
  }

  private generateActionProposals(userContent: string): AgentActionProposal[] {
    const proposals: AgentActionProposal[] = [];
    const now = Math.floor(Date.now() / 1000);
    const text = userContent.toLowerCase();

    const pushProposal = (proposal: AgentActionProposal): void => {
      if (!proposals.some((item) => item.type === proposal.type && item.target === proposal.target)) {
        proposals.push(proposal);
      }
    };

    // Check for navigation suggestions
    if (userContent.includes('暂存') || userContent.includes('inbox') || text.includes('staging')) {
      pushProposal({
        id: `action_${now}_1`,
        type: 'navigate',
        label: '查看工作台',
        description: '跳转到工作台的暂存与整理区域',
        riskLevel: 'safe',
        requiresConfirmation: false,
        target: 'workbench',
        createdAt: now,
        status: 'proposed',
      });
    }

    if (userContent.includes('整理') || userContent.includes('审阅') || text.includes('distill')) {
      pushProposal({
        id: `action_${now}_2`,
        type: 'navigate',
        label: '去工作台整理',
        description: '跳转到工作台的整理/确认区域',
        riskLevel: 'safe',
        requiresConfirmation: false,
        target: 'workbench',
        createdAt: now,
        status: 'proposed',
      });
    }

    if (userContent.includes('知识库') || userContent.includes('知识') || text.includes('search')) {
      pushProposal({
        id: `action_${now}_3`,
        type: 'navigate',
        label: '查看知识沉淀',
        description: '跳转到工作台的知识库区域',
        riskLevel: 'safe',
        requiresConfirmation: false,
        target: 'workbench',
        createdAt: now,
        status: 'proposed',
      });
    }

    if (userContent.includes('导出') || text.includes('export')) {
      pushProposal({
        id: `action_${now}_4`,
        type: 'navigate',
        label: '打开导出页',
        description: '跳转到导出页面处理 Markdown 入库',
        riskLevel: 'safe',
        requiresConfirmation: false,
        target: 'export',
        createdAt: now,
        status: 'proposed',
      });
    }

    if (userContent.includes('任务') || userContent.includes('待办') || userContent.includes('定时')) {
      pushProposal({
        id: `action_${now}_5`,
        type: 'create_task',
        label: '创建 Agent 任务',
        description: '把这次请求登记为可执行任务',
        riskLevel: 'safe',
        requiresConfirmation: false,
        target: 'agent-tasks',
        params: { name: userContent.slice(0, 40) },
        createdAt: now,
        status: 'proposed',
      });
    }

    if (userContent.includes('模型') || userContent.includes('provider') || text.includes('model')) {
      pushProposal({
        id: `action_${now}_6`,
        type: 'navigate',
        label: '配置模型',
        description: '跳转到设置页的 AI 模型区',
        riskLevel: 'safe',
        requiresConfirmation: false,
        target: 'settings',
        params: { tab: 'ai-models' },
        createdAt: now,
        status: 'proposed',
      });
    }

    return proposals;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // -------------------------------------------------------------------------
  // IPC Event Emitters
  // -------------------------------------------------------------------------

  private emitStreamChunk(messageId: string, chunk: string, accumulated: string): void {
    const timestamp = Date.now();
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_CHAT_IPC_CHANNELS.STREAM_CHUNK, {
          messageId,
          chunk,
          accumulated,
          timestamp,
        });
      }
    }
  }

  private emitStreamDone(messageId: string, interrupted: boolean): void {
    const timestamp = Date.now();
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_CHAT_IPC_CHANNELS.STREAM_DONE, {
          messageId,
          interrupted,
          timestamp,
        });
      }
    }
  }

  private emitStreamError(messageId: string, error: string): void {
    const timestamp = Date.now();
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_CHAT_IPC_CHANNELS.STREAM_ERROR, {
          messageId,
          error,
          timestamp,
        });
      }
    }
  }

  private emitSessionChanged(action: 'created' | 'updated' | 'deleted', id: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_CHAT_IPC_CHANNELS.SESSION_CHANGED, {
          action,
          id,
          timestamp,
        });
      }
    }
  }

  private emitMessageChanged(action: 'created' | 'updated' | 'deleted', id: string, sessionId: string): void {
    const timestamp = Math.floor(Date.now() / 1000);
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_CHAT_IPC_CHANNELS.MESSAGE_CHANGED, {
          action,
          id,
          sessionId,
          timestamp,
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Status Getters
  // -------------------------------------------------------------------------

  getStatus(): ChatServiceStatus {
    return { ...this.status };
  }

  isGenerating(): boolean {
    return this.status.isGenerating;
  }

  // -------------------------------------------------------------------------
  // Action Proposal Execution (Phase B)
  // -------------------------------------------------------------------------

  /**
   * 执行 Agent Action Proposal
   *
   * 流程：
   * 1. 检查权限策略
   * 2. 如果需要确认，发送事件到渲染进程等待用户确认
   * 3. 执行操作
   * 4. 更新 proposal 状态
   */
  async executeActionProposal(
    proposal: AgentActionProposal,
    sessionId: string
  ): Promise<{ success: boolean; result?: PermissionCheckResult; error?: string }> {
    const config = this.getConfig();
    const policy = config.permissions;

    // 1. 检查权限
    const permissionCheck = permissionGuard.checkPermission(proposal, policy);

    if (!permissionCheck.allowed) {
      logger.warn('ai', 'chatService', 'executeActionProposal', `Permission denied: ${permissionCheck.reason}`);
      return {
        success: false,
        result: permissionCheck,
        error: permissionCheck.reason || '权限不足',
      };
    }

    // 2. 如果需要确认，发送事件到渲染进程
    if (permissionCheck.requiresConfirmation) {
      this.emitActionConfirmationRequired(proposal, sessionId, permissionCheck);

      // 更新 proposal 状态为等待确认
      this.updateProposalStatus(sessionId, proposal.id, 'pending_confirmation');

      return {
        success: false,
        result: permissionCheck,
        error: '等待用户确认',
      };
    }

    // 3. 执行操作
    try {
      const result = await this.runAction(proposal, sessionId);

      // 4. 更新 proposal 状态
      this.updateProposalStatus(sessionId, proposal.id, result.success ? 'completed' : 'failed');

      return result;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('ai', 'chatService', 'executeActionProposal', errorMsg);

      this.updateProposalStatus(sessionId, proposal.id, 'failed');

      return {
        success: false,
        error: errorMsg,
      };
    }
  }

  /**
   * 确认并执行需要确认的操作
   */
  async confirmAndExecuteAction(
    proposal: AgentActionProposal,
    sessionId: string
  ): Promise<{ success: boolean; error?: string }> {
    try {
      const result = await this.runAction(proposal, sessionId);
      this.updateProposalStatus(sessionId, proposal.id, result.success ? 'completed' : 'failed');
      return result;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.updateProposalStatus(sessionId, proposal.id, 'failed');
      return { success: false, error: errorMsg };
    }
  }

  /**
   * 内部：执行具体操作
   */
  private async runAction(proposal: AgentActionProposal, sessionId?: string): Promise<{ success: boolean; error?: string }> {
    switch (proposal.type) {
      case 'navigate':
        if (!proposal.target) return { success: false, error: '导航目标不能为空' };
        this.emitActionExecuted(proposal, { navigatedTo: proposal.target });
        return { success: true };

      case 'open_file':
        if (!proposal.target) return { success: false, error: '文件路径不能为空' };
        // 实际文件打开由渲染进程处理
        this.emitActionExecuted(proposal, { filePath: proposal.target });
        return { success: true };

      case 'distill':
        // 触发蒸馏流程
        this.emitActionExecuted(proposal, { params: proposal.params });
        return { success: true };

      case 'export':
        // 触发导出流程
        this.emitActionExecuted(proposal, { params: proposal.params });
        return { success: true };

      case 'scan':
        // 触发扫描流程
        this.emitActionExecuted(proposal, { params: proposal.params });
        return { success: true };

      case 'run_skill':
        if (!proposal.target) return { success: false, error: '技能名称不能为空' };
        // Phase C: Create an agent task and execute via skillRegistry
        try {
          const task = agentTaskService.createTask({
            sessionId: sessionId ?? '__unknown__',
            name: `执行技能: ${proposal.target}`,
            skillName: proposal.target,
            inputParams: (proposal.params as Record<string, unknown>) ?? {},
          });
          // Fire-and-forget: run the task asynchronously
          agentTaskService.runTask(task.id).catch((err) => {
            logger.error('ai', 'chatService', 'runAction', `Skill task failed: ${err instanceof Error ? err.message : String(err)}`);
          });
          this.emitActionExecuted(proposal, { skillName: proposal.target, params: proposal.params, taskId: task.id });
          return { success: true };
        } catch (err) {
          const errorMsg = err instanceof Error ? err.message : String(err);
          return { success: false, error: errorMsg };
        }

      case 'create_task':
        // 触发创建任务流程
        this.emitActionExecuted(proposal, { params: proposal.params });
        return { success: true };

      default:
        return { success: false, error: `未知的操作类型: ${(proposal as AgentActionProposal).type}` };
    }
  }

  /**
   * 内部：更新 proposal 状态
   */
  private updateProposalStatus(
    sessionId: string,
    proposalId: string,
    status: AgentActionProposal['status']
  ): void {
    // 获取会话的最新消息并更新 proposal 状态
    const messages = this.listMessages(sessionId);
    for (const message of messages) {
      if (message.actionProposals) {
        const proposal = message.actionProposals.find(p => p.id === proposalId);
        if (proposal) {
          proposal.status = status;
          storage.updateChatMessage(message.id, { actionProposals: message.actionProposals });
          this.emitMessageChanged('updated', message.id, sessionId);
          break;
        }
      }
    }
  }

  /**
   * 发送操作确认请求到渲染进程
   */
  private emitActionConfirmationRequired(
    proposal: AgentActionProposal,
    sessionId: string,
    permissionCheck: PermissionCheckResult
  ): void {
    const timestamp = Date.now();
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_CHAT_IPC_CHANNELS.ACTION_CONFIRMATION_REQUIRED, {
          proposal,
          sessionId,
          permissionCheck,
          timestamp,
        });
      }
    }
  }

  /**
   * 发送操作执行事件到渲染进程
   */
  private emitActionExecuted(proposal: AgentActionProposal, result: Record<string, unknown>): void {
    const timestamp = Date.now();
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send(AGENT_CHAT_IPC_CHANNELS.ACTION_EXECUTED, {
          proposal,
          result,
          timestamp,
        });
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const chatService = new ChatService();
