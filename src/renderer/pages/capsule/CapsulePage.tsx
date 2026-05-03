import { useEffect, useState } from 'react';
import { CapsuleCollapsed } from './CapsuleCollapsed';
import { CapsuleExpanded } from './CapsuleExpanded';
import { CapsuleEdgeHidden } from './CapsuleEdgeHidden';
import type { CapsuleStatus } from '../../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

type CapsuleState =
  | 'hidden_disabled'
  | 'visible_idle'
  | 'visible_has_content'
  | 'edge_hidden'
  | 'edge_peek'
  | 'expanded'
  | 'recording_voice'
  | 'capturing_screen'
  | 'saving'
  | 'success'
  | 'error';

interface CapsuleStatePayload {
  state: string;
  edge?: string;
  pendingCount?: number;
}

// ─── CapsulePage ─────────────────────────────────────────────────────────────

/**
 * Main capsule page component. Renders the appropriate capsule state
 * (collapsed, expanded, or edge-hidden) based on state from the main process.
 *
 * This component is loaded via capsule.html (a dedicated transparent window),
 * NOT the main App.tsx router. It does NOT import global styles.css.
 */
export function CapsulePage(): JSX.Element {
  const [capsuleState, setCapsuleState] = useState<CapsuleState>('visible_idle');
  const [edge, setEdge] = useState<'left' | 'right' | 'bottom'>('right');
  const [pendingCount, setPendingCount] = useState(0);
  const [capsuleStatus, setCapsuleStatus] = useState<CapsuleStatus | null>(null);

  // ── Force transparent background on html/body/#root ──
  useEffect(() => {
    const html = document.documentElement;
    const body = document.body;
    const root = document.getElementById('root');

    html.style.background = 'transparent';
    html.style.backgroundColor = 'transparent';
    body.style.background = 'transparent';
    body.style.backgroundColor = 'transparent';
    if (root) {
      root.style.background = 'transparent';
      root.style.backgroundColor = 'transparent';
    }
  }, []);

  // ── Listen for state changes from main process ──
  useEffect(() => {
    const capsule = (window as unknown as { acmind?: { capsule?: { onStateChanged?: (cb: (p: CapsuleStatePayload) => void) => () => void } } }).acmind?.capsule;
    if (capsule?.onStateChanged) {
      const unsubscribe = capsule.onStateChanged((payload: CapsuleStatePayload) => {
        setCapsuleState(payload.state as CapsuleState);
        if (payload.edge) {
          setEdge(payload.edge as 'left' | 'right' | 'bottom');
        }
        if (payload.pendingCount !== undefined) {
          setPendingCount(payload.pendingCount);
        }
      });
      return unsubscribe;
    }
    return undefined;
  }, []);

  // ── Load pending count + capsule status ──
  useEffect(() => {
    let cancelled = false;

    const loadData = async () => {
      try {
        const items = await window.acmind.sourceItems.list({ status: 'inbox' });
        if (!cancelled) {
          setPendingCount(items.length);
        }
      } catch {
        if (!cancelled) {
          setPendingCount(0);
        }
      }

      // Batch 4: Load capsule status
      try {
        const status = await (window as unknown as { acmind: { capsule: { getStatus: () => Promise<CapsuleStatus> } } }).acmind.capsule.getStatus();
        if (!cancelled) {
          setCapsuleStatus(status);
        }
      } catch {
        // ignore - capsule status is best-effort
      }
    };

    void loadData();

    const unsubscribe = window.acmind.onRecordsChanged(() => {
      void loadData();
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, []);

  // ── Render based on state ──
  switch (capsuleState) {
    case 'edge_hidden':
    case 'edge_peek':
      return <CapsuleEdgeHidden edge={edge} />;

    case 'expanded':
    case 'recording_voice':
    case 'capturing_screen':
    case 'saving':
    case 'success':
    case 'error':
      return <CapsuleExpanded capsuleState={capsuleState} />;

    case 'visible_idle':
    case 'visible_has_content':
    default:
      return (
        <CapsuleCollapsed
          capsuleState={capsuleState}
          pendingCount={pendingCount}
          hasContent={capsuleState === 'visible_has_content'}
        />
      );
  }
}
