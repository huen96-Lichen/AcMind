import { useEffect, useState } from 'react';

export type LayoutMode = 'large' | 'medium' | 'compact' | 'small';

/**
 * Detects the current layout mode based on window width.
 *
 * - large:   >= 1280px — Sidebar(240px) + Main(1fr) + DetailPanel(380px)
 * - medium:  960-1279px — Sidebar(240px) + Main(1fr), detail becomes drawer
 * - compact: 720-959px  — Collapsed sidebar, top entry only
 * - small:   < 720px    — Single column mode
 */
export function useLayoutMode(): LayoutMode {
  const [mode, setMode] = useState<LayoutMode>(() => {
    if (typeof window === 'undefined') return 'large';
    const w = window.innerWidth;
    if (w >= 1280) return 'large';
    if (w >= 960) return 'medium';
    if (w >= 720) return 'compact';
    return 'small';
  });

  useEffect(() => {
    const check = () => {
      const w = window.innerWidth;
      if (w >= 1280) setMode('large');
      else if (w >= 960) setMode('medium');
      else if (w >= 720) setMode('compact');
      else setMode('small');
    };
    check();
    window.addEventListener('resize', check);
    return () => window.removeEventListener('resize', check);
  }, []);

  return mode;
}
