/**
 * ASR Provider — OpenAI-compatible Whisper API
 *
 * 支持：
 * - OpenAI Whisper API (POST /v1/audio/transcriptions)
 * - 任何 OpenAI-compatible endpoint (如 local whisper server, Groq, etc.)
 * - 本地 whisper CLI fallback
 */

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { logger } from '../../logger';
import { settings } from '../../settings';

// ── Types ────────────────────────────────────────────────────────

export interface VoiceAsrProviderStatus {
  provider: 'openai_compatible' | 'whisper_compatible' | 'none';
  configured: boolean;
  message: string;
  endpoint?: string;
}

export interface AsrTranscribeOptions {
  language?: string;
  translate?: boolean;
  prompt?: string;
  responseFormat?: 'json' | 'text' | 'verbose_json';
}

export interface AsrTranscribeResult {
  success: boolean;
  text: string;
  language?: string;
  duration?: number;
  segments?: Array<{ start: number; end: number; text: string }>;
  error?: string;
  engine?: string;
}

// ── Provider ─────────────────────────────────────────────────────

class AsrProvider {
  /**
   * Check if ASR is configured and available.
   */
  getStatus(): VoiceAsrProviderStatus {
    const s = settings.load();
    const ts = s.transcription;

    // Check API provider
    if (ts.provider === 'api' && ts.apiEndpoint && ts.apiKey) {
      return {
        provider: 'openai_compatible',
        configured: true,
        message: `API endpoint: ${ts.apiEndpoint}`,
        endpoint: ts.apiEndpoint,
      };
    }

    // Check local whisper
    if (ts.provider === 'local') {
      return {
        provider: 'whisper_compatible',
        configured: true,
        message: `Local engine: ${ts.localEngine}, model: ${ts.localModel}`,
      };
    }

    return {
      provider: 'none',
      configured: false,
      message: 'ASR not configured. Set transcription provider in Settings → AI Models.',
    };
  }

  /**
   * Transcribe audio file using configured provider.
   */
  async transcribe(filePath: string, options?: AsrTranscribeOptions): Promise<AsrTranscribeResult> {
    const status = this.getStatus();

    if (status.provider === 'openai_compatible') {
      return this.transcribeViaApi(filePath, options);
    }

    if (status.provider === 'whisper_compatible') {
      return this.transcribeViaLocal(filePath, options);
    }

    return {
      success: false,
      text: '',
      error: 'No ASR provider configured. Please set up transcription in Settings.',
    };
  }

  /**
   * Transcribe via OpenAI-compatible API (POST /v1/audio/transcriptions).
   */
  private async transcribeViaApi(filePath: string, options?: AsrTranscribeOptions): Promise<AsrTranscribeResult> {
    const s = settings.load();
    const ts = s.transcription;
    const endpoint = ts.apiEndpoint!;
    const apiKey = ts.apiKey!;

    try {
      const fileBuffer = readFileSync(filePath);
      const fileName = path.basename(filePath);
      const mimeType = this.getMimeType(filePath);

      // Build multipart form data
      const boundary = `----FormBoundary${Date.now()}`;
      const parts: Buffer[] = [];

      // File part
      parts.push(Buffer.from(`--${boundary}\r\n`));
      parts.push(Buffer.from(`Content-Disposition: form-data; name="file"; filename="${fileName}"\r\n`));
      parts.push(Buffer.from(`Content-Type: ${mimeType}\r\n\r\n`));
      parts.push(fileBuffer);
      parts.push(Buffer.from('\r\n'));

      // Model part
      parts.push(Buffer.from(`--${boundary}\r\n`));
      parts.push(Buffer.from(`Content-Disposition: form-data; name="model"\r\n\r\n`));
      parts.push(Buffer.from(`${ts.apiModel || 'whisper-1'}\r\n`));

      // Language part
      const language = options?.language ?? ts.apiLanguage;
      if (language) {
        parts.push(Buffer.from(`--${boundary}\r\n`));
        parts.push(Buffer.from(`Content-Disposition: form-data; name="language"\r\n\r\n`));
        parts.push(Buffer.from(`${language}\r\n`));
      }

      // Response format
      const responseFormat = options?.responseFormat ?? 'verbose_json';
      parts.push(Buffer.from(`--${boundary}\r\n`));
      parts.push(Buffer.from(`Content-Disposition: form-data; name="response_format"\r\n\r\n`));
      parts.push(Buffer.from(`${responseFormat}\r\n`));

      // Prompt (hot words / context)
      const prompt = options?.prompt ?? ts.apiPrompt;
      if (prompt) {
        parts.push(Buffer.from(`--${boundary}\r\n`));
        parts.push(Buffer.from(`Content-Disposition: form-data; name="prompt"\r\n\r\n`));
        parts.push(Buffer.from(`${prompt}\r\n`));
      }

      // Translate flag
      if (options?.translate) {
        parts.push(Buffer.from(`--${boundary}\r\n`));
        parts.push(Buffer.from(`Content-Disposition: form-data; name="translate"\r\n\r\n`));
        parts.push(Buffer.from(`true\r\n`));
      }

      parts.push(Buffer.from(`--${boundary}--\r\n`));
      const body = Buffer.concat(parts);

      const url = endpoint.endsWith('/') ? `${endpoint}audio/transcriptions` : `${endpoint}/audio/transcriptions`;

      logger.info('app', 'asr', 'transcribe', `Calling API: ${url}`, {
        file: fileName,
        model: ts.apiModel || 'whisper-1',
        language,
      });

      const timeoutMs = ts.apiTimeoutMs ?? 60000;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);

      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
          },
          body,
          signal: controller.signal,
        });

        clearTimeout(timer);

        if (!response.ok) {
          const errorText = await response.text().catch(() => 'Unknown error');
          logger.error('error', 'asr', 'transcribe', `API error: ${response.status}`, { error: errorText });
          return {
            success: false,
            text: '',
            error: `API returned ${response.status}: ${errorText}`,
            engine: 'openai_compatible',
          };
        }

        const result = await response.json() as Record<string, unknown>;
        const text = (result.text as string) ?? '';

        return {
          success: true,
          text,
          language: result.language as string | undefined,
          duration: result.duration as number | undefined,
          segments: result.segments as AsrTranscribeResult['segments'],
          engine: 'openai_compatible',
        };
      } catch (fetchError) {
        clearTimeout(timer);
        if (fetchError instanceof Error && fetchError.name === 'AbortError') {
          return { success: false, text: '', error: `API timeout after ${timeoutMs}ms`, engine: 'openai_compatible' };
        }
        throw fetchError;
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'asr', 'transcribe', `API transcription failed: ${msg}`);
      return { success: false, text: '', error: msg, engine: 'openai_compatible' };
    }
  }

  /**
   * Transcribe via local whisper CLI.
   */
  private async transcribeViaLocal(filePath: string, options?: AsrTranscribeOptions): Promise<AsrTranscribeResult> {
    const s = settings.load();
    const ts = s.transcription;
    const engine = ts.localEngine ?? 'whisper-ctranslate2';
    const model = ts.localModel ?? 'base';

    try {
      const args = [filePath, '--model', model, '--output_format', 'json'];

      const language = options?.language ?? ts.apiLanguage;
      if (language) {
        args.push('--language', language);
      }
      if (options?.translate) {
        args.push('--task', 'translate');
      }

      logger.info('app', 'asr', 'transcribe', `Running local ${engine}`, { file: filePath, model });

      const { execFile: execFileCb } = await import('node:child_process');
      const { promisify } = await import('node:util');
      const execFileAsync = promisify(execFileCb);

      const { stdout } = await execFileAsync(engine, args, { timeout: 300000 });

      // Try to parse JSON output
      try {
        const parsed = JSON.parse(stdout) as Record<string, unknown>;
        return {
          success: true,
          text: (parsed.text as string) ?? '',
          language: parsed.language as string | undefined,
          duration: parsed.duration as number | undefined,
          segments: parsed.segments as AsrTranscribeResult['segments'],
          engine,
        };
      } catch {
        // Fallback: treat stdout as plain text
        return {
          success: true,
          text: stdout.trim(),
          engine,
        };
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'asr', 'transcribe', `Local transcription failed: ${msg}`);
      return { success: false, text: '', error: msg, engine };
    }
  }

  private getMimeType(filePath: string): string {
    const ext = path.extname(filePath).toLowerCase();
    const map: Record<string, string> = {
      '.mp3': 'audio/mpeg',
      '.mp4': 'audio/mp4',
      '.m4a': 'audio/mp4',
      '.wav': 'audio/wav',
      '.webm': 'audio/webm',
      '.ogg': 'audio/ogg',
      '.flac': 'audio/flac',
      '.aac': 'audio/aac',
      '.opus': 'audio/opus',
    };
    return map[ext] ?? 'audio/wav';
  }
}

export const asrProvider = new AsrProvider();

// Keep backward-compatible export
export function getVoiceAsrProviderStatus(): VoiceAsrProviderStatus {
  return asrProvider.getStatus();
}
