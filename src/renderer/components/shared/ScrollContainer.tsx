import type { ReactNode } from 'react';

interface ScrollContainerProps {
  children: ReactNode;
  className?: string;
  /** Extra bottom padding (in px) to prevent content from being obscured by fixed bottom bars. */
  bottomPadding?: number;
}

/**
 * Scrollable container wrapper.
 * Ensures all pages can scroll (hard requirement from governance docs).
 * min-h-0 is critical for flex children to allow overflow scrolling.
 *
 * `bottomPadding` adds inline padding-bottom so content is never hidden
 * behind a fixed BottomRuntimeBar or similar footer element.
 */
export function ScrollContainer({ children, className, bottomPadding = 64 }: ScrollContainerProps): JSX.Element {
  return (
    <div
      className={`overflow-y-auto flex-1 min-h-0 scroll-smooth-y ${className ?? ''}`}
      style={{ paddingBottom: bottomPadding }}
    >
      {children}
    </div>
  );
}
