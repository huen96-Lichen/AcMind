import { desktopCapturer, screen, BrowserWindow, nativeImage, app } from 'electron'
import path from 'path'
import fs from 'fs'
import log from 'electron-log'
import { createSourceItem } from '../storage'
import * as assets from '../assets'

let selectionWindow: BrowserWindow | null = null

interface Rect {
  x: number
  y: number
  width: number
  height: number
}

export async function captureFullScreen(): Promise<string | null> {
  try {
    const primaryDisplay = screen.getPrimaryDisplay()
    const { width, height } = primaryDisplay.size
    
    const sources = await desktopCapturer.getSources({
      types: ['screen'],
      thumbnailSize: { width, height }
    })

    if (sources.length > 0) {
      const dataUrl = sources[0].thumbnail.toDataURL()
      return dataUrl
    }
    return null
  } catch (error) {
    log.error('Full screen capture failed:', error)
    return null
  }
}

export async function captureRegion(rect: Rect): Promise<string | null> {
  try {
    const primaryDisplay = screen.getPrimaryDisplay()
    const sources = await desktopCapturer.getSources({
      types: ['screen'],
      thumbnailSize: primaryDisplay.size
    })

    if (sources.length === 0) return null

    const thumbnail = sources[0].thumbnail
    const cropped = thumbnail.crop({
      x: Math.round(rect.x * (thumbnail.getSize().width / primaryDisplay.size.width)),
      y: Math.round(rect.y * (thumbnail.getSize().height / primaryDisplay.size.height)),
      width: Math.round(rect.width * (thumbnail.getSize().width / primaryDisplay.size.width)),
      height: Math.round(rect.height * (thumbnail.getSize().height / primaryDisplay.size.height))
    })

    return cropped.toDataURL()
  } catch (error) {
    log.error('Region capture failed:', error)
    return null
  }
}

export async function captureAndSave(rect?: Rect): Promise<{ dataUrl: string; localPath: string } | null> {
  try {
    const dataUrl = rect ? await captureRegion(rect) : await captureFullScreen()
    if (!dataUrl) return null

    const base64Data = dataUrl.replace(/^data:image\/\w+;base64,/, '')
    const buffer = Buffer.from(base64Data, 'base64')
    const fileName = `screenshot_${Date.now()}.png`
    const tempPath = path.join(app.getPath('temp'), fileName)
    
    fs.writeFileSync(tempPath, buffer)

    const asset = assets.saveAssetFile(undefined, fileName, tempPath)

    await createSourceItem({
      type: 'screenshot',
      source: 'screenshot',
      status: 'captured',
      title: `截图 ${new Date().toLocaleString('zh-CN')}`,
      previewText: '屏幕截图',
      contentPath: asset.localPath,
      tags: [],
      assetFileIds: [asset.id],
      metadata: { capturedAt: Date.now(), rect }
    })

    fs.unlinkSync(tempPath)

    return { dataUrl, localPath: asset.localPath }
  } catch (error) {
    log.error('Capture and save failed:', error)
    return null
  }
}

export function showSelectionOverlay(callback: (rect: Rect | null) => void): void {
  if (selectionWindow) {
    selectionWindow.close()
  }

  const primaryDisplay = screen.getPrimaryDisplay()
  const { width, height } = primaryDisplay.bounds
  const scaleFactor = primaryDisplay.scaleFactor

  selectionWindow = new BrowserWindow({
    x: primaryDisplay.bounds.x,
    y: primaryDisplay.bounds.y,
    width,
    height,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    movable: false,
    fullscreenable: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  })

  selectionWindow.setIgnoreMouseEvents(false)

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          width: 100vw;
          height: 100vh;
          cursor: crosshair;
          user-select: none;
        }
        #overlay {
          position: absolute;
          top: 0; left: 0;
          width: 100%; height: 100%;
          background: rgba(0, 0, 0, 0.3);
        }
        #selection {
          position: absolute;
          border: 2px solid #f97316;
          background: transparent;
          box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.5);
        }
        #info {
          position: absolute;
          bottom: 20px;
          left: 50%;
          transform: translateX(-50%);
          background: rgba(0,0,0,0.8);
          color: white;
          padding: 8px 16px;
          border-radius: 6px;
          font-family: system-ui;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div id="overlay"></div>
      <div id="selection"></div>
      <div id="info">拖动选择区域，按 ESC 取消</div>
      <script>
        const overlay = document.getElementById('overlay');
        const selection = document.getElementById('selection');
        let isSelecting = false;
        let startX, startY;

        overlay.addEventListener('mousedown', (e) => {
          isSelecting = true;
          startX = e.clientX;
          startY = e.clientY;
          selection.style.left = startX + 'px';
          selection.style.top = startY + 'px';
          selection.style.width = '0';
          selection.style.height = '0';
        });

        overlay.addEventListener('mousemove', (e) => {
          if (!isSelecting) return;
          const currentX = e.clientX;
          const currentY = e.clientY;
          const left = Math.min(startX, currentX);
          const top = Math.min(startY, currentY);
          const width = Math.abs(currentX - startX);
          const height = Math.abs(currentY - startY);
          selection.style.left = left + 'px';
          selection.style.top = top + 'px';
          selection.style.width = width + 'px';
          selection.style.height = height + 'px';
        });

        overlay.addEventListener('mouseup', (e) => {
          if (!isSelecting) return;
          isSelecting = false;
          const currentX = e.clientX;
          const currentY = e.clientY;
          const left = Math.min(startX, currentX);
          const top = Math.min(startY, currentY);
          const width = Math.abs(currentX - startX);
          const height = Math.abs(currentY - startY);
          
          if (width > 10 && height > 10) {
            window.electronAPI.sendSelection({ x: left, y: top, width, height });
          } else {
            window.close();
          }
        });

        document.addEventListener('keydown', (e) => {
          if (e.key === 'Escape') {
            window.close();
          }
        });
      </script>
    </body>
    </html>
  `

  selectionWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`)

  selectionWindow.on('closed', () => {
    selectionWindow = null
  })
}
