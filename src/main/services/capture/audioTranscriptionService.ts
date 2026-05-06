// AcMind Audio Transcription Service
// Phase 10: 管理音频转写任务的提交、状态追踪、回填和重试
//
// 职责：
// 1. 提交转写 job
// 2. 追踪转写状态
// 3. 回填 transcript_text 到 SourceItem
// 4. 支持重试转写
// 5. 处理无转写引擎的情况

import { existsSync, statSync, readFileSync, unlinkSync, writeFileSync, mkdirSync } from 'node:fs';
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import type {
  TranscriptStatus,
  CaptureItemStatus,
  TranscriptionLocalEngine,
  TranscriptionModelSize,
  TranscriptionSettings,
} from '../../../shared/types';
import { normalizeTranscriptionLanguage } from '../../../shared/transcriptionLanguage';
import { logger } from '../../logger';
import { storage } from '../../storage';
import { settings } from '../../settings';

const execFileAsync = promisify(execFile);

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface TranscriptionJob {
  id: string;
  original_id: string;
  capture_item_id: string;
  raw_file_path: string;
  status: TranscriptStatus;
  created_at: number;
  started_at?: number;
  completed_at?: number;
  error?: string;
  engine?: string;
}

export interface TranscriptionResult {
  success: boolean;
  jobId?: string;
  error?: string;
  engineUnavailable?: boolean;
}

export interface WhisperTranscriptionOptions {
  language?: string;
  translate?: boolean;
}

export interface WhisperRuntimeStatus {
  status: 'ready' | 'error';
  engine: string | null;
  message: string;
}

export interface WhisperModelInfo {
  size: 'tiny' | 'base' | 'small';
  displayName: string;
  fileSize: string;
  description: string;
  cached: boolean;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const LONG_AUDIO_FILE_SIZE_THRESHOLD_BYTES = 100 * 1024 * 1024; // 100MB
const WHISPER_MODEL_CATALOG: WhisperModelInfo[] = [
  {
    size: 'tiny',
    displayName: 'Tiny (75MB)',
    fileSize: '75 MB',
    description: '最轻量，速度最快，适合快速笔记',
    cached: false,
  },
  {
    size: 'base',
    displayName: 'Base (142MB)',
    fileSize: '142 MB',
    description: '精度与速度平衡，推荐日常使用',
    cached: false,
  },
  {
    size: 'small',
    displayName: 'Small (466MB)',
    fileSize: '466 MB',
    description: '较高精度，适合重要内容',
    cached: false,
  },
];
const WHISPER_MODEL_FILE_NAMES: Record<WhisperModelInfo['size'], string> = {
  tiny: 'tiny.pt',
  base: 'base.pt',
  small: 'small.pt',
};

// ---------------------------------------------------------------------------
// AudioTranscriptionService
// ---------------------------------------------------------------------------

class AudioTranscriptionService {
  private jobs = new Map<string, TranscriptionJob>();
  private bundledModelDownloads = new Map<WhisperModelInfo['size'], Promise<void>>();

  private getTranscriptionConfig(): TranscriptionSettings {
    return settings.load().transcription;
  }

  /**
   * 暴露给主进程 whisper IPC 的运行态信息。
   */
  getRuntimeStatus(): WhisperRuntimeStatus {
    const config = this.getTranscriptionConfig();
    const engine = this.resolveConfiguredEngine(config);
    if (config.provider === 'api') {
      return {
        status: engine ? 'ready' : 'error',
        engine,
        message: engine
          ? `外部转写 API 已就绪：${this.describeApiEndpoint(config.apiEndpoint)}`
          : '未配置外部转写 API 端点',
      };
    }

    return {
      status: engine ? 'ready' : 'error',
      engine,
      message: engine
        ? engine === 'whisper'
          ? this.getBundledModelCacheMessage(config.localModel)
          : `本地转写已就绪：${engine} / ${config.localModel}`
        : '未找到可用本地转写引擎，请安装 whisper-ctranslate2 或 whisper',
    };
  }

  /**
   * 暴露给主进程 whisper IPC 的模型列表。
   * 目前模型本身不是主链路的必要条件，但接口保留给前端展示。
   */
  getWhisperModels(): WhisperModelInfo[] {
    return WHISPER_MODEL_CATALOG.map((model) => ({
      ...model,
      cached: this.isWhisperModelAvailable(model.size),
    }));
  }

  /**
   * 初始化 whisper 接口。
   * 对当前 CLI 转写实现而言，初始化只做引擎可用性探测。
   */
  initializeWhisper(): WhisperRuntimeStatus {
    return this.getRuntimeStatus();
  }

  /**
   * 转写浮点 PCM 音频。
   */
  async transcribePcm(
    pcmf32: Float32Array,
    options?: WhisperTranscriptionOptions & { sampleRate?: number },
  ): Promise<{ text: string; engine: string; elapsedMs: number }> {
    const sampleRate =
      options?.sampleRate && Number.isFinite(options.sampleRate) && options.sampleRate > 0
        ? Math.round(options.sampleRate)
        : 16000;

    const tmpDir = path.join(process.cwd(), '.acmind-tmp');
    mkdirSync(tmpDir, { recursive: true });

    const tmpPath = path.join(tmpDir, `whisper-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.wav`);
    try {
      const wavBuffer = this.encodePcmAsWav(pcmf32, sampleRate);
      writeFileSync(tmpPath, wavBuffer);

      const start = performance.now();
      const { text, engine } = await this.transcribeWithConfiguredProvider(tmpPath, options);
      const elapsedMs = Math.round(performance.now() - start);

      return {
        text,
        engine,
        elapsedMs,
      };
    } finally {
      try {
        unlinkSync(tmpPath);
      } catch {
        // ignore temp cleanup failures
      }
    }
  }

  /**
   * 预下载或预热本地 Whisper 模型缓存。
   */
  async downloadBundledWhisperModel(
    modelSize: WhisperModelInfo['size'],
    onProgress?: (progress: number) => void,
  ): Promise<void> {
    await this.ensureBundledWhisperModel(modelSize, { force: true, onProgress });
  }

  /**
   * 删除本地 Whisper 模型缓存。
   */
  deleteBundledWhisperModel(modelSize: WhisperModelInfo['size']): void {
    const filePath = this.getBundledWhisperModelPath(modelSize);
    if (existsSync(filePath)) {
      unlinkSync(filePath);
    }
  }

  /**
   * 提交转写任务
   * @param captureItemId - CaptureItem 的 ID（用于关联 SourceItem）
   * @param rawFilePath - 原始音频文件路径
   */
  async submitTranscriptionJob(captureItemId: string, rawFilePath: string): Promise<TranscriptionResult> {
    // 校验文件
    if (!existsSync(rawFilePath)) {
      this.updateCaptureItemStatus(captureItemId, 'failed');
      return { success: false, error: '原始录音文件不存在' };
    }

    // 查找关联的 SourceItem
    const sourceItem = storage.getSourceItemByCaptureItemId(captureItemId);
    if (!sourceItem) {
      return { success: false, error: '未找到关联的 SourceItem' };
    }

    // 检查是否有可用的转写引擎
    const config = this.getTranscriptionConfig();
    const engine = this.resolveConfiguredEngine(config);
    if (!engine) {
      this.updateSourceItemMetadata(sourceItem.id, { transcript_status: 'unsupported' });
      this.updateCaptureItemStatus(captureItemId, 'failed');
      logger.warn('error', 'audioTranscriptionService', 'submitTranscriptionJob', 'No transcription engine available', {
        captureItemId,
      });
      return {
        success: false,
        error: '需要配置转写引擎',
        engineUnavailable: true,
      };
    }

    // 创建 job
    const jobId = `vk_audio_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const job: TranscriptionJob = {
      id: jobId,
      original_id: sourceItem.originalId || sourceItem.id,
      capture_item_id: captureItemId,
      raw_file_path: rawFilePath,
      status: 'pending',
      created_at: Date.now(),
      engine,
    };

    this.jobs.set(jobId, job);

    // 更新 SourceItem metadata
    this.updateSourceItemMetadata(sourceItem.id, {
      vk_job_id: jobId,
      transcription_provider: config.provider,
      transcription_engine: engine,
      transcription_model: config.provider === 'api' ? config.apiModel : config.localModel,
      transcription_started_at: new Date().toISOString(),
      transcript_status: 'pending',
    });

    // 更新 CaptureItem 状态为 transcribing
    this.updateCaptureItemStatus(captureItemId, 'transcribing');

    logger.info('app', 'audioTranscriptionService', 'submitTranscriptionJob', 'Transcription job submitted', {
      jobId,
      captureItemId,
      sourceItemId: sourceItem.id,
      engine,
    });

    // 异步执行转写
    this.executeTranscription(job).catch((err) => {
      logger.error('error', 'audioTranscriptionService', 'submitTranscriptionJob', 'Transcription execution error', {
        jobId,
        error: String(err),
      });
    });

    return { success: true, jobId };
  }

  /**
   * 重试转写
   */
  async retryTranscription(captureItemId: string): Promise<TranscriptionResult> {
    const sourceItem = storage.getSourceItemByCaptureItemId(captureItemId);
    if (!sourceItem) {
      return { success: false, error: '记录不存在' };
    }

    if (sourceItem.source !== 'audio') {
      return { success: false, error: '非音频记录' };
    }

    const metadata = (sourceItem.metadata || {}) as Record<string, unknown>;
    const rawFilePath = metadata.raw_file_path as string | undefined;
    if (!rawFilePath) {
      return { success: false, error: '原始录音路径不存在' };
    }

    if (!existsSync(rawFilePath)) {
      this.updateSourceItemMetadata(sourceItem.id, { transcript_status: 'failed' });
      this.updateCaptureItemStatus(captureItemId, 'failed');
      return { success: false, error: '原始录音文件不存在' };
    }

    // 重置状态
    this.updateSourceItemMetadata(sourceItem.id, { transcript_status: 'pending' });
    this.updateCaptureItemStatus(captureItemId, 'transcribing');

    return this.submitTranscriptionJob(captureItemId, rawFilePath);
  }

  /**
   * 获取转写状态
   */
  getTranscriptionStatus(captureItemId: string): {
    transcriptStatus: TranscriptStatus;
    transcriptText?: string;
    jobId?: string;
    error?: string;
  } {
    const sourceItem = storage.getSourceItemByCaptureItemId(captureItemId);
    if (!sourceItem || sourceItem.source !== 'audio') {
      return { transcriptStatus: 'not_started' };
    }

    const metadata = (sourceItem.metadata || {}) as Record<string, unknown>;
    const vkJobId = metadata.vk_job_id as string | undefined;
    const job = vkJobId ? this.jobs.get(vkJobId) : undefined;

    return {
      transcriptStatus: (metadata.transcript_status as TranscriptStatus) || 'not_started',
      transcriptText: sourceItem.ocrText || undefined,
      jobId: vkJobId,
      error: job?.error || undefined,
    };
  }

  /**
   * 获取所有转写任务
   */
  getAllJobs(): TranscriptionJob[] {
    return Array.from(this.jobs.values());
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  /**
   * 执行转写（当前为 stub，等待接入真实引擎）
   */
  private async executeTranscription(job: TranscriptionJob): Promise<void> {
    job.status = 'processing';
    job.started_at = Date.now();

    const sourceItem = storage.getSourceItemByCaptureItemId(job.capture_item_id);
    if (!sourceItem) {
      job.status = 'failed';
      job.error = 'SourceItem 不存在';
      job.completed_at = Date.now();
      return;
    }

    this.updateSourceItemMetadata(sourceItem.id, { transcript_status: 'processing' });
    this.updateCaptureItemStatus(job.capture_item_id, 'transcribing');

    logger.info('app', 'audioTranscriptionService', 'executeTranscription', 'Starting transcription', {
      jobId: job.id,
      engine: job.engine,
    });

    try {
      // 检查是否为长录音
      const isLongAudio = this.checkIsLongAudio(job.raw_file_path);
      if (isLongAudio) {
        job.status = 'unsupported';
        job.error = '长录音暂不支持完整自动转写。请稍后使用分段转写能力，或手动处理。';
        job.completed_at = Date.now();
        this.updateSourceItemMetadata(sourceItem.id, {
          transcript_status: 'unsupported',
          is_long_audio: true,
          segment_status: 'unsupported',
          transcription_finished_at: new Date().toISOString(),
        });
        this.updateCaptureItemStatus(job.capture_item_id, 'failed');
        logger.warn('error', 'audioTranscriptionService', 'executeTranscription', 'Long audio not supported', {
          jobId: job.id,
        });
        return;
      }

      const { text: transcriptText } = await this.transcribeByJob(job);

      if (transcriptText.trim().length === 0) {
        job.status = 'failed';
        job.error = '转写结果为空';
        job.completed_at = Date.now();
        this.updateSourceItemMetadata(sourceItem.id, {
          transcript_status: 'failed',
          transcription_finished_at: new Date().toISOString(),
        });
        this.updateCaptureItemStatus(job.capture_item_id, 'failed');
        logger.warn('error', 'audioTranscriptionService', 'executeTranscription', 'Empty transcript', {
          jobId: job.id,
        });
        return;
      }

      // 回填 transcript_text
      this.backfillTranscript(sourceItem.id, job.capture_item_id, transcriptText);

      job.status = 'completed';
      job.completed_at = Date.now();
      this.updateSourceItemMetadata(sourceItem.id, {
        transcript_status: 'completed',
        transcription_finished_at: new Date().toISOString(),
      });
      this.updateCaptureItemStatus(job.capture_item_id, 'transcribed');

      logger.info('app', 'audioTranscriptionService', 'executeTranscription', 'Transcription completed', {
        jobId: job.id,
        sourceItemId: sourceItem.id,
        transcriptLength: transcriptText.length,
      });
    } catch (err) {
      job.status = 'failed';
      job.error = err instanceof Error ? err.message : String(err);
      job.completed_at = Date.now();
      this.updateSourceItemMetadata(sourceItem.id, {
        transcript_status: 'failed',
        transcription_finished_at: new Date().toISOString(),
      });
      this.updateCaptureItemStatus(job.capture_item_id, 'failed');
      logger.error('error', 'audioTranscriptionService', 'executeTranscription', 'Transcription failed', {
        jobId: job.id,
        error: job.error,
      });
    }
  }

  /**
   * 调用转写引擎
   * 返回 null 表示引擎不可用
   * 返回空字符串表示转写结果为空
   *
   * 支持的引擎（按优先级）：
   * 1. whisper-cli (openai-whisper Python 包)
   * 2. whisper-ctranslate2 (更快的 CTranslate2 实现)
   * 3. macOS: afplay + say (仅用于短音频的 fallback)
   */
  private async callTranscriptionEngine(
    filePath: string,
    engine: TranscriptionLocalEngine,
    options?: { language?: string; translate?: boolean; model?: TranscriptionModelSize },
  ): Promise<string | null> {
    logger.info('app', 'audioTranscriptionService', 'callTranscriptionEngine', 'Starting transcription', {
      filePath,
      engine,
    });

    try {
      switch (engine) {
        case 'whisper':
          return await this.runBundledWhisper(filePath, options);
        case 'whisper-ctranslate2':
          return await this.runWhisperCT2(filePath, options);
        default:
          logger.warn('error', 'audioTranscriptionService', 'callTranscriptionEngine', 'Unknown engine', { engine });
          return null;
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      logger.error('error', 'audioTranscriptionService', 'callTranscriptionEngine', 'Engine execution failed', {
        filePath,
        engine,
        error: msg,
      });
      return null;
    }
  }

  /**
   * Run bundled openai-whisper via Python, using the app-managed model cache.
   */
  private async runBundledWhisper(
    filePath: string,
    options?: { language?: string; translate?: boolean; model?: TranscriptionModelSize },
  ): Promise<string | null> {
    const python = this.resolvePythonCommand();
    if (!python) {
      throw new Error('未找到 Python 运行时，无法使用内置 Whisper 模型');
    }

    await this.ensurePythonModule(python, 'whisper', 'openai-whisper');
    await this.ensureBundledWhisperModel(options?.model || 'base');

    const cacheDir = this.getWhisperModelCacheDir();
    mkdirSync(cacheDir, { recursive: true });

    try {
      const script = `
import json
import sys
import whisper

audio_path = sys.argv[1]
model_dir = sys.argv[2]
model_name = sys.argv[3]
language = sys.argv[4]
translate = sys.argv[5] == "1"

model = whisper.load_model(model_name, download_root=model_dir)
result = model.transcribe(
    audio_path,
    fp16=False,
    language=None if language in ("", "auto") else language,
    task="translate" if translate else "transcribe",
)
print(json.dumps({"text": (result.get("text") or "").strip()}))
`;
      const { stdout } = await execFileAsync(
        python,
        [
          '-c',
          script,
          filePath,
          cacheDir,
          options?.model || 'base',
          normalizeTranscriptionLanguage(options?.language, 'zh') || '',
          options?.translate ? '1' : '0',
        ],
        {
          timeout: 30 * 60 * 1000,
          maxBuffer: 10 * 1024 * 1024,
        },
      );

      const parsed = JSON.parse(stdout.trim()) as { text?: string };
      return parsed.text?.trim() || null;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('No module named whisper')) {
        logger.warn('error', 'audioTranscriptionService', 'runBundledWhisper', 'openai-whisper module not found', {
          filePath,
        });
        return null;
      }
      throw err;
    }
  }

  /**
   * Run whisper-ctranslate2 CLI (faster implementation)
   * Requires: pip install whisper-ctranslate2
   */
  private async runWhisperCT2(
    filePath: string,
    options?: { language?: string; translate?: boolean; model?: TranscriptionModelSize },
  ): Promise<string | null> {
    const python = this.resolvePythonCommand();
    if (!python) {
      throw new Error('未找到 Python 运行时，无法使用 whisper-ctranslate2');
    }

    await this.ensureWhisperCT2Available(python);
    const whisperCommand = this.resolveWhisperCT2Command(python);
    if (!whisperCommand) {
      throw new Error('已安装 whisper-ctranslate2，但未找到可执行入口');
    }

    const tmpDir = path.join(process.cwd(), '.acmind-tmp');
    mkdirSync(tmpDir, { recursive: true });

    try {
      const language = normalizeTranscriptionLanguage(options?.language, 'zh');
      const whisperArgs = [
        filePath,
        '--model',
        options?.model || 'base',
        '--output_format',
        'txt',
        '--output_dir',
        tmpDir,
        ...(language ? ['--language', language] : []),
        ...(options?.translate ? ['--task', 'translate'] : []),
      ];

      const { stdout } = await execFileAsync(whisperCommand, whisperArgs, {
        timeout: 300_000,
        maxBuffer: 10 * 1024 * 1024,
      });

      const baseName = path.basename(filePath, path.extname(filePath));
      const txtPath = path.join(tmpDir, `${baseName}.txt`);
      if (existsSync(txtPath)) {
        const text = readFileSync(txtPath, 'utf8').trim();
        try {
          unlinkSync(txtPath);
        } catch {
          /* ignore cleanup error */
        }
        return text || null;
      }
      // Fallback: try parsing stdout
      return stdout?.trim() || null;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('ENOENT') || msg.includes('not found')) {
        logger.warn('error', 'audioTranscriptionService', 'runWhisperCT2', 'whisper-ctranslate2 not found', {
          filePath,
        });
        return null;
      }
      throw err;
    }
  }

  /**
   * 回填 transcript_text 到 SourceItem 和 CaptureItem
   */
  private backfillTranscript(sourceItemId: string, captureItemId: string, transcriptText: string): void {
    // 更新 SourceItem 的 ocr_text 字段（用于存储 transcript_text）
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) {
      logger.error('error', 'audioTranscriptionService', 'backfillTranscript', 'SourceItem not found', {
        sourceItemId,
      });
      return;
    }

    storage.updateSourceItem(sourceItemId, { ocrText: transcriptText });

    // 更新 CaptureItem 的 raw_text 字段
    const captureItem = storage.getCaptureItem(captureItemId);
    if (captureItem) {
      storage.updateCaptureItem(captureItemId, { rawText: transcriptText });
    }

    logger.info('app', 'audioTranscriptionService', 'backfillTranscript', 'Transcript backfilled', {
      sourceItemId,
      captureItemId,
      transcriptLength: transcriptText.length,
    });
  }

  /**
   * 更新 SourceItem 的 metadata
   */
  private updateSourceItemMetadata(sourceItemId: string, updates: Record<string, unknown>): void {
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) return;

    const metadata = (sourceItem.metadata || {}) as Record<string, unknown>;
    Object.assign(metadata, updates);
    storage.updateSourceItem(sourceItemId, { metadata });
  }

  /**
   * 更新 CaptureItem 的状态
   */
  private updateCaptureItemStatus(captureItemId: string, status: string): void {
    storage.updateCaptureItem(captureItemId, { status: status as CaptureItemStatus });
  }

  /**
   * 检查是否为长录音
   */
  private checkIsLongAudio(filePath: string): boolean {
    try {
      const stats = statSync(filePath);
      return stats.size >= LONG_AUDIO_FILE_SIZE_THRESHOLD_BYTES;
    } catch {
      return false;
    }
  }

  private isWhisperModelAvailable(modelSize: WhisperModelInfo['size']): boolean {
    return existsSync(this.getBundledWhisperModelPath(modelSize));
  }

  private async transcribeByJob(job: TranscriptionJob): Promise<{ text: string; engine: string }> {
    const config = this.getTranscriptionConfig();
    if (job.engine === 'api') {
      const text = await this.transcribeViaApi(job.raw_file_path, config, {
        language: config.apiLanguage,
        translate: config.apiTranslate,
      });
      return { text, engine: 'api' };
    }

    const localEngine =
      this.resolveLocalEngine(config.localEngine) ?? (job.engine as TranscriptionLocalEngine | undefined);
    if (!localEngine) {
      throw new Error('未找到可用本地转写引擎');
    }

    const text = await this.callTranscriptionEngine(job.raw_file_path, localEngine, {
      language: 'zh',
      translate: false,
      model: config.localModel,
    });

    if (text === null) {
      throw new Error('转写引擎尚未接入');
    }

    return { text, engine: localEngine };
  }

  private async transcribeWithConfiguredProvider(
    filePath: string,
    options?: WhisperTranscriptionOptions & { sampleRate?: number },
  ): Promise<{ text: string; engine: string }> {
    const config = this.getTranscriptionConfig();
    if (config.provider === 'api') {
      const text = await this.transcribeViaApi(filePath, config, options);
      return { text, engine: 'api' };
    }

    const engine = this.resolveLocalEngine(config.localEngine);
    if (!engine) {
      throw new Error('未找到可用本地转写引擎');
    }

    const text = await this.callTranscriptionEngine(filePath, engine, {
      language: normalizeTranscriptionLanguage(options?.language, 'zh'),
      translate: Boolean(options?.translate),
      model: config.localModel,
    });

    if (text === null) {
      throw new Error('转写引擎尚未接入');
    }

    return { text, engine };
  }

  private async transcribeViaApi(
    filePath: string,
    config: TranscriptionSettings,
    options?: WhisperTranscriptionOptions,
  ): Promise<string> {
    const endpoint = this.resolveApiEndpoint(config.apiEndpoint);
    if (!endpoint) {
      throw new Error('未配置外部转写 API 端点');
    }

    const fileBuffer = readFileSync(filePath);
    const form = new FormData();
    form.append('file', new Blob([fileBuffer], { type: 'audio/wav' }), path.basename(filePath));
    form.append('model', config.apiModel || 'whisper-1');
    const language = normalizeTranscriptionLanguage(options?.language ?? config.apiLanguage);
    if (language) {
      form.append('language', language);
    }
    form.append('response_format', 'json');
    if (options?.translate ?? config.apiTranslate) {
      form.append('task', 'translate');
    }
    if (config.apiPrompt?.trim()) {
      form.append('prompt', config.apiPrompt.trim());
    }

    const controller = new AbortController();
    const timeoutMs = Number.isFinite(config.apiTimeoutMs) && config.apiTimeoutMs > 0 ? config.apiTimeoutMs : 30000;
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const headers: Record<string, string> = {};
      if (config.apiKey?.trim()) {
        headers.Authorization = `Bearer ${config.apiKey.trim()}`;
      }

      const response = await fetch(endpoint, {
        method: 'POST',
        headers,
        body: form,
        signal: controller.signal,
      });

      const bodyText = await response.text();
      if (!response.ok) {
        throw new Error(`转写 API 请求失败：${response.status} ${response.statusText} ${bodyText}`.trim());
      }

      const parsed = this.extractApiTranscriptText(bodyText);
      if (!parsed) {
        throw new Error('转写 API 未返回文本结果');
      }

      return parsed;
    } finally {
      clearTimeout(timeoutId);
    }
  }

  private extractApiTranscriptText(bodyText: string): string | null {
    const trimmed = bodyText.trim();
    if (!trimmed) {
      return null;
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        const parsed = JSON.parse(trimmed) as {
          text?: unknown;
          transcript?: unknown;
          transcription?: unknown;
          output_text?: unknown;
          result?: unknown;
          data?: { text?: unknown } | unknown;
          choices?: Array<{ text?: unknown } | unknown>;
        };
        const firstChoice = parsed.choices?.[0];
        const candidates = [
          parsed.text,
          parsed.transcript,
          parsed.transcription,
          parsed.output_text,
          parsed.result,
          parsed.data && typeof parsed.data === 'object' ? (parsed.data as { text?: unknown }).text : undefined,
          firstChoice && typeof firstChoice === 'object' ? (firstChoice as { text?: unknown }).text : undefined,
        ];
        for (const candidate of candidates) {
          if (typeof candidate === 'string' && candidate.trim()) {
            return candidate.trim();
          }
        }
      } catch {
        // fall through to plain text
      }
    }

    return trimmed;
  }

  private resolveConfiguredEngine(config: TranscriptionSettings): string | null {
    if (config.provider === 'api') {
      return this.resolveApiEndpoint(config.apiEndpoint) ? 'api' : null;
    }

    return this.resolveLocalEngine(config.localEngine);
  }

  private resolveLocalEngine(preferred: TranscriptionLocalEngine): TranscriptionLocalEngine | null {
    const candidates: TranscriptionLocalEngine[] =
      preferred === 'whisper' ? ['whisper', 'whisper-ctranslate2'] : ['whisper-ctranslate2', 'whisper'];

    for (const engine of candidates) {
      if (this.isEngineAvailable(engine)) {
        return engine;
      }
    }

    return null;
  }

  getWhisperModelCacheDir(): string {
    return path.join(settings.getStorageRoot(), 'cache', 'whisper-models');
  }

  private getBundledWhisperModelPath(modelSize: WhisperModelInfo['size']): string {
    return path.join(this.getWhisperModelCacheDir(), WHISPER_MODEL_FILE_NAMES[modelSize]);
  }

  private async ensureBundledWhisperModel(
    modelSize: WhisperModelInfo['size'],
    options?: { force?: boolean; onProgress?: (progress: number) => void },
  ): Promise<void> {
    const force = Boolean(options?.force);
    const cachedPath = this.getBundledWhisperModelPath(modelSize);
    const onProgress = options?.onProgress;
    onProgress?.(0);
    if (!force && existsSync(cachedPath)) {
      onProgress?.(100);
      return;
    }

    const inFlight = this.bundledModelDownloads.get(modelSize);
    if (inFlight) {
      return inFlight;
    }

    const task = (async () => {
      const python = this.resolvePythonCommand();
      if (!python) {
        throw new Error('未找到 Python 运行时，无法下载本地模型');
      }
      onProgress?.(15);

      await this.ensurePythonModule(python, 'whisper', 'openai-whisper');
      onProgress?.(35);

      const cacheDir = this.getWhisperModelCacheDir();
      mkdirSync(cacheDir, { recursive: true });

      if (force && existsSync(cachedPath)) {
        try {
          unlinkSync(cachedPath);
        } catch {
          // ignore stale cache cleanup failures
        }
      }
      onProgress?.(45);

      const script = `
import sys
import whisper

model_dir = sys.argv[1]
model_name = sys.argv[2]
whisper.load_model(model_name, download_root=model_dir)
print("ok")
`;

      onProgress?.(60);
      await execFileAsync(python, ['-c', script, cacheDir, modelSize], {
        timeout: 30 * 60 * 1000,
        maxBuffer: 10 * 1024 * 1024,
      });
      onProgress?.(90);

      if (!existsSync(cachedPath)) {
        throw new Error(`模型 ${modelSize} 下载完成，但缓存文件未找到`);
      }
      onProgress?.(100);
    })().finally(() => {
      this.bundledModelDownloads.delete(modelSize);
    });

    this.bundledModelDownloads.set(modelSize, task);
    return task;
  }

  private getBundledModelCacheMessage(modelSize: WhisperModelInfo['size']): string {
    const cached = existsSync(this.getBundledWhisperModelPath(modelSize));
    return cached
      ? `本地 Whisper 模型已缓存：${modelSize}`
      : `本地 Whisper 可用，${modelSize} 模型尚未缓存，首次使用会自动下载到本地`;
  }

  private resolvePythonCommand(): string | null {
    const candidates = ['python3', 'python'];
    for (const command of candidates) {
      try {
        execFileSync(command, ['--version'], { timeout: 5000, stdio: 'pipe' });
        return command;
      } catch {
        // continue
      }
    }
    return null;
  }

  private async ensurePythonModule(python: string, importName: string, pipPackage: string): Promise<void> {
    try {
      execFileSync(python, ['-c', `import ${importName}`], { timeout: 5000, stdio: 'pipe' });
      return;
    } catch {
      // continue to installation
    }

    try {
      await execFileAsync(python, ['-m', 'pip', '--version'], {
        timeout: 5000,
        maxBuffer: 1024 * 1024,
      });
    } catch {
      throw new Error(`Python 环境缺少 pip，无法安装 ${pipPackage}`);
    }

    await execFileAsync(python, ['-m', 'pip', 'install', '--user', pipPackage], {
      timeout: 30 * 60 * 1000,
      maxBuffer: 20 * 1024 * 1024,
    });

    try {
      execFileSync(python, ['-c', `import ${importName}`], { timeout: 5000, stdio: 'pipe' });
    } catch {
      throw new Error(`已尝试安装 ${pipPackage}，但 ${importName} 仍不可用`);
    }
  }

  private async ensureWhisperCT2Available(python: string, onProgress?: (progress: number) => void): Promise<void> {
    onProgress?.(0);
    try {
      execFileSync('whisper-ctranslate2', ['--help'], { timeout: 5000, stdio: 'pipe' });
      onProgress?.(100);
      return;
    } catch {
      // continue to installation
    }

    onProgress?.(30);
    await this.ensurePythonModule(python, 'whisper_ctranslate2', 'whisper-ctranslate2');
    onProgress?.(70);

    try {
      const command = this.resolveWhisperCT2Command(python);
      if (!command) {
        throw new Error('已尝试安装 whisper-ctranslate2，但命令仍不可用');
      }
      execFileSync(command, ['--help'], { timeout: 5000, stdio: 'pipe' });
      onProgress?.(100);
    } catch {
      throw new Error('已尝试安装 whisper-ctranslate2，但命令仍不可用');
    }
  }

  async repairWhisperEnvironment(
    modelSize?: WhisperModelInfo['size'],
    onProgress?: (progress: number) => void,
  ): Promise<{ engine: TranscriptionLocalEngine | 'api' | null; repaired: boolean; message: string }> {
    const config = this.getTranscriptionConfig();
    const selectedModel = modelSize ?? config.localModel;
    const python = this.resolvePythonCommand();
    const engine = config.provider === 'api' ? 'api' : config.localEngine;

    if (config.provider === 'api') {
      return {
        engine,
        repaired: false,
        message: '当前使用外部 API 转写，不需要修复本地模型缓存。',
      };
    }

    if (!python) {
      throw new Error('未找到 Python 运行时，无法修复本地转写环境');
    }

    if (config.localEngine === 'whisper') {
      onProgress?.(10);
      await this.ensurePythonModule(python, 'whisper', 'openai-whisper');
      onProgress?.(45);
      await this.ensureBundledWhisperModel(selectedModel, { onProgress });
      return {
        engine,
        repaired: true,
        message: `已检查并修复 openai-whisper 与 ${selectedModel} 模型缓存`,
      };
    }

    await this.ensureWhisperCT2Available(python, onProgress);
    return {
      engine,
      repaired: true,
      message: '已检查并修复 whisper-ctranslate2 环境',
    };
  }

  private isEngineAvailable(engine: TranscriptionLocalEngine): boolean {
    try {
      if (engine === 'whisper-ctranslate2') {
        const python = this.resolvePythonCommand();
        const command = python ? this.resolveWhisperCT2Command(python) : null;
        if (command) {
          execFileSync(command, ['--help'], { timeout: 5000, stdio: 'pipe' });
          return true;
        }
        return false;
      }

      const python = this.resolvePythonCommand();
      if (!python) {
        return false;
      }
      execFileSync(python, ['-c', 'import whisper'], { timeout: 5000, stdio: 'pipe' });
      return true;
    } catch {
      return false;
    }
  }

  private resolveWhisperCT2Command(python: string): string | null {
    const candidates = new Set<string>();
    candidates.add('whisper-ctranslate2');

    try {
      const script = `
import os
import site
import sysconfig

paths = []
user_base = site.getuserbase()
if user_base:
  paths.append(os.path.join(user_base, 'bin', 'whisper-ctranslate2'))
scripts_dir = sysconfig.get_path('scripts')
if scripts_dir:
  paths.append(os.path.join(scripts_dir, 'whisper-ctranslate2'))
print('\\n'.join(paths))
`;
      const stdout = execFileSync(python, ['-c', script], { timeout: 5000, stdio: ['pipe', 'pipe', 'pipe'] }).toString(
        'utf8',
      );
      for (const line of stdout.split(/\r?\n/)) {
        const trimmed = line.trim();
        if (trimmed) {
          candidates.add(trimmed);
        }
      }
    } catch {
      // fall back to PATH lookup only
    }

    for (const candidate of candidates) {
      if (candidate === 'whisper-ctranslate2') {
        try {
          execFileSync(candidate, ['--help'], { timeout: 5000, stdio: 'pipe' });
          return candidate;
        } catch {
          continue;
        }
      }

      if (existsSync(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  private resolveApiEndpoint(endpoint: string): string | null {
    const trimmed = endpoint.trim();
    if (!trimmed) {
      return null;
    }

    if (trimmed.includes('/audio/transcriptions')) {
      return trimmed;
    }

    return trimmed.replace(/\/$/, '') + '/v1/audio/transcriptions';
  }

  private describeApiEndpoint(endpoint: string): string {
    try {
      return new URL(this.resolveApiEndpoint(endpoint) ?? endpoint).origin;
    } catch {
      return endpoint.trim();
    }
  }

  private encodePcmAsWav(pcmf32: Float32Array, sampleRate: number): Buffer {
    const numChannels = 1;
    const bytesPerSample = 2;
    const blockAlign = numChannels * bytesPerSample;
    const byteRate = sampleRate * blockAlign;
    const dataSize = pcmf32.length * bytesPerSample;
    const buffer = Buffer.alloc(44 + dataSize);

    let offset = 0;
    buffer.write('RIFF', offset);
    offset += 4;
    buffer.writeUInt32LE(36 + dataSize, offset);
    offset += 4;
    buffer.write('WAVE', offset);
    offset += 4;
    buffer.write('fmt ', offset);
    offset += 4;
    buffer.writeUInt32LE(16, offset);
    offset += 4;
    buffer.writeUInt16LE(1, offset);
    offset += 2;
    buffer.writeUInt16LE(numChannels, offset);
    offset += 2;
    buffer.writeUInt32LE(sampleRate, offset);
    offset += 4;
    buffer.writeUInt32LE(byteRate, offset);
    offset += 4;
    buffer.writeUInt16LE(blockAlign, offset);
    offset += 2;
    buffer.writeUInt16LE(16, offset);
    offset += 2;
    buffer.write('data', offset);
    offset += 4;
    buffer.writeUInt32LE(dataSize, offset);
    offset += 4;

    for (let i = 0; i < pcmf32.length; i++) {
      const sample = Math.max(-1, Math.min(1, pcmf32[i] || 0));
      buffer.writeInt16LE(sample < 0 ? sample * 0x8000 : sample * 0x7fff, offset);
      offset += 2;
    }

    return buffer;
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const audioTranscriptionService = new AudioTranscriptionService();
