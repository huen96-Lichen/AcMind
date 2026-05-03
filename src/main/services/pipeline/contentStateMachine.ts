// AcMind ContentStateMachine
// Phase 2: State machine for content lifecycle management.
// Ensures stable state transitions, prevents duplicate exports,
// and tracks all state changes for debugging and recovery.

import { randomUUID } from 'node:crypto';
import { createHash } from 'node:crypto';
import { storage } from '../../storage';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Content lifecycle states */
export type ContentState =
  | 'captured'
  | 'processing'
  | 'structured'
  | 'exporting'
  | 'exported'
  // Failure states
  | 'capture_failed'
  | 'process_failed'
  | 'export_failed'
  | 'conflict_pending'
  | 'permission_required';

/** State transition record */
export interface StateTransition {
  sourceItemId: string;
  fromState: ContentState;
  toState: ContentState;
  actor: 'system' | 'user' | 'pipeline';
  reason?: string;
  error?: string;
  timestamp: number;
}

/** Valid state transitions (from → allowed targets) */
const VALID_TRANSITIONS: Record<ContentState, ContentState[]> = {
  captured: ['processing', 'capture_failed'],
  processing: ['structured', 'process_failed', 'captured'],
  structured: ['exporting', 'processing'],
  exporting: ['exported', 'export_failed', 'conflict_pending', 'permission_required', 'structured'],
  exported: [], // Terminal state (can retry via explicit retry action)
  capture_failed: ['captured'],
  process_failed: ['processing', 'captured'],
  export_failed: ['exporting', 'structured'],
  conflict_pending: ['exporting', 'structured'],
  permission_required: ['exporting', 'structured'],
};

/** Mapping from ContentState to SourceItem.status */
const STATE_TO_SOURCE_STATUS: Record<ContentState, string> = {
  captured: 'inbox',
  processing: 'distilling',
  structured: 'distilled',
  exporting: 'distilling',
  exported: 'exported',
  capture_failed: 'inbox',
  process_failed: 'inbox',
  export_failed: 'distilled',
  conflict_pending: 'distilled',
  permission_required: 'distilled',
};

// ---------------------------------------------------------------------------
// ContentStateMachine
// ---------------------------------------------------------------------------

class ContentStateMachine {
  /**
   * Transition a content item to a new state.
   * Validates the transition, updates the database, and records the history.
   * Returns true if the transition was successful.
   */
  transition(
    sourceItemId: string,
    toState: ContentState,
    options?: {
      actor?: 'system' | 'user' | 'pipeline';
      reason?: string;
      error?: string;
    },
  ): boolean {
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) {
      logger.error('error', 'stateMachine', 'transition', `SourceItem not found: ${sourceItemId}`);
      return false;
    }

    const fromState = this.resolveCurrentState(sourceItem);

    // Skip if already in target state (no-op)
    if (fromState === toState) {
      return true;
    }

    // Validate transition
    if (!this.isValidTransition(fromState, toState)) {
      logger.warn('app', 'stateMachine', 'transition', `Invalid transition: ${fromState} → ${toState}`, {
        sourceItemId,
      });
      return false;
    }

    // Update SourceItem status
    const newStatus = STATE_TO_SOURCE_STATUS[toState];
    if (newStatus) {
      storage.updateSourceItem(sourceItemId, { status: newStatus as any });
    }

    // Record state history
    storage.insertContentStateHistory({
      sourceItemId,
      fromState,
      toState,
      actor: options?.actor ?? 'system',
      reason: options?.reason,
      error: options?.error,
    });

    logger.info('app', 'stateMachine', 'transition', `${fromState} → ${toState}`, {
      sourceItemId,
      actor: options?.actor ?? 'system',
    });

    return true;
  }

  /**
   * Get the current state of a content item.
   */
  getCurrentState(sourceItemId: string): ContentState {
    const sourceItem = storage.getSourceItem(sourceItemId);
    if (!sourceItem) return 'capture_failed';
    return this.resolveCurrentState(sourceItem);
  }

  /**
   * Check if a content item has already been exported successfully.
   */
  isExported(sourceItemId: string): boolean {
    const state = this.getCurrentState(sourceItemId);
    return state === 'exported';
  }

  /**
   * Check if a content item can be retried.
   */
  canRetry(sourceItemId: string): boolean {
    const state = this.getCurrentState(sourceItemId);
    return ['export_failed', 'process_failed', 'conflict_pending', 'permission_required'].includes(state);
  }

  /**
   * Check if a content item can transition to a specific state.
   */
  canTransition(sourceItemId: string, toState: ContentState): boolean {
    const currentState = this.getCurrentState(sourceItemId);
    return this.isValidTransition(currentState, toState);
  }

  /**
   * Get the full state history for a content item.
   */
  getHistory(sourceItemId: string): StateTransition[] {
    const records = storage.getContentStateHistory(sourceItemId);
    return records.map((r: { id: string; sourceItemId: string; fromState: string; toState: string; actor: string; reason?: string; error?: string; createdAt: number }) => ({
      sourceItemId: r.sourceItemId,
      fromState: r.fromState as ContentState,
      toState: r.toState as ContentState,
      actor: r.actor as 'system' | 'user' | 'pipeline',
      reason: r.reason,
      error: r.error,
      timestamp: r.createdAt,
    }));
  }

  /**
   * Generate a content hash for deduplication.
   * Uses SHA-256 of the normalized text content.
   */
  generateContentHash(content: string): string {
    const normalized = content.trim().replace(/\s+/g, ' ');
    return createHash('sha256').update(normalized).digest('hex').slice(0, 16);
  }

  /**
   * Check if content already exists (by original_id hash).
   * Returns the existing SourceItem if found, null otherwise.
   */
  findDuplicate(content: string): { sourceItem: any; originalId: string } | null {
    const originalId = this.generateContentHash(content);
    const existing = storage.getSourceItemByOriginalId(originalId);
    if (existing) {
      return { sourceItem: existing, originalId };
    }
    return null;
  }

  /**
   * Resolve the current ContentState from a SourceItem's database status,
   * export records, and state history.
   */
  private resolveCurrentState(sourceItem: { id: string; status: string }): ContentState {
    // Check for successful export
    const exportRecords = storage.getExportRecords({ sourceItemId: sourceItem.id });
    const hasSuccess = exportRecords.some((r: { status: string }) => r.status === 'success');
    const hasConflict = exportRecords.some((r: { status: string }) => r.status === 'conflict');
    const hasFailed = exportRecords.some((r: { status: string }) => r.status === 'failed');

    if (hasSuccess) return 'exported';
    if (hasConflict) return 'conflict_pending';
    if (hasFailed) return 'export_failed';

    // Check state history for the most recent state (resolves processing vs exporting ambiguity)
    const history = storage.getContentStateHistory(sourceItem.id);
    if (history.length > 0) {
      // history is ordered by insertion time (oldest first), get the latest entry
      const latestEntry = history[history.length - 1];
      const latestState = latestEntry.toState as ContentState;
      // Only use history if it's a valid ContentState and not a terminal state
      // that would conflict with the DB status
      if (latestState && latestState !== 'captured') {
        return latestState;
      }
    }

    // Fallback: Map SourceItem status to ContentState
    switch (sourceItem.status) {
      case 'inbox': return 'captured';
      case 'distilling': return 'processing';
      case 'distilled': return 'structured';
      case 'exported': return 'exported';
      case 'archived': return 'exported';
      default: return 'captured';
    }
  }

  /**
   * Validate if a state transition is allowed.
   */
  private isValidTransition(fromState: ContentState, toState: ContentState): boolean {
    // Allow retry transitions for failure states
    if (fromState === 'exported' && toState === 'exporting') {
      // Allow re-export from exported state (explicit retry)
      return true;
    }

    const allowedTargets = VALID_TRANSITIONS[fromState];
    return allowedTargets.includes(toState);
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const contentStateMachine = new ContentStateMachine();
