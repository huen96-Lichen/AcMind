import { useState, useCallback } from 'react'

interface DropZoneProps {
  onFilesDropped: (filePaths: string[]) => void
  children: React.ReactNode
}

function DropZone({ onFilesDropped, children }: DropZoneProps) {
  const [isDragging, setIsDragging] = useState(false)

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(true)
  }, [])

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)
  }, [])

  const handleDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)

    const files = Array.from(e.dataTransfer.files)
    const filePaths = files.map(f => (f as File & { path: string }).path).filter(Boolean)
    
    if (filePaths.length > 0) {
      onFilesDropped(filePaths)
    }
  }, [onFilesDropped])

  return (
    <div
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      style={{ position: 'relative', height: '100%' }}
    >
      {isDragging && (
        <div style={{
          position: 'absolute',
          inset: 0,
          background: 'rgba(249, 115, 22, 0.1)',
          border: '2px dashed var(--color-accent)',
          borderRadius: 12,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 100,
          pointerEvents: 'none'
        }}>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 48 }}>📁</div>
            <div style={{ marginTop: 8, fontWeight: 500 }}>松开以导入文件</div>
          </div>
        </div>
      )}
      {children}
    </div>
  )
}

export default DropZone
