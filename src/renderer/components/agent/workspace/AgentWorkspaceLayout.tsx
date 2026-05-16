import React, { ReactNode } from 'react'

interface AgentWorkspaceLayoutProps {
  left: ReactNode
  center: ReactNode
}

const containerStyle: React.CSSProperties = {
  height: '100%',
  display: 'flex',
  overflow: 'hidden',
  backgroundColor: 'var(--color-bg)',
}

const leftColumnStyle: React.CSSProperties = {
  width: 240,
  minWidth: 240,
  height: '100%',
  overflowY: 'auto',
  borderRight: '1px solid rgba(0,0,0,0.06)',
  backgroundColor: '#F7F7F8',
  padding: 0,
}

const centerColumnStyle: React.CSSProperties = {
  flex: 1,
  display: 'flex',
  flexDirection: 'column',
  height: '100%',
  minWidth: 0,
  overflow: 'hidden',
  backgroundColor: 'var(--color-bg)',
  padding: 0,
}

const AgentWorkspaceLayout: React.FC<AgentWorkspaceLayoutProps> = ({ left, center }) => {
  return (
    <div style={containerStyle}>
      <div style={leftColumnStyle}>{left}</div>
      <div style={centerColumnStyle}>{center}</div>
    </div>
  )
}

export default AgentWorkspaceLayout
