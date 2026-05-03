import { useCallback, useState } from 'react';

interface CapsuleEdgeHiddenProps {
  edge: 'left' | 'right' | 'bottom';
}

function PeekIcon(): JSX.Element {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
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

function BorderIcon(): JSX.Element {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
      <path d="M8 4H6a2 2 0 0 0-2 2v2M16 4h2a2 2 0 0 1 2 2v2M8 20H6a2 2 0 0 1-2-2v-2M16 20h2a2 2 0 0 0 2-2v-2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

export function CapsuleEdgeHidden({ edge }: CapsuleEdgeHiddenProps): JSX.Element {
  const [isPeeking, setIsPeeking] = useState(false);

  const handleMouseEnter = useCallback(() => {
    setIsPeeking(true);
  }, []);

  const handleMouseLeave = useCallback(() => {
    setIsPeeking(false);
  }, []);

  const handleClick = useCallback(() => {
    window.acmind?.capsule?.expand?.();
  }, []);

  const horizontal = edge === 'bottom';
  const sizeStyle: React.CSSProperties = isPeeking
    ? horizontal
      ? { width: 96, height: 40, borderRadius: 999 }
      : { width: 56, height: 72, borderRadius: 28 }
    : horizontal
      ? { width: 64, height: 12, borderRadius: 999 }
      : { width: 12, height: 64, borderRadius: 999 };

  return (
    <div
      className={`capsule-edge-hidden edge-${edge} ${isPeeking ? 'is-peeking' : ''}`}
      style={sizeStyle}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      onClick={handleClick}
    >
      {isPeeking ? (
        <div className="capsule-edge-hidden-content">
          <PeekIcon />
          <span>AcMind</span>
        </div>
      ) : (
        <div className="capsule-edge-hidden-rail">
          <BorderIcon />
        </div>
      )}
    </div>
  );
}
