import { useState, useEffect } from 'react'
import type { SourceItem } from '../../shared/types'

function ClipboardPage() {
  const [clipboardItems, setClipboardItems] = useState<SourceItem[]>([])
  const [watching, setWatching] = useState(true)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadClipboardItems()
    loadStatus()

    const unsubscribe = window.electronAPI.on('clipboard:newItem', (data: unknown) => {
      console.log('New clipboard item:', data)
      loadClipboardItems()
    })

    return () => {
      unsubscribe()
    }
  }, [])

  const loadClipboardItems = async () => {
    try {
      const items = await window.electronAPI.storage.getSourceItems({
        source: 'clipboard',
        limit: 50
      })
      setClipboardItems(items)
    } catch (error) {
      console.error('Failed to load clipboard items:', error)
    } finally {
      setLoading(false)
    }
  }

  const loadStatus = async () => {
    try {
      const status = await window.electronAPI.clipboard.getStatus()
      setWatching(status.watching)
    } catch (error) {
      console.error('Failed to load clipboard status:', error)
    }
  }

  const handleToggle = async () => {
    try {
      const result = await window.electronAPI.clipboard.toggle()
      setWatching(result.watching)
    } catch (error) {
      console.error('Failed to toggle clipboard:', error)
    }
  }

  const formatDate = (date: Date) => {
    return new Date(date).toLocaleString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  return (
    <div className="page-content">
      <div className="page-header">
        <h1>剪贴板</h1>
        <p>自动记录剪贴板内容</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <h3 style={{ marginBottom: 4 }}>剪贴板监听</h3>
            <p style={{ color: 'var(--color-text-secondary)', fontSize: 13 }}>
              {watching ? '正在监听剪贴板变化' : '已暂停监听'}
            </p>
          </div>
          <button
            className={`btn ${watching ? 'btn-primary' : 'btn-secondary'}`}
            onClick={handleToggle}
          >
            {watching ? '⏸️ 暂停' : '▶️ 开启'}
          </button>
        </div>
      </div>

      <h3 style={{ marginBottom: 16 }}>历史记录</h3>

      {loading ? (
        <div className="empty-state">加载中...</div>
      ) : clipboardItems.length === 0 ? (
        <div className="empty-state">
          <div>📋</div>
          <h3>暂无记录</h3>
          <p>复制内容后会自动显示在这里</p>
        </div>
      ) : (
        <div className="list">
          {clipboardItems.map((item) => (
            <div key={item.id} className="list-item">
              <span style={{ fontSize: 20 }}>
                {item.type === 'image' ? '🖼️' : item.type === 'webpage' ? '🌐' : '📝'}
              </span>
              <div className="list-item-content">
                <div className="list-item-title">
                  {item.previewText?.slice(0, 100) || item.title || '无内容'}
                </div>
                <div className="list-item-meta">
                  {item.type} · {formatDate(item.createdAt)}
                </div>
              </div>
              <button
                className="btn btn-secondary"
                onClick={() => {
                  navigator.clipboard.writeText(item.previewText || '')
                }}
                style={{ padding: '4px 8px', fontSize: 12 }}
              >
                复制
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default ClipboardPage
