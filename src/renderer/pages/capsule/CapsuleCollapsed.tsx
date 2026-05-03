import { useCallback, useEffect, useRef, useState } from 'react';

type CapsuleVisualState =
  | 'hidden_disabled'
  | 'visible_idle'
  | 'visible_has_content'
  | 'recording_voice'
  | 'capturing_screen'
  | 'saving'
  | 'success'
  | 'error';

interface CapsuleCollapsedProps {
  capsuleState?: CapsuleVisualState;
  pendingCount?: number;
  hasContent?: boolean;
}

const MOVE_THRESHOLD = 6;

function LightbulbIcon({ state }: { state: CapsuleVisualState }): JSX.Element {
  const color = state === 'error' ? '#EF4444' : state === 'success' ? '#16A34A' : 'currentColor';

  if (state === 'recording_voice') {
    return (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" style={{ color }}>
        <rect x="9" y="2.5" width="6" height="11" rx="3" stroke="currentColor" strokeWidth="1.6" />
        <path d="M5 10a7 7 0 0 0 14 0" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
        <path d="M12 17v3.5M8.5 21h7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      </svg>
    );
  }

  if (state === 'capturing_screen') {
    return (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" style={{ color }}>
        <rect x="4" y="4" width="16" height="16" rx="3" stroke="currentColor" strokeWidth="1.6" />
        <path d="M8 4v3M16 4v3M8 17v3M16 17v3M4 8h3M17 8h3M4 16h3M17 16h3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
      </svg>
    );
  }

  if (state === 'success') {
    return (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" style={{ color }}>
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
        <path d="M8 12l2.6 2.8L16.5 8.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }

  if (state === 'error') {
    return (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" style={{ color }}>
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
        <path d="M12 7.8v5" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" />
        <path d="M12 15.9h.01" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
      </svg>
    );
  }

  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" style={{ color }}>
      <path
        d="M12 2.4C8.1 2.4 5 5.5 5 9.4c0 2.4 1.2 4.6 3.1 5.8V17c0 .6.4 1 1 1h5.8c.6 0 1-.4 1-1v-1.8c1.9-1.2 3.1-3.4 3.1-5.8 0-3.9-3.1-7-7-7Z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M10.2 10.4c0-.8.7-1.5 1.5-1.5h.6c.8 0 1.5.7 1.5 1.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
      <path d="M9.1 19h5.8M10.2 21h3.6" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

function ScreenshotIcon(): JSX.Element {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
      <path d="M8 4H6a2 2 0 0 0-2 2v2M16 4h2a2 2 0 0 1 2 2v2M8 20H6a2 2 0 0 1-2-2v-2M16 20h2a2 2 0 0 0 2-2v-2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M9 13l1.8-1.8a2 2 0 0 1 2.8 0L18 15.6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="9.2" cy="9" r="1.2" fill="currentColor" />
    </svg>
  );
}

function CapsuleStateLabel(state: CapsuleVisualState): string {
  switch (state) {
    case 'recording_voice':
      return '录音中';
    case 'capturing_screen':
      return '截图中';
    case 'saving':
      return '收集中';
    case 'success':
      return '已收集';
    case 'error':
      return '出错';
    case 'visible_has_content':
      return 'PinMind';
    case 'visible_idle':
    default:
      return 'PinMind';
  }
}

export function CapsuleCollapsed({
  capsuleState = 'visible_idle',
  pendingCount = 0,
  hasContent = false,
}: CapsuleCollapsedProps): JSX.Element {
  const [isHovered, setIsHovered] = useState(false);
  const [isPressed, setIsPressed] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const dragRef = useRef<{
    startScreenX: number;
    startScreenY: number;
    didMove: boolean;
  } | null>(null);
  const clickTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const toneState: CapsuleVisualState = capsuleState;
  const hasBadge = pendingCount > 0;

  const handleExpand = useCallback(() => {
    if (window.pinmind?.capsule?.expand) {
      window.pinmind.capsule.expand();
    }
  }, []);

  const handleDoubleClick = useCallback(() => {
    if (clickTimerRef.current) {
      clearTimeout(clickTimerRef.current);
      clickTimerRef.current = null;
    }
    void window.pinmind?.capture?.takeScreenshot?.();
  }, []);

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    setIsPressed(true);
    dragRef.current = {
      startScreenX: e.screenX,
      startScreenY: e.screenY,
      didMove: false,
    };

    if (window.pinmind?.capsule?.startDrag) {
      window.pinmind.capsule.startDrag(e.screenX, e.screenY);
    }

    const onMove = (ev: MouseEvent) => {
      if (!dragRef.current) return;
      const dx = Math.abs(ev.screenX - dragRef.current.startScreenX);
      const dy = Math.abs(ev.screenY - dragRef.current.startScreenY);
      if (dx >= MOVE_THRESHOLD || dy >= MOVE_THRESHOLD) {
        dragRef.current.didMove = true;
        setIsDragging(true);
        if (window.pinmind?.capsule?.dragMove) {
          window.pinmind.capsule.dragMove(
            ev.screenX - dragRef.current.startScreenX,
            ev.screenY - dragRef.current.startScreenY,
          );
        }
      }
    };

    const onUp = () => {
      setIsPressed(false);
      const didMove = dragRef.current?.didMove ?? false;
      dragRef.current = null;
      setIsDragging(false);

      if (!didMove) {
        if (clickTimerRef.current) {
          clearTimeout(clickTimerRef.current);
          clickTimerRef.current = null;
          handleDoubleClick();
        } else {
          clickTimerRef.current = setTimeout(() => {
            clickTimerRef.current = null;
            handleExpand();
          }, 200);
        }
      }

      if (window.pinmind?.capsule?.endDrag) {
        window.pinmind.capsule.endDrag();
      }

      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
    };

    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  }, [handleDoubleClick, handleExpand]);

  useEffect(() => {
    return () => {
      if (clickTimerRef.current) {
        clearTimeout(clickTimerRef.current);
      }
    };
  }, []);

  const showBadge = hasBadge;

  return (
    <div
      className={`capsule-collapsed capsule-state-${toneState} ${isHovered ? 'is-hovered' : ''} ${isPressed ? 'is-pressed' : ''} ${isDragging ? 'is-dragging' : ''}`}
      onMouseDown={handleMouseDown}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div className="capsule-collapsed-core">
        <div className="capsule-collapsed-icon-wrap">
          <LightbulbIcon state={toneState} />
          {toneState === 'capturing_screen' && (
            <div className="capsule-collapsed-accent">
              <ScreenshotIcon />
            </div>
          )}
        </div>

        <div className="capsule-collapsed-copy">
          <div className="capsule-collapsed-label">
            {CapsuleStateLabel(toneState)}
          </div>
        </div>

        {showBadge && (
          <div className="capsule-badge">
            {pendingCount > 9 ? '9+' : pendingCount}
          </div>
        )}
      </div>

      {hasContent && !showBadge && <div className="capsule-dot" />}
    </div>
  );
}
