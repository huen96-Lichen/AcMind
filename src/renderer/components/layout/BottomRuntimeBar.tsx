/**
 * @deprecated BottomRuntimeBar has been removed from the layout in V2.0.
 * Status information has been migrated to TopBar.
 * This file is kept for reference only and should not be imported.
 */
import { PinStackIcon } from '../../design-system/icons';
import type { ShellSnapshot } from '../../hooks/useShellSnapshot';

interface BottomRuntimeBarProps {
  snapshot: ShellSnapshot;
}

export function BottomRuntimeBar({ snapshot }: BottomRuntimeBarProps): JSX.Element {
  const settings = snapshot.settings;
  const storageRoot = settings?.storageRoot ?? '~/Documents/AcMind';

  return (
    <footer
      className="acmind-runtime-bar flex items-center gap-3 px-4"
      style={{
        height: '44px',
        background: 'var(--pm-bg-bottombar)',
      }}
    >
      <RuntimeItem label="数据目录" value={shortenPath(storageRoot)} tone="neutral" />

      <span
        className="shrink-0"
        style={{
          width: '1px',
          height: '14px',
          background: 'rgba(31,41,51,0.08)',
        }}
      />

      <div className="ml-auto flex items-center gap-1.5 shrink-0" style={{ fontSize: '11px', color: 'var(--pm-status-success)' }}>
        <PinStackIcon name="help" size={11} />
        <span>本地数据已保护</span>
      </div>
    </footer>
  );
}

function RuntimeItem({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: 'neutral' | 'muted' | 'success' | 'warning' | 'danger';
}): JSX.Element {
  const dotColor: Record<string, string> = {
    neutral: 'text-[color:var(--pm-text-tertiary)]',
    muted: 'text-[color:var(--pm-text-disabled,#b8c0cc)]',
    success: 'text-[color:var(--pm-status-success)]',
    warning: 'text-[color:var(--pm-status-warning)]',
    danger: 'text-[color:var(--pm-status-danger)]',
  };

  return (
    <div
      className="inline-flex items-center gap-[5px] shrink-0"
      style={{ fontSize: '11px', color: 'var(--text-body)', padding: '0 8px' }}
    >
      <span className={dotColor[tone]} style={{ fontSize: '6px' }}>●</span>
      <span style={{ color: 'var(--text-muted)' }}>{label}:</span>
      <span>{value}</span>
    </div>
  );
}

function shortenPath(value: string): string {
  if (!value) return '~/Documents/AcMind';
  if (value.startsWith('~/')) return value;
  if (value.startsWith('/Users/')) {
    const parts = value.split('/');
    return '~/' + parts.slice(3).join('/');
  }
  return value;
}
