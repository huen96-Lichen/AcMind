import type { SourceItem } from '../../../shared/types'

interface AgentDistillPanelProps {
  items: SourceItem[]
  onDistill: (item: SourceItem) => void
}

function AgentDistillPanel({ items, onDistill }: AgentDistillPanelProps) {
  return (
    // EDITABLE WORKSPACE BLOCK: queue, preview, bulk actions, and filters belong here.
    <div className="card" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
      <h3 style={{ marginBottom: 16 }}>待蒸馏内容</h3>
      <p style={{ color: 'var(--color-text-secondary)', marginBottom: 16, fontSize: 13 }}>
        点击按钮对内容进行 AI 蒸馏，自动生成结构化笔记
      </p>

      {items.length === 0 ? (
        <div className="empty-state">
          <div>📭</div>
          <p>收集箱暂无待蒸馏内容</p>
        </div>
      ) : (
        <div className="list">
          {items.map(item => (
            <div key={item.id} className="list-item">
              <div className="list-item-content">
                <div className="list-item-title">
                  {item.title || item.previewText?.slice(0, 50) || '无标题'}
                </div>
                <div className="list-item-meta">
                  {item.type} · {item.source}
                </div>
              </div>
              <button
                className="btn btn-primary"
                onClick={() => onDistill(item)}
                style={{ padding: '6px 12px' }}
              >
                蒸馏
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default AgentDistillPanel
