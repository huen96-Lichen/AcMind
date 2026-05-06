/**
 * AgentChatPanel — 主页面的 Agent Chat 面板
 *
 * 包含：
 * - Header (会话标题 + 新会话按钮)
 * - Context Bar (附加上下文显示)
 * - 消息列表或空状态
 * - 输入框
 * - 连接状态指示器
 * - Permission Confirm Dialog
 */

import { useEffect, useState, useCallback } from 'react';
import type { AgentActionProposal, SourceItem } from '../../../shared/types';
import { Button } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { useChat } from '../../hooks/useChat';
import { ChatMessageList } from './ChatMessageList';
import { ChatComposer } from './ChatComposer';
import { ChatEmptyState } from './ChatEmptyState';
import { PermissionConfirmDialog } from './PermissionConfirmDialog';
import { executeAction } from './actionHandlers';

interface AgentChatPanelProps {
  className?: string;
  showHeader?: boolean;
  initialContext?: SourceItem[];
}

export function AgentChatPanel({ className, showHeader = true, initialContext }: AgentChatPanelProps): JSX.Element {
  const {
    sessions,
    currentSession,
    messages,
    sending,
    error,
    attachedContext,
    createSession,
    sendMessage,
    stopGeneration,
    attachContext,
    detachContext,
    clearContext,
  } = useChat();

  const [mockMode, setMockMode] = useState(false);
  const [pendingAction, setPendingAction] = useState<AgentActionProposal | null>(null);

  // Load mock mode setting and initial context
  useEffect(() => {
    void window.acmind.settings.get().then((settings) => {
      setMockMode(settings.agentChat.mockMode);
    });

    // Attach initial context if provided
    if (initialContext && initialContext.length > 0) {
      for (const item of initialContext) {
        attachContext(item);
      }
    }
  }, [initialContext, attachContext]);

  // Handle new session
  const handleNewSession = useCallback(async () => {
    clearContext();
    await createSession({ title: '新对话' });
  }, [createSession, clearContext]);

  // Handle send message
  const handleSend = useCallback(
    async (content: string) => {
      let sessionId = currentSession?.id;
      if (!sessionId) {
        // C4/C7: 创建会话后使用返回的 session 对象发消息，避免首次消息丢失
        const newSession = await createSession({ title: content.slice(0, 20) });
        if (!newSession) {
          return; // 创建失败，error 已在 createSession 中设置
        }
        sessionId = newSession.id;
      }
      await sendMessage(content);
    },
    [currentSession, createSession, sendMessage],
  );

  // Handle stop
  const handleStop = useCallback(async () => {
    await stopGeneration();
  }, [stopGeneration]);

  // Handle quick command
  const handleQuickCommand = useCallback(
    async (command: string) => {
      if (!currentSession) {
        const newSession = await createSession({ title: command });
        if (!newSession) return;
      }
      await sendMessage(command);
    },
    [currentSession, createSession, sendMessage],
  );

  // Handle action click from message bubble
  const handleActionConfirm = useCallback((action: AgentActionProposal) => {
    setPendingAction(action);
  }, []);

  // Handle confirm dialog confirm
  const handleConfirmAction = useCallback(async () => {
    if (!pendingAction) return;

    const result = await executeAction(pendingAction);
    if (!result.success) {
      console.error('Action execution failed:', result.error);
    }

    setPendingAction(null);
  }, [pendingAction]);

  // Handle confirm dialog cancel
  const handleCancelAction = useCallback(() => {
    setPendingAction(null);
  }, []);

  return (
    <div className={`flex flex-col h-full bg-surface ${className ?? ''}`}>
      {/* Header */}
      {showHeader && (
        <div className="flex items-center justify-between px-4 py-3 border-b border-border-subtle">
          <div className="flex items-center gap-2">
            <AcMindIcon name="ai-workspace" size={18} className="text-accent" />
            <span className="font-medium text-text-primary">{currentSession?.title ?? 'Agent 对话'}</span>
            {mockMode && <span className="text-xs px-2 py-0.5 rounded-full bg-mock-soft text-mock">Mock</span>}
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={handleNewSession}
            leadingIcon={<AcMindIcon name="duplicate" size={14} />}
          >
            新会话
          </Button>
        </div>
      )}

      {/* Error banner */}
      {error && (
        <div className="px-4 py-2 bg-danger-soft text-danger text-sm flex items-center gap-2">
          <AcMindIcon name="status-error" size={14} />
          {error}
        </div>
      )}

      {/* Context Bar */}
      {attachedContext.length > 0 && (
        <div className="px-4 py-2 bg-surface-muted border-b border-border-subtle">
          <div className="flex items-center gap-2">
            <span className="text-xs text-text-tertiary">已附加:</span>
            <div className="flex flex-wrap gap-1.5 flex-1">
              {attachedContext.map((item) => (
                <span
                  key={item.id}
                  className="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-accent-soft text-accent"
                >
                  {item.title || item.previewText?.slice(0, 20) || item.id}
                  <button onClick={() => detachContext(item.id)} className="hover:text-danger">
                    <AcMindIcon name="close" size={10} />
                  </button>
                </span>
              ))}
            </div>
            <button onClick={clearContext} className="text-xs text-text-tertiary hover:text-danger">
              清除
            </button>
          </div>
        </div>
      )}

      {/* Message area */}
      <div className="flex-1 min-h-0 overflow-hidden">
        {!currentSession || messages.length === 0 ? (
          <ChatEmptyState onNewSession={handleNewSession} onQuickCommand={handleQuickCommand} mockMode={mockMode} />
        ) : (
          <ChatMessageList messages={messages} className="h-full" onActionConfirm={handleActionConfirm} />
        )}
      </div>

      {/* Composer */}
      <ChatComposer
        onSend={handleSend}
        onStop={handleStop}
        sending={sending}
        placeholder={currentSession ? '输入消息...' : '输入消息开始新对话...'}
      />

      {/* Permission Confirm Dialog */}
      {pendingAction && (
        <PermissionConfirmDialog
          proposal={pendingAction}
          onConfirm={handleConfirmAction}
          onCancel={handleCancelAction}
        />
      )}
    </div>
  );
}
