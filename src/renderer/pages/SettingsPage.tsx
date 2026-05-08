import { useState, useEffect } from 'react'
import type { AppSettings } from '../../shared/types'

declare global {
  interface Window {
    electronAPI: {
      settings: {
        get: () => Promise<AppSettings>
        update: (settings: Partial<AppSettings>) => Promise<AppSettings>
      }
      export: {
        selectVault: () => Promise<string | null>
      }
    }
  }
}

function SettingsPage() {
  const [settings, setSettings] = useState<AppSettings | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadSettings()
  }, [])

  const loadSettings = async () => {
    try {
      const result = await window.electronAPI.settings.get()
      setSettings(result)
    } catch (error) {
      console.error('Failed to load settings:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleUpdate = async (updates: Partial<AppSettings>) => {
    if (!settings) return
    try {
      const updated = await window.electronAPI.settings.update(updates)
      setSettings(updated)
    } catch (error) {
      console.error('Failed to update settings:', error)
    }
  }

  const handleSelectVault = async () => {
    try {
      const vaultPath = await window.electronAPI.export.selectVault()
      if (vaultPath) {
        await handleUpdate({ vaultPath })
      }
    } catch (error) {
      console.error('Failed to select vault:', error)
    }
  }

  if (loading || !settings) {
    return <div className="page-content"><div className="empty-state">加载中...</div></div>
  }

  return (
    <div className="page-content">
      <div className="page-header">
        <h1>设置</h1>
        <p>应用配置与偏好设置</p>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginBottom: 16 }}>外观</h3>
        <div style={{ display: 'flex', gap: 8 }}>
          {(['light', 'dark', 'system'] as const).map((theme) => (
            <button
              key={theme}
              className={`btn ${settings.theme === theme ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => handleUpdate({ theme })}
            >
              {theme === 'light' ? '☀️ 浅色' : theme === 'dark' ? '🌙 深色' : '💻 跟随系统'}
            </button>
          ))}
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginBottom: 16 }}>Obsidian 导出</h3>
        <div style={{ marginBottom: 12 }}>
          <label style={{ fontSize: 13, color: 'var(--color-text-secondary)' }}>仓库路径</label>
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <input
              type="text"
              value={settings.vaultPath || '未设置'}
              readOnly
              style={{
                flex: 1,
                padding: '8px 12px',
                borderRadius: 6,
                border: '1px solid var(--color-border)',
                background: 'var(--color-bg)',
                color: settings.vaultPath ? 'var(--color-text)' : 'var(--color-text-secondary)',
                fontSize: 14
              }}
            />
            <button className="btn btn-secondary" onClick={handleSelectVault}>
              选择仓库
            </button>
          </div>
        </div>
        <div style={{ marginBottom: 12 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={settings.autoFrontmatter}
              onChange={(e) => handleUpdate({ autoFrontmatter: e.target.checked })}
              style={{ width: 16, height: 16 }}
            />
            <span>自动生成 YAML frontmatter</span>
          </label>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginBottom: 16 }}>剪贴板</h3>
        <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
          <input
            type="checkbox"
            checked={settings.autoCaptureClipboard}
            onChange={(e) => handleUpdate({ autoCaptureClipboard: e.target.checked })}
            style={{ width: 16, height: 16 }}
          />
          <span>自动捕获剪贴板内容</span>
        </label>
      </div>

      <div className="card">
        <h3 style={{ marginBottom: 16 }}>关于</h3>
        <p style={{ color: 'var(--color-text-secondary)', fontSize: 13 }}>
          <strong>AcMind</strong> v0.10.0<br />
          Local-first desktop AI information hub<br /><br />
          基于 Electron + React + SQLite 构建
        </p>
      </div>
    </div>
  )
}

export default SettingsPage
