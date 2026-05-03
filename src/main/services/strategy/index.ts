// AcMind Strategy Module
// Phase 8.1-8.6: 内容类型处理策略模块入口

// ── Types ────────────────────────────────────────────────────────
export type {
  ProcessedContent,
  StrategyInput,
  ContentProcessingStrategy,
  StrategyRegistry,
  ModelCallRecord,
  ProcessingContext,
} from './types';

// ── Phase 8.1: 策略基础 ─────────────────────────────────────────
export { BaseStrategy } from './baseStrategy';
export { DefaultStrategyRegistry, strategyRegistry } from './strategyRegistry';

export {
  ManualTextStrategy,
  ClipboardTextStrategy,
  WebpageStrategy,
  ScreenshotStrategy,
  FileStrategy,
  AudioStrategy,
  VideoStrategy,
  PdfStrategy,
  DocxStrategy,
  ImageStrategy,
  UnknownFileStrategy,
} from './strategies';

// ── Phase 8.2: Prompt Profile ────────────────────────────────────
export type { PromptProfile } from './promptProfile';
export { promptProfileRegistry, renderTemplate } from './promptProfile';

// ── Phase 8.3: Model Router ──────────────────────────────────────
export type { ModelTier, RoutingDecision, RoutingContext } from './modelRouter';
export { modelRouter } from './modelRouter';

// ── Phase 8.4: Output Validator ──────────────────────────────────
export type { QualityFlag, ValidationResult } from './outputValidator';
export { outputValidator } from './outputValidator';

// ── Phase 8.5: Quality Fallback ──────────────────────────────────
export type {
  QualityLevel,
  QualityAssessment,
  QualityIssue,
  RegenerationSuggestion,
  RegenerationRecord,
} from './qualityFallback';
export { qualityFallback } from './qualityFallback';

// ── Strategy Processor (集成所有模块) ────────────────────────────
export type { ProcessingResult } from './strategyProcessor';
export { strategyProcessor } from './strategyProcessor';
