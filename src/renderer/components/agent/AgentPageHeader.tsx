import type { ReactNode } from 'react'

interface AgentPageHeaderProps {
  title: string
  description: string
  children?: ReactNode
}

function AgentPageHeader({ title, description, children }: AgentPageHeaderProps) {
  return (
    // FIXED HEADER BLOCK: keep the header structure stable.
    // Only the right-side badges are meant to change dynamically.
    <div
      className="page-header"
      style={{
        display: 'flex',
        alignItems: 'flex-start',
        justifyContent: 'space-between',
        gap: 16
      }}
    >
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>

      {children && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
          {children}
        </div>
      )}
    </div>
  )
}

export default AgentPageHeader
