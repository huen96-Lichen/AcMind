import { useEffect, useMemo, useState } from 'react';
import { Button } from '../../../design-system/components';

interface HotkeyRecorderProps {
  value: string;
  defaultValue: string;
  onCommit: (value: string) => Promise<void> | void;
}

const MODIFIER_ORDER = ['CommandOrControl', 'Alt', 'Shift'] as const;

const SPECIAL_KEYS: Record<string, string> = {
  ':': 'Semicolon',
  ';': 'Semicolon',
  '+': 'Plus',
  '=': 'Equal',
  '-': 'Minus',
  ',': 'Comma',
  '.': 'Period',
  '/': 'Slash',
  '\\': 'Backslash',
  '[': 'BracketLeft',
  ']': 'BracketRight',
  '`': 'Backquote',
  ' ': 'Space',
  Escape: 'Escape',
  Esc: 'Escape',
  Enter: 'Enter',
  Tab: 'Tab',
  Backspace: 'Backspace',
  Delete: 'Delete',
  Insert: 'Insert',
  Home: 'Home',
  End: 'End',
  PageUp: 'PageUp',
  PageDown: 'PageDown',
  ArrowUp: 'Up',
  ArrowDown: 'Down',
  ArrowLeft: 'Left',
  ArrowRight: 'Right',
  MediaPlayPause: 'MediaPlayPause',
  MediaStop: 'MediaStop',
  MediaNextTrack: 'MediaNextTrack',
  MediaPreviousTrack: 'MediaPreviousTrack',
};

function normalizeAcceleratorFromEvent(event: KeyboardEvent): string | null {
  const modifiers: string[] = [];

  if (event.metaKey || event.ctrlKey) {
    modifiers.push('CommandOrControl');
  }
  if (event.altKey) {
    modifiers.push('Alt');
  }
  if (event.shiftKey) {
    modifiers.push('Shift');
  }

  const rawKey = event.key;
  if (!rawKey || ['Shift', 'Control', 'Alt', 'Meta', 'AltGraph'].includes(rawKey)) {
    return null;
  }

  const key = SPECIAL_KEYS[rawKey] ?? (rawKey.length === 1 ? rawKey.toUpperCase() : rawKey);
  if (!key) {
    return null;
  }

  const dedupedModifiers = MODIFIER_ORDER.filter((modifier) => modifiers.includes(modifier));
  if (dedupedModifiers.length === 0) {
    return null;
  }

  return [...dedupedModifiers, key].join('+');
}

export function HotkeyRecorder({ value, defaultValue, onCommit }: HotkeyRecorderProps): JSX.Element {
  const [recording, setRecording] = useState(false);
  const [draft, setDraft] = useState(value || defaultValue);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!recording) {
      setDraft(value || defaultValue);
    }
  }, [value, defaultValue, recording]);

  useEffect(() => {
    if (!recording) {
      return;
    }

    const cancel = () => {
      setRecording(false);
      setError(null);
      setDraft(value || defaultValue);
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      event.preventDefault();
      event.stopPropagation();

      if (event.key === 'Escape') {
        cancel();
        return;
      }

      const accelerator = normalizeAcceleratorFromEvent(event);
      if (!accelerator) {
        setError('请按下至少包含一个修饰键的快捷键，例如 Cmd+Shift+V。');
        return;
      }

      setError(null);
      setDraft(accelerator);
      setRecording(false);
      void onCommit(accelerator);
    };

    window.addEventListener('keydown', handleKeyDown, true);
    return () => {
      window.removeEventListener('keydown', handleKeyDown, true);
    };
  }, [recording, onCommit, value, defaultValue]);

  const statusText = useMemo(() => {
    if (recording) return '按下想要设置的快捷键，Esc 取消';
    return '点击后按下组合键即可自动保存';
  }, [recording]);

  return (
    <div className="flex items-center gap-3">
      <div className="flex min-w-0 items-center gap-2">
        <Button
          variant={recording ? 'primary' : 'secondary'}
          size="sm"
          onClick={() => {
            setError(null);
            setDraft(value || defaultValue);
            setRecording(true);
          }}
        >
          {recording ? '录制中...' : '录制快捷键'}
        </Button>
        <div
          className="rounded-[6px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.03)] px-3 py-1.5 text-[13px] text-[color:var(--pm-text-primary)]"
          aria-live="polite"
        >
          {draft || defaultValue}
        </div>
      </div>
      <div className="min-w-0 text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
        {statusText}
        {error ? <div className="mt-1 text-[12px] text-[color:var(--pm-status-danger)]">{error}</div> : null}
      </div>
    </div>
  );
}
