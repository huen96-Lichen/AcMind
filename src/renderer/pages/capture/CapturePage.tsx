import { useState } from 'react';
import { PinStackIcon } from '../../design-system/icons';
import { useShellSnapshot } from '../../hooks/useShellSnapshot';

export function CapturePage(): JSX.Element {
  const snapshot = useShellSnapshot();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string>('准备就绪');

  const handleCapture = async () => {
    setBusy(true);
    setMessage('截图中...');
    try {
      const ok = await window.pinmind.capture.screenshot();
      setMessage(ok ? '截图已保存到收集箱' : '截图未完成，请检查权限');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex h-full w-full items-center justify-center p-6">
      <div className="pinmind-window-panel flex w-full max-w-[720px] flex-col overflow-hidden">
        <div className="flex items-center justify-between border-b border-[color:var(--pm-border-subtle)] px-5 py-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-[12px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand-primary)]">
              <PinStackIcon name="capture" size={18} />
            </div>
            <div>
              <h1 className="text-[18px] font-semibold text-[color:var(--pm-text-primary)]">快速捕获</h1>
              <p className="text-[12px] text-[color:var(--pm-text-tertiary)]">一键截图，或者回到主工作区继续整理。</p>
            </div>
          </div>
          <button
            type="button"
            className="pinmind-btn pinmind-btn-ghost motion-button text-[12px]"
            onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'daily-flow' }))}
          >
            返回工作台
          </button>
        </div>

        <div className="grid gap-4 p-5 md:grid-cols-[minmax(0,1.1fr)_minmax(280px,0.9fr)]">
          <section className="pinmind-panel-soft p-4">
            <p className="pinmind-section-eyebrow">主操作</p>
            <h2 className="text-[14px] font-semibold text-[color:var(--pm-text-primary)]">截图并保存</h2>
            <p className="mt-2 text-[12px] leading-6 text-[color:var(--pm-text-secondary)]">
              这里不保留占位按钮。点击后会直接执行截图，截图成功后会入库到收集箱。
            </p>
            <button
              type="button"
              disabled={busy}
              onClick={() => void handleCapture()}
              className="mt-4 inline-flex h-11 items-center justify-center gap-2 rounded-[10px] border border-[color:var(--pm-brand-primary)] bg-[color:var(--pm-brand-primary)] px-4 text-[13px] font-medium text-white shadow-[0_10px_18px_rgba(232,122,61,0.18)] transition-opacity disabled:cursor-not-allowed disabled:opacity-60"
            >
              <PinStackIcon name="capture" size={16} />
              {busy ? '截图中...' : '开始截图'}
            </button>
            <p className="mt-3 text-[11px] text-[color:var(--pm-text-tertiary)]">{message}</p>
          </section>

          <section className="pinmind-panel-soft p-4">
            <p className="pinmind-section-eyebrow">运行状态</p>
            <div className="flex flex-col gap-2">
              <RuntimeLine label="剪贴板" value={snapshot.clipboard?.enabled ? '开启' : '关闭'} />
              <RuntimeLine label="屏幕录制" value={snapshot.permissions?.screenRecording ?? '未知'} />
              <RuntimeLine label="存储" value={snapshot.settings?.storageRoot ?? '未加载'} />
              <RuntimeLine label="整理方式" value={formatTier(snapshot.settings?.defaultTier ?? 'local_light')} />
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              <button
                type="button"
                className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
                onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'inbox' }))}
              >
                打开收件箱
              </button>
              <button
                type="button"
                className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
                onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: 'settings' }))}
              >
                打开设置
              </button>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}

function RuntimeLine({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div className="flex items-center justify-between gap-3 rounded-[10px] border border-[color:var(--pm-border-subtle)] bg-white/70 px-3 py-2 text-[12px]">
      <span className="text-[color:var(--pm-text-tertiary)]">{label}</span>
      <span className="text-[color:var(--pm-text-secondary)]">{value}</span>
    </div>
  );
}

function formatTier(value: string): string {
  switch (value) {
    case 'local_light':
      return '本地轻量';
    case 'cloud_standard':
      return '云端标准';
    case 'cloud_advanced':
      return '云端高级';
    default:
      return value;
  }
}
