import React from 'react'

interface AgentWelcomeProps {
  onSuggestionClick: (text: string) => void
}

const suggestions = [
  { icon: '📊', label: '分析数据', prompt: '帮我分析一下数据' },
  { icon: '📋', label: '生成计划', prompt: '帮我生成一个计划' },
  { icon: '📁', label: '整理资料', prompt: '帮我整理这些资料' },
  { icon: '💡', label: '头脑风暴', prompt: '我们来头脑风暴一下' },
]

const AgentWelcome: React.FC<AgentWelcomeProps> = ({ onSuggestionClick }) => {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100%',
        paddingTop: '0',
        transform: 'translateY(-22%)',
      }}
    >
      <div
        style={{
          width: 48,
          height: 48,
          borderRadius: '50%',
          background: 'var(--color-accent)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 24,
          marginBottom: 20,
        }}
      >
        🤖
      </div>
      <div
        style={{
          fontSize: 28,
          fontWeight: 700,
          color: 'var(--color-text)',
          marginBottom: 8,
        }}
      >
        你好，我是 Agent
      </div>
      <div
        style={{
          fontSize: 15,
          color: 'var(--color-text-secondary)',
          marginBottom: 40,
        }}
      >
        我可以帮你对话、分析、规划和执行任务
      </div>
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: 16,
          justifyContent: 'center',
          maxWidth: 860,
        }}
      >
        {suggestions.map((s) => (
          <SuggestionCard
            key={s.label}
            icon={s.icon}
            label={s.label}
            onClick={() => onSuggestionClick(s.prompt)}
          />
        ))}
      </div>
    </div>
  )
}

interface SuggestionCardProps {
  icon: string
  label: string
  onClick: () => void
}

const SuggestionCard: React.FC<SuggestionCardProps> = ({ icon, label, onClick }) => {
  const [hovered, setHovered] = React.useState(false)

  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        width: 200,
        height: 96,
        borderRadius: 16,
        border: '1px solid var(--color-border)',
        background: 'var(--color-bg)',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
        boxShadow: hovered ? '0 4px 12px rgba(0,0,0,0.08)' : 'none',
        transform: hovered ? 'translateY(-1px)' : 'none',
        transition: 'all 0.2s',
      }}
    >
      <span style={{ fontSize: 28, marginBottom: 6 }}>{icon}</span>
      <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--color-text)' }}>{label}</span>
    </div>
  )
}

export default AgentWelcome
