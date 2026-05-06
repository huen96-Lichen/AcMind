// ─── DictationCapsule ──────────────────────────────────────────
// Self-contained dictation capsule UI, inspired by OpenLess Capsule.tsx.
// Listens for `dictation:state` IPC events from main process.
// No outbound IPC — all controls via main process hotkeys.

import { useEffect, useRef, useState, useCallback } from 'react';
import type { DictationCapsulePayload, DictationSessionPhase } from '../../../shared/types';

// ─── Helpers ────────────────────────────────────────────────────

function formatElapsed(ms: number): string {
  const totalSec = Math.floor(ms / 1000);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return min > 0 ? `${min}:${sec.toString().padStart(2, '0')}` : `${sec}`;
}

// ─── Audio Bars ────────────────────────────────────────────────

function AudioBars({ level }: { level: number }) {
  const barCount = 5;
  const bars = useRef(
    Array.from({ length: barCount }, (_, i) => ({
      baseHeight: 8 + Math.random() * 16,
      phase: (i / barCount) * Math.PI * 2,
    })),
  );

  return (
    <div style={styles.audioBarsContainer}>
      {bars.current.map((bar, i) => {
        const h = bar.baseHeight + level * 20 * Math.sin(bar.phase + Date.now() / 200 + i);
        return (
          <div
            key={i}
            style={{
              ...styles.audioBar,
              height: `${Math.max(4, h)}px`,
              animationDelay: `${i * 0.08}s`,
            }}
          />
        );
      })}
    </div>
  );
}

// ─── Bouncing Dots ─────────────────────────────────────────────

function BouncingDots() {
  return (
    <div style={styles.dotsContainer}>
      {[0, 1, 2].map(i => (
        <div
          key={i}
          style={{
            ...styles.dot,
            animationDelay: `${i * 0.15}s`,
          }}
        />
      ))}
    </div>
  );
}

function StatusPill({ state, text }: { state: Exclude<DictationSessionPhase, 'idle' | 'done' | 'cancelled' | 'error'>; text: string }) {
  const tone = state === 'transcribing' ? 'warm' : state === 'polishing' ? 'cool' : state === 'inserting' ? 'neutral' : 'calm';

  return (
    <div style={{ ...styles.statusPill, ...STATUS_PILL_TONES[tone] }}>
      <span style={styles.statusPillDotWrap}>
        {state === 'transcribing' ? (
          <span style={styles.spinner} />
        ) : (
          <span style={styles.statusPillDot} />
        )}
      </span>
      <span style={styles.statusPillText}>{text}</span>
    </div>
  );
}

function FloatingHint({
  state,
  translation,
}: {
  state: DictationSessionPhase;
  translation: boolean;
}) {
  if (state === 'starting') {
    return <StatusPill state="starting" text="准备录音..." />;
  }

  if (state === 'listening') {
    return <StatusPill state="listening" text={translation ? '录音中 · 松开后翻译并转录' : '录音中 · 松开后自动转录'} />;
  }

  if (state === 'transcribing') {
    return <StatusPill state="transcribing" text="正在转录..." />;
  }

  if (state === 'polishing') {
    return <StatusPill state="polishing" text="正在整理文本..." />;
  }

  if (state === 'inserting') {
    return <StatusPill state="inserting" text="正在插入光标..." />;
  }

  return null;
}

const STATUS_PILL_TONES: Record<'calm' | 'warm' | 'cool' | 'neutral', React.CSSProperties> = {
  calm: {
    backgroundColor: 'rgba(15, 23, 42, 0.72)',
    color: '#ffffff',
  },
  warm: {
    backgroundColor: 'rgba(30, 41, 59, 0.78)',
    color: '#ffffff',
  },
  cool: {
    backgroundColor: 'rgba(17, 24, 39, 0.72)',
    color: '#ffffff',
  },
  neutral: {
    backgroundColor: 'rgba(15, 23, 42, 0.70)',
    color: '#ffffff',
  },
};

// ─── Main Component ────────────────────────────────────────────

export function DictationCapsule() {
  const [payload, setPayload] = useState<DictationCapsulePayload>({
    state: 'idle',
    level: 0,
    elapsedMs: 0,
    message: '',
    insertedChars: 0,
    translation: false,
  });

  const animFrameRef = useRef<number>(0);

  // Listen for IPC events from main process
  useEffect(() => {
    const unsubscribe = window.acmind?.dictation?.onStateChange?.((data) => {
      setPayload(data as unknown as DictationCapsulePayload);
    });

    return () => {
      unsubscribe?.();
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    };
  }, []);

  // Re-render audio bars during listening phase
  useEffect(() => {
    if (payload.state !== 'listening') return;

    let running = true;
    const tick = () => {
      if (!running) return;
      // Force re-render for audio bar animation
      setPayload(prev => ({ ...prev }));
      animFrameRef.current = requestAnimationFrame(tick);
    };
    animFrameRef.current = requestAnimationFrame(tick);

    return () => {
      running = false;
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current);
    };
  }, [payload.state]);

  const { state, level, elapsedMs, message, insertedChars, translation } = payload;

  // Idle: hidden
  const isVisible = state !== 'idle';

  return (
    <div style={{
      ...styles.root,
      opacity: isVisible ? 1 : 0,
      pointerEvents: isVisible ? 'auto' : 'none',
    }}>
      <div style={styles.capsuleWrap}>
        <FloatingHint state={state} translation={translation} />
        <div style={styles.capsule}>
        {/* Translation indicator */}
        {translation && state === 'listening' && (
          <div style={styles.translationBadge}>翻译</div>
        )}

        {/* Starting */}
        {state === 'starting' && (
          <div style={styles.contentRow}>
            <BouncingDots />
            <span style={styles.statusText}>准备中...</span>
          </div>
        )}

        {/* Listening */}
        {state === 'listening' && (
          <div style={styles.listeningContent}>
            <div style={styles.contentRow}>
              <AudioBars level={level} />
              <span style={styles.elapsedText}>{formatElapsed(elapsedMs)}</span>
            </div>
            <span style={styles.hintText}>再次按下快捷键结束</span>
          </div>
        )}

        {/* Transcribing / Polishing / Inserting */}
        {(state === 'transcribing' || state === 'polishing' || state === 'inserting') && (
          <div style={styles.contentRow}>
            <BouncingDots />
            <span style={styles.statusText}>
              {state === 'transcribing' ? '识别中...' :
               state === 'polishing' ? '整理中...' : '插入中...'}
            </span>
          </div>
        )}

        {/* Done */}
        {state === 'done' && (
          <div style={styles.contentRow}>
            <span style={styles.doneText}>{message}</span>
          </div>
        )}

        {/* Cancelled */}
        {state === 'cancelled' && (
          <div style={styles.contentRow}>
            <span style={styles.cancelledText}>{message}</span>
          </div>
        )}

        {/* Error */}
        {state === 'error' && (
          <div style={styles.contentRow}>
            <span style={styles.errorText}>{message}</span>
          </div>
        )}
        </div>
      </div>
    </div>
  );
}

// ─── Styles ────────────────────────────────────────────────────

const styles: Record<string, React.CSSProperties> = {
  root: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'opacity 0.3s ease',
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
  },
  capsuleWrap: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  capsule: {
    position: 'relative',
    width: 220,
    minHeight: 42,
    maxHeight: 110,
    borderRadius: 22,
    backgroundColor: 'rgba(0, 0, 0, 0.75)',
    backdropFilter: 'blur(20px)',
    WebkitBackdropFilter: 'blur(20px)',
    border: '1px solid rgba(255, 255, 255, 0.08)',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '12px 16px',
    color: '#ffffff',
    transition: 'all 0.3s ease',
    boxShadow: '0 8px 32px rgba(0, 0, 0, 0.3)',
  },
  statusPill: {
    position: 'absolute',
    top: -14,
    right: -6,
    display: 'inline-flex',
    alignItems: 'center',
    gap: 8,
    padding: '7px 11px',
    borderRadius: 999,
    backdropFilter: 'blur(18px)',
    WebkitBackdropFilter: 'blur(18px)',
    boxShadow: '0 10px 24px rgba(0, 0, 0, 0.18)',
    border: '1px solid rgba(255, 255, 255, 0.12)',
    animation: 'dictation-pill-float 2.2s ease-in-out infinite',
    zIndex: 2,
  },
  statusPillDotWrap: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 12,
    height: 12,
    flexShrink: 0,
  },
  statusPillDot: {
    width: 6,
    height: 6,
    borderRadius: 999,
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    boxShadow: '0 0 0 3px rgba(255, 255, 255, 0.08)',
  },
  spinner: {
    width: 10,
    height: 10,
    borderRadius: '50%',
    border: '1.6px solid rgba(255, 255, 255, 0.28)',
    borderTopColor: 'rgba(255, 255, 255, 0.95)',
    animation: 'dictation-spin 0.8s linear infinite',
  },
  statusPillText: {
    fontSize: 11,
    fontWeight: 600,
    letterSpacing: '0.01em',
    whiteSpace: 'nowrap' as const,
  },
  translationBadge: {
    position: 'absolute',
    top: -8,
    right: 12,
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    borderRadius: 8,
    padding: '2px 8px',
    fontSize: 10,
    color: 'rgba(255, 255, 255, 0.8)',
    fontWeight: 500,
  },
  contentRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  listeningContent: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 8,
  },
  audioBarsContainer: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 3,
    height: 28,
  },
  audioBar: {
    width: 3,
    minHeight: 4,
    borderRadius: 1.5,
    backgroundColor: '#ffffff',
    opacity: 0.9,
    animation: 'dictation-bar-bounce 0.6s ease-in-out infinite alternate',
  },
  dotsContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: 'rgba(255, 255, 255, 0.7)',
    animation: 'dictation-dot-bounce 0.6s ease-in-out infinite alternate',
  },
  statusText: {
    fontSize: 13,
    fontWeight: 500,
    color: 'rgba(255, 255, 255, 0.9)',
    whiteSpace: 'nowrap' as const,
  },
  elapsedText: {
    fontSize: 13,
    fontWeight: 400,
    color: 'rgba(255, 255, 255, 0.6)',
    fontVariantNumeric: 'tabular-nums' as const,
    minWidth: 32,
    textAlign: 'right' as const,
  },
  hintText: {
    fontSize: 11,
    color: 'rgba(255, 255, 255, 0.4)',
  },
  doneText: {
    fontSize: 13,
    fontWeight: 500,
    color: 'rgba(255, 255, 255, 0.9)',
  },
  cancelledText: {
    fontSize: 13,
    fontWeight: 400,
    color: 'rgba(255, 255, 255, 0.5)',
  },
  errorText: {
    fontSize: 12,
    fontWeight: 400,
    color: '#ff6b6b',
    textAlign: 'center' as const,
    maxWidth: 180,
    lineHeight: 1.4,
  },
};

// ─── Keyframe injection (only once) ────────────────────────────

const styleSheetId = 'dictation-capsule-keyframes';
if (typeof document !== 'undefined' && !document.getElementById(styleSheetId)) {
  const style = document.createElement('style');
  style.id = styleSheetId;
  style.textContent = `
    @keyframes dictation-bar-bounce {
      0% { transform: scaleY(0.4); opacity: 0.5; }
      100% { transform: scaleY(1); opacity: 1; }
    }
    @keyframes dictation-dot-bounce {
      0% { transform: translateY(0); opacity: 0.4; }
      100% { transform: translateY(-4px); opacity: 1; }
    }
    @keyframes dictation-pill-float {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-3px); }
    }
    @keyframes dictation-spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  `;
  document.head.appendChild(style);
}
