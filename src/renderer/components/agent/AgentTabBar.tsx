import type { AgentTab } from './types'

interface AgentTabBarProps {
  activeTab: AgentTab
  onChange: (tab: AgentTab) => void
}

function AgentTabBar({ activeTab, onChange }: AgentTabBarProps) {
  return (
    // EDITABLE CONTROL BLOCK: add or remove modes here as the workspace grows.
    <div className="card" style={{ marginBottom: 16, flexShrink: 0 }}>
      <div style={{ display: 'flex', gap: 8 }}>
        <button
          className={`btn ${activeTab === 'chat' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => onChange('chat')}
        >
          💬 AI 对话
        </button>
        <button
          className={`btn ${activeTab === 'distill' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => onChange('distill')}
        >
          🧪 知识蒸馏
        </button>
      </div>
    </div>
  )
}

export default AgentTabBar
