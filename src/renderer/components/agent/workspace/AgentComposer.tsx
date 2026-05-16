import { useState, useRef, useCallback, useEffect } from 'react'

interface AgentComposerProps {
  input: string
  loading: boolean
  disabled?: boolean
  onInputChange: (value: string) => void
  onSend: () => void
  onQuickDistill?: () => void
}

export default function AgentComposer({
  input,
  loading,
  disabled,
  onInputChange,
  onSend,
  onQuickDistill,
}: AgentComposerProps) {
  const [focused, setFocused] = useState(false)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const adjustHeight = useCallback(() => {
    const el = textareaRef.current
    if (!el) return
    el.style.height = 'auto'
    const lineHeight = 21
    const maxLines = 8
    const maxHeight = lineHeight * maxLines
    el.style.height = `${Math.min(el.scrollHeight, maxHeight)}px`
  }, [])

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    onInputChange(e.target.value)
    requestAnimationFrame(adjustHeight)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      onSend()
    }
  }

  useEffect(() => {
    if (input === '' && textareaRef.current) {
      textareaRef.current.style.height = 'auto'
    }
  }, [input])

  return (
    <div style={{
      flexShrink: 0,
      padding: '16px 32px 24px',
      background: 'linear-gradient(to bottom, rgba(255,255,255,0), rgba(255,255,255,0.96) 28%)',
      display: 'flex',
      justifyContent: 'center',
    }}>
      <div style={{
        width: '100%',
        maxWidth: 860,
        background: 'var(--color-bg)',
        borderRadius: 18,
        border: `1px solid ${focused ? 'var(--color-accent)' : 'var(--color-border)'}`,
        padding: '12px 16px',
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
        boxShadow: focused ? '0 2px 12px rgba(0,0,0,0.06)' : '0 1px 4px rgba(0,0,0,0.04)',
        transition: 'border-color 0.2s, box-shadow 0.2s',
      }}>
        <textarea
          ref={textareaRef}
          value={input}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          placeholder="输入消息..."
          rows={1}
          disabled={disabled}
          style={{
            width: '100%',
            border: 'none',
            background: 'transparent',
            color: 'var(--color-text)',
            fontSize: 14,
            resize: 'none',
            outline: 'none',
            fontFamily: 'inherit',
            lineHeight: 1.5,
            overflow: 'hidden',
            maxHeight: 168,
            padding: 0,
          }}
        />
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}>
          <div style={{ display: 'flex', gap: 6 }}>
            <button
              onClick={() => onQuickDistill?.()}
              style={{
                fontSize: 12,
                color: 'var(--color-text-secondary)',
                background: 'transparent',
                border: '1px solid var(--color-border)',
                borderRadius: 8,
                padding: '4px 10px',
                cursor: 'pointer',
              }}
            >
              🧪 蒸馏
            </button>
          </div>
          <button
            onClick={() => { if (!loading && input.trim()) onSend() }}
            disabled={loading || !input.trim() || disabled}
            style={{
              background: 'var(--color-accent)',
              color: 'white',
              border: 'none',
              borderRadius: 10,
              width: 32,
              height: 32,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 15,
              fontWeight: 600,
              opacity: loading || !input.trim() ? 0.4 : 1,
              transition: 'opacity 0.15s',
            }}
          >
            ↑
          </button>
        </div>
      </div>
    </div>
  )
}