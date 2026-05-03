/**
 * OCRService — macOS Vision OCR 服务
 *
 * 使用 macOS Vision Framework（通过 Swift CLI）提取图片中的文字。
 * 不调用云端 API，完全本地处理。
 */

import { execFile } from 'child_process';
import { promisify } from 'util';
import { existsSync } from 'fs';
import { join } from 'path';
import { app } from 'electron';
import { logger } from './logger';
import { OcrResult } from '../shared/types';

const execFileAsync = promisify(execFile);

// Swift OCR 脚本路径
const SCRIPT_PATH = join(__dirname, '../../scripts/vision_ocr.swift');

class OCRService {
  private swiftAvailable: boolean | null = null;

  /**
   * 检查 Swift 是否可用
   */
  async isAvailable(): Promise<boolean> {
    if (this.swiftAvailable !== null) return this.swiftAvailable;

    try {
      if (process.platform !== 'darwin') {
        this.swiftAvailable = false;
        return false;
      }

      // 检查 swift 命令
      await execFileAsync('/usr/bin/swift', ['--version'], { timeout: 5000 });
      this.swiftAvailable = true;
      return true;
    } catch {
      this.swiftAvailable = false;
      return false;
    }
  }

  /**
   * 对图片执行 OCR
   */
  async extractText(imagePath: string, language?: string): Promise<OcrResult> {
    if (!existsSync(imagePath)) {
      return { text: '', error: 'Image file not found' };
    }

    const available = await this.isAvailable();
    if (!available) {
      return { text: '', error: 'OCR not available on this platform' };
    }

    try {
      // 使用 Swift Vision Framework
      const args = [SCRIPT_PATH, imagePath];
      if (language) args.push(language);

      const { stdout, stderr } = await execFileAsync('/usr/bin/swift', args, {
        timeout: 30000, // 30 秒超时
        maxBuffer: 10 * 1024 * 1024, // 10MB buffer
      });

      if (stderr && stderr.includes('Error:')) {
        logger.warn('error', 'ocrService', 'extractText', 'Swift OCR stderr', { stderr });
      }

      const text = stdout.trim();
      if (!text) {
        return { text: '', language: language || 'auto' };
      }

      return {
        text,
        language: language || 'auto',
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'ocrService', 'extractText', 'OCR extraction failed', {
        imagePath,
        error: errorMsg,
      });
      return { text: '', error: errorMsg };
    }
  }
}

export const ocrService = new OCRService();
