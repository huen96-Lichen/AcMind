// External Processor Adapter
// Phase 9: AcMind 与外部处理服务的真实 HTTP 通信层
//
// 职责边界：
// - 负责：提交任务、查询状态、获取结果、取消任务、标准化结果/错误
// - 不负责：Markdown 渲染、Obsidian 写入、UI 展示
//
// 外部处理服务不可用时优雅降级：checkHealth 不抛异常，submitJob 失败由调用方处理

import { logger } from '../../logger';
import { settings } from '../../settings';
import type {
  IVaultKeeperAdapter,
  VKJobType,
  VKJobStatus,
  VKSubmitJobRequest,
  VKSubmitJobResponse,
  VKJobStatusResponse,
  VKJobResult,
  VKHealthStatus,
} from './types';

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

interface VKErrorResponse {
  error?: string;
  message?: string;
  detail?: string;
}

function getEndpoint(): string {
  const epSettings = settings.getExternalProcessorSettings();
  return epSettings.endpoint.replace(/\/+$/, '');
}

function getTimeout(): number {
  return settings.getExternalProcessorSettings().timeout ?? 30000;
}

function getHeaders(): Record<string, string> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const apiKey = settings.getExternalProcessorSettings().apiKey;
  if (apiKey) {
    headers['Authorization'] = `Bearer ${apiKey}`;
  }
  return headers;
}

async function vkFetch(path: string, init?: RequestInit): Promise<Response> {
  const endpoint = getEndpoint();
  const url = `${endpoint}${path}`;
  const timeout = getTimeout();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const resp = await fetch(url, {
      ...init,
      headers: { ...getHeaders(), ...(init?.headers ?? {}) },
      signal: controller.signal,
    });
    return resp;
  } finally {
    clearTimeout(timer);
  }
}

async function parseVKError(resp: Response): Promise<string> {
  try {
    const body = (await resp.json()) as VKErrorResponse;
    return body.error || body.message || body.detail || `HTTP ${resp.status}`;
  } catch {
    return `HTTP ${resp.status} ${resp.statusText}`;
  }
}

// ---------------------------------------------------------------------------
// ExternalProcessorAdapter
// ---------------------------------------------------------------------------

class ExternalProcessorAdapter implements IVaultKeeperAdapter {
  /** 缓存最近一次健康检查结果 */
  private lastHealthStatus: VKHealthStatus | null = null;

  // -------------------------------------------------------------------------
  // 健康检查
  // -------------------------------------------------------------------------

  async checkHealth(): Promise<VKHealthStatus> {
    const epSettings = settings.getExternalProcessorSettings();
    if (!epSettings.enabled || !epSettings.endpoint) {
      const status: VKHealthStatus = {
        available: false,
        connection_method: 'unavailable',
        supported_job_types: [],
        error: '外部处理服务未启用或未配置端点',
        checked_at: Math.floor(Date.now() / 1000),
      };
      this.lastHealthStatus = status;
      return status;
    }

    try {
      const resp = await vkFetch('/health');
      if (!resp.ok) {
        const errMsg = await parseVKError(resp);
        const status: VKHealthStatus = {
          available: false,
          connection_method: 'http',
          supported_job_types: [],
          error: errMsg,
          checked_at: Math.floor(Date.now() / 1000),
        };
        this.lastHealthStatus = status;
        return status;
      }

      const body = (await resp.json()) as Record<string, unknown>;
      const status: VKHealthStatus = {
        available: true,
        connection_method: 'http',
        version: (body.version as string) || undefined,
        supported_job_types: (body.supported_job_types as VKJobType[]) || [],
        checked_at: Math.floor(Date.now() / 1000),
      };
      this.lastHealthStatus = status;
      return status;
    } catch (error) {
      const status: VKHealthStatus = {
        available: false,
        connection_method: 'http',
        supported_job_types: [],
        error: error instanceof Error ? error.message : String(error),
        checked_at: Math.floor(Date.now() / 1000),
      };
      this.lastHealthStatus = status;
      return status;
    }
  }

  // -------------------------------------------------------------------------
  // 任务提交
  // -------------------------------------------------------------------------

  async submitJob(request: VKSubmitJobRequest): Promise<VKSubmitJobResponse> {
    const health = this.lastHealthStatus ?? (await this.checkHealth());
    if (!health.available) {
      throw new Error(`外部处理服务不可用: ${health.error ?? '未知原因'}`);
    }

    const resp = await vkFetch('/jobs', {
      method: 'POST',
      body: JSON.stringify({
        job_type: request.job_type,
        file_path: request.file_path,
        url: request.url,
        original_id: request.original_id,
        options: request.options,
        priority: request.priority ?? 'normal',
        callback_url: request.callback_url,
      }),
    });

    if (!resp.ok) {
      const errMsg = await parseVKError(resp);
      throw new Error(`外部处理服务 submitJob 失败: ${errMsg}`);
    }

    const body = (await resp.json()) as Record<string, unknown>;
    return {
      job_id: (body.job_id as string) || (body.id as string) || '',
      status: (body.status as VKJobStatus) || 'pending',
      submitted_at: (body.submitted_at as number) || Math.floor(Date.now() / 1000),
    };
  }

  // -------------------------------------------------------------------------
  // 任务状态查询
  // -------------------------------------------------------------------------

  async getJobStatus(jobId: string): Promise<VKJobStatusResponse> {
    const resp = await vkFetch(`/jobs/${encodeURIComponent(jobId)}`);
    if (!resp.ok) {
      const errMsg = await parseVKError(resp);
      throw new Error(`外部处理服务 getJobStatus 失败: ${errMsg}`);
    }

    const body = (await resp.json()) as Record<string, unknown>;
    return {
      job_id: jobId,
      status: (body.status as VKJobStatus) || 'pending',
      progress: body.progress != null ? Number(body.progress) : undefined,
      error: (body.error as string) || undefined,
      submitted_at: (body.submitted_at as number) || 0,
      started_at: (body.started_at as number) || undefined,
      completed_at: (body.completed_at as number) || undefined,
    };
  }

  // -------------------------------------------------------------------------
  // 任务结果获取
  // -------------------------------------------------------------------------

  async getJobResult(jobId: string): Promise<VKJobResult> {
    const resp = await vkFetch(`/jobs/${encodeURIComponent(jobId)}/result`);
    if (!resp.ok) {
      const errMsg = await parseVKError(resp);
      throw new Error(`外部处理服务 getJobResult 失败: ${errMsg}`);
    }

    const body = (await resp.json()) as Record<string, unknown>;
    const jobType = (body.job_type as VKJobType) || 'file_convert';
    return this.normalizeResult(body, jobType, jobId);
  }

  // -------------------------------------------------------------------------
  // 任务取消
  // -------------------------------------------------------------------------

  async cancelJob(jobId: string): Promise<boolean> {
    const resp = await vkFetch(`/jobs/${encodeURIComponent(jobId)}/cancel`, {
      method: 'POST',
    });
    if (!resp.ok) {
      const errMsg = await parseVKError(resp);
      throw new Error(`外部处理服务 cancelJob 失败: ${errMsg}`);
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // 结果标准化
  // -------------------------------------------------------------------------

  normalizeResult(raw: Record<string, unknown>, jobType: VKJobType, jobId?: string): VKJobResult {
    const result: VKJobResult = {
      job_id: jobId || (raw.job_id as string) || '',
      job_type: jobType,
      status: (raw.status as VKJobStatus) || 'completed',
      completed_at: (raw.completed_at as number) || Math.floor(Date.now() / 1000),
    };

    switch (jobType) {
      // 文档类：同时写入 parsed_markdown 和 extracted_text
      case 'webpage_extract':
      case 'pdf_parse':
      case 'docx_parse':
        result.parsed_markdown =
          (raw.markdown as string) || (raw.parsed_markdown as string) || (raw.text as string) || '';
        result.extracted_text = (raw.text as string) || (raw.extracted_text as string) || '';
        result.extracted_title = (raw.title as string) || (raw.extracted_title as string) || undefined;
        break;

      // OCR：写入 extracted_text
      case 'image_ocr':
        result.extracted_text =
          (raw.text as string) || (raw.extracted_text as string) || '';
        break;

      // 转写：写入 transcript_text
      case 'audio_transcribe':
      case 'video_transcribe':
        result.transcript_text =
          (raw.transcript as string) || (raw.transcript_text as string) || (raw.text as string) || '';
        break;

      // 格式转换：写入 parsed_markdown
      case 'file_convert':
        result.parsed_markdown = (raw.markdown as string) || (raw.text as string) || '';
        break;
    }

    // 保留原始结果供调试
    result.raw_result = raw;

    // 提取通用元数据
    if (raw.metadata && typeof raw.metadata === 'object') {
      result.extracted_metadata = raw.metadata as Record<string, unknown>;
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // 错误标准化
  // -------------------------------------------------------------------------

  normalizeError(error: unknown, jobId?: string): VKJobResult {
    const message = error instanceof Error ? error.message : String(error);
    logger.error('error', 'external-processor', 'normalizeError', message, { jobId });
    return {
      job_id: jobId || '',
      job_type: 'file_convert', // 占位，调用方应覆盖
      status: 'failed',
      error: message,
    };
  }

  // -------------------------------------------------------------------------
  // 辅助方法
  // -------------------------------------------------------------------------

  /** 获取最近一次健康检查结果（缓存） */
  getLastHealthStatus(): VKHealthStatus | null {
    return this.lastHealthStatus;
  }
}

export const vaultKeeperAdapter = new ExternalProcessorAdapter();
