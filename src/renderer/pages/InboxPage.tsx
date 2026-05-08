import { useState, useEffect, useCallback } from 'react'
import type { SourceItem, SourceItemStatus, SourceType } from '../../shared/types'
import DropZone from '../components/DropZone'

declare global {
  interface Window {
    electronAPI: {
      storage: {
        getSourceItems: (filter?: { status?: string; type?: string; source?: string; limit?: number; offset?: number }) => Promise<SourceItem[]>
        getSourceItem: (id: string) => Promise<SourceItem | null>
        createSourceItem: (item: Omit<SourceItem, 'id' | 'createdAt'>) => Promise<SourceItem>
        updateSourceItem: (id: string, updates: Partial<SourceItem>) => Promise<SourceItem>
        deleteSourceItem: (id: string) => Promise<void>
        searchSourceItems: (query: string) => Promise<SourceItem[]>
      }
      capture: {
        screenshot: () => Promise<string | null>
        screenshotRegion: () => Promise<string | null>
        selectFile: () => Promise<string[]>
        importFile: (filePath: string) => Promise<SourceItem | null>
        captureWebpage: (url: string) => Promise<SourceItem | null>
      }
    }
  }
}

const STATUS_OPTIONS: { value: SourceItemStatus | ''; label: string }[] = [
  { value: '', label: '全部状态' },
  { value: 'inbox', label: '收集箱' },
  { value: 'pending', label: '待处理' },
  { value: 'distilling', label: '蒸馏中' },
  { value: 'distilled', label: '已蒸馏' },
  { value: 'exported', label: '已导出' },
  { value: 'archived', label: '已归档' },
]

const TYPE_OPTIONS: { value: SourceType | ''; label: string }[] = [
  { value: '', label: '全部类型' },
  { value: 'text', label: '文本' },
  { value: 'image', label: '图片' },
  { value: 'screenshot', label: '截图' },
  { value: 'webpage', label: '网页' },
  { value: 'file', label: '文件' },
]

function InboxPage() {
  const [items, setItems] = useState<SourceItem[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedItem, setSelectedItem] = useState<SourceItem | null>(null)
  const [newText, setNewText] = useState('')
  const [webpageUrl, setWebpageUrl] = useState('')
  const [showWebpageInput, setShowWebpageInput] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<SourceItemStatus | ''>('')
  const [typeFilter, setTypeFilter] = useState<SourceType | ''>('')

  const loadItems = useCallback(async () => {
    setLoading(true)
    try {
      const filter: { status?: string; type?: string; limit?: number } = { limit: 100 }
      if (statusFilter) filter.status = statusFilter
      if (typeFilter) filter.type = typeFilter
      const result = await window.electronAPI.storage.getSourceItems(filter)
      setItems(result)
    } catch (error) {
      console.error('Failed to load items:', error)
    } finally {
      setLoading(false)
    }
  }, [statusFilter, typeFilter])

  useEffect(() => {
    loadItems()
  }, [loadItems])

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      loadItems()
      return
    }
    setLoading(true)
    try {
      const result = await window.electronAPI.storage.searchSourceItems(searchQuery)
      setItems(result)
    } catch (error) {
      console.error('Failed to search:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleAddText = async () => {
    if (!newText.trim()) return
    try {
      await window.electronAPI.storage.createSourceItem({
        type: 'text',
        source: 'manual',
        status: 'inbox',
        previewText: newText.trim(),
        title: newText.trim().slice(0, 50),
        contentPath: '',
        tags: [],
        assetFileIds: [],
        metadata: {}
      })
      setNewText('')
      loadItems()
    } catch (error) {
      console.error('Failed to create item:', error)
    }
  }

  const handleScreenshot = async () => {
    try {
      const result = await window.electronAPI.capture.screenshot()
      if (result) {
        console.log('Screenshot captured')
      }
      loadItems()
    } catch (error) {
      console.error('Failed to capture screenshot:', error)
    }
  }

  const handleScreenshotRegion = async () => {
    try {
      const result = await window.electronAPI.capture.screenshotRegion()
      if (result) {
        console.log('Region screenshot captured')
      }
      loadItems()
    } catch (error) {
      console.error('Failed to capture region:', error)
    }
  }

  const handleSelectFile = async () => {
    try {
      const filePaths = await window.electronAPI.capture.selectFile()
      for (const filePath of filePaths) {
        await window.electronAPI.capture.importFile(filePath)
      }
      loadItems()
    } catch (error) {
      console.error('Failed to import file:', error)
    }
  }

  const handleFilesDropped = async (filePaths: string[]) => {
    try {
      for (const filePath of filePaths) {
        await window.electronAPI.capture.importFile(filePath)
      }
      loadItems()
    } catch (error) {
      console.error('Failed to import dropped files:', error)
    }
  }

  const handleCaptureWebpage = async () => {
    if (!webpageUrl.trim()) return
    try {
      await window.electronAPI.capture.captureWebpage(webpageUrl)
      setWebpageUrl('')
      setShowWebpageInput(false)
      loadItems()
    } catch (error) {
      console.error('Failed to capture webpage:', error)
    }
  }

  const handleDelete = async (id: string) => {
    try {
      await window.electronAPI.storage.deleteSourceItem(id)
      if (selectedItem?.id === id) setSelectedItem(null)
      loadItems()
    } catch (error) {
      console.error('Failed to delete item:', error)
    }
  }

  const handleUpdateStatus = async (id: string, status: SourceItemStatus) => {
    try {
      await window.electronAPI.storage.updateSourceItem(id, { status })
      if (selectedItem?.id === id) {
        setSelectedItem({ ...selectedItem, status })
      }
      loadItems()
    } catch (error) {
      console.error('Failed to update status:', error)
    }
  }

  const formatDate = (date: Date) => {
    return new Date(date).toLocaleString('zh-CN', {
      month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
    })
  }

  const getStatusColor = (status: SourceItemStatus) => {
    const colors: Record<SourceItemStatus, string> = {
      inbox: '#f97316', pending: '#a1a1a6', capturing: '#3b82f6', captured: '#3b82f6',
      parsing: '#8b5cf6', parsed: '#8b5cf6', distilling: '#eab308', distilled: '#22c55e',
      exporting: '#3b82f6', exported: '#22c55e', archived: '#6b7280', deleted: '#ef4444'
    }
    return colors[status] || '#6b7280'
  }

  const getTypeIcon = (type: SourceType) => {
    const icons: Record<string, string> = {
      text: '📝', image: '🖼️', screenshot: '📸', webpage: '🌐', file: '📁',
      audio: '🎵', video: '🎬', pdf: '📄', docx: '📃', unknownFile: '❓'
    }
    return icons[type] || '📄'
  }

  return (
    <DropZone onFilesDropped={handleFilesDropped}>
      <div className="page-content" style={{ display: 'flex', gap: 24, height: 'calc(100vh - 100px)' }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
          <div className="page-header">
            <h1>收集箱</h1>
            <p>拖拽文件到此处导入 · 支持截图和网页抓取</p>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
              <input
                type="text"
                placeholder="搜索..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                style={{ flex: 1, padding: '8px 12px', borderRadius: 6, border: '1px solid var(--color-border)', background: 'var(--color-bg)', color: 'var(--color-text)', fontSize: 14 }}
              />
              <button className="btn btn-secondary" onClick={handleSearch}>搜索</button>
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as SourceItemStatus | '')} style={{ padding: '6px 12px', borderRadius: 6, border: '1px solid var(--color-border)', background: 'var(--color-bg)', color: 'var(--color-text)', fontSize: 13 }}>
                {STATUS_OPTIONS.map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
              </select>
              <select value={typeFilter} onChange={(e) => setTypeFilter(e.target.value as SourceType | '')} style={{ padding: '6px 12px', borderRadius: 6, border: '1px solid var(--color-border)', background: 'var(--color-bg)', color: 'var(--color-text)', fontSize: 13 }}>
                {TYPE_OPTIONS.map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
              </select>
            </div>
          </div>

          <div className="card" style={{ marginBottom: 16 }}>
            <div style={{ display: 'flex', gap: 8 }}>
              <input
                type="text"
                placeholder="输入文本..."
                value={newText}
                onChange={(e) => setNewText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleAddText()}
                style={{ flex: 1, padding: '8px 12px', borderRadius: 6, border: '1px solid var(--color-border)', background: 'var(--color-bg)', color: 'var(--color-text)', fontSize: 14 }}
              />
              <button className="btn btn-primary" onClick={handleAddText}>添加</button>
              <button className="btn btn-secondary" onClick={handleScreenshot}>📸</button>
              <button className="btn btn-secondary" onClick={handleScreenshotRegion}>✂️</button>
              <button className="btn btn-secondary" onClick={handleSelectFile}>📁</button>
              <button className="btn btn-secondary" onClick={() => setShowWebpageInput(!showWebpageInput)}>🌐</button>
            </div>
            {showWebpageInput && (
              <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                <input
                  type="url"
                  placeholder="输入网址..."
                  value={webpageUrl}
                  onChange={(e) => setWebpageUrl(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleCaptureWebpage()}
                  style={{ flex: 1, padding: '8px 12px', borderRadius: 6, border: '1px solid var(--color-border)', background: 'var(--color-bg)', color: 'var(--color-text)', fontSize: 14 }}
                />
                <button className="btn btn-primary" onClick={handleCaptureWebpage}>抓取</button>
              </div>
            )}
          </div>

          {loading ? (
            <div className="empty-state">加载中...</div>
          ) : items.length === 0 ? (
            <div className="empty-state">
              <div>📥</div>
              <h3>收集箱为空</h3>
              <p>拖拽文件或使用上方工具添加内容</p>
            </div>
          ) : (
            <div className="list" style={{ flex: 1, overflowY: 'auto' }}>
              {items.map((item) => (
                <div
                  key={item.id}
                  className="list-item"
                  onClick={() => setSelectedItem(item)}
                  style={{ cursor: 'pointer', borderColor: selectedItem?.id === item.id ? 'var(--color-accent)' : undefined }}
                >
                  <span style={{ fontSize: 20 }}>{getTypeIcon(item.type)}</span>
                  <div className="list-item-content">
                    <div className="list-item-title">{item.title || item.previewText?.slice(0, 50) || '无标题'}</div>
                    <div className="list-item-meta">
                      <span style={{ display: 'inline-block', padding: '1px 6px', borderRadius: 4, background: getStatusColor(item.status), color: 'white', fontSize: 11, marginRight: 8 }}>{item.status}</span>
                      {item.source} · {formatDate(item.createdAt)}
                    </div>
                  </div>
                  <button className="btn btn-secondary" onClick={(e) => { e.stopPropagation(); handleDelete(item.id) }} style={{ padding: '4px 8px', fontSize: 12 }}>删除</button>
                </div>
              ))}
            </div>
          )}
        </div>

        {selectedItem && (
          <div className="card" style={{ width: 400, flexShrink: 0, alignSelf: 'flex-start', position: 'sticky', top: 0 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3>详情</h3>
              <button className="btn btn-secondary" onClick={() => setSelectedItem(null)} style={{ padding: '4px 8px' }}>×</button>
            </div>
            <div style={{ marginBottom: 12 }}>
              <label style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>标题</label>
              <div style={{ marginTop: 4 }}>{selectedItem.title || '-'}</div>
            </div>
            <div style={{ marginBottom: 12 }}>
              <label style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>状态</label>
              <select value={selectedItem.status} onChange={(e) => handleUpdateStatus(selectedItem.id, e.target.value as SourceItemStatus)} style={{ width: '100%', marginTop: 4, padding: '6px 8px', borderRadius: 6, border: '1px solid var(--color-border)', background: 'var(--color-bg)', color: 'var(--color-text)' }}>
                {STATUS_OPTIONS.filter(o => o.value).map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
              </select>
            </div>
            <div style={{ marginBottom: 12 }}>
              <label style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>类型</label>
              <div style={{ marginTop: 4 }}>{getTypeIcon(selectedItem.type)} {selectedItem.type}</div>
            </div>
            <div style={{ marginBottom: 12 }}>
              <label style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>来源</label>
              <div style={{ marginTop: 4 }}>{selectedItem.source}</div>
            </div>
            {selectedItem.previewText && (
              <div style={{ marginBottom: 12 }}>
                <label style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>内容预览</label>
                <div style={{ marginTop: 4, padding: 8, background: 'var(--color-bg)', borderRadius: 6, fontSize: 13, maxHeight: 150, overflow: 'auto', whiteSpace: 'pre-wrap' }}>{selectedItem.previewText}</div>
              </div>
            )}
            {selectedItem.originalUrl && (
              <div style={{ marginBottom: 12 }}>
                <label style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>原始链接</label>
                <a href={selectedItem.originalUrl} target="_blank" rel="noopener noreferrer" style={{ marginTop: 4, display: 'block', fontSize: 13, color: 'var(--color-accent)' }}>{selectedItem.originalUrl}</a>
              </div>
            )}
            {selectedItem.tags.length > 0 && (
              <div style={{ marginBottom: 12 }}>
                <label style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>标签</label>
                <div style={{ marginTop: 4, display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                  {selectedItem.tags.map((tag, i) => <span key={i} style={{ padding: '2px 8px', background: 'var(--color-accent)', color: 'white', borderRadius: 12, fontSize: 12 }}>{tag}</span>)}
                </div>
              </div>
            )}
            <div style={{ marginTop: 16, paddingTop: 16, borderTop: '1px solid var(--color-border)', fontSize: 11, color: 'var(--color-text-secondary)' }}>
              创建于 {formatDate(selectedItem.createdAt)}
            </div>
          </div>
        )}
      </div>
    </DropZone>
  )
}

export default InboxPage
