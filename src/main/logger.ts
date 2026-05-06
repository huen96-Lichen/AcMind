import { mkdirSync, appendFileSync, existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import type { LogChannel, LogLevel, LogEntry } from '../shared/types';

// ---------------------------------------------------------------------------
// Logger — four-channel JSON-lines logger
// ---------------------------------------------------------------------------

const LEVEL_PRIORITY: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

const DEFAULT_MIN_LEVEL: LogLevel = 'info';

class Logger {
  private logDir: string | null = null;
  private streams: Map<LogChannel, string | null> = new Map();
  private minLevel: LogLevel = DEFAULT_MIN_LEVEL;

  /**
   * Initialize the logger with a log directory.
   * Creates the directory if it does not exist.
   */
  init(logDir: string): void {
    if (!existsSync(logDir)) {
      mkdirSync(logDir, { recursive: true });
    }
    this.logDir = logDir;

    const channels: LogChannel[] = ['app', 'ai', 'export', 'error', 'search'];
    for (const channel of channels) {
      const filePath = path.join(logDir, `${channel}.log`);
      this.streams.set(channel, filePath);
    }

    this.info('app', 'logger', 'init', 'Logger initialized', {
      logDir,
      channels: channels.join(', '),
    });
  }

  /**
   * Set the minimum log level. Messages below this level are suppressed.
   */
  setLevel(level: LogLevel): void {
    this.minLevel = level;
  }

  /**
   * Get the current minimum log level.
   */
  getLevel(): LogLevel {
    return this.minLevel;
  }

  /**
   * Write a log entry to the appropriate channel file.
   */
  private write(channel: LogChannel, entry: LogEntry): void {
    const priority = LEVEL_PRIORITY[entry.status as LogLevel] ?? 1;
    const minPriority = LEVEL_PRIORITY[this.minLevel];
    if (priority < minPriority) {
      return;
    }

    const line = JSON.stringify(entry) + '\n';

    // Always write error channel entries to error.log as well
    if (channel !== 'error' && entry.status === 'error') {
      const errorPath = this.streams.get('error');
      if (errorPath) {
        try {
          appendFileSync(errorPath, line, 'utf8');
        } catch {
          // Swallow write failures to avoid crashing the app
        }
      }
    }

    const filePath = this.streams.get(channel);
    if (filePath) {
      try {
        appendFileSync(filePath, line, 'utf8');
      } catch {
        // Swallow write failures
      }
    }

    // Also output to console for development visibility
    const consoleFn =
      entry.status === 'error'
        ? console.error
        : entry.status === 'warn'
          ? console.warn
          : entry.status === 'debug'
            ? console.debug
            : console.info;
    consoleFn(`[${channel}:${entry.module}] ${entry.action} — ${entry.message}`);
  }

  /**
   * Log an info-level message.
   */
  info(
    channel: LogChannel,
    module: string,
    action: string,
    message: string,
    detail?: unknown,
  ): void {
    this.write(channel, {
      time: new Date().toISOString(),
      channel,
      module,
      action,
      status: 'info',
      message,
      detail: detail !== undefined ? JSON.stringify(detail) : undefined,
    });
  }

  /**
   * Log a warn-level message.
   */
  warn(
    channel: LogChannel,
    module: string,
    action: string,
    message: string,
    detail?: unknown,
  ): void {
    this.write(channel, {
      time: new Date().toISOString(),
      channel,
      module,
      action,
      status: 'warn',
      message,
      detail: detail !== undefined ? JSON.stringify(detail) : undefined,
    });
  }

  /**
   * Log an error-level message.
   */
  error(
    channel: LogChannel,
    module: string,
    action: string,
    message: string,
    detail?: unknown,
  ): void {
    this.write(channel, {
      time: new Date().toISOString(),
      channel,
      module,
      action,
      status: 'error',
      message,
      detail: detail !== undefined ? JSON.stringify(detail) : undefined,
    });
  }

  /**
   * Log a debug-level message.
   */
  debug(
    channel: LogChannel,
    module: string,
    action: string,
    message: string,
    detail?: unknown,
  ): void {
    this.write(channel, {
      time: new Date().toISOString(),
      channel,
      module,
      action,
      status: 'debug',
      message,
      detail: detail !== undefined ? JSON.stringify(detail) : undefined,
    });
  }

  /**
   * Read the last N lines from a channel log file.
   */
  readChannel(channel: LogChannel, limit = 100): string[] {
    const filePath = this.streams.get(channel);
    if (!filePath || !existsSync(filePath)) {
      return [];
    }
    try {
      const content = readFileSync(filePath, 'utf8');
      const lines = content.trim().split('\n').filter(Boolean);
      return lines.slice(-limit);
    } catch {
      return [];
    }
  }

  /**
   * Redact sensitive information from a log entry for diagnostics export.
   * - API keys (sk-..., key=..., bearer ...) → [REDACTED]
   * - Long text values (>200 chars) → truncated with [TRUNCATED]
   */
  private redactSensitive(entry: LogEntry): LogEntry {
    const redacted = { ...entry };
    if (redacted.detail) {
      let detail = redacted.detail;
      // Redact API key patterns
      detail = detail.replace(/(sk-[a-zA-Z0-9]{16,})/g, '[REDACTED]');
      detail = detail.replace(/(key[=:]\s*)[^\s,}"]{8,}/gi, '$1[REDACTED]');
      detail = detail.replace(/(bearer\s+)[^\s,}"]{8,}/gi, '$1[REDACTED]');
      detail = detail.replace(/(apiKey[=:]\s*)[^\s,}"]{8,}/gi, '$1[REDACTED]');
      detail = detail.replace(/(api_key[=:]\s*)[^\s,}"]{8,}/gi, '$1[REDACTED]');
      // Truncate long detail strings
      if (detail.length > 500) {
        detail = detail.slice(0, 500) + '...[TRUNCATED]';
      }
      redacted.detail = detail;
    }
    return redacted;
  }

  /**
   * Export a diagnostics bundle to a single JSON file.
   * Aggregates recent logs from all channels + system info.
   * Returns the path to the exported file.
   */
  exportDiagnostics(): string {
    const channels: LogChannel[] = ['app', 'ai', 'export', 'error', 'search'];
    const recentLogs: Record<string, LogEntry[]> = {};

    for (const channel of channels) {
      const lines = this.readChannel(channel, 200);
      recentLogs[channel] = lines
        .map((line) => {
          try {
            return this.redactSensitive(JSON.parse(line) as LogEntry);
          } catch {
            return null;
          }
        })
        .filter((entry): entry is LogEntry => entry !== null);
    }

    const diagnostics = {
      exportedAt: new Date().toISOString(),
      system: {
        platform: os.platform(),
        arch: os.arch(),
        release: os.release(),
        nodeVersion: process.version,
        electronVersion: process.versions.electron ?? 'unknown',
        appVersion: process.env.npm_package_version ?? 'unknown',
        uptime: process.uptime(),
        totalMemory: os.totalmem(),
        freeMemory: os.freemem(),
        cpus: os.cpus().length,
      },
      logDir: this.logDir,
      logFiles: {} as Record<string, { size: number; modified: string }>,
      recentLogs,
    };

    for (const channel of channels) {
      const filePath = this.streams.get(channel);
      if (filePath && existsSync(filePath)) {
        try {
          const stat = statSync(filePath);
          diagnostics.logFiles[channel] = {
            size: stat.size,
            modified: stat.mtime.toISOString(),
          };
        } catch {
          // ignore
        }
      }
    }

    const outDir = this.logDir ?? os.tmpdir();
    const outPath = path.join(outDir, `diagnostics-${Date.now()}.json`);
    try {
      appendFileSync(outPath, JSON.stringify(diagnostics, null, 2), 'utf8');
    } catch (error) {
      this.error('error', 'logger', 'exportDiagnostics', 'Failed to export diagnostics', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }

    this.info('app', 'logger', 'exportDiagnostics', 'Diagnostics exported', { path: outPath });
    return outPath;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const logger = new Logger();
