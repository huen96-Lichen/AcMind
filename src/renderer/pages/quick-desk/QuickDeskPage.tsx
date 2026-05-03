import { useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { usePinPool } from '../../hooks/usePinPool';

export function QuickDeskPage(): JSX.Element {
  const { pins, selectedPin, setSelectedPin, loading, error, refresh, createFromText, prefilter, promoteToInbox, ignore, deletePin } = usePinPool();
  const [inputText, setInputText] = useState('');

  const navigate = (view: string) => {
    window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view } }));
  };

  const handleCreatePin = async () => {
    const text = inputText.trim();
    if (!text) return;
    await createFromText(text);
    setInputText('');
  };

  if (loading) {
    return (
      <PageShell>
        <div className="px-6 pt-5">
          <PageHeader title="AcMind" description="先 Pin 住，再变成知识。" />
        </div>
        <div className="flex items-center justify-center" style={{ minHeight: 420 }}>
          <LoadingState title="正在加载 Quick Desk" description="正在读取 Pin Pool。" />
        </div>
      </PageShell>
    );
  }

  if (error) {
    return (
      <PageShell>
        <div className="px-6 pt-5">
          <PageHeader title="AcMind" description="先 Pin 住，再变成知识。" />
        </div>
        <ErrorState title="Quick Desk 加载失败" reason={error} suggestion="请检查本地数据库状态。" action={{ label: '重新加载', onClick: () => void refresh() }} />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <div className="px-6 pt-5">
        <PageHeader
          title="AcMind"
          description="先 Pin 住，再变成知识。"
          actions={
            <div className="flex items-center gap-2">
              <Button variant="secondary" size="sm" leadingIcon={<PinStackIcon name="act-quick-capture" size={14} />} onClick={() => navigate('capture-inbox')}>
                输入想法
              </Button>
              <Button variant="primary" size="sm" leadingIcon={<PinStackIcon name="sb-ai-process" size={14} />} onClick={() => navigate('distill')}>
                Knowledge Flow
              </Button>
            </div>
          }
        />
      </div>

      <div className="grid min-h-0 flex-1 grid-cols-[220px_minmax(0,1fr)_320px] gap-4 px-6 pb-6">
        <Section title="快捷动作" compact>
          <div className="flex flex-col gap-2">
            <textarea
              value={inputText}
              onChange={(event) => setInputText(event.target.value)}
              placeholder="输入想法、笔记、灵感…"
              className="min-h-[128px] resize-none rounded-[10px] border border-[color:var(--border-light)] bg-white/70 p-3 text-[13px] outline-none"
              onKeyDown={(e) => {
                if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
                  e.preventDefault();
                  void handleCreatePin();
                }
              }}
            />
            <Button variant="primary" onClick={() => void handleCreatePin()}>Pin 住</Button>
            <div className="my-1 h-px bg-[color:var(--pm-border-subtle)]" />
            <Button variant="secondary" onClick={() => window.acmind.capture.screenshot()}>截图</Button>
            <Button variant="secondary" onClick={() => window.acmind.capture.collectClipboard()}>收集剪贴板</Button>
          </div>
        </Section>

        <Section title={`Pin Pool · ${pins.length}`} compact>
          {pins.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="filled-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="还没有待筛理内容"
              description="截图、复制、语音和手动输入都会先进入这里。"
              action={{ label: '新增内容', onClick: () => navigate('capture-inbox') }}
            />
          ) : (
            <div className="grid grid-cols-2 gap-3">
              {pins.map((pin) => (
                <Card
                  key={pin.id}
                  variant="interactive"
                  className={selectedPin?.id === pin.id ? 'ring-2 ring-[color:var(--pm-brand)]' : ''}
                  onClick={() => setSelectedPin(pin)}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{pin.title || '未命名 Pin'}</p>
                      <p className="mt-1 line-clamp-3 text-[12px]" style={{ color: 'var(--text-muted)' }}>{pin.previewText || pin.rawText || pin.sourceType}</p>
                    </div>
                    <span className="shrink-0 rounded-full px-2 py-1 text-[11px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">{pin.status}</span>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </Section>

        <Section title="当前内容" compact>
          {selectedPin ? (
            <Card variant="base" className="flex flex-col gap-3">
              <div>
                <p className="text-[15px] font-semibold" style={{ color: 'var(--text-title)' }}>{selectedPin.title || '未命名 Pin'}</p>
                <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>{selectedPin.sourceType}</p>
              </div>
              <p className="max-h-[220px] overflow-auto whitespace-pre-wrap text-[13px]" style={{ color: 'var(--text-body)' }}>
                {selectedPin.rawText || selectedPin.previewText || '暂无文本预览'}
              </p>
              {selectedPin.prefilterResult && (() => {
                const pf = selectedPin.prefilterResult as Record<string, unknown>;
                return (
                  <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] p-3 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                    价值分 {String(pf.valueScore ?? '待评估')} · 建议 {String(pf.suggestedAction || '待判断')}
                    {pf.reason ? <p className="mt-1">{String(pf.reason)}</p> : null}
                  </div>
                );
              })()}
              <div className="flex flex-wrap gap-2">
                <Button size="sm" variant="secondary" onClick={() => void prefilter(selectedPin.id)}>AI 预筛</Button>
                <Button size="sm" variant="primary" onClick={() => void promoteToInbox(selectedPin.id)}>入 Inbox</Button>
                <Button size="sm" variant="ghost" onClick={() => void ignore(selectedPin.id)}>忽略</Button>
                <Button size="sm" variant="ghost" onClick={() => void deletePin(selectedPin.id)}>删除</Button>
              </div>
            </Card>
          ) : (
            <EmptyState title="选择一个 Pin" description="查看预览、AI 建议和下一步动作。" />
          )}
        </Section>
      </div>
    </PageShell>
  );
}
