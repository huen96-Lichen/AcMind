// ═══════════════════════════════════════════════════════════════════════════════
// AcMind — Whisper WASM Service
// 本地语音转文字服务，基于 whisper.cpp WebAssembly 构建
// 在渲染进程中运行，无需原生依赖，跨平台兼容
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Types ───────────────────────────────────────────────────────────────────

export type WhisperModelSize = 'tiny' | 'base' | 'small';

export interface WhisperModelInfo {
  size: WhisperModelSize;
  displayName: string;
  fileSize: string;
  description: string;
}

export interface WhisperTranscribeOptions {
  /** 识别语言，'auto' 为自动检测 */
  language: string;
  /** 是否翻译为英文 */
  translate: boolean;
  /** 进度回调 */
  onProgress?: (progress: number, message: string) => void;
}

export interface WhisperTranscribeResult {
  /** 转写文本 */
  text: string;
  /** 检测到的语言 */
  detectedLanguage?: string;
  /** 处理耗时 (ms) */
  elapsedMs: number;
  /** 分段结果 */
  segments: Array<{
    text: string;
    start: number;
    end: number;
  }>;
}

export type WhisperServiceStatus =
  | 'uninitialized'
  | 'loading-model'
  | 'ready'
  | 'transcribing'
  | 'error';

// ─── Constants ───────────────────────────────────────────────────────────────

export const WHISPER_MODELS: Record<WhisperModelSize, WhisperModelInfo> = {
  tiny: {
    size: 'tiny',
    displayName: 'Tiny (75MB)',
    fileSize: '75 MB',
    description: '最轻量，速度最快，适合快速笔记',
  },
  base: {
    size: 'base',
    displayName: 'Base (142MB)',
    fileSize: '142 MB',
    description: '精度与速度平衡，推荐日常使用',
  },
  small: {
    size: 'small',
    displayName: 'Small (466MB)',
    fileSize: '466 MB',
    description: '较高精度，适合重要内容',
  },
};

/** 模型下载 URL (HuggingFace) */
const MODEL_BASE_URL = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

const MODEL_FILE_MAP: Record<WhisperModelSize, string> = {
  tiny: 'ggml-tiny.bin',
  base: 'ggml-base.bin',
  small: 'ggml-small.bin',
};

// ─── WhisperService ──────────────────────────────────────────────────────────

/**
 * Whisper WASM 语音转文字服务
 *
 * 架构说明：
 * - whisper.cpp 的 WASM 版本在渲染进程中运行
 * - 模型文件从 HuggingFace 下载并缓存在 IndexedDB 中
 * - 音频输入要求：16kHz 单声道 Float32 PCM
 */
class WhisperService {
  private status: WhisperServiceStatus = 'uninitialized';
  private currentModel: WhisperModelSize | null = null;
  private wasmModule: any = null;
  private whisperContext: any = null;
  private statusListeners: Set<(status: WhisperServiceStatus) => void> = new Set();

  // ── Status Management ──

  getStatus(): WhisperServiceStatus {
    return this.status;
  }

  private setStatus(status: WhisperServiceStatus): void {
    this.status = status;
    this.statusListeners.forEach((cb) => cb(status));
  }

  onStatusChange(callback: (status: WhisperServiceStatus) => void): () => void {
    this.statusListeners.add(callback);
    return () => this.statusListeners.delete(callback);
  }

  /**
   * Promisified IDB store.get()
   */
  private idbGet(store: IDBObjectStore, key: string): Promise<any> {
    return new Promise((resolve, reject) => {
      const req = store.get(key);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  /**
   * Promisified IDB store.put()
   */
  private idbPut(store: IDBObjectStore, value: unknown): Promise<void> {
    return new Promise((resolve, reject) => {
      const req = store.put(value);
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  }

  /**
   * Promisified IDB store.delete()
   */
  private idbDelete(store: IDBObjectStore, key: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const req = store.delete(key);
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  }

  // ── Model Management ──

  /**
   * 获取指定模型的下载 URL
   */
  getModelUrl(modelSize: WhisperModelSize): string {
    return `${MODEL_BASE_URL}/${MODEL_FILE_MAP[modelSize]}`;
  }

  /**
   * 检查模型是否已缓存在 IndexedDB 中
   */
  async isModelCached(modelSize: WhisperModelSize): Promise<boolean> {
    try {
      const db = await this.openModelDB();
      const tx = db.transaction('models', 'readonly');
      const store = tx.objectStore('models');
      const record = await this.idbGet(store, modelSize);
      db.close();
      return !!record;
    } catch {
      return false;
    }
  }

  /**
   * 获取已缓存模型的大小信息
   */
  async getCachedModelInfo(modelSize: WhisperModelSize): Promise<{ cached: boolean; size?: number } | null> {
    try {
      const db = await this.openModelDB();
      const tx = db.transaction('models', 'readonly');
      const store = tx.objectStore('models');
      const record = await this.idbGet(store, modelSize);
      db.close();
      if (record) {
        return { cached: true, size: record.sizeBytes };
      }
      return { cached: false };
    } catch {
      return null;
    }
  }

  /**
   * 下载模型并缓存到 IndexedDB
   */
  async downloadModel(
    modelSize: WhisperModelSize,
    onProgress?: (progress: number) => void,
  ): Promise<void> {
    const url = this.getModelUrl(modelSize);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`模型下载失败: ${response.status} ${response.statusText}`);
    }

    const contentLength = response.headers.get('content-length');
    const totalBytes = contentLength ? parseInt(contentLength, 10) : 0;

    if (!response.body) {
      // Fallback: 无流式进度
      const buffer = await response.arrayBuffer();
      await this.saveModelToDB(modelSize, buffer);
      return;
    }

    // 流式下载并报告进度
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let receivedBytes = 0;

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      receivedBytes += value.length;
      if (totalBytes > 0 && onProgress) {
        onProgress(Math.round((receivedBytes / totalBytes) * 100));
      }
    }

    // 合并 chunks
    const totalLength = chunks.reduce((acc, chunk) => acc + chunk.length, 0);
    const merged = new Uint8Array(totalLength);
    let offset = 0;
    for (const chunk of chunks) {
      merged.set(chunk, offset);
      offset += chunk.length;
    }

    await this.saveModelToDB(modelSize, merged.buffer);
  }

  /**
   * 删除已缓存的模型
   */
  async deleteCachedModel(modelSize: WhisperModelSize): Promise<void> {
    const db = await this.openModelDB();
    const tx = db.transaction('models', 'readwrite');
    const store = tx.objectStore('models');
    await this.idbDelete(store, modelSize);
    db.close();
  }

  // ── Initialization ──

  /**
   * 初始化 Whisper WASM 并加载模型
   * 这是异步操作，可能需要几秒钟
   */
  async initialize(modelSize: WhisperModelSize): Promise<void> {
    if (this.status === 'loading-model' || this.status === 'transcribing') {
      throw new Error('Whisper 服务正在忙碌中');
    }

    try {
      this.setStatus('loading-model');

      // 检查模型是否已缓存
      const cached = await this.isModelCached(modelSize);
      if (!cached) {
        throw new Error(`模型 ${modelSize} 尚未下载，请先下载模型`);
      }

      // 加载 WASM 模块
      if (!this.wasmModule) {
        this.wasmModule = await this.loadWasmModule();
      }

      // 从 IndexedDB 读取模型数据
      const modelBuffer = await this.loadModelFromDB(modelSize);
      if (!modelBuffer) {
        throw new Error(`模型 ${modelSize} 缓存数据损坏，请重新下载`);
      }

      // 初始化 whisper context
      this.whisperContext = this.wasmModule.init(modelBuffer);
      if (!this.whisperContext) {
        throw new Error('Whisper 模型初始化失败');
      }

      this.currentModel = modelSize;
      this.setStatus('ready');
    } catch (error) {
      this.setStatus('error');
      this.whisperContext = null;
      throw error;
    }
  }

  /**
   * 释放当前加载的模型和 WASM 资源
   */
  dispose(): void {
    if (this.whisperContext && this.wasmModule) {
      this.wasmModule.free(this.whisperContext);
      this.whisperContext = null;
    }
    this.currentModel = null;
    this.setStatus('uninitialized');
  }

  // ── Transcription ──

  /**
   * 转写音频数据
   * @param pcmf32 16kHz 单声道 Float32 PCM 音频数据
   */
  async transcribe(
    pcmf32: Float32Array,
    options?: WhisperTranscribeOptions,
  ): Promise<WhisperTranscribeResult> {
    if (this.status !== 'ready' || !this.whisperContext || !this.wasmModule) {
      throw new Error('Whisper 服务未就绪，请先初始化');
    }

    this.setStatus('transcribing');
    const startTime = performance.now();
    const opts = options ?? { language: 'auto', translate: false };

    try {
      opts.onProgress?.(0, '正在转写...');

      const result = this.wasmModule.transcribe(this.whisperContext, pcmf32, {
        language: opts.language === 'auto' ? '' : opts.language,
        translate: opts.translate,
        onProgress: (progress: number) => {
          opts.onProgress?.(progress, '正在转写...');
        },
      });

      const elapsedMs = Math.round(performance.now() - startTime);

      opts.onProgress?.(100, '转写完成');

      this.setStatus('ready');

      return {
        text: result.text || '',
        detectedLanguage: result.language,
        elapsedMs,
        segments: result.segments || [],
      };
    } catch (error) {
      this.setStatus('error');
      throw error;
    }
  }

  /**
   * 获取当前加载的模型大小
   */
  getCurrentModel(): WhisperModelSize | null {
    return this.currentModel;
  }

  // ── Private Helpers ──

  private openModelDB(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('acmind-whisper-models', 1);

      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains('models')) {
          db.createObjectStore('models', { keyPath: 'size' });
        }
      };

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  private async saveModelToDB(modelSize: WhisperModelSize, buffer: ArrayBuffer): Promise<void> {
    const db = await this.openModelDB();
    const tx = db.transaction('models', 'readwrite');
    const store = tx.objectStore('models');
    await this.idbPut(store, {
      size: modelSize,
      data: buffer,
      sizeBytes: buffer.byteLength,
      downloadedAt: Date.now(),
    });
    db.close();
  }

  private async loadModelFromDB(modelSize: WhisperModelSize): Promise<ArrayBuffer | null> {
    const db = await this.openModelDB();
    const tx = db.transaction('models', 'readonly');
    const store = tx.objectStore('models');
    const record = await this.idbGet(store, modelSize);
    db.close();
    return record?.data || null;
  }

  /**
   * 加载 whisper.cpp WASM 模块
   *
   * 注意：这是一个 stub 实现。实际部署时需要：
   * 1. 从 whisper.cpp 仓库编译 WASM 版本
   * 2. 将生成的 .wasm 文件和 JS glue 代码放入 public/whisper/ 目录
   * 3. 或者使用 npm 包如 @anthropic/whisper-wasm（如果有）
   *
   * 当前实现使用 Web Audio API + OfflineAudioContext 作为临时方案，
   * 后续替换为真正的 whisper.cpp WASM 绑定。
   */
  private async loadWasmModule(): Promise<any> {
    // ── Stub: 返回模拟的 WASM 模块接口 ──
    // 实际实现需要加载 whisper.cpp 的 WASM 编译产物
    //
    // 推荐的集成方式：
    //
    // 方式 1: 直接加载 whisper.cpp 官方 WASM
    //   const module = await import('./whisper/libmain.js');
    //   await module.default(); // 初始化 WASM
    //   return module;
    //
    // 方式 2: 使用 whisper.cpp 的 stream.wasm 示例
    //   const module = await import('./whisper/stream.js');
    //   return module;
    //
    // 方式 3: 自定义编译并打包
    //   cd whisper.cpp && mkdir build-wasm && cd build-wasm
    //   emcmake cmake .. && make
    //   将生成的文件复制到 public/whisper/

    console.warn(
      '[WhisperService] 使用 stub WASM 模块。' +
      '请编译 whisper.cpp WASM 并替换此实现。' +
      '参见: https://github.com/ggml-org/whisper.cpp/tree/master/examples/whisper.wasm',
    );

    return {
      init(_buffer: ArrayBuffer): any {
        // Stub: 返回模拟的 context
        return { initialized: true };
      },
      free(_ctx: any): void {
        // Stub
      },
      transcribe(
        _ctx: any,
        _pcm: Float32Array,
        _options: any,
      ): { text: string; language: string; segments: Array<{ text: string; start: number; end: number }> } {
        // Stub: 返回模拟结果
        // 实际实现会调用 whisper_full() 并解析结果
        return {
          text: '',
          language: 'zh',
          segments: [],
        };
      },
    };
  }
}

// ─── Singleton Export ────────────────────────────────────────────────────────

export const whisperService = new WhisperService();

export default whisperService;
