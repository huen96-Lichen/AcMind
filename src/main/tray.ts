import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { Menu, Tray, app, nativeImage } from 'electron';

// ---------------------------------------------------------------------------
// Tray icon resolution
// ---------------------------------------------------------------------------

function resolveTrayAssetCandidates(fileName: string): string[] {
  return [
    path.join(app.getAppPath(), 'assets', 'icons', 'tray', fileName),
    path.join(process.resourcesPath, 'assets', 'icons', 'tray', fileName),
    path.join(__dirname, '../../assets/icons/tray', fileName),
    path.join(process.cwd(), 'assets/icons/tray', fileName),
  ];
}

export function createBrandNativeImage(): Electron.NativeImage {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
    <defs>
      <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="#f6b15b"/>
        <stop offset="100%" stop-color="#e87a3d"/>
      </linearGradient>
    </defs>
    <circle cx="32" cy="32" r="28" fill="url(#g)"/>
    <path d="M22 20h20a4 4 0 0 1 4 4v16a4 4 0 0 1-4 4H28l-8 8v-8h2a4 4 0 0 1-4-4V24a4 4 0 0 1 4-4Z" fill="rgba(255,255,255,0.95)"/>
    <path d="M28 28h12M28 34h8" stroke="#e87a3d" stroke-width="3" stroke-linecap="round"/>
  </svg>`;
  const image = nativeImage.createFromDataURL(`data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`);
  if (process.platform === 'darwin') {
    image.setTemplateImage(true);
  }
  return image.resize({ width: 64, height: 64 });
}

function loadTrayIcon(): Electron.NativeImage {
  const representations = [
    { fileName: 'pinmind-menubar-template.png', scaleFactor: 1 },
    { fileName: 'pinmind-menubar-template@2x.png', scaleFactor: 2 },
  ];

  const icon = nativeImage.createEmpty();
  const loadedPaths: string[] = [];

  for (const rep of representations) {
    const resolvedPath = resolveTrayAssetCandidates(rep.fileName).find((c) => existsSync(c));
    if (!resolvedPath) continue;

    icon.addRepresentation({
      scaleFactor: rep.scaleFactor,
      buffer: readFileSync(resolvedPath),
    });
    loadedPaths.push(resolvedPath);
  }

  if (!icon.isEmpty()) {
    if (process.platform === 'darwin') {
      icon.setTemplateImage(true);
    }
    return icon;
  }

  return createBrandNativeImage().resize({ width: 16, height: 16 });
}

// ---------------------------------------------------------------------------
// TrayController
// ---------------------------------------------------------------------------

export interface TrayControllerOptions {
  onToggleWindow: () => void;
  onShowSettings: () => void;
  onQuit: () => void;
}

export function createTrayController(options: TrayControllerOptions): Tray {
  const icon = loadTrayIcon();
  const tray = new Tray(icon);
  tray.setToolTip('PinMind');

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Show PinMind',
      click: () => options.onToggleWindow(),
    },
    {
      label: 'Settings',
      click: () => options.onShowSettings(),
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => options.onQuit(),
    },
  ]);

  tray.setContextMenu(contextMenu);

  // Click tray icon to toggle window visibility
  tray.on('click', () => {
    options.onToggleWindow();
  });

  return tray;
}
