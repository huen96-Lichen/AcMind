// External Processor Adapter Types
// Phase 9: 定义 AcMind 与外部处理服务的通信协议类型边界
//
// 设计原则：
// - AcMind 不做复杂解析引擎
// - Adapter 不负责 Markdown 渲染、Obsidian 写入、UI
// - VKJobResult 的 extracted_text / transcript_text / parsed_markdown
//   与 ComplexFileMetadata 同名字段一一对应，便于回填

// ---------------------------------------------------------------------------
// Job 类型
// ---------------------------------------------------------------------------

/** 外部处理服务支持的 Job 类型 */
export type VKJobType =
  | 'webpage_extract'
  | 'pdf_parse'
  | 'docx_parse'
  | 'image_ocr'
  | 'audio_transcribe'
  | 'video_transcribe'
  | 'file_convert';

// ---------------------------------------------------------------------------
// Job 状态
// ---------------------------------------------------------------------------

/** 外部处理服务 Job 状态 */
export type VKJobStatus =
  | 'pending'
  | 'queued'
  | 'processing'
  | 'completed'
  | 'failed'
  | 'cancelled';

// ---------------------------------------------------------------------------
// 请求 / 响应结构
// ---------------------------------------------------------------------------

/** 提交 Job 的请求参数 */
export interface VKSubmitJobRequest {
  /** 任务类型 */
  job_type: VKJobType;
  /** 文件路径（本地文件需要外部处理服务可访问） */
  file_path?: string;
  /** URL（网页提取时使用） */
  url?: string;
  /** 原始内容 ID，用于回填关联 */
  original_id: string;
  /** 附加参数（extension / mime_type / filename 等） */
  options?: Record<string, unknown>;
  /** 优先级 */
  priority?: 'low' | 'normal' | 'high';
  /** 回调 URL（外部处理服务完成后通知） */
  callback_url?: string;
}

/** 提交 Job 的响应 */
export interface VKSubmitJobResponse {
  /** 外部处理服务分配的任务 ID */
  job_id: string;
  /** 初始状态 */
  status: VKJobStatus;
  /** 提交时间（Unix 秒） */
  submitted_at: number;
}

/** 查询 Job 状态的响应 */
export interface VKJobStatusResponse {
  job_id: string;
  status: VKJobStatus;
  /** 处理进度 0-100 */
  progress?: number;
  /** 失败时的错误信息 */
  error?: string;
  /** 提交时间（Unix 秒） */
  submitted_at: number;
  /** 开始处理时间（Unix 秒） */
  started_at?: number;
  /** 完成时间（Unix 秒） */
  completed_at?: number;
}

// ---------------------------------------------------------------------------
// Job 结果（标准化后）
// ---------------------------------------------------------------------------

/** 外部处理服务 Job 结果（标准化后） */
export interface VKJobResult {
  job_id: string;
  job_type: VKJobType;
  status: VKJobStatus;
  /** OCR / 解析提取的文本 */
  extracted_text?: string;
  /** 音频 / 视频转写文本 */
  transcript_text?: string;
  /** 文档解析后的 Markdown */
  parsed_markdown?: string;
  /** 提取的标题 */
  extracted_title?: string;
  /** 提取的元数据 */
  extracted_metadata?: Record<string, unknown>;
  /** 原始结果（标准化前） */
  raw_result?: Record<string, unknown>;
  /** 失败时的错误信息 */
  error?: string;
  /** 完成时间（Unix 秒） */
  completed_at?: number;
}

// ---------------------------------------------------------------------------
// 健康检查
// ---------------------------------------------------------------------------

/** 外部处理服务健康检查结果 */
export interface VKHealthStatus {
  /** 是否可用 */
  available: boolean;
  /** 连接方式 */
  connection_method: 'http' | 'stdio' | 'unavailable';
  /** 支持的 job 类型 */
  supported_job_types: VKJobType[];
  /** 外部处理服务版本 */
  version?: string;
  /** 不可用时的错误信息 */
  error?: string;
  /** 检查时间（Unix 秒） */
  checked_at: number;
}

// ---------------------------------------------------------------------------
// Adapter 接口
// ---------------------------------------------------------------------------

/** 外部处理服务 Adapter 接口 — AcMind 与外部处理服务的唯一通信边界 */
export interface IVaultKeeperAdapter {
  /** 检查外部处理服务是否可用（不抛异常） */
  checkHealth(): Promise<VKHealthStatus>;
  /** 提交一个处理任务 */
  submitJob(request: VKSubmitJobRequest): Promise<VKSubmitJobResponse>;
  /** 查询任务状态 */
  getJobStatus(jobId: string): Promise<VKJobStatusResponse>;
  /** 获取任务结果 */
  getJobResult(jobId: string): Promise<VKJobResult>;
  /** 取消任务 */
  cancelJob(jobId: string): Promise<boolean>;
  /** 标准化原始结果为 VKJobResult */
  normalizeResult(raw: Record<string, unknown>, jobType: VKJobType, jobId?: string): VKJobResult;
  /** 标准化错误为 VKJobResult */
  normalizeError(error: unknown, jobId?: string): VKJobResult;
}
