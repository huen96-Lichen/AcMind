// PinMind Unified Error Service (V2.1 Phase 6.1)
// Centralized error recording, querying, and lifecycle management.
// All critical failures across the pipeline are converted into ErrorRecords
// and persisted to SQLite for user-facing error review and developer debugging.

import { randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';
import type { ErrorRecord, ErrorType, ErrorStatus } from '../shared/types';
import { logger } from './logger';

// ---------------------------------------------------------------------------
// User-friendly Chinese messages mapped from ErrorType
// ---------------------------------------------------------------------------

const DEFAULT_USER_MESSAGES: Record<ErrorType, string> = {
  capture_failed: '内容捕获失败，请检查剪贴板权限或重试。',
  process_failed: '内容处理失败，请稍后重试或手动编辑。',
  export_failed: '导出到 Obsidian 失败，请检查仓库路径和权限。',
  permission_required: '需要系统权限才能完成此操作，请在系统设置中授权。',
  conflict_pending: '文件存在冲突，请选择覆盖、重命名或跳过。',
  template_missing: '导出模板缺失，请检查输出规范配置。',
  vault_missing: 'Obsidian 仓库未配置或路径无效，请在设置中指定仓库路径。',
  model_unavailable: 'AI 模型不可用，请检查模型配置或网络连接。',
  // Phase 9.7: VaultKeeper 错误用户消息
  vaultkeeper_unavailable: 'VaultKeeper 服务不可用，已保留原始内容并生成占位记录。',
  external_job_failed: '外部处理任务失败，请重试或手动处理。',
  external_result_invalid: '外部处理结果无效，请重新提交任务。',
  external_result_ingest_failed: '外部处理结果回填失败，请重试。',
  unknown_error: '发生了未知错误，请查看日志或联系支持。',
};

// ---------------------------------------------------------------------------
// Retryability rules per ErrorType
// ---------------------------------------------------------------------------

const RETRYABLE_MAP: Record<ErrorType, boolean> = {
  capture_failed: true,
  process_failed: true,
  export_failed: true,
  permission_required: false,
  conflict_pending: true,
  template_missing: false,
  vault_missing: false,
  model_unavailable: true,
  // Phase 9.7: VaultKeeper 错误可重试
  vaultkeeper_unavailable: true,
  external_job_failed: true,
  external_result_invalid: true,
  external_result_ingest_failed: true,
  unknown_error: false,
};

// ---------------------------------------------------------------------------
// ErrorService
// ---------------------------------------------------------------------------

class ErrorService {
  private _db: Database.Database | null = null;

  /**
   * Initialize the error service. Called from storage.init().
   * Receives the raw better-sqlite3 database instance.
   */
  init(db: Database.Database): void {
    this._db = db;
    logger.info('app', 'errorService', 'init', 'Error service initialized');
  }

  /**
   * Create and persist a new error record.
   * This is the primary entry point for recording errors.
   */
  createRecord(params: {
    errorType: ErrorType;
    originalId?: string;
    outputId?: string;
    stage: string;
    message: string;
    userMessage?: string;
    rawError?: string;
    retryable?: boolean;
  }): ErrorRecord {
    const db = this._db;
    if (!db) {
      // Fallback: log and return an in-memory record if DB not ready
      logger.error('error', 'errorService', 'createRecord', 'Database not initialized, error record not persisted', {
        errorType: params.errorType,
        message: params.message,
      });
      return this.buildRecord(params);
    }

    const record = this.buildRecord(params);

    try {
      db.prepare(`
        INSERT INTO error_records (
          error_id, error_type, original_id, output_id, stage,
          message, user_message, raw_error, retryable, retry_count,
          created_at, resolved_at, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        record.error_id,
        record.error_type,
        record.original_id ?? null,
        record.output_id ?? null,
        record.stage,
        record.message,
        record.user_message,
        record.raw_error ?? null,
        record.retryable ? 1 : 0,
        record.retry_count,
        record.created_at,
        record.resolved_at ?? null,
        record.status,
      );
    } catch (err) {
      logger.error('error', 'errorService', 'createRecord', 'Failed to persist error record', {
        error: err instanceof Error ? err.message : String(err),
        recordId: record.error_id,
      });
    }

    logger.error('error', 'errorService', 'recorded', `[${record.error_type}] ${record.user_message}`, {
      errorId: record.error_id,
      errorType: record.error_type,
      originalId: record.original_id,
      outputId: record.output_id,
      stage: record.stage,
      retryable: record.retryable,
    });

    return record;
  }

  /**
   * Record an error from a caught exception, automatically extracting context.
   */
  recordError(params: {
    errorType: ErrorType;
    originalId?: string;
    outputId?: string;
    stage: string;
    error: unknown;
    userMessage?: string;
    retryable?: boolean;
  }): ErrorRecord {
    const message = errorToMessage(params.error);
    const rawError = extractRawError(params.error);
    return this.createRecord({
      errorType: params.errorType,
      originalId: params.originalId,
      outputId: params.outputId,
      stage: params.stage,
      message,
      rawError,
      userMessage: params.userMessage,
      retryable: params.retryable,
    });
  }

  /**
   * Get a single error record by ID.
   */
  getRecord(errorId: string): ErrorRecord | null {
    const db = this._db;
    if (!db) return null;

    const row = db.prepare(
      'SELECT * FROM error_records WHERE error_id = ?',
    ).get(errorId) as any;
    return row ? this.rowToRecord(row) : null;
  }

  /**
   * List error records with optional filtering.
   */
  listRecords(filter?: {
    status?: ErrorStatus;
    errorType?: ErrorType;
    originalId?: string;
    limit?: number;
    offset?: number;
  }): ErrorRecord[] {
    const db = this._db;
    if (!db) return [];

    const conditions: string[] = [];
    const params: any[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }
    if (filter?.errorType) {
      conditions.push('error_type = ?');
      params.push(filter.errorType);
    }
    if (filter?.originalId) {
      conditions.push('original_id = ?');
      params.push(filter.originalId);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const limitClause = filter?.limit ? `LIMIT ?` : '';
    const offsetClause = filter?.offset ? `OFFSET ?` : '';

    if (filter?.limit) params.push(filter.limit);
    if (filter?.offset) params.push(filter.offset);

    const rows = db.prepare(
      `SELECT * FROM error_records ${whereClause} ORDER BY created_at DESC ${limitClause} ${offsetClause}`,
    ).all(...params) as any[];

    return rows.map((row) => this.rowToRecord(row));
  }

  /**
   * Resolve an error record (mark as resolved).
   */
  resolveRecord(errorId: string): boolean {
    const db = this._db;
    if (!db) return false;

    try {
      const result = db.prepare(
        "UPDATE error_records SET status = 'resolved', resolved_at = ? WHERE error_id = ? AND status = 'open'",
      ).run(Math.floor(Date.now() / 1000), errorId);
      return result.changes > 0;
    } catch (err) {
      logger.error('error', 'errorService', 'resolveRecord', 'Failed to resolve error record', {
        error: err instanceof Error ? err.message : String(err),
        errorId,
      });
      return false;
    }
  }

  /**
   * Dismiss an error record (user chose to ignore it).
   */
  dismissRecord(errorId: string): boolean {
    const db = this._db;
    if (!db) return false;

    try {
      const result = db.prepare(
        "UPDATE error_records SET status = 'dismissed', resolved_at = ? WHERE error_id = ? AND status = 'open'",
      ).run(Math.floor(Date.now() / 1000), errorId);
      return result.changes > 0;
    } catch (err) {
      logger.error('error', 'errorService', 'dismissRecord', 'Failed to dismiss error record', {
        error: err instanceof Error ? err.message : String(err),
        errorId,
      });
      return false;
    }
  }

  /**
   * Clear all resolved/dismissed error records.
   */
  clearResolved(): number {
    const db = this._db;
    if (!db) return 0;

    try {
      const result = db.prepare(
        "DELETE FROM error_records WHERE status IN ('resolved', 'dismissed')",
      ).run();
      return result.changes;
    } catch (err) {
      logger.error('error', 'errorService', 'clearResolved', 'Failed to clear resolved records', {
        error: err instanceof Error ? err.message : String(err),
      });
      return 0;
    }
  }

  /**
   * Get count of open errors.
   */
  getOpenCount(): number {
    const db = this._db;
    if (!db) return 0;

    try {
      const row = db.prepare(
        "SELECT COUNT(*) as count FROM error_records WHERE status = 'open'",
      ).get() as { count: number };
      return row.count;
    } catch {
      return 0;
    }
  }

  /**
   * Increment the retry_count for an error record and return the updated count.
   */
  incrementRetryCount(errorId: string): number {
    const db = this._db;
    if (!db) return 0;

    try {
      db.prepare(
        'UPDATE error_records SET retry_count = retry_count + 1 WHERE error_id = ?',
      ).run(errorId);
      const row = db.prepare(
        'SELECT retry_count FROM error_records WHERE error_id = ?',
      ).get(errorId) as { retry_count: number } | undefined;
      return row?.retry_count ?? 0;
    } catch {
      return 0;
    }
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  private buildRecord(params: {
    errorType: ErrorType;
    originalId?: string;
    outputId?: string;
    stage: string;
    message: string;
    userMessage?: string;
    rawError?: string;
    retryable?: boolean;
  }): ErrorRecord {
    return {
      error_id: `err_${Date.now()}_${randomUUID().slice(0, 8)}`,
      error_type: params.errorType,
      original_id: params.originalId,
      output_id: params.outputId,
      stage: params.stage,
      message: params.message,
      user_message: params.userMessage ?? DEFAULT_USER_MESSAGES[params.errorType],
      raw_error: params.rawError,
      retryable: params.retryable ?? RETRYABLE_MAP[params.errorType],
      retry_count: 0,
      created_at: Math.floor(Date.now() / 1000),
      status: 'open',
    };
  }

  private rowToRecord(row: any): ErrorRecord {
    return {
      error_id: row.error_id,
      error_type: row.error_type as ErrorType,
      original_id: row.original_id ?? undefined,
      output_id: row.output_id ?? undefined,
      stage: row.stage,
      message: row.message,
      user_message: row.user_message,
      raw_error: row.raw_error ?? undefined,
      retryable: Boolean(row.retryable),
      retry_count: row.retry_count ?? 0,
      created_at: row.created_at,
      resolved_at: row.resolved_at ?? undefined,
      status: row.status as ErrorStatus,
    };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function errorToMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return String(error);
}

function extractRawError(error: unknown): string | undefined {
  if (error instanceof Error) {
    return error.stack ?? error.message;
  }
  if (typeof error === 'string') return error;
  return undefined;
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const errorService = new ErrorService();
