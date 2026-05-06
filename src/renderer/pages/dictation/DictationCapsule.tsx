// ─── DictationCapsule ──────────────────────────────────────────
// Self-contained dictation capsule UI, inspired by OpenLess Capsule.tsx.
// Listens for `dictation:state` IPC events from main process.
// No outbound IPC — all controls via main process hotkeys.

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { AppSettings, DictationCapsulePayload, DictationSessionPhase } from '../../../shared/types';

// ─── Helpers ────────────────────────────────────────────────────

function formatElapsed(ms: number): string {
  const totalSec = Math.floor(ms / 1000);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return min > 0 ? `${min}:${sec.toString().padStart(2, '0')}` : `${sec}`;
}

type SpeechRecognitionResultLike = {
  isFinal: boolean;
  0: { transcript: string };
  length: number;
};

type SpeechRecognitionEventLike = {
  resultIndex: number;
  results: SpeechRecognitionResultLike[];
};

type SpeechRecognitionLike = {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  maxAlternatives: number;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onerror: ((event: { error?: string; message?: string }) => void) | null;
  onend: (() => void) | null;
};

type SpeechRecognitionCtorLike = new () => SpeechRecognitionLike;

function normalizeSpeechLanguage(language?: string | null): string {
  const value = (language ?? '').trim().toLowerCase();
  if (!value) return 'zh-CN';
  if (value === 'zh' || value.startsWith('zh-')) return 'zh-CN';
  if (value === 'en' || value.startsWith('en-')) return 'en-US';
  if (value === 'ja' || value.startsWith('ja-')) return 'ja-JP';
  if (value === 'ko' || value.startsWith('ko-')) return 'ko-KR';
  return (language ?? '').trim() || 'zh-CN';
}

function getSpeechRecognitionCtor(): SpeechRecognitionCtorLike | null {
  const globalWindow = window as Window & {
    SpeechRecognition?: SpeechRecognitionCtorLike;
    webkitSpeechRecognition?: SpeechRecognitionCtorLike;
  };
  return globalWindow.SpeechRecognition ?? globalWindow.webkitSpeechRecognition ?? null;
}

function splitPreviewChunks(text: string): string[] {
  const trimmed = text.trim();
  if (!trimmed) return [];

  if (/\s/.test(trimmed)) {
    const chunks = trimmed.match(/(\S+\s*)/g);
    return chunks?.filter(Boolean) ?? [trimmed];
  }

  const punctuationAware = trimmed.match(/[^，。！？；：、,.!?]+[，。！？；：、,.!?]?/g);
  if (punctuationAware && punctuationAware.length > 1) {
    return punctuationAware;
  }

  const chars = Array.from(trimmed);
  const chunks: string[] = [];
  for (let i = 0; i < chars.length; i += 2) {
    chunks.push(chars.slice(i, i + 2).join(''));
  }
  return chunks.length > 0 ? chunks : [trimmed];
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
    previewText: '',
  });
  const [previewLanguage, setPreviewLanguage] = useState('zh-CN');
  const [livePreviewText, setLivePreviewText] = useState('');
  const [previewStatus, setPreviewStatus] = useState<string | null>(null);
  const [speechRecognitionSupported, setSpeechRecognitionSupported] = useState(false);
  const [animatedPreviewText, setAnimatedPreviewText] = useState('');

  const animFrameRef = useRef<number>(0);
  const previewAnimationTimerRef = useRef<number | null>(null);
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const recognitionRestartTimerRef = useRef<number | null>(null);
  const recognitionShouldRunRef = useRef(false);
  const sessionPhaseRef = useRef<DictationSessionPhase>('idle');
  const livePreviewFinalRef = useRef('');
  const previewRenderSourceRef = useRef('');

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

  useEffect(() => {
    sessionPhaseRef.current = payload.state;
  }, [payload.state]);

  useEffect(() => {
    setSpeechRecognitionSupported(Boolean(getSpeechRecognitionCtor()));
  }, []);

  // Load a reasonable speech-recognition language for preview mode.
  useEffect(() => {
    let cancelled = false;

    void window.acmind.settings.get().then((settings: AppSettings) => {
      if (cancelled) return;
      const lang = settings.dictation?.workingLanguages?.[0] ?? settings.transcription?.apiLanguage ?? navigator.language;
      setPreviewLanguage(normalizeSpeechLanguage(lang));
    }).catch(() => {
      if (!cancelled) {
        setPreviewLanguage(normalizeSpeechLanguage(navigator.language));
      }
    });

    return () => {
      cancelled = true;
    };
  }, []);

  const previewSourceText = useMemo(() => livePreviewText || payload.previewText || '', [livePreviewText, payload.previewText]);

  useEffect(() => {
    const target = previewSourceText.trim();
    if (previewAnimationTimerRef.current) {
      window.clearTimeout(previewAnimationTimerRef.current);
      previewAnimationTimerRef.current = null;
    }

    if (!target) {
      previewRenderSourceRef.current = '';
      setAnimatedPreviewText('');
      return;
    }

    if (speechRecognitionSupported && payload.state === 'listening' && livePreviewText) {
      previewRenderSourceRef.current = target;
      setAnimatedPreviewText(target);
      return;
    }

    if (previewRenderSourceRef.current === target) {
      return;
    }

    previewRenderSourceRef.current = target;

    const chunks = splitPreviewChunks(target);
    if (chunks.length <= 1) {
      setAnimatedPreviewText(target);
      return;
    }

    setAnimatedPreviewText('');
    let index = 0;

    const step = () => {
      index += 1;
      setAnimatedPreviewText(chunks.slice(0, index).join(''));
      if (index < chunks.length) {
        const delay = index < 4 ? 18 : 26;
        previewAnimationTimerRef.current = window.setTimeout(step, delay);
      } else {
        previewAnimationTimerRef.current = null;
      }
    };

    previewAnimationTimerRef.current = window.setTimeout(step, 16);

    return () => {
      if (previewAnimationTimerRef.current) {
        window.clearTimeout(previewAnimationTimerRef.current);
        previewAnimationTimerRef.current = null;
      }
    };
  }, [livePreviewText, payload.previewText, payload.state, previewSourceText, speechRecognitionSupported]);

  const stopRecognition = useCallback((clearPreview = false) => {
    recognitionShouldRunRef.current = false;
    if (recognitionRestartTimerRef.current) {
      window.clearTimeout(recognitionRestartTimerRef.current);
      recognitionRestartTimerRef.current = null;
    }
    if (previewAnimationTimerRef.current) {
      window.clearTimeout(previewAnimationTimerRef.current);
      previewAnimationTimerRef.current = null;
    }

    const recognition = recognitionRef.current;
    recognitionRef.current = null;
    if (recognition) {
      try {
        recognition.onresult = null;
        recognition.onerror = null;
        recognition.onend = null;
        recognition.abort();
      } catch {
        try {
          recognition.stop();
        } catch {
          // ignore
        }
      }
    }

    if (clearPreview) {
      livePreviewFinalRef.current = '';
      setLivePreviewText('');
      setPreviewStatus(null);
      previewRenderSourceRef.current = '';
      setAnimatedPreviewText('');
    }
  }, []);

  const startRecognition = useCallback(async () => {
    if (recognitionRef.current) {
      return;
    }

    const RecognitionCtor = getSpeechRecognitionCtor();
    if (!RecognitionCtor) {
      setPreviewStatus('实时预览不可用');
      return;
    }

    try {
      if (navigator.mediaDevices?.getUserMedia) {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        stream.getTracks().forEach((track) => track.stop());
      }

      const recognition = new RecognitionCtor();
      recognition.lang = previewLanguage;
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;

      recognitionShouldRunRef.current = true;
      livePreviewFinalRef.current = '';
      setLivePreviewText('');
      setPreviewStatus('实时预览中');

      recognition.onresult = (event) => {
        let nextFinal = livePreviewFinalRef.current;
        let nextInterim = '';

        for (let i = event.resultIndex; i < event.results.length; i += 1) {
          const result = event.results[i];
          const transcript = result[0]?.transcript ?? '';
          if (!transcript) continue;
          if (result.isFinal) {
            nextFinal += transcript;
          } else {
            nextInterim += transcript;
          }
        }

        livePreviewFinalRef.current = nextFinal;
        const combined = `${nextFinal}${nextInterim}`.replace(/\s+/g, ' ').trim();
        setLivePreviewText(combined);
        setPreviewStatus('实时预览中');
      };

      recognition.onerror = (event) => {
        const error = event.error ?? event.message ?? 'unknown';
        if (error === 'not-allowed' || error === 'service-not-allowed') {
          setPreviewStatus('请授权浏览器麦克风权限');
        } else if (error === 'no-speech') {
          setPreviewStatus('等待声音...');
        } else {
          setPreviewStatus('实时预览暂不可用');
        }
      };

      recognition.onend = () => {
        recognitionRef.current = null;
        if (!recognitionShouldRunRef.current) {
          return;
        }

        if (sessionPhaseRef.current === 'listening') {
          recognitionRestartTimerRef.current = window.setTimeout(() => {
            if (!recognitionShouldRunRef.current || sessionPhaseRef.current !== 'listening') {
              return;
            }
            void startRecognition();
          }, 180);
        }
      };

      recognitionRef.current = recognition;
      recognition.start();
    } catch (error) {
      recognitionRef.current = null;
      if (error instanceof DOMException && error.name === 'NotAllowedError') {
        setPreviewStatus('请先允许麦克风权限');
      } else {
        setPreviewStatus('实时预览启动失败');
      }
    }
  }, [payload.state, previewLanguage]);

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

  // Start/stop live preview recognition in sync with the dictation session.
  useEffect(() => {
    if (payload.state === 'listening') {
      void startRecognition();
      return () => {
        stopRecognition(false);
      };
    }

    if (payload.state === 'starting') {
      stopRecognition(true);
    }

    if (payload.state === 'idle') {
      stopRecognition(true);
    }

    if (payload.state === 'transcribing' || payload.state === 'polishing' || payload.state === 'inserting') {
      stopRecognition(false);
    }

    return undefined;
  }, [payload.state, startRecognition, stopRecognition]);

  const { state, level, elapsedMs, message, insertedChars, translation } = payload;
  const previewText = speechRecognitionSupported && state === 'listening'
    ? (livePreviewText || previewSourceText)
    : (animatedPreviewText || previewSourceText);
  const hasPreviewText = previewText.trim().length > 0;
  const previewModeLabel = speechRecognitionSupported && state === 'listening' ? '实时草稿' : '渐进预览';

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
            <div style={styles.previewChrome}>
              <div style={styles.previewHeaderRow}>
                <span style={styles.previewModeChip}>{previewModeLabel}</span>
                <span style={styles.previewStatusChip}>{previewStatus ?? (speechRecognitionSupported ? '监听中' : '转写后预览')}</span>
              </div>
              {hasPreviewText ? (
                <div style={styles.previewText}>{previewText}</div>
              ) : (
                <div style={styles.previewPlaceholder}>
                  继续说话，草稿会在这里像输入法一样逐步出现
                </div>
              )}
              <div style={styles.previewFooterRow}>
                <span style={styles.previewHintText}>边说边看 · 松开后完成整理</span>
                <span style={styles.previewCaret}>▍</span>
              </div>
            </div>
            <span style={styles.hintText}>再次按下快捷键结束</span>
          </div>
        )}

        {/* Transcribing / Polishing / Inserting */}
        {(state === 'transcribing' || state === 'polishing' || state === 'inserting') && (
          <div style={styles.listeningContent}>
            <div style={styles.contentRow}>
              <BouncingDots />
              <span style={styles.statusText}>
                {state === 'transcribing' ? '识别中...' :
                 state === 'polishing' ? '整理中...' : '插入中...'}
              </span>
            </div>
            <div style={styles.previewChrome}>
              <div style={styles.previewHeaderRow}>
                <span style={styles.previewModeChip}>渐进预览</span>
                <span style={styles.previewStatusChip}>{previewStatus ?? '正在完善文本'}</span>
              </div>
              {hasPreviewText ? (
                <div style={styles.previewText}>{previewText}</div>
              ) : (
                <div style={styles.previewPlaceholder}>
                  文本整理完成前，这里会逐步显示内容
                </div>
              )}
              <div style={styles.previewFooterRow}>
                <span style={styles.previewHintText}>结果即将插入光标位置</span>
              </div>
            </div>
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
    width: 320,
    minHeight: 42,
    maxHeight: 160,
    borderRadius: 24,
    background:
      'linear-gradient(180deg, rgba(10, 10, 12, 0.84), rgba(12, 12, 16, 0.72))',
    backdropFilter: 'blur(22px) saturate(140%)',
    WebkitBackdropFilter: 'blur(22px) saturate(140%)',
    border: '1px solid rgba(255, 255, 255, 0.10)',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '14px 16px',
    color: '#ffffff',
    transition: 'all 0.3s ease',
    boxShadow: '0 12px 42px rgba(0, 0, 0, 0.34)',
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
  previewChrome: {
    width: '100%',
    padding: '10px 12px',
    borderRadius: 18,
    background: 'linear-gradient(180deg, rgba(255, 255, 255, 0.11), rgba(255, 255, 255, 0.06))',
    border: '1px solid rgba(255, 255, 255, 0.10)',
    boxShadow: 'inset 0 1px 0 rgba(255, 255, 255, 0.08)',
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
    maxHeight: 112,
    overflow: 'auto',
  },
  previewHeaderRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  previewModeChip: {
    fontSize: 10,
    fontWeight: 700,
    letterSpacing: '0.08em',
    textTransform: 'uppercase',
    color: 'rgba(255, 255, 255, 0.84)',
    backgroundColor: 'rgba(255, 255, 255, 0.12)',
    border: '1px solid rgba(255, 255, 255, 0.10)',
    borderRadius: 999,
    padding: '3px 8px',
    flexShrink: 0,
  },
  previewStatusChip: {
    fontSize: 10,
    color: 'rgba(255, 255, 255, 0.60)',
    backgroundColor: 'rgba(15, 23, 42, 0.20)',
    border: '1px solid rgba(255, 255, 255, 0.08)',
    borderRadius: 999,
    padding: '3px 8px',
    flexShrink: 0,
  },
  previewText: {
    fontSize: 14,
    lineHeight: 1.56,
    fontWeight: 500,
    color: '#ffffff',
    wordBreak: 'break-word',
    whiteSpace: 'pre-wrap',
    letterSpacing: '0.01em',
    textShadow: '0 1px 0 rgba(0, 0, 0, 0.15)',
  },
  previewPlaceholder: {
    fontSize: 13,
    lineHeight: 1.55,
    color: 'rgba(255, 255, 255, 0.42)',
    wordBreak: 'break-word',
  },
  previewFooterRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  previewHintText: {
    fontSize: 10,
    color: 'rgba(255, 255, 255, 0.45)',
    letterSpacing: '0.02em',
  },
  previewCaret: {
    fontSize: 14,
    lineHeight: 1,
    color: 'rgba(255, 255, 255, 0.8)',
    animation: 'dictation-caret-blink 1s steps(1, end) infinite',
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
    @keyframes dictation-caret-blink {
      0%, 49% { opacity: 1; }
      50%, 100% { opacity: 0; }
    }
  `;
  document.head.appendChild(style);
}
