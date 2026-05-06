import type { AgentActionProposal, ChatMessage } from '../../../shared/types';
import { AgentWelcome } from './AgentWelcome';
import { ChatMessageList } from './ChatMessageList';

interface ChatCanvasProps {
  messages: ChatMessage[];
  mockMode: boolean;
  onNewConversation: () => void;
  onCapabilitySelect: (prompt: string) => void;
  onActionClick?: (action: AgentActionProposal) => void;
  onActionConfirm?: (action: AgentActionProposal) => void;
}

export function ChatCanvas({
  messages,
  mockMode,
  onNewConversation,
  onCapabilitySelect,
  onActionClick,
  onActionConfirm,
}: ChatCanvasProps): JSX.Element {
  return (
    <div className="flex-1 min-h-0 overflow-hidden">
      {messages.length === 0 ? (
        <div className="flex h-full items-center justify-center px-8 py-10">
          <AgentWelcome
            mockMode={mockMode}
            onNewConversation={onNewConversation}
            onCapabilitySelect={onCapabilitySelect}
          />
        </div>
      ) : (
        <ChatMessageList
          messages={messages}
          className="h-full"
          onActionClick={onActionClick}
          onActionConfirm={onActionConfirm}
        />
      )}
    </div>
  );
}
