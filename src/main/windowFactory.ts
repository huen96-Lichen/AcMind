import { BrowserWindow, screen } from 'electron';
import type { BrowserWindowConstructorOptions } from 'electron';

export interface RendererLoadOptions {
  isDev: boolean;
  rendererDevUrl?: string;
  rendererFilePath: string;
  view?: string;
}

export interface ManagedWindowOptions {
  browserWindow: BrowserWindowConstructorOptions;
  renderer: RendererLoadOptions;
  centerOnCreate?: boolean;
  onCreate?: (windowRef: BrowserWindow) => void;
}

function buildRendererUrl(baseUrl: string, view?: string): string {
  if (!view) {
    return baseUrl;
  }

  const url = new URL(baseUrl);
  url.searchParams.set('view', view);
  return url.toString();
}

export function centerWindowOnActiveDisplay(windowRef: BrowserWindow): void {
  const display = screen.getDisplayNearestPoint(screen.getCursorScreenPoint()).workArea;
  const bounds = windowRef.getBounds();
  const x = Math.round(display.x + (display.width - bounds.width) / 2);
  const y = Math.round(display.y + (display.height - bounds.height) / 2);
  windowRef.setPosition(x, y);
}

export function loadRendererContent(windowRef: BrowserWindow, options: RendererLoadOptions): void {
  if (options.isDev && options.rendererDevUrl) {
    console.log('window.renderer.load', {
      mode: 'dev',
      target: options.rendererDevUrl,
      view: options.view ?? null
    });
    void windowRef.loadURL(buildRendererUrl(options.rendererDevUrl, options.view));
    return;
  }

  if (options.view) {
    console.log('window.renderer.load', {
      mode: 'file-query',
      target: options.rendererFilePath,
      view: options.view
    });
    void windowRef.loadFile(options.rendererFilePath, {
      query: {
        view: options.view
      }
    });
    return;
  }

  console.log('window.renderer.load', {
    mode: 'file',
    target: options.rendererFilePath,
    view: null
  });
  void windowRef.loadFile(options.rendererFilePath);
}

export function createManagedWindow(options: ManagedWindowOptions): BrowserWindow {
  const windowRef = new BrowserWindow(options.browserWindow);

  console.log('window.created', {
    title: options.browserWindow.title ?? null,
    width: options.browserWindow.width ?? null,
    height: options.browserWindow.height ?? null,
    frame: options.browserWindow.frame ?? null,
    transparent: options.browserWindow.transparent ?? null,
    alwaysOnTop: options.browserWindow.alwaysOnTop ?? null
  });

  if (options.centerOnCreate !== false) {
    centerWindowOnActiveDisplay(windowRef);
  }

  loadRendererContent(windowRef, options.renderer);
  options.onCreate?.(windowRef);
  return windowRef;
}
