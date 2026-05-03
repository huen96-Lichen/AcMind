import { useCallback, useEffect, useState } from 'react';
import { Button, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import type { ExportRecord } from '../../../shared/types';

type FilterKey = 'all' | 'today' | 'week' | 'failed';

const FILTERS: { key: FilterKey; label: string }[] = [
  { key: 'all', label: '全部' },
  { key: 'today', label: '今日' },
  { key: 'week', label: '本周' },
  { key: 'failed', label: '失败' },
];

export function ImportPage(): JSX.Element {
  const [records, setRecords] = useState<ExportRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<FilterKey>('all');
  const [search, setSearch] = useState('');

  const loadRecords = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await window.pinmind.export.history({});
      setRecords(result);
    } catch (err) {
      setError('加载失败，请稍后重试。');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  useEffect(() => {
    const unsubscribe = window.pinmind.onRecordsChanged(() => {
      void loadRecords();
    });
    return unsubscribe;
  }, [loadRecords]);

  const filteredRecords = records.filter((record) => {
    if (filter === 'today') {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      if (record.exportedAt < today.getTime() / 1000) return false;
    }
    if (filter === 'week') {
      const weekAgo = Date.now() / 1000 - 7 * 86400;
      if (record.exportedAt < weekAgo) return false;
    }
    if (filter === 'failed' && record.status !== 'failed') return false;
    if (search) {
      const q = search.toLowerCase();
      const filePath = (record.relativeFilePath || '').toLowerCase();
      const vaultPath = (record.vaultPath || '').toLowerCase();
      if (!filePath.includes(q) && !vaultPath.includes(q)) return false;
    }
    return true;
  });

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
          <PageHeader title="资料库" description="已保存的内容" />
        </div>
        <div className="flex items-center justify-center" style={{ minHeight: 400 }}>
          <LoadingState title="正在加载" description="正在读取资料库。" />
        </div>
      </PageShell>
    );
  }

  if (error) {
    return (
      <PageShell>
        <div className="px-6 pt-5">
          <PageHeader title="资料库" description="已保存的内容" />
        </div>
        <ErrorState
          title="加载失败"
          reason={error}
          suggestion="请稍后重试。"
          action={{ label: '重新加载', onClick: () => void loadRecords() }}
        />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <div className="px-6 pt-5">
        <PageHeader title="资料库" description="已保存的内容" />
      </div>

      <div className="px-6 pb-6 flex flex-col gap-4">
        <div className="flex items-center gap-3">
          <div className="pm-ds-search-field flex-1">
            <span className="pm-ds-search-icon" aria-hidden="true">
              <PinStackIcon name="search" size={14} />
            </span>
            <input
              type="text"
              placeholder="搜索标题、标签、来源"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pm-ds-search-input"
            />
          </div>
          <div className="flex gap-1">
            {FILTERS.map((f) => (
              <Button
                key={f.key}
                variant={filter === f.key ? 'primary' : 'secondary'}
                size="sm"
                onClick={() => setFilter(f.key)}
              >
                {f.label}
              </Button>
            ))}
          </div>
        </div>

        {filteredRecords.length === 0 ? (
          <EmptyState
            icon={<PinStackIcon name="sb-results" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="还没有内容"
            description="整理后会出现在这里"
            action={{
              label: '去整理',
              onClick: () => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'distill' } })),
            }}
          />
        ) : (
          <div className="flex flex-col gap-1.5">
            {filteredRecords.map((record) => (
              <div
                key={record.id}
                className="flex items-center gap-3 rounded-[10px] px-3 py-2.5"
                style={{ background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.5))' }}
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>
                    {record.relativeFilePath || '未命名'}
                  </p>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                      {formatTime(record.exportedAt)}
                    </span>
                    {record.vaultPath && (
                      <span className="text-[11px] truncate" style={{ color: 'var(--pm-text-tertiary)' }}>
                        {record.vaultPath}
                      </span>
                    )}
                  </div>
                </div>
                <StatusBadge
                  tone={record.status === 'success' ? 'success' : record.status === 'failed' ? 'danger' : 'warning'}
                  label={record.status === 'success' ? '已入库' : record.status === 'failed' ? '入库失败' : '文件冲突'}
                />
                <div className="flex items-center gap-1">
                  {record.status === 'success' && record.vaultPath && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => window.pinmind.export.revealInVault(record.vaultPath)}
                    >
                      打开文件
                    </Button>
                  )}
                  {record.status === 'failed' && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'distill' } }))}
                    >
                      重新入库
                    </Button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </PageShell>
  );
}
