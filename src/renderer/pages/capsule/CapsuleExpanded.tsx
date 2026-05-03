import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { VoiceCapturePanel } from './VoiceCapturePanel';
import './capsule.css';

type CollectMode = 'text' | 'link' | 'screenshot' | 'voice';

interface CapsuleExpandedProps {
  capsuleState?: 'expanded' | 'recording_voice' | 'capturing_screen' | 'saving' | 'success' | 'error';
}

const MODES: Array<{ id: CollectMode; label: string; desc: string }> = [
  { id: 'text', label: '文字', desc: '写下想法' },
  { id: 'link', label: '链接', desc: '粘贴网页' },
  { id: 'screenshot', label: '截图', desc: '截取屏幕' },
  { id: 'voice', label: '语音', desc: '说出来' },
];

function ModeIcon({ mode }: { mode: CollectMode }): JSX.Element {
  switch (mode) {
    case 'link':
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7.1-7.1l-1.7 1.7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          <path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7.1 7.1l1.7-1.7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
      );
    case 'screenshot':
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <path d="M8 4H6a2 2 0 0 0-2 2v2M16 4h2a2 2 0 0 1 2 2v2M8 20H6a2 2 0 0 1-2-2v-2M16 20h2a2 2 0 0 0 2-2v-2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
          <path d="M9 13l1.8-1.8a2 2 0 0 1 2.8 0L18 15.6" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
          <circle cx="9.2" cy="9" r="1.2" fill="currentColor" />
        </svg>
      );
    case 'voice':
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <rect x="9" y="2.5" width="6" height="11" rx="3" stroke="currentColor" strokeWidth="1.6" />
          <path d="M5 10a7 7 0 0 0 14 0" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          <path d="M12 17v3.5M8.5 21h7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
      );
    case 'text':
    default:
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
          <path d="M14 2v6h6M16 13H8M16 17H8M10 9H8" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
  }
}

function ScreenshotIcon(): JSX.Element {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
      <path d="M8 4H6a2 2 0 0 0-2 2v2M16 4h2a2 2 0 0 1 2 2v2M8 20H6a2 2 0 0 1-2-2v-2M16 20h2a2 2 0 0 0 2-2v-2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
      <path d="M9 13l1.8-1.8a2 2 0 0 1 2.8 0L18 15.6" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="9.2" cy="9" r="1.2" fill="currentColor" />
    </svg>
  );
}

function StatusIcon({ state }: { state: NonNullable<CapsuleExpandedProps['capsuleState']> }): JSX.Element {
  if (state === 'success') {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
        <path d="M8 12l2.6 2.8L16.5 8.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }

  if (state === 'error') {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
        <path d="M12 7.8v5" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
        <path d="M12 15.9h.01" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
      </svg>
    );
  }

  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" opacity="0.35" />
      <path d="M12 2v5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

export function CapsuleExpanded({ capsuleState = 'expanded' }: CapsuleExpandedProps): JSX.Element {
  const [mode, setMode] = useState<CollectMode>('text');
  const [textValue, setTextValue] = useState('');
  const [linkValue, setLinkValue] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [inlineMessage, setInlineMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const mountedRef = useRef(true);

  useEffect(() => {
    return () => {
      mountedRef.current = false;
    };
  }, []);

  const headerTitle = useMemo(() => '快速收集', []);
  const headerSubtitle = useMemo(() => '把想法先放进来', []);

  const collapseCapsule = useCallback(() => {
    window.pinmind?.capsule?.collapse?.();
  }, []);

  const showMessage = useCallback((type: 'success' | 'error', text: string) => {
    setInlineMessage({ type, text });
    window.setTimeout(() => {
      setInlineMessage((current) => (current?.text === text ? null : current));
    }, 1600);
  }, []);

  const collectText = useCallback(async () => {
    const content = textValue.trim();
    if (!content) {
      showMessage('error', '先写一点内容');
      return;
    }

    setSubmitting(true);
    try {
      await window.pinmind.captureItems.create({
        type: 'text',
        title: content.split('\n')[0]?.slice(0, 50) || '文字内容',
        rawText: content,
      });
      showMessage('success', '已收集到收集箱');
      window.setTimeout(() => collapseCapsule(), 700);
      setTextValue('');
    } catch (error) {
      showMessage('error', error instanceof Error ? error.message : '收集失败');
    } finally {
      setSubmitting(false);
    }
  }, [collapseCapsule, showMessage, textValue]);

  const collectLink = useCallback(async () => {
    const content = linkValue.trim();
    if (!content) {
      showMessage('error', '先粘贴链接');
      return;
    }

    setSubmitting(true);
    try {
      await window.pinmind.captureItems.create({
        type: 'link',
        title: '网页链接',
        rawText: content,
        sourceUrl: content,
      });
      showMessage('success', '已收集到收集箱');
      window.setTimeout(() => collapseCapsule(), 700);
      setLinkValue('');
    } catch (error) {
      showMessage('error', error instanceof Error ? error.message : '收集失败');
    } finally {
      setSubmitting(false);
    }
  }, [collapseCapsule, linkValue, showMessage]);

  const collectScreenshot = useCallback(async () => {
    setSubmitting(true);
    try {
      collapseCapsule();
      window.setTimeout(async () => {
        try {
          await window.pinmind.capture.takeScreenshot();
        } catch (error) {
          if (mountedRef.current) {
            showMessage('error', error instanceof Error ? error.message : '截图失败');
          }
        }
      }, 250);
    } catch (error) {
      if (mountedRef.current) {
        setSubmitting(false);
        showMessage('error', error instanceof Error ? error.message : '截图失败');
      }
    }
  }, [collapseCapsule, mountedRef, showMessage]);

  const handleCollect = useCallback(() => {
    if (mode === 'text') {
      void collectText();
      return;
    }
    if (mode === 'link') {
      void collectLink();
      return;
    }
    if (mode === 'screenshot') {
      void collectScreenshot();
      return;
    }
    if (mode === 'voice') {
      return;
    }
  }, [collectLink, collectScreenshot, collectText, mode]);

  const handleVoiceComplete = useCallback(async (transcribedText: string) => {
    setSubmitting(true);
    try {
      await window.pinmind.captureItems.create({
        type: 'text',
        title: transcribedText.split('\n')[0]?.slice(0, 50) || '语音内容',
        rawText: transcribedText,
      });
      showMessage('success', '已收集到收集箱');
      window.setTimeout(() => collapseCapsule(), 700);
    } catch (error) {
      showMessage('error', error instanceof Error ? error.message : '收集失败');
    } finally {
      setSubmitting(false);
    }
  }, [collapseCapsule, showMessage]);

  const handleVoiceCancel = useCallback(() => {
    setMode('text');
  }, []);

  const handleLater = useCallback(() => {
    collapseCapsule();
  }, [collapseCapsule]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      void handleCollect();
    }
  }, [handleCollect]);

  const stateClass = capsuleState === 'saving'
    ? 'state-saving'
    : capsuleState === 'success'
      ? 'state-success'
      : capsuleState === 'error'
        ? 'state-error'
        : capsuleState === 'recording_voice'
          ? 'state-recording'
          : capsuleState === 'capturing_screen'
            ? 'state-capturing'
            : 'state-idle';

  return (
    <div className={`capsule-panel capsule-panel-collect ${stateClass}`}>
      <div className="capsule-header capsule-header-collect">
        <div className="capsule-header-main">
          <div className="panel-title-row">
            <span className="capsule-title-mark" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                <path d="M12 2.4C8.1 2.4 5 5.5 5 9.4c0 2.4 1.2 4.6 3.1 5.8V17c0 .6.4 1 1 1h5.8c.6 0 1-.4 1-1v-1.8c1.9-1.2 3.1-3.4 3.1-5.8 0-3.9-3.1-7-7-7Z" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
                <path d="M10.2 10.4c0-.8.7-1.5 1.5-1.5h.6c.8 0 1.5.7 1.5 1.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
              </svg>
            </span>
            <div className="min-w-0">
              <div className="panel-title">{headerTitle}</div>
              <div className="panel-subtitle">{headerSubtitle}</div>
            </div>
          </div>
        </div>

        <button type="button" className="capsule-icon-btn" onClick={collapseCapsule} aria-label="关闭">
          ×
        </button>
      </div>

      <div className="capsule-collect-body">
        <div className="capsule-mode-grid capsule-mode-grid-collect">
          {MODES.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`capsule-mode-card capsule-mode-card-collect ${mode === item.id ? 'active' : ''}`}
              onClick={() => setMode(item.id)}
              disabled={submitting}
            >
              <span className="capsule-mode-icon">
                <ModeIcon mode={item.id} />
              </span>
              <span className="capsule-mode-label">{item.label}</span>
              <span className="capsule-mode-desc">{item.desc}</span>
            </button>
          ))}
        </div>

        {mode === 'text' && (
          <div className="capsule-input-shell capsule-input-shell-collect">
            <textarea
              className="quick-input capsule-text-fragment-editor"
              value={textValue}
              onChange={(e) => setTextValue(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="写下想法，或粘贴内容..."
              autoFocus
            />
          </div>
        )}

        {mode === 'link' && (
          <div className="capsule-input-shell capsule-input-shell-collect">
            <input
              className="capsule-url-input capsule-link-input"
              type="text"
              value={linkValue}
              onChange={(e) => setLinkValue(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="粘贴网页链接..."
              autoFocus
            />
          </div>
        )}

        {mode === 'screenshot' && (
          <div className="capsule-screenshot-shell">
            <div className="capsule-screenshot-hero">
              <ScreenshotIcon />
              <span>截下这一屏，先放进来</span>
            </div>
            <button type="button" className="capsule-screenshot-btn" onClick={() => void collectScreenshot()} disabled={submitting}>
              {submitting ? '处理中…' : '开始截图'}
            </button>
          </div>
        )}

        {mode === 'voice' && (
          <VoiceCapturePanel
            onComplete={handleVoiceComplete}
            onCancel={handleVoiceCancel}
          />
        )}

        {mode !== 'voice' && (
          <div className="capsule-actions-row capsule-actions-row-collect">
            <button
              type="button"
              className="capsule-secondary-action"
              disabled={submitting}
              onClick={handleLater}
            >
              稍后整理
            </button>
            <button
              type="button"
              className="primary-action"
              disabled={submitting || ((mode === 'text' || mode === 'link') && !(mode === 'text' ? textValue.trim() : linkValue.trim()))}
              onClick={() => void handleCollect()}
            >
              {submitting ? '收集中…' : mode === 'screenshot' ? '开始截图' : '收集'}
            </button>
          </div>
        )}
      </div>

      {inlineMessage && (
        <div className={`capsule-collect-toast ${inlineMessage.type}`}>
          <StatusIcon state={inlineMessage.type === 'success' ? 'success' : 'error'} />
          <span>{inlineMessage.text}</span>
        </div>
      )}
    </div>
  );
}
