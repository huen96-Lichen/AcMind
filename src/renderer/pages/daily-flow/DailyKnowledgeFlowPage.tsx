import { useCallback, useEffect, useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import type { SourceItem } from '../../../shared/types';
import { AgentChatPanel } from '../../components/agent-chat/AgentChatPanel';

interface HomeStats {
  pending: number;
  distilled: number;
  exported: number;
}

export function DailyKnowledgeFlowPage(): JSX.Element {
  const [stats, setStats] = useState<HomeStats>({ pending: 0, distilled: 0, exported: 0 });
  const [recentItems, setRecentItems] = useState<SourceItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedItem, setSelectedItem] = useState<SourceItem | null>(null);
  const [inputText, setInputText] = useState('');

  // Context Panel tab state: 'agent' | 'preview'
  const [contextTab, setContextTab] = useState<'agent' | 'preview'>('agent');

  // Auto-switch to preview when item is selected
  useEffect(() => {
    if (selectedItem) {
      setContextTab('preview');
    }
  }, [selectedItem]);

  const loadData = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const [allItems, distilledItems, exportRecords] = await Promise.all([
        window.acmind.sourceItems.list({}),
        window.acmind.sourceItems.list({ status: 'distilled' }),
        window.acmind.export.history({}),
      ]);

      const pending = allItems.filter(
        (item) => item.status === 'inbox' || item.status === 'distilling',
      ).length;
      const distilled = distilledItems.length;
      const exported = exportRecords.filter((r) => r.status === 'success').length;

      setStats({ pending, distilled, exported });

      const sorted = [...allItems].sort((a, b) => b.createdAt - a.createdAt).slice(0, 3);
      setRecentItems(sorted);
    } catch (err) {
      setError('加载失败，请稍后重试。');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  useEffect(() => {
    const unsubscribe = window.acmind.onRecordsChanged(() => {
      void loadData();
    });
    return unsubscribe;
  }, [loadData]);

  const navigate = (view: string) => {
    window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view } }));
  };

  const handleCreatePin = async () => {
    const text = inputText.trim();
    if (!text) return;
    await window.acmind.sourceItems.createText(text);
    setInputText('');
    void loadData();
  };

  const formatTime = (ts: number) => {
    const diff = Math.floor((Date.now() / 1000 - ts));
    if (diff < 60) return '刚刚';
    if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`;
    if (diff < 86400) return `${Math.floor(diff / 3600)} 小时前`;
    return new Date(ts * 1000).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
  };

  if (loading) {
    return (
      <PageShell>
        <div className="px-6 pt-5">
          <PageHeader title="工作台" description="个人桌面 AI 信息中枢 — 从碎片收集到知识沉淀" />
        </div>
        <div className="flex items-center justify-center" style={{ minHeight: 400 }}>
          <LoadingState title="正在加载" description="正在读取数据。" />
        </div>
      </PageShell>
    );
  }

  if (error) {
    return (
      <PageShell>
        <div className="px-6 pt-5">
          <PageHeader title="工作台" description="个人桌面 AI 信息中枢 — 从碎片收集到知识沉淀" />
        </div>
        <ErrorState
          title="加载失败"
          reason={error}
          suggestion="请稍后重试。"
          action={{ label: '重新加载', onClick: () => void loadData() }}
        />
      </PageShell>
    );
  }

  const pendingCount = recentItems.filter(
    (item) => item.status === 'inbox' || item.status === 'distilling',
  ).length;

  return (
    <PageShell>
      <div className="px-6 pt-5">
        <PageHeader
          title="工作台"
          description="个人桌面 AI 信息中枢 — 从碎片收集到知识沉淀"
          actions={
            <div className="flex items-center gap-2">
              <Button
                variant="primary"
                size="sm"
                leadingIcon={<AcMindIcon name="act-quick-capture" size={14} />}
                onClick={() => navigate('capture-inbox')}
              >
                收集新内容
              </Button>
              {stats.pending > 0 && (
                <Button
                  variant="secondary"
                  size="sm"
                  leadingIcon={<AcMindIcon name="sb-ai-process" size={14} />}
                  onClick={() => navigate('distill')}
                >
                  整理 {stats.pending} 条
                </Button>
              )}
            </div>
          }
        />
      </div>

      <div className="px-6 pb-6 flex flex-col gap-5">
        {/* ── 统计卡片 ── */}
        <Section title="当前状态" compact>
          <div className="grid grid-cols-3 gap-3">
            <Card variant="base" className="pm-ds-metric-card">
              <div className="pm-ds-metric-value" style={{ color: 'var(--pm-warning)' }}>{stats.pending}</div>
              <div className="pm-ds-metric-label">待整理</div>
            </Card>
            <Card variant="base" className="pm-ds-metric-card">
              <div className="pm-ds-metric-value" style={{ color: 'var(--pm-brand)' }}>{stats.distilled}</div>
              <div className="pm-ds-metric-label">已整理</div>
            </Card>
            <Card variant="base" className="pm-ds-metric-card">
              <div className="pm-ds-metric-value" style={{ color: 'var(--pm-success)' }}>{stats.exported}</div>
              <div className="pm-ds-metric-label">已入库</div>
            </Card>
          </div>
        </Section>

        {/* ── 下一步建议 ── */}
        {stats.pending > 0 && (
          <Section title="下一步" compact>
            <Card variant="interactive" className="pm-ds-suggestion-card" onClick={() => navigate('distill')}>
              <div className="pm-ds-suggestion-icon" style={{ background: 'var(--pm-warning-bg)', color: 'var(--pm-warning)' }}>
                <AcMindIcon name="filled-inbox" size={18} />
              </div>
              <div className="pm-ds-suggestion-body">
                <p className="pm-ds-suggestion-desc">有 {stats.pending} 条内容待整理</p>
                <Button
                  variant="primary"
                  size="sm"
                  onClick={(e) => { e.stopPropagation(); navigate('distill'); }}
                >
                  开始整理
                </Button>
              </div>
            </Card>
          </Section>
        )}

        {/* ── 快速动作 + Pin Pool + 预览 三栏 ── */}
        <div className="grid min-h-0 grid-cols-[200px_minmax(0,1fr)_300px] gap-4">
          {/* 左侧：快速动作 */}
          <Section title="快速动作" compact>
            <div className="flex flex-col gap-2">
              <textarea
                value={inputText}
                onChange={(e) => setInputText(e.target.value)}
                placeholder="输入想法、笔记、灵感…"
                className="min-h-[100px] resize-none rounded-[10px] border border-[color:var(--border-light)] bg-white/70 p-3 text-[13px] outline-none"
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
                    e.preventDefault();
                    void handleCreatePin();
                  }
                }}
              />
              <Button variant="primary" size="sm" onClick={() => void handleCreatePin()}>记录想法</Button>
              <div className="my-1 h-px bg-[color:var(--pm-border-subtle)]" />
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="capture" size={14} />} onClick={() => window.acmind.capture.screenshot()}>
                截图 Pin
              </Button>
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="record" size={14} />} onClick={() => navigate('voice-dictionary')}>
                语音 Pin
              </Button>
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="duplicate" size={14} />} onClick={() => window.acmind.capture.collectClipboard()}>
                收集剪贴板
              </Button>
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="filled-file-import" size={14} />} onClick={() => navigate('capture-inbox')}>
                导入文件
              </Button>
            </div>
          </Section>

          {/* 中间：收集收件箱 */}
          <Section title={`今日暂存 · ${recentItems.length} 条`} compact>
            {recentItems.length === 0 ? (
              <EmptyState
                icon={<AcMindIcon name="filled-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
                title="还没有暂存内容"
                description="截图、复制、语音和手动输入都会先进入这里。"
                action={{ label: '记录想法', onClick: () => navigate('capture-inbox') }}
              />
            ) : (
              <>
                {pendingCount > 0 && (
                  <div className="mb-3 flex items-center gap-2 rounded-[8px] bg-[color:var(--pm-brand-soft)] px-3 py-2 text-[12px] text-[color:var(--pm-brand)]">
                    <AcMindIcon name="spark" size={14} />
                    <span>{pendingCount} 条内容待整理</span>
                    <Button variant="ghost" size="sm" className="ml-auto" onClick={() => navigate('capture-inbox')}>
                      前往收件箱
                    </Button>
                  </div>
                )}
                <div className="grid grid-cols-2 gap-3">
                  {recentItems.slice(0, 5).map((item) => (
                    <Card
                      key={item.id}
                      variant="interactive"
                      className={selectedItem?.id === item.id ? 'ring-2 ring-[color:var(--pm-brand)]' : ''}
                      onClick={() => setSelectedItem(item)}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="truncate text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{item.title || '未命名'}</p>
                          <p className="mt-1 line-clamp-3 text-[12px]" style={{ color: 'var(--text-muted)' }}>{item.previewText || item.source}</p>
                        </div>
                        <span className="shrink-0 rounded-full px-2 py-1 text-[11px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">{item.status}</span>
                      </div>
                    </Card>
                  ))}
                </div>
                {recentItems.length > 5 && (
                  <div className="mt-3 text-center">
                    <Button variant="ghost" size="sm" onClick={() => navigate('capture-inbox')}>
                      查看全部 {recentItems.length} 条
                    </Button>
                  </div>
                )}
              </>
            )}
          </Section>

          {/* 右侧：Context Panel (Agent / Preview tabs) */}
          <Section title="上下文" compact>
            {/* Tab headers */}
            <div className="flex border-b border-border-subtle mb-3">
              <button
                onClick={() => setContextTab('agent')}
                className={`flex-1 py-2 text-sm font-medium transition-colors ${
                  contextTab === 'agent'
                    ? 'text-accent border-b-2 border-accent'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                Agent
              </button>
              <button
                onClick={() => setContextTab('preview')}
                className={`flex-1 py-2 text-sm font-medium transition-colors ${
                  contextTab === 'preview'
                    ? 'text-accent border-b-2 border-accent'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                预览
              </button>
            </div>

            {/* Tab content */}
            <div className="min-h-[300px]">
              {contextTab === 'agent' ? (
                <AgentChatPanel showHeader={false} />
              ) : selectedItem ? (
                <Card variant="base" className="flex flex-col gap-3">
                  <div>
                    <p className="text-[15px] font-semibold" style={{ color: 'var(--text-title)' }}>{selectedItem.title || '未命名'}</p>
                    <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>{selectedItem.source}</p>
                  </div>
                  <p className="max-h-[180px] overflow-auto whitespace-pre-wrap text-[13px]" style={{ color: 'var(--text-body)' }}>
                    {selectedItem.previewText || '暂无文本预览'}
                  </p>
                  <div className="flex flex-wrap gap-2">
                    <Button size="sm" variant="primary" onClick={() => navigate('capture-inbox')}>查看详情</Button>
                  </div>
                </Card>
              ) : (
                <EmptyState title="选择一条内容" description="查看预览和下一步动作。" />
              )}
            </div>
          </Section>
        </div>

        {/* ── 最近内容 ── */}
        <Section title="最近内容" compact>
          {recentItems.length === 0 ? (
            <EmptyState
              icon={<AcMindIcon name="filled-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="还没有内容"
              description="先收集一条内容吧"
              action={{ label: '去收集', onClick: () => navigate('capture-inbox') }}
            />
          ) : (
            <div className="flex flex-col gap-2">
              {recentItems.map((item) => (
                <Card
                  key={item.id}
                  variant="interactive"
                  className="pm-ds-item-row"
                  onClick={() => navigate('capture-inbox')}
                >
                  <div className="pm-ds-item-body">
                    <div className="pm-ds-item-header">
                      <h4 className="pm-ds-item-title">{item.title || '未命名内容'}</h4>
                    </div>
                    <p className="pm-ds-item-preview">{item.previewText || '暂无预览'}</p>
                    <div className="pm-ds-item-meta">
                      <span>{formatTime(item.createdAt)}</span>
                      <span>{item.sourceApp || item.source}</span>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </Section>

        {/* ── 底部常用工具 ── */}
        <Section title="常用工具" compact>
          <div className="flex gap-3">
            <Card variant="interactive" className="flex items-center gap-3 px-4 py-3" onClick={() => navigate('file-converter')}>
              <AcMindIcon name="feat-markdown" size={20} />
              <div>
                <p className="text-[13px] font-semibold" style={{ color: 'var(--text-title)' }}>文件转 Markdown</p>
                <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>PDF / DOCX / PPTX</p>
              </div>
            </Card>
            <Card variant="interactive" className="flex items-center gap-3 px-4 py-3" onClick={() => navigate('auto-tools')}>
              <AcMindIcon name="image" size={20} />
              <div>
                <p className="text-[13px] font-semibold" style={{ color: 'var(--text-title)' }}>图片 OCR</p>
                <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>识别图片中的文字</p>
              </div>
            </Card>
            <Card variant="interactive" className="flex items-center gap-3 px-4 py-3" onClick={() => window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'auto-tools', tab: 'overview' } }))}>
              <AcMindIcon name="filled-search" size={20} />
              <div>
                <p className="text-[13px] font-semibold" style={{ color: 'var(--text-title)' }}>ZTools</p>
                <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>搜索与插件平台参考</p>
              </div>
            </Card>
            <Card variant="interactive" className="flex items-center gap-3 px-4 py-3" onClick={() => navigate('voice-dictionary')}>
              <AcMindIcon name="record" size={20} />
              <div>
                <p className="text-[13px] font-semibold" style={{ color: 'var(--text-title)' }}>音频转文字</p>
                <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>语音转写与整理</p>
              </div>
            </Card>
          </div>
        </Section>
      </div>
    </PageShell>
  );
}
