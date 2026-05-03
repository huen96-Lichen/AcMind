// PinMind Strategy Registry
// Phase 8.1: 策略注册表，管理所有 source_type 对应的处理策略

import type { SourceType } from '../../../shared/types';
import type { ContentProcessingStrategy, StrategyRegistry } from './types';
import { ManualTextStrategy } from './strategies/manualTextStrategy';
import { ClipboardTextStrategy } from './strategies/clipboardTextStrategy';
import { WebpageStrategy } from './strategies/webpageStrategy';
import { ScreenshotStrategy } from './strategies/screenshotStrategy';
import { FileStrategy } from './strategies/fileStrategy';
import { AudioStrategy } from './strategies/audioStrategy';
import { VideoStrategy } from './strategies/videoStrategy';
import { PdfStrategy } from './strategies/pdfStrategy';
import { DocxStrategy } from './strategies/docxStrategy';
import { ImageStrategy } from './strategies/imageStrategy';
import { UnknownFileStrategy } from './strategies/unknownFileStrategy';

// ---------------------------------------------------------------------------
// DefaultStrategyRegistry
// ---------------------------------------------------------------------------

export class DefaultStrategyRegistry implements StrategyRegistry {
  private strategies = new Map<SourceType, ContentProcessingStrategy>();

  constructor() {
    // 注册所有内置策略
    this.register(new ManualTextStrategy());
    this.register(new ClipboardTextStrategy());
    this.register(new WebpageStrategy());
    this.register(new ScreenshotStrategy());
    this.register(new FileStrategy());
    this.register(new AudioStrategy());
    this.register(new VideoStrategy());
    this.register(new PdfStrategy());
    this.register(new DocxStrategy());
    this.register(new ImageStrategy());
    this.register(new UnknownFileStrategy());
  }

  register(strategy: ContentProcessingStrategy): void {
    this.strategies.set(strategy.sourceType, strategy);
  }

  hasStrategy(sourceType: SourceType): boolean {
    return this.strategies.has(sourceType);
  }

  getStrategy(sourceType: SourceType): ContentProcessingStrategy {
    const strategy = this.strategies.get(sourceType);
    if (!strategy) {
      // 回退到 unknown_file 策略
      const fallback = this.strategies.get('unknown_file');
      if (fallback) {
        return fallback;
      }
      throw new Error(`No strategy found for source_type: ${sourceType}`);
    }
    return strategy;
  }

  /**
   * 获取所有已注册的策略（用于调试和测试）
   */
  getAllStrategies(): ContentProcessingStrategy[] {
    return Array.from(this.strategies.values());
  }
}

// ---------------------------------------------------------------------------
// 单例导出
// ---------------------------------------------------------------------------

export const strategyRegistry = new DefaultStrategyRegistry();
