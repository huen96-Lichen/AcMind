import { useState, useEffect, useRef } from 'react'
import type { ProviderConfig, SourceItem } from '../../shared/types'

interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

declare global {
  interface Window {
    electronAPI: {
      ai: {
        getProviders: () => Promise<ProviderConfig[]>
        chat: (providerId: string, messages: ChatMessage[]) => Promise<{ content: string }>
      }
      distill: {
        quick: (content: string) => Promise<string>
        item: (id: string) => Promise<{ success: boolean; error?: string }>
      }
      storage: {
        getSourceItems: (filter?: { source?: string; limit?: number }) => Promise<SourceItem[]>
        updateSourceItem: (id: string, updates: Partial<SourceItem>) => Promise<SourceItem>
      }
    }
  }
}

function AgentPage() {
  const [providers, setProviders] = useState<ProviderConfig[]>([])
  const [selectedProvider, setSelectedProvider] = useState<string>('')
  const [messages, setMessages] = useState<ChatMessage[]>([
    { role: 'assistant', content: '你好！我是 AcMind AI 助手。有什么我可以帮你的吗？' }
  ])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [distillItems, setDistillItems] = useState<SourceItem[]>([])
  const [activeTab, setActiveTab] = useState<'chat' | 'distill'>('chat')
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    loadProviders()
    loadDistillableItems()
  }, [])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const loadProviders = async () => {
    try {
      const result = await window.electronAPI.ai.getProviders()
      setProviders(result)
      if (result.length > 0 && !selectedProvider) {
        setSelectedProvider(result[0].id)
      }
    } catch (error) {
      console.error('Failed to load providers:', error)
    }
  }

  const loadDistillableItems = async () => {
    try {
      const items = await window.electronAPI.storage.getSourceItems({
        source: 'inbox',
        limit: 20
      })
      setDistillItems(items)
    } catch (error) {
      console.error('Failed to load items:', error)
    }
  }

  const handleSend = async () => {
    if (!input.trim() || loading) return

    const userMessage: ChatMessage = { role: 'user', content: input.trim() }
    setMessages(prev => [...prev, userMessage])
    setInput('')
    setLoading(true)

    try {
      const allMessages = [...messages, userMessage]
      const response = await window.electronAPI.ai.chat(selectedProvider, allMessages)
      
      setMessages(prev => [...prev, { role: 'assistant', content: response.content }])
    } catch (error) {
      console.error('AI chat error:', error)
      setMessages(prev => [...prev, { role: 'assistant', content: '抱歉，发生了错误。请检查 AI 服务是否可用。' }])
    } finally {
      setLoading(false)
    }
  }

  const handleDistillItem = async (item: SourceItem) => {
    try {
      const result = await window.electronAPI.distill.item(item.id)
      if (result.success) {
        await loadDistillableItems()
        alert('蒸馏完成！')
      } else {
        alert(`蒸馏失败: ${result.error}`)
      }
    } catch (error) {
      console.error('Distill error:', error)
      alert('蒸馏失败')
    }
  }

  const handleQuickDistill = async () => {
    if (!input.trim()) return
    
    setLoading(true)
    try {
      const result = await window.electronAPI.distill.quick(input)
      setMessages(prev => [...prev, { role: 'assistant', content: `📝 快速蒸馏结果：\n\n${result}` }])
      setInput('')
    } catch (error) {
      console.error('Quick distill error:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="page-content">
      <div className="page-header">
        <h1>Agent</h1>
        <p>AI 对话与知识蒸馏</p>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            className={`btn ${activeTab === 'chat' ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => setActiveTab('chat')}
          >
            💬 AI 对话
          </button>
          <button
            className={`btn ${activeTab === 'distill' ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => { setActiveTab('distill'); loadDistillableItems() }}
          >
            🧪 知识蒸馏
          </button>
        </div>
      </div>

      {activeTab === 'chat' && (
        <>
          <div className="card" style={{ marginBottom: 16 }}>
            <label style={{ fontSize: 13, color: 'var(--color-text-secondary)', marginBottom: 8, display: 'block' }}>
              选择 AI 模型
            </label>
            <select
              value={selectedProvider}
              onChange={(e) => setSelectedProvider(e.target.value)}
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: 6,
                border: '1px solid var(--color-border)',
                background: 'var(--color-bg)',
                color: 'var(--color-text)'
              }}
            >
              {providers.map(p => (
                <option key={p.id} value={p.id}>{p.name} ({p.modelId})</option>
              ))}
            </select>
          </div>

          <div className="card" style={{ height: 400, display: 'flex', flexDirection: 'column' }}>
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
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && handleSend()}
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
              <button className="btn btn-primary" onClick={handleSend} disabled={loading}>
                发送
              </button>
              <button
                className="btn btn-secondary"
                onClick={handleQuickDistill}
                disabled={loading || !input.trim()}
                title="快速蒸馏为笔记"
              >
                🧪
              </button>
            </div>
          </div>
        </>
      )}

      {activeTab === 'distill' && (
        <div className="card">
          <h3 style={{ marginBottom: 16 }}>待蒸馏内容</h3>
          <p style={{ color: 'var(--color-text-secondary)', marginBottom: 16, fontSize: 13 }}>
            点击按钮对内容进行 AI 蒸馏，自动生成结构化笔记
          </p>
          
          {distillItems.length === 0 ? (
            <div className="empty-state">
              <div>📭</div>
              <p>收集箱暂无待蒸馏内容</p>
            </div>
          ) : (
            <div className="list">
              {distillItems.map(item => (
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
                    onClick={() => handleDistillItem(item)}
                    style={{ padding: '6px 12px' }}
                  >
                    蒸馏
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default AgentPage
