// PinMind CaptureAdapter Registry
// V2.1 Phase 7.1: Central registry for all capture adapters.
// Provides a single entry point to capture content from any source type.

import type { CaptureAdapter, CaptureRecord, SourceType, CaptureInput } from '../../../shared/types';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Re-export CaptureInput from shared types for backward compatibility
// ---------------------------------------------------------------------------

export type { CaptureInput };

// ---------------------------------------------------------------------------
// CaptureAdapterRegistry
// ---------------------------------------------------------------------------

class CaptureAdapterRegistry {
  private adapters = new Map<SourceType, CaptureAdapter<any>>();

  /**
   * Register a capture adapter for a specific source type.
   */
  register<TInput>(adapter: CaptureAdapter<TInput>): void {
    if (this.adapters.has(adapter.sourceType)) {
      logger.warn('app', 'captureRegistry', 'register', `Adapter already registered for ${adapter.sourceType}, replacing`);
    }
    this.adapters.set(adapter.sourceType, adapter as CaptureAdapter<unknown>);
    logger.info('app', 'captureRegistry', 'register', `CaptureAdapter registered: ${adapter.sourceType}`);
  }

  /**
   * Get the adapter for a specific source type.
   */
  get<TInput>(sourceType: SourceType): CaptureAdapter<TInput> | undefined {
    return this.adapters.get(sourceType) as CaptureAdapter<TInput> | undefined;
  }

  /**
   * Check if an adapter is registered for a specific source type.
   */
  has(sourceType: SourceType): boolean {
    return this.adapters.has(sourceType);
  }

  /**
   * Get all registered source types.
   */
  getAvailableTypes(): SourceType[] {
    return Array.from(this.adapters.keys());
  }

  /**
   * Capture content using the appropriate adapter based on source type.
   * This is the main entry point for the unified capture architecture.
   */
  capture(input: CaptureInput): CaptureRecord {
    const adapter = this.adapters.get(input.sourceType);
    if (!adapter) {
      throw new Error(`No CaptureAdapter registered for source type: ${input.sourceType}`);
    }

    try {
      const record = adapter.capture(input);
      logger.info('app', 'captureRegistry', 'capture', `Content captured via ${input.sourceType}`, {
        originalId: record.original_id,
        sourceType: record.source_type,
      });
      return record;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      logger.error('error', 'captureRegistry', 'capture', `Capture failed for ${input.sourceType}`, {
        error: errorMsg,
      });
      throw error;
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const captureRegistry = new CaptureAdapterRegistry();
