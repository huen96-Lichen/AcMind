import { useCallback, useEffect, useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import type { SourceItem } from '../../../shared/types';

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
          <PageHeader title="首页" description="今天要处理什么？" />
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
          <PageHeader title="首页" description="今天要处理什么？" />
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

  return (
    <PageShell>
      <div className="px-6 pt-5">
        <PageHeader
          title="首页"
          description="今天要处理什么？"
          actions={
            <div className="flex items-center gap-2">
              <Button
                variant="primary"
                size="sm"
                leadingIcon={<PinStackIcon name="act-quick-capture" size={14} />}
                onClick={() => navigate('capture-inbox')}
              >
                收集新内容
              </Button>
              {stats.pending > 0 && (
                <Button
                  variant="secondary"
                  size="sm"
                  leadingIcon={<PinStackIcon name="sb-ai-process" size={14} />}
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

        {stats.pending > 0 && (
          <Section title="下一步" compact>
            <Card variant="interactive" className="pm-ds-suggestion-card" onClick={() => navigate('distill')}>
              <div className="pm-ds-suggestion-icon" style={{ background: 'var(--pm-warning-bg)', color: 'var(--pm-warning)' }}>
                <PinStackIcon name="filled-inbox" size={18} />
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

        <Section title="最近内容" compact>
          {recentItems.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="filled-inbox" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
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
      </div>
    </PageShell>
  );
}
