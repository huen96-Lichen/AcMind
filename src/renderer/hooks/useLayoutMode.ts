import { useEffect, useState } from 'react';

export type LayoutMode = 'large' | 'medium' | 'compact' | 'small';

/**
 * Detects the current layout mode based on window width.
 *
 * - large:   >= 1440px — full desktop shell with detail panel
 * - medium:  1180-1439px — sidebar visible, main content primary
 * - compact: 980-1179px  — sidebar collapses, dense controls only
 * - small:   < 980px    — single column mode
 */
export function useLayoutMode(): LayoutMode {
  const [mode, setMode] = useState<LayoutMode>(() => {
    if (typeof window === 'undefined') return 'large';
    const w = window.innerWidth;
    if (w >= 1440) return 'large';
    if (w >= 1180) return 'medium';
    if (w >= 980) return 'compact';
    return 'small';
  });

  useEffect(() => {
    const check = () => {
      const w = window.innerWidth;
      if (w >= 1440) setMode('large');
      else if (w >= 1180) setMode('medium');
      else if (w >= 980) setMode('compact');
      else setMode('small');
    };
    check();
    window.addEventListener('resize', check);
    return () => window.removeEventListener('resize', check);
  }, []);

  return mode;
}
