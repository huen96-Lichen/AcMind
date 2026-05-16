import type { RefObject } from 'react'
import type { ChatMessage } from '../types'
import AgentMessageItem from './AgentMessageItem'

interface AgentMessageListProps {
  messages: ChatMessage[]
  loading: boolean
  messagesEndRef: RefObject<HTMLDivElement>
}

const containerStyle: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  flex: 1,
  overflowY: 'auto',
  padding: '20px 32px',
  justifyContent: 'center'
}

const thinkingBubbleStyle: React.CSSProperties = {
  display: 'flex',
  justifyContent: 'flex-start',
  marginBottom: 12
}

const thinkingContentStyle: React.CSSProperties = {
  background: 'var(--color-bg-secondary)',
  borderRadius: 12,
  padding: '10px 14px',
  fontSize: 14,
  color: 'var(--color-text-secondary)',
  display: 'inline-flex',
  alignItems: 'center',
  gap: 2
}

const dotKeyframes = `
@keyframes agentDotPulse {
  0%, 80%, 100% { opacity: 0.3; }
  40% { opacity: 1; }
}
`

function AgentMessageList({ messages, loading, messagesEndRef }: AgentMessageListProps) {
  return (
    <div style={containerStyle}>
      <style>{dotKeyframes}</style>
      <div style={{ width: '100%', maxWidth: 860, margin: '0 auto' }}>
        {messages.map((msg, i) => (
          <AgentMessageItem key={i} message={msg} isLast={i === messages.length - 1} />
        ))}

        {loading && (
          <div style={thinkingBubbleStyle}>
            <div style={thinkingContentStyle}>
              思考中...
              {[0, 1, 2].map(i => (
                <span
                  key={i}
                  style={{
                    display: 'inline-block',
                    width: 4,
                    height: 4,
                    borderRadius: '50%',
                    background: 'var(--color-text-secondary)',
                    marginLeft: 2,
                    animation: 'agentDotPulse 1.4s ease-in-out infinite',
                    animationDelay: `${i * 0.2}s`
                  }}
                />
              ))}
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>
    </div>
  )
}

export default AgentMessageList
