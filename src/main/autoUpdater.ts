import { autoUpdater, type UpdateInfo } from 'electron-updater';
import { app, BrowserWindow, dialog } from 'electron';
import { logger } from './logger';

let updateDownloaded = false;

export function initAutoUpdater(isDev: boolean): void {
  if (isDev) {
    logger.info('app', 'autoUpdater', 'skip', 'Auto-update disabled in development mode');
    return;
  }

  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;
  autoUpdater.disableWebInstaller = true;

  autoUpdater.on('checking-for-update', () => {
    logger.info('app', 'autoUpdater', 'checking', 'Checking for updates...');
  });

  autoUpdater.on('update-available', (info: UpdateInfo) => {
    logger.info('app', 'autoUpdater', 'available', `Update available: ${info.version}`, {
      currentVersion: app.getVersion(),
      newVersion: info.version,
    });
  });

  autoUpdater.on('update-not-available', () => {
    logger.info('app', 'autoUpdater', 'up-to-date', 'App is up to date');
  });

  autoUpdater.on('download-progress', (progress) => {
    logger.info('app', 'autoUpdater', 'downloading', `Download progress: ${Math.round(progress.percent)}%`);
  });

  autoUpdater.on('update-downloaded', (info: UpdateInfo) => {
    updateDownloaded = true;
    logger.info('app', 'autoUpdater', 'downloaded', `Update downloaded: ${info.version}`);

    const windows = BrowserWindow.getAllWindows();
    const focusedWindow = windows.find((w) => w.isFocused()) ?? windows[0];

    if (focusedWindow) {
      dialog
        .showMessageBox(focusedWindow, {
          type: 'info',
          title: '更新就绪',
          message: `新版本 ${info.version} 已下载完成`,
          detail: '重启应用后生效。是否现在重启？',
          buttons: ['稍后重启', '立即重启'],
          defaultId: 0,
        })
        .then(({ response }) => {
          if (response === 1) {
            autoUpdater.quitAndInstall(false, true);
          }
        })
        .catch((err) => {
          logger.error('error', 'autoUpdater', 'dialog', 'Failed to show update dialog', {
            error: err instanceof Error ? err.message : String(err),
          });
        });
    }
  });

  autoUpdater.on('error', (err) => {
    logger.error('error', 'autoUpdater', 'error', 'Auto-update error', {
      error: err instanceof Error ? err.message : String(err),
    });
  });

  // Check for updates after a short delay to let the app fully load
  setTimeout(() => {
    autoUpdater.checkForUpdates().catch((err) => {
      logger.warn('app', 'autoUpdater', 'check-failed', 'Failed to check for updates', {
        error: err instanceof Error ? err.message : String(err),
      });
    });
  }, 10_000);
}

export function isUpdateDownloaded(): boolean {
  return updateDownloaded;
}
