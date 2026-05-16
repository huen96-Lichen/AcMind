import { useState } from 'react'
import type { AgentSession } from '../types'

interface AgentProjectSidebarProps {
  history: AgentSession[]
  selectedSessionId?: string
  onSelectHistory: (id: string) => void
  onNewChat: () => void
  modelName?: string
}

const sidebarStyle: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  height: '100%',
  padding: '12px',
}

const newChatBtnStyle: React.CSSProperties = {
  background: 'var(--color-accent)',
  color: 'white',
  borderRadius: 10,
  padding: '10px 16px',
  border: 'none',
  width: '100%',
  cursor: 'pointer',
  fontSize: 13,
  fontWeight: 600,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 6,
  marginBottom: 16,
  flexShrink: 0,
}

const sectionLabelStyle: React.CSSProperties = {
  fontSize: 11,
  fontWeight: 600,
  textTransform: 'uppercase',
  letterSpacing: 0.5,
  color: 'var(--color-text-secondary)',
  padding: '8px 4px 6px',
}

const listContainerStyle: React.CSSProperties = {
  flex: 1,
  overflowY: 'auto',
  minHeight: 0,
}

const footerStyle: React.CSSProperties = {
  flexShrink: 0,
  padding: '12px 4px 4px',
  borderTop: '1px solid var(--color-border)',
  fontSize: 12,
  color: 'var(--color-text-secondary)',
  display: 'flex',
  alignItems: 'center',
  gap: 6,
}

function AgentProjectSidebar({
  history,
  selectedSessionId,
  onSelectHistory,
  onNewChat,
  modelName,
}: AgentProjectSidebarProps) {
  const [hoveredId, setHoveredId] = useState<string | null>(null)

  const getItemStyle = (id: string, selected: boolean): React.CSSProperties => ({
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    padding: '10px 12px',
    borderRadius: 10,
    cursor: 'pointer',
    fontSize: 13,
    fontWeight: 500,
    color: 'var(--color-text)',
    background: selected
      ? 'var(--color-bg)'
      : hoveredId === id
        ? 'var(--color-bg-hover)'
        : 'transparent',
    boxShadow: selected ? '0 1px 3px rgba(0,0,0,0.06)' : 'none',
    marginBottom: 2,
    transition: 'background 0.15s, box-shadow 0.15s',
  })

  return (
    <div style={sidebarStyle}>
      <button onClick={onNewChat} style={newChatBtnStyle}>
        + 新对话
      </button>

      <div style={sectionLabelStyle}>历史对话</div>

      <div style={listContainerStyle}>
        {history.length === 0 ? (
          <div style={{ padding: '12px 4px', fontSize: 12, color: 'var(--color-text-secondary)', opacity: 0.6 }}>
            暂无历史对话
          </div>
        ) : (
          history.map(s => (
            <div
              key={s.id}
              style={getItemStyle(s.id, s.id === selectedSessionId)}
              onClick={() => onSelectHistory(s.id)}
              onMouseEnter={() => setHoveredId(s.id)}
              onMouseLeave={() => setHoveredId(null)}
            >
              <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {s.title}
              </span>
            </div>
          ))
        )}
      </div>

      {modelName && (
        <div style={footerStyle}>
          <span>🤖</span>
          <span>{modelName}</span>
        </div>
      )}
    </div>
  )
}

export default AgentProjectSidebar
