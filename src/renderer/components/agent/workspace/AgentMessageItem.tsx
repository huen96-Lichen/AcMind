import type { ChatMessage } from '../types'

interface AgentMessageItemProps {
  message: ChatMessage
  isLast?: boolean
}

const wrapperBase: React.CSSProperties = {
  display: 'flex',
  marginBottom: 12
}

const bubbleBase: React.CSSProperties = {
  maxWidth: '75%',
  padding: '10px 14px',
  borderRadius: 12,
  whiteSpace: 'pre-wrap',
  fontSize: 14,
  lineHeight: 1.6
}

function AgentMessageItem({ message }: AgentMessageItemProps) {
  const { role, content, toolResult } = message

  if (role === 'system') {
    return (
      <div style={{ ...wrapperBase, justifyContent: 'center' }}>
        <div
          style={{
            ...bubbleBase,
            fontSize: 12,
            color: 'var(--color-text-secondary)',
            fontStyle: 'italic',
            background: 'transparent'
          }}
        >
          {content}
        </div>
      </div>
    )
  }

  if (role === 'user') {
    return (
      <div style={{ ...wrapperBase, justifyContent: 'flex-end' }}>
        <div
          style={{
            ...bubbleBase,
            background: 'var(--color-accent)',
            color: 'white'
          }}
        >
          {content}
        </div>
      </div>
    )
  }

  if ((role as string) === 'tool') {
    return (
      <div style={{ ...wrapperBase, justifyContent: 'flex-start' }}>
        <div
          style={{
            ...bubbleBase,
            border: '1px solid var(--color-border)',
            background: 'var(--color-bg)',
            color: 'var(--color-text)'
          }}
        >
          {toolResult ? (
            <div>
              <div
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  marginBottom: 6,
                  color: 'var(--color-text-secondary)'
                }}
              >
                🔧 工具结果
              </div>
              <div>{toolResult.content}</div>
            </div>
          ) : (
            content
          )}
        </div>
      </div>
    )
  }

  return (
    <div style={{ ...wrapperBase, justifyContent: 'flex-start' }}>
      <div
        style={{
          ...bubbleBase,
          background: 'var(--color-bg-secondary)',
          color: 'var(--color-text)'
        }}
      >
        {content}
      </div>
    </div>
  )
}

export default AgentMessageItem
