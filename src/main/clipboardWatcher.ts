import { createHash } from 'node:crypto';
import path from 'node:path';
import { clipboard } from 'electron';
import type { NativeImage } from 'electron';
import { logger } from './logger';
import { getClipboardSourceApp } from './sourceApp';
import { settings } from './settings';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ClipboardContentType = 'text' | 'image';

export interface ClipboardContent {
  type: ClipboardContentType;
  text?: string;
  image?: NativeImage;
  contentHash: string;
}

export type OnNewContentCallback = (content: ClipboardContent) => Promise<void> | void;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_POLL_INTERVAL_MS = 500;

// ---------------------------------------------------------------------------
// ClipboardWatcher
// ---------------------------------------------------------------------------

class ClipboardWatcher {
  private pollIntervalMs: number = DEFAULT_POLL_INTERVAL_MS;
  private timer: NodeJS.Timeout | null = null;
  private isTicking = false;
  private lastTextHash: string | null = null;
  private lastImageHash: string | null = null;
  private skippedTickCount = 0;
  private onNewContent: OnNewContentCallback | null = null;
  private enabled = true;

  /**
   * Start polling the clipboard at the configured interval.
   * Takes an optional callback that fires when new content is detected.
   */
  start(onNewContent?: OnNewContentCallback): void {
    if (this.timer) {
      return;
    }

    this.onNewContent = onNewContent ?? null;

    // Read current poll interval from settings
    const currentSettings = settings.load();
    this.pollIntervalMs =
      Number.isFinite(currentSettings.pollIntervalMs) && currentSettings.pollIntervalMs > 0
        ? Math.floor(currentSettings.pollIntervalMs)
        : DEFAULT_POLL_INTERVAL_MS;

    // Snapshot current clipboard state to avoid capturing stale content
    try {
      this.lastTextHash = this.hashText(clipboard.readText());
      this.lastImageHash = this.hashImageBuffer(clipboard.readImage().toPNG());
    } catch (error) {
      logger.warn('app', 'clipboardWatcher', 'start', 'Failed to read initial clipboard snapshot', {
        error: error instanceof Error ? error.message : String(error),
      });
      this.lastTextHash = null;
      this.lastImageHash = null;
    }

    this.timer = setInterval(() => {
      void this.tick();
    }, this.pollIntervalMs);

    logger.info('app', 'clipboardWatcher', 'start', 'Clipboard watcher started', {
      pollIntervalMs: this.pollIntervalMs,
    });
  }

  /**
   * Stop polling the clipboard.
   */
  stop(): void {
    if (!this.timer) {
      return;
    }

    clearInterval(this.timer);
    this.timer = null;

    logger.info('app', 'clipboardWatcher', 'stop', 'Clipboard watcher stopped');
  }

  /**
   * Check if the clipboard watcher is currently running.
   */
  isRunning(): boolean {
    return this.timer !== null;
  }

  /**
   * Enable or disable clipboard capture without stopping the poll timer.
   */
  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    logger.info('app', 'clipboardWatcher', 'setEnabled', `Clipboard capture ${enabled ? 'enabled' : 'disabled'}`);
  }

  /**
   * Check if clipboard capture is enabled.
   */
  isEnabled(): boolean {
    return this.enabled;
  }

  // -------------------------------------------------------------------------
  // Private: polling tick
  // -------------------------------------------------------------------------

  private async tick(): Promise<void> {
    if (this.isTicking) {
      this.skippedTickCount += 1;
      if (this.skippedTickCount % 10 === 0) {
        logger.warn('app', 'clipboardWatcher', 'tick', 'Clipboard ticks are being skipped', {
          skippedTickCount: this.skippedTickCount,
        });
      }
      return;
    }

    this.isTicking = true;

    try {
      // Check text content
      const text = clipboard.readText();
      const textHash = this.hashText(text);
      if (textHash && textHash !== this.lastTextHash) {
        this.lastTextHash = textHash;
        if (this.enabled && this.onNewContent) {
          await this.onNewContent({ type: 'text', text, contentHash: textHash });
        }
      }

      // Check image content
      const image = clipboard.readImage();
      if (!image.isEmpty()) {
        const png = image.toPNG();
        const imageHash = this.hashImageBuffer(png);
        if (imageHash && imageHash !== this.lastImageHash) {
          this.lastImageHash = imageHash;
          if (this.enabled && this.onNewContent) {
            await this.onNewContent({ type: 'image', image, contentHash: imageHash });
          }
        }
      }
    } catch (error) {
      logger.error('error', 'clipboardWatcher', 'tick', 'Clipboard tick failed', {
        error: error instanceof Error ? error.message : String(error),
      });
    } finally {
      this.isTicking = false;
    }
  }

  // -------------------------------------------------------------------------
  // Private: hash utilities
  // -------------------------------------------------------------------------

  private hashText(text: string): string | null {
    const value = text.trim();
    if (!value) {
      return null;
    }
    return createHash('md5').update(value).digest('hex');
  }

  private hashImageBuffer(buffer: Buffer): string | null {
    if (!buffer.length) {
      return null;
    }
    return createHash('md5').update(buffer).digest('hex');
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const clipboardWatcher = new ClipboardWatcher();
