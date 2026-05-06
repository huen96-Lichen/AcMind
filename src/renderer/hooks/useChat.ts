/**
 * useChat — Agent Chat 数据 Hook
 *
 * 管理会话列表、消息、流式响应状态。
 */

import { useState, useEffect, useCallback, useRef } from 'react';
import type { ChatSession, ChatMessage, ChatSessionMetadata, SourceItem } from '../../shared/types';

interface UseChatResult {
  // State
  sessions: ChatSession[];
  currentSession: ChatSession | null;
  messages: ChatMessage[];
  sending: boolean;
  error: string | null;
  connectionStatus: 'connected' | 'disconnected' | 'error';
  attachedContext: SourceItem[];

  // Session operations
  loadSessions: () => Promise<void>;
  createSession: (params?: { title?: string; metadata?: ChatSessionMetadata; providerId?: string; modelId?: string }) => Promise<ChatSession | null>;
  switchSession: (sessionId: string) => Promise<void>;
  deleteSession: (sessionId: string) => Promise<boolean>;
  updateSessionTitle: (sessionId: string, title: string) => Promise<boolean>;

  // Message operations
  loadMessages: (sessionId: string) => Promise<void>;
  sendMessage: (content: string, contextItems?: SourceItem[]) => Promise<boolean>;
  stopGeneration: () => Promise<boolean>;

  // Context operations
  attachContext: (item: SourceItem) => void;
  detachContext: (itemId: string) => void;
  clearContext: () => void;

  // Refresh
  refresh: () => Promise<void>;
}

export function useChat(): UseChatResult {
  const [sessions, setSessions] = useState<ChatSession[]>([]);
  const [currentSession, setCurrentSession] = useState<ChatSession | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [connectionStatus, setConnectionStatus] = useState<'connected' | 'disconnected' | 'error'>('connected');
  const [attachedContext, setAttachedContext] = useState<SourceItem[]>([]);

  // Refs for tracking streaming state
  const streamingMessageIdRef = useRef<string | null>(null);
  const sendingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Load sessions
  const loadSessions = useCallback(async () => {
    try {
      setError(null);
      const result = await window.acmind.agentChat.listSessions({ status: 'active', limit: 50 });
      if (result.success) {
        setSessions(result.sessions);
      } else {
        setError('加载会话列表失败');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载会话列表失败');
      setConnectionStatus('error');
    }
  }, []);

  // Create new session
  const createSession = useCallback(async (params?: { title?: string; metadata?: ChatSessionMetadata; providerId?: string; modelId?: string }): Promise<ChatSession | null> => {
    try {
      setError(null);
      const result = await window.acmind.agentChat.createSession(params);
      if (result.success && result.session) {
        setSessions(prev => [result.session!, ...prev]);
        setCurrentSession(result.session);
        setMessages([]);
        return result.session;
      } else {
        setError(result.error || '创建会话失败');
        return null;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '创建会话失败');
      return null;
    }
  }, []);

  // Switch to a session
  const switchSession = useCallback(async (sessionId: string) => {
    try {
      setError(null);
      const sessionResult = await window.acmind.agentChat.getSession(sessionId);
      if (sessionResult.success && sessionResult.session) {
        setCurrentSession(sessionResult.session);
        await loadMessages(sessionId);
      } else {
        setError('会话不存在');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '切换会话失败');
    }
  }, []);

  // Delete a session
  const deleteSession = useCallback(async (sessionId: string): Promise<boolean> => {
    try {
      const result = await window.acmind.agentChat.deleteSession(sessionId);
      if (result.success) {
        setSessions(prev => prev.filter(s => s.id !== sessionId));
        if (currentSession?.id === sessionId) {
          setCurrentSession(null);
          setMessages([]);
        }
        return true;
      }
      return false;
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除会话失败');
      return false;
    }
  }, [currentSession?.id]);

  // Update session title
  const updateSessionTitle = useCallback(async (sessionId: string, title: string): Promise<boolean> => {
    try {
      const result = await window.acmind.agentChat.updateSession(sessionId, { title });
      if (result.success && result.session) {
        setSessions(prev => prev.map(s => s.id === sessionId ? result.session! : s));
        if (currentSession?.id === sessionId) {
          setCurrentSession(result.session);
        }
        return true;
      }
      return false;
    } catch (err) {
      setError(err instanceof Error ? err.message : '更新会话标题失败');
      return false;
    }
  }, [currentSession?.id]);

  // Load messages for a session
  const loadMessages = useCallback(async (sessionId: string) => {
    try {
      setError(null);
      const result = await window.acmind.agentChat.listMessages(sessionId, { limit: 100 });
      if (result.success) {
        setMessages(result.messages);
      } else {
        setError('加载消息失败');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载消息失败');
    }
  }, []);

  // Context operations
  const attachContext = useCallback((item: SourceItem) => {
    setAttachedContext(prev => {
      if (prev.some(i => i.id === item.id)) return prev;
      return [...prev, item];
    });
  }, []);

  const detachContext = useCallback((itemId: string) => {
    setAttachedContext(prev => prev.filter(i => i.id !== itemId));
  }, []);

  const clearContext = useCallback(() => {
    setAttachedContext([]);
  }, []);

  // Send a message
  const sendMessage = useCallback(async (content: string, contextItems?: SourceItem[]): Promise<boolean> => {
    if (!currentSession) {
      setError('请先选择或创建一个会话');
      return false;
    }

    if (!content.trim()) {
      return false;
    }

    try {
      setSending(true);
      setError(null);

      // Build context content if items provided
      const itemsToAttach = contextItems ?? attachedContext;
      let finalContent = content.trim();

      if (itemsToAttach.length > 0) {
        const contextHeader = formatContextForPrompt(itemsToAttach);
        finalContent = `${contextHeader}\n\n用户问题：${content.trim()}`;
      }

      // Optimistically add user message
      const userMessage: ChatMessage = {
        id: `temp_user_${Date.now()}`,
        sessionId: currentSession.id,
        role: 'user',
        content: content.trim(),
        status: 'completed',
        modelId: null,
        providerId: null,
        promptTokens: null,
        completionTokens: null,
        latencyMs: null,
        error: null,
        createdAt: Math.floor(Date.now() / 1000),
      };
      setMessages(prev => [...prev, userMessage]);

      // Send to main process
      const result = await window.acmind.agentChat.sendMessage({
        sessionId: currentSession.id,
        content: finalContent,
        providerId: currentSession.providerId ?? undefined,
      });

      if (!result.success) {
        setSending(false);
        setError(result.error || '发送消息失败');
        return false;
      }

      // C3: 安全超时 — 如果 30s 内无任何流式事件，重置 sending 状态
      if (sendingTimeoutRef.current) {
        clearTimeout(sendingTimeoutRef.current);
      }
      sendingTimeoutRef.current = setTimeout(() => {
        setSending(false);
        setError('响应超时，请重试');
      }, 30_000);

      // Track streaming message
      if (result.messageId) {
        streamingMessageIdRef.current = result.messageId;

        // Add placeholder for assistant message
        const assistantMessage: ChatMessage = {
          id: result.messageId,
          sessionId: currentSession.id,
          role: 'assistant',
          content: '',
          status: 'streaming',
          modelId: currentSession.modelId,
          providerId: currentSession.providerId,
          promptTokens: null,
          completionTokens: null,
          latencyMs: null,
          error: null,
          createdAt: Math.floor(Date.now() / 1000),
        };
        setMessages(prev => [...prev, assistantMessage]);
      }

      // Clear attached context after sending
      if (itemsToAttach.length > 0) {
        setAttachedContext([]);
      }

      return true;
    } catch (err) {
      setSending(false);
      setError(err instanceof Error ? err.message : '发送消息失败');
      return false;
    } finally {
      // Don't set sending to false here - wait for stream to complete
      // Timeout will handle the edge case where no stream events arrive
    }
  }, [currentSession, attachedContext]);

  // Stop generation
  const stopGeneration = useCallback(async (): Promise<boolean> => {
    try {
      const result = await window.acmind.agentChat.stopGeneration();
      if (result.success && result.stopped) {
        setSending(false);
        return true;
      }
      return false;
    } catch (err) {
      return false;
    }
  }, []);

  // Refresh all data
  const refresh = useCallback(async () => {
    await loadSessions();
    if (currentSession) {
      await loadMessages(currentSession.id);
    }
  }, [currentSession, loadSessions, loadMessages]);

  // Setup IPC event listeners
  useEffect(() => {
    // Listen for stream chunks
    const unsubscribeChunk = window.acmind.agentChat.onStreamChunk((data) => {
      setMessages(prev => prev.map(msg => {
        if (msg.id === data.messageId) {
          return { ...msg, content: data.accumulated };
        }
        return msg;
      }));
    });

    // Listen for stream completion
    const unsubscribeDone = window.acmind.agentChat.onStreamDone((data) => {
      if (sendingTimeoutRef.current) {
        clearTimeout(sendingTimeoutRef.current);
        sendingTimeoutRef.current = null;
      }
      setSending(false);
      streamingMessageIdRef.current = null;

      setMessages(prev => prev.map(msg => {
        if (msg.id === data.messageId) {
          return {
            ...msg,
            status: data.interrupted ? 'interrupted' : 'completed',
          };
        }
        return msg;
      }));

      // Refresh sessions to update order
      loadSessions();
    });

    // Listen for stream errors
    const unsubscribeError = window.acmind.agentChat.onStreamError((data) => {
      if (sendingTimeoutRef.current) {
        clearTimeout(sendingTimeoutRef.current);
        sendingTimeoutRef.current = null;
      }
      setSending(false);
      streamingMessageIdRef.current = null;
      setError(data.error);

      setMessages(prev => prev.map(msg => {
        if (msg.id === data.messageId) {
          return {
            ...msg,
            status: 'error',
            error: data.error,
          };
        }
        return msg;
      }));
    });

    // Listen for session changes
    const unsubscribeSession = window.acmind.agentChat.onSessionChanged(() => {
      loadSessions();
    });

    // Listen for message changes
    const unsubscribeMessage = window.acmind.agentChat.onMessageChanged((data) => {
      if (data.sessionId === currentSession?.id) {
        loadMessages(data.sessionId);
      }
    });

    // Cleanup
    return () => {
      unsubscribeChunk();
      unsubscribeDone();
      unsubscribeError();
      unsubscribeSession();
      unsubscribeMessage();
    };
  }, [currentSession?.id, loadSessions, loadMessages]);

  // Initial load
  useEffect(() => {
    void loadSessions();
  }, [loadSessions]);

  return {
    sessions,
    currentSession,
    messages,
    sending,
    error,
    connectionStatus,
    attachedContext,
    loadSessions,
    createSession,
    switchSession,
    deleteSession,
    updateSessionTitle,
    loadMessages,
    sendMessage,
    stopGeneration,
    attachContext,
    detachContext,
    clearContext,
    refresh,
  };
}

/**
 * 将 SourceItem 数组格式化为 LLM prompt 的上下文
 */
function formatContextForPrompt(items: SourceItem[]): string {
  const parts: string[] = ['【附加上下文】'];

  for (const item of items) {
    parts.push(`\n--- 条目 ${item.id} ---`);
    parts.push(`类型: ${item.type}`);
    if (item.title) parts.push(`标题: ${item.title}`);
    if (item.previewText) parts.push(`预览: ${item.previewText}`);
    if (item.ocrText) parts.push(`OCR: ${item.ocrText}`);
    if (item.originalUrl) parts.push(`来源: ${item.originalUrl}`);
    parts.push(`状态: ${item.status}`);
  }

  return parts.join('\n');
}
