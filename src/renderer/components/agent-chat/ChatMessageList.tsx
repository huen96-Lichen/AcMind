/**
 * ChatMessageList — 消息列表容器
 *
 * 支持：
 * - ScrollContainer 包装
 * - 自动滚动到底部
 * - 消息到 ChatMessageBubble 的映射
 * - Action 确认回调
 */

import { useEffect, useRef } from 'react';
import type { ChatMessage, AgentActionProposal } from '../../../shared/types';
import { ScrollContainer } from '../shared/ScrollContainer';
import { ChatMessageBubble } from './ChatMessageBubble';

interface ChatMessageListProps {
  messages: ChatMessage[];
  className?: string;
  onActionClick?: (action: AgentActionProposal) => void;
  onActionConfirm?: (action: AgentActionProposal) => void;
}

export function ChatMessageList({
  messages,
  className,
  onActionClick,
  onActionConfirm,
}: ChatMessageListProps): JSX.Element {
  const bottomRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom when messages change
  useEffect(() => {
    if (bottomRef.current) {
      bottomRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages]);

  return (
    <ScrollContainer className={className} bottomPadding={24}>
      <div className="chat-thread mx-auto flex w-full max-w-[920px] flex-col gap-4 px-8 py-6">
        {messages.length === 0 ? (
          <div className="flex-1 flex items-center justify-center py-12 text-text-tertiary text-sm">
            暂无消息，开始对话吧
          </div>
        ) : (
          messages.map((message) => (
            <ChatMessageBubble
              key={message.id}
              message={message}
              onActionClick={onActionClick}
              onActionConfirm={onActionConfirm}
            />
          ))
        )}
        <div ref={bottomRef} />
      </div>
    </ScrollContainer>
  );
}
