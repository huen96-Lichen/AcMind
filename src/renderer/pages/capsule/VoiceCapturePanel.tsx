// ═══════════════════════════════════════════════════════════════════════════════
// PinMind — VoiceCapturePanel Component
// 语音收集面板：录音后交给主进程导入并转写，完成后回填文本
// ═══════════════════════════════════════════════════════════════════════════════

import { useCallback, useEffect, useRef, useState } from 'react';

type VoicePhase = 'idle' | 'recording' | 'transcribing' | 'result';

interface VoiceCapturePanelProps {
  onComplete: (text: string) => void;
  onCancel: () => void;
}

interface VoiceImportResult {
  success: boolean;
  originalId?: string;
  captureItemId?: string;
  error?: string;
}

interface VoiceTranscriptionStatus {
  transcriptStatus: string;
  transcriptText?: string;
  jobId?: string;
  error?: string;
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}

function pickMimeType(): string {
  if (typeof MediaRecorder === 'undefined') return 'audio/webm';
  if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) return 'audio/webm;codecs=opus';
  if (MediaRecorder.isTypeSupported('audio/webm')) return 'audio/webm';
  if (MediaRecorder.isTypeSupported('audio/ogg;codecs=opus')) return 'audio/ogg;codecs=opus';
  if (MediaRecorder.isTypeSupported('audio/ogg')) return 'audio/ogg';
  return 'audio/webm';
}

function mimeToLabel(mimeType: string): string {
  if (mimeType.includes('ogg')) return 'ogg';
  if (mimeType.includes('wav')) return 'wav';
  return 'webm';
}

export function VoiceCapturePanel({ onComplete, onCancel }: VoiceCapturePanelProps): JSX.Element {
  const [phase, setPhase] = useState<VoicePhase>('idle');
  const [transcript, setTranscript] = useState('');
  const [interimText, setInterimText] = useState('');
  const [duration, setDuration] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [statusText, setStatusText] = useState('点击开始录音');

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const recordedChunksRef = useRef<BlobPart[]>([]);
  const timerRef = useRef<number | null>(null);
  const startTimeRef = useRef<number>(0);
  const mountedRef = useRef(true);
  const activeRequestRef = useRef(0);
  const discardRecordingRef = useRef(false);

  useEffect(() => {
    return () => {
      mountedRef.current = false;
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        try {
          mediaRecorderRef.current.stop();
        } catch {
          // ignore
        }
      }
      mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
    };
  }, []);

  const stopTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const resetToIdle = useCallback((message = '点击开始录音') => {
    setPhase('idle');
    setTranscript('');
    setInterimText('');
    setDuration(0);
    setStatusText(message);
    setError(null);
  }, []);

  const finalizeTranscription = useCallback(async (blob: Blob, mimeType: string) => {
    const requestId = ++activeRequestRef.current;
    setPhase('transcribing');
    setStatusText('正在转写内容…');

    try {
      const arrayBuffer = await blob.arrayBuffer();
      const result = await window.pinmind.voice.importAudioBuffer({
        data: arrayBuffer,
        mimeType,
        title: '语音收集',
      }) as VoiceImportResult;

      if (!mountedRef.current || requestId !== activeRequestRef.current) {
        return;
      }

      if (!result.success) {
        throw new Error(result.error || '语音导入失败');
      }

      const captureItemId = result.captureItemId;
      if (!captureItemId) {
        throw new Error('未返回转写任务');
      }

      const deadline = Date.now() + 20000;
      let latestText = '';

      while (Date.now() < deadline) {
        const status = await window.pinmind.voice.getTranscriptionStatus(captureItemId) as VoiceTranscriptionStatus;
        if (!mountedRef.current || requestId !== activeRequestRef.current) {
          return;
        }

        if (status.transcriptText && status.transcriptText.trim().length > 0) {
          latestText = status.transcriptText.trim();
          break;
        }

        if (status.transcriptStatus === 'failed' || status.transcriptStatus === 'unsupported') {
          throw new Error(status.error || '当前环境没有可用的转写引擎');
        }

        await new Promise((resolve) => window.setTimeout(resolve, 1200));
      }

      if (!latestText) {
        const status = await window.pinmind.voice.getTranscriptionStatus(captureItemId) as VoiceTranscriptionStatus;
        latestText = (status.transcriptText || '').trim();
      }

      if (!latestText) {
        throw new Error('没有识别出可用内容');
      }

      if (!mountedRef.current || requestId !== activeRequestRef.current) {
        return;
      }

      setTranscript(latestText);
      setInterimText('');
      setPhase('result');
      setStatusText('内容已转写，确认后收集');
    } catch (finalError) {
      if (!mountedRef.current || requestId !== activeRequestRef.current) {
        return;
      }
      setPhase('idle');
      setError(finalError instanceof Error ? finalError.message : '语音处理失败');
      setStatusText('语音处理失败');
    }
  }, []);

  const startRecording = useCallback(async () => {
    setError(null);
    setTranscript('');
    setInterimText('');
    setDuration(0);

    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
      setError('当前环境不支持麦克风录音');
      setStatusText('当前环境不支持麦克风录音');
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mimeType = pickMimeType();
      const recorder = new MediaRecorder(stream, { mimeType });
      discardRecordingRef.current = false;
      mediaStreamRef.current = stream;
      mediaRecorderRef.current = recorder;
      recordedChunksRef.current = [];
      startTimeRef.current = Date.now();
      setPhase('recording');
      setStatusText('正在收集语音…');
      timerRef.current = window.setInterval(() => {
        setDuration((Date.now() - startTimeRef.current) / 1000);
      }, 200);

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          recordedChunksRef.current.push(event.data);
        }
      };

      recorder.onstop = () => {
        stopTimer();
        const chunks = recordedChunksRef.current.slice();
        recordedChunksRef.current = [];
        mediaRecorderRef.current = null;
        mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
        mediaStreamRef.current = null;

        if (discardRecordingRef.current) {
          discardRecordingRef.current = false;
          resetToIdle();
          return;
        }

        const blob = new Blob(chunks, { type: mimeType });
        if (blob.size === 0) {
          resetToIdle('没有录到声音');
          setError('没有录到声音');
          return;
        }

        void finalizeTranscription(blob, mimeType);
      };

      recorder.onerror = () => {
        stopTimer();
        mediaRecorderRef.current = null;
        mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
        mediaStreamRef.current = null;
        resetToIdle('录音失败');
        setError('录音失败，请检查麦克风权限');
      };

      recorder.start(500);
    } catch (err) {
      stopTimer();
      mediaRecorderRef.current = null;
      mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
      mediaStreamRef.current = null;
      setError(err instanceof Error ? err.message : '无法启动麦克风');
      setStatusText('无法启动麦克风');
      setPhase('idle');
    }
  }, [finalizeTranscription, resetToIdle, stopTimer]);

  const stopRecording = useCallback(() => {
    const recorder = mediaRecorderRef.current;
    if (!recorder || recorder.state === 'inactive') {
      return;
    }

    setStatusText('停止后正在转写…');
    try {
      recorder.stop();
    } catch {
      stopTimer();
      mediaRecorderRef.current = null;
      mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
      mediaStreamRef.current = null;
      resetToIdle('录音停止失败');
    }
  }, [resetToIdle, stopTimer]);

  const handleCancel = useCallback(() => {
    activeRequestRef.current += 1;
    discardRecordingRef.current = true;
    stopTimer();
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      try {
        mediaRecorderRef.current.stop();
      } catch {
        // ignore
      }
    }
    mediaRecorderRef.current = null;
    mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
    mediaStreamRef.current = null;
    resetToIdle();
    onCancel();
  }, [onCancel, resetToIdle, stopTimer]);

  const handleConfirm = useCallback(() => {
    const finalText = transcript.trim();
    if (!finalText) {
      setError('先收集到一段可用内容');
      return;
    }
    onComplete(finalText);
  }, [onComplete, transcript]);

  const handleRerecord = useCallback(() => {
    activeRequestRef.current += 1;
    discardRecordingRef.current = false;
    resetToIdle();
  }, [resetToIdle]);

  const handleTextChange = useCallback((e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setTranscript(e.target.value);
    setInterimText('');
  }, []);

  const displayText = `${transcript}${interimText}`;
  const hasText = displayText.trim().length > 0;

  return (
    <div className="voice-capture-panel">
      <div className="voice-panel-header">
        <button type="button" className="capsule-icon-btn" onClick={handleCancel} aria-label="返回">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <path d="M15 18l-6-6 6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
        <div className="voice-panel-title">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <rect x="9" y="2" width="6" height="12" rx="3" stroke="currentColor" strokeWidth="1.5" />
            <path d="M5 10a7 7 0 0014 0" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            <path d="M12 17v4M8 21h8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
          <span>语音收集</span>
        </div>
        <div style={{ width: 28 }} />
      </div>

      {error && (
        <div className="voice-error">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.5" />
            <path d="M12 8v4M12 16h.01" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
          <span>{error}</span>
          <button type="button" onClick={() => setError(null)}>×</button>
        </div>
      )}

      {phase === 'idle' && (
        <div className="voice-phase-idle">
          <button type="button" className="voice-record-btn" onClick={startRecording}>
            <div className="voice-record-btn-inner">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
                <rect x="9" y="2" width="6" height="12" rx="3" />
                <path d="M5 10a7 7 0 0014 0" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" />
                <path d="M12 17v4M8 21h8" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" />
              </svg>
            </div>
          </button>
          <span className="voice-record-hint">{statusText}</span>
        </div>
      )}

      {phase === 'recording' && (
        <div className="voice-phase-recording">
          <div className="voice-recording-indicator">
            <div className="voice-recording-dot" />
            <span>{statusText}</span>
          </div>
          <div className="voice-recording-timer">{formatDuration(duration)}</div>

          {displayText && (
            <div
              style={{
                padding: '8px 14px',
                margin: '0 14px',
                borderRadius: 12,
                background: 'rgba(255, 106, 26, 0.06)',
                border: '1px solid rgba(255, 106, 26, 0.12)',
                fontSize: 13,
                lineHeight: 1.6,
                color: 'var(--pm-capsule-text-primary)',
                maxHeight: 120,
                overflow: 'auto',
                flex: 1,
                minHeight: 0,
              }}
            >
              {transcript}
              <span style={{ color: 'var(--pm-capsule-text-tertiary)' }}>{interimText}</span>
            </div>
          )}

          <div className="voice-recording-actions">
            <button type="button" className="voice-cancel-btn" onClick={handleCancel}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
              <span>取消</span>
            </button>
            <button type="button" className="voice-stop-btn" onClick={stopRecording}>
              <div className="voice-stop-btn-inner" />
            </button>
          </div>
        </div>
      )}

      {phase === 'transcribing' && (
        <div className="voice-phase-transcribing">
          <div className="voice-transcribing-spinner" />
          <div className="voice-transcribing-text">{statusText}</div>
          <div className="voice-recording-timer">{formatDuration(duration)}</div>
          <div style={{ fontSize: 12, color: 'var(--pm-capsule-text-tertiary)', textAlign: 'center', lineHeight: 1.5 }}>
            {mimeToLabel(pickMimeType())} 音频已提交，正在整理文本
          </div>
        </div>
      )}

      {phase === 'result' && (
        <div className="voice-phase-result">
          <div className="voice-result-header">
            <span className="voice-result-label">内容预览</span>
            <span className="voice-result-meta">{formatDuration(duration)}</span>
          </div>
          <textarea
            className="voice-result-textarea"
            value={transcript}
            onChange={handleTextChange}
            placeholder="未识别到内容…"
          />
          <div className="voice-result-actions">
            <button type="button" className="voice-rerecord-btn" onClick={handleRerecord}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path d="M1 4v6h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                <path d="M3.51 15a9 9 0 105.64-12.36L1 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              重录
            </button>
            <button
              type="button"
              className="voice-confirm-btn"
              onClick={handleConfirm}
              disabled={!hasText}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path d="M20 6L9 17l-5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              使用这段内容
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default VoiceCapturePanel;
