import type { RefObject } from 'react'
import type { ProviderConfig } from '../../../shared/types'
import type { ChatMessage } from './types'

interface AgentChatPanelProps {
  providers: ProviderConfig[]
  selectedProvider: string
  messages: ChatMessage[]
  loading: boolean
  input: string
  onSelectedProviderChange: (providerId: string) => void
  onInputChange: (value: string) => void
  onSend: () => void
  onQuickDistill: () => void
  messagesEndRef: RefObject<HTMLDivElement>
}

function AgentChatPanel({
  providers,
  selectedProvider,
  messages,
  loading,
  input,
  onSelectedProviderChange,
  onInputChange,
  onSend,
  onQuickDistill,
  messagesEndRef
}: AgentChatPanelProps) {
  return (
    <>
      {/* EDITABLE CONTROL BLOCK: provider selection can grow into model settings. */}
      <div className="card" style={{ marginBottom: 16, flexShrink: 0 }}>
        <label
          style={{
            fontSize: 13,
            color: 'var(--color-text-secondary)',
            marginBottom: 8,
            display: 'block'
          }}
        >
          选择 AI 模型
        </label>
        <select
          value={selectedProvider}
          onChange={(e) => onSelectedProviderChange(e.target.value)}
          style={{
            width: '100%',
            padding: '8px 12px',
            borderRadius: 6,
            border: '1px solid var(--color-border)',
            background: 'var(--color-bg)',
            color: 'var(--color-text)'
          }}
          disabled={providers.length === 0}
        >
          {providers.length === 0 ? (
            <option value="">暂无可用模型</option>
          ) : (
            providers.map(p => (
              <option key={p.id} value={p.id}>
                {p.name} ({p.modelId})
              </option>
            ))
          )}
        </select>
      </div>

      {/* EDITABLE WORKSPACE BLOCK: message stream and composer live here. */}
      <div className="card" style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ flex: 1, overflowY: 'auto', marginBottom: 16 }}>
          {messages.map((msg, i) => (
            <div
              key={i}
              style={{
                display: 'flex',
                justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start',
                marginBottom: 12
              }}
            >
              <div
                style={{
                  maxWidth: '70%',
                  padding: '10px 14px',
                  borderRadius: 12,
                  background: msg.role === 'user' ? 'var(--color-accent)' : 'var(--color-bg-secondary)',
                  color: msg.role === 'user' ? 'white' : 'var(--color-text)',
                  whiteSpace: 'pre-wrap'
                }}
              >
                {msg.content}
              </div>
            </div>
          ))}
          {loading && (
            <div style={{ display: 'flex', justifyContent: 'flex-start', marginBottom: 12 }}>
              <div style={{ padding: '10px 14px', borderRadius: 12, background: 'var(--color-bg-secondary)' }}>
                thinking...
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <input
            type="text"
            placeholder="输入消息..."
            value={input}
            onChange={(e) => onInputChange(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && onSend()}
            disabled={loading}
            style={{
              flex: 1,
              padding: '10px 14px',
              borderRadius: 8,
              border: '1px solid var(--color-border)',
              background: 'var(--color-bg)',
              color: 'var(--color-text)',
              fontSize: 14
            }}
          />
          <button className="btn btn-primary" onClick={onSend} disabled={loading || providers.length === 0}>
            发送
          </button>
          <button
            className="btn btn-secondary"
            onClick={onQuickDistill}
            disabled={loading || !input.trim()}
            title="快速蒸馏为笔记"
          >
            🧪
          </button>
        </div>
      </div>
    </>
  )
}

export default AgentChatPanel
