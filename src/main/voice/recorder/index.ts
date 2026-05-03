import type { VoiceSessionPhase } from '../../../shared/types';

export interface VoiceRecorderSnapshot {
  phase: VoiceSessionPhase;
  startedAt: number | null;
  source: 'openless-inspired-electron';
}

export class VoiceRecorderState {
  private phase: VoiceSessionPhase = 'idle';
  private startedAt: number | null = null;

  start(): VoiceRecorderSnapshot {
    this.phase = 'listening';
    this.startedAt = Date.now();
    return this.snapshot();
  }

  stop(): VoiceRecorderSnapshot {
    this.phase = 'processing';
    return this.snapshot();
  }

  reset(): VoiceRecorderSnapshot {
    this.phase = 'idle';
    this.startedAt = null;
    return this.snapshot();
  }

  snapshot(): VoiceRecorderSnapshot {
    return {
      phase: this.phase,
      startedAt: this.startedAt,
      source: 'openless-inspired-electron',
    };
  }
}

export const voiceRecorderState = new VoiceRecorderState();
