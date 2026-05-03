import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  LoadingState,
  PageHeader,
  PageShell,
  Section,
  StatusBadge,
} from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { useToast } from '../../components/shared/ToastViewport';
import type { AiTask } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

type TaskStatus = AiTask['status'];

interface TabDef {
  key: TaskStatus | 'all';
  label: string;
}

const TABS: TabDef[] = [
  { key: 'all', label: '全部' },
  { key: 'queued', label: '排队中' },
  { key: 'running', label: '运行中' },
  { key: 'done', label: '成功' },
  { key: 'failed', label: '失败' },
  { key: 'cancelled', label: '已取消' },
];

const STATUS_CONFIG: Record<
  string,
  { label: string; tone: 'success' | 'warning' | 'danger' | 'neutral' }
> = {
  queued: { label: '排队中', tone: 'neutral' },
  running: { label: '运行中', tone: 'warning' },
  done: { label: '完成', tone: 'success' },
  failed: { label: '失败', tone: 'danger' },
  cancelled: { label: '已取消', tone: 'neutral' },
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function opLabel(op?: string): string {
  const map: Record<string, string> = {
    distill: '整理',
    summarize: '摘要',
    tag: '标签',
    export: '导出',
    ocr: 'OCR',
    asr: '语音转写',
    markitdown: '文件转换',
    rewrite: '改写',
  };
  return map[op || ''] || op || '未知';
}

function formatDuration(ms?: number): string {
  if (ms == null) return '-';
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

function formatRelativeTime(ts: number): string {
  const diff = Date.now() - ts;
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return '刚刚';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} 分钟前`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} 小时前`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days} 天前`;
  return new Date(ts).toLocaleDateString('zh-CN');
}

function truncateId(id?: string, maxLen = 12): string {
  if (!id) return '-';
  if (id.length <= maxLen) return id;
  return `${id.slice(0, maxLen - 2)}...`;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function TaskQueuePage(): JSX.Element {
  const { addToast } = useToast();

  const [tasks, setTasks] = useState<AiTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TaskStatus | 'all'>('all');
  const [paused, setPaused] = useState(false);

  // ---- Data fetching ----

  const fetchTasks = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const statusFilter = activeTab === 'all' ? undefined : (activeTab as TaskStatus);
      const list = await window.acmind.aiTasks.list({ status: statusFilter });
      setTasks(list);
    } catch (e: any) {
      setError(e?.message || '加载任务列表失败');
    } finally {
      setLoading(false);
    }
  }, [activeTab]);

  useEffect(() => {
    fetchTasks();
  }, [fetchTasks]);

  useEffect(() => {
    const unsub = window.acmind.onRecordsChanged(() => {
      fetchTasks();
    });
    return unsub;
  }, [fetchTasks]);

  // ---- Actions ----

  const handleCancel = useCallback(
    async (taskId: string) => {
      try {
        await window.acmind.aiTasks.cancel(taskId);
        addToast('任务已取消', 'info');
        fetchTasks();
      } catch (e: any) {
        addToast(e?.message || '取消失败', 'error');
      }
    },
    [fetchTasks, addToast],
  );

  const handleRetry = useCallback(
    async (taskId: string) => {
      try {
        await window.acmind.aiTasks.retry(taskId);
        addToast('已重新提交任务', 'success');
        fetchTasks();
      } catch (e: any) {
        addToast(e?.message || '重试失败', 'error');
      }
    },
    [fetchTasks, addToast],
  );

  const handleTogglePause = useCallback(async () => {
    try {
      if (paused) {
        await window.acmind.aiTasks.resume();
        setPaused(false);
        addToast('队列已恢复', 'success');
      } else {
        await window.acmind.aiTasks.pause();
        setPaused(true);
        addToast('队列已暂停', 'info');
      }
    } catch (e: any) {
      addToast(e?.message || '操作失败', 'error');
    }
  }, [paused, addToast]);

  const handleRetryAllFailed = useCallback(async () => {
    const failedTasks = tasks.filter((t) => t.status === 'failed');
    if (failedTasks.length === 0) {
      addToast('没有失败的任务', 'info');
      return;
    }
    try {
      await Promise.all(failedTasks.map((t) => window.acmind.aiTasks.retry(t.id)));
      addToast(`已重试 ${failedTasks.length} 个失败任务`, 'success');
      fetchTasks();
    } catch (e: any) {
      addToast(e?.message || '批量重试失败', 'error');
    }
  }, [tasks, fetchTasks, addToast]);

  // ---- Derived ----

  const counts = {
    queued: tasks.filter((t) => t.status === 'queued').length,
    running: tasks.filter((t) => t.status === 'running').length,
    done: tasks.filter((t) => t.status === 'done').length,
    failed: tasks.filter((t) => t.status === 'failed').length,
  };

  const filteredTasks =
    activeTab === 'all' ? tasks : tasks.filter((t) => t.status === activeTab);

  // ---- Render ----

  return (
    <PageShell>
      <PageHeader
        title="任务队列"
        description="后台处理任务管理"
      />

      <ScrollContainer>
        {/* Summary bar */}
        <div style={styles.summaryBar}>
          {(
            [
              ['排队中', counts.queued, 'var(--pm-status-neutral, #94a3b8)'],
              ['运行中', counts.running, 'var(--pm-status-warning, #f59e0b)'],
              ['完成', counts.done, 'var(--pm-status-success, #22c55e)'],
              ['失败', counts.failed, 'var(--pm-status-danger, #ef4444)'],
            ] as const
          ).map(([label, count, color]) => (
            <Card key={label} style={styles.summaryCard}>
              <div style={{ ...styles.summaryCount, color }}>{count}</div>
              <div style={styles.summaryLabel}>{label}</div>
            </Card>
          ))}
        </div>

        {/* Tab bar */}
        <div style={styles.tabBar}>
          {TABS.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              style={{
                ...styles.tab,
                ...(activeTab === tab.key ? styles.tabActive : {}),
              }}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Task list */}
        <Section title="任务列表">
          {loading && <LoadingState title="加载中" description="正在加载任务列表..." />}
            {error && <ErrorState title="加载失败" reason={error} suggestion="请稍后重试。" action={{ label: '重新加载', onClick: fetchTasks }} />}
            {!loading && !error && filteredTasks.length === 0 && (
              <EmptyState
                icon={<PinStackIcon name="sb-ai-process" size={28} />}
                title="暂无任务"
                description="当前筛选条件下没有任务"
              />
            )}
          {!loading && !error && filteredTasks.length > 0 && (
            <div style={styles.taskList}>
              {/* Header row */}
              <div style={{ ...styles.taskRow, ...styles.taskHeader }}>
                <span style={styles.colOp}>操作</span>
                <span style={styles.colSource}>来源</span>
                <span style={styles.colModel}>模型</span>
                <span style={styles.colStatus}>状态</span>
                <span style={styles.colDuration}>耗时</span>
                <span style={styles.colTime}>创建时间</span>
                <span style={styles.colError}>错误</span>
                <span style={styles.colActions}>操作</span>
              </div>

              {filteredTasks.map((task) => {
                const cfg = STATUS_CONFIG[task.status] || STATUS_CONFIG.queued;
                const isRunning = task.status === 'running';
                const isFailed = task.status === 'failed';

                return (
                  <div
                    key={task.id}
                    style={{
                      ...styles.taskRow,
                      ...(isFailed ? styles.taskRowFailed : {}),
                    }}
                    title={isFailed ? task.error : undefined}
                  >
                    <span style={styles.colOp}>
                      <PinStackIcon name="sb-ai-process" size={14} style={{ marginRight: 6, verticalAlign: 'middle' }} />
                      {opLabel(task.operation)}
                    </span>
                    <span style={styles.colSource} title={task.sourceItemId}>
                      {truncateId(task.sourceItemId)}
                    </span>
                    <span style={styles.colModel}>
                      {task.provider && task.model
                        ? `${task.provider}/${task.model}`
                        : task.provider || task.model || '-'}
                    </span>
                    <span style={styles.colStatus}>
                      <span
                        style={{
                          ...styles.badge,
                          ...(isRunning ? styles.badgePulse : {}),
                        }}
                      >
                        <StatusBadge tone={cfg.tone} label={cfg.label} />
                      </span>
                    </span>
                    <span style={styles.colDuration}>
                      {isRunning
                        ? formatDuration(Date.now() - task.updatedAt)
                        : formatDuration(task.latencyMs)}
                    </span>
                    <span style={styles.colTime}>{formatRelativeTime(task.createdAt)}</span>
                    <span style={styles.colError}>
                      {isFailed
                        ? (task.error && task.error.length > 30
                            ? task.error.slice(0, 30) + '...'
                            : task.error) || '-'
                        : '-'}
                    </span>
                    <span style={styles.colActions}>
                      {isFailed && (
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => handleRetry(task.id)}
                        >
                          重试
                        </Button>
                      )}
                      {(task.status === 'queued' || task.status === 'running') && (
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => handleCancel(task.id)}
                        >
                          取消
                        </Button>
                      )}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </Section>

        {/* Batch actions bar */}
        <div style={styles.batchBar}>
          <Button
            variant={paused ? 'primary' : 'secondary'}
            size="sm"
            onClick={handleTogglePause}
          >
            {paused ? '恢复队列' : '暂停队列'}
          </Button>
          <Button variant="secondary" size="sm" onClick={handleRetryAllFailed}>
            重试全部失败
          </Button>
        </div>
      </ScrollContainer>
    </PageShell>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles: Record<string, React.CSSProperties> = {
  summaryBar: {
    display: 'grid',
    gridTemplateColumns: 'repeat(4, 1fr)',
    gap: 12,
    marginBottom: 16,
  },
  summaryCard: {
    padding: '12px 16px',
    textAlign: 'center' as const,
  },
  summaryCount: {
    fontSize: 24,
    fontWeight: 700,
    lineHeight: 1.2,
  },
  summaryLabel: {
    fontSize: 12,
    color: 'var(--pm-text-secondary, #64748b)',
    marginTop: 4,
  },
  tabBar: {
    display: 'flex',
    gap: 4,
    marginBottom: 16,
    borderBottom: '1px solid var(--pm-border, #e2e8f0)',
    paddingBottom: 0,
  },
  tab: {
    padding: '8px 16px',
    border: 'none',
    background: 'none',
    cursor: 'pointer',
    fontSize: 13,
    color: 'var(--pm-text-secondary, #64748b)',
    borderBottom: '2px solid transparent',
    marginBottom: -1,
    transition: 'color 0.15s, border-color 0.15s',
  },
  tabActive: {
    color: 'var(--pm-text-primary, #0f172a)',
    borderBottomColor: 'var(--pm-accent, #3b82f6)',
    fontWeight: 600,
  },
  taskList: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: 0,
  },
  taskRow: {
    display: 'grid',
    gridTemplateColumns: '120px 100px 140px 80px 70px 90px 1fr 100px',
    alignItems: 'center',
    padding: '10px 12px',
    borderBottom: '1px solid var(--pm-border, #e2e8f0)',
    fontSize: 13,
    gap: 8,
    minWidth: 0,
  },
  taskHeader: {
    fontSize: 12,
    fontWeight: 600,
    color: 'var(--pm-text-secondary, #64748b)',
    borderBottom: '2px solid var(--pm-border, #e2e8f0)',
  },
  taskRowFailed: {
    borderLeft: '3px solid var(--pm-status-danger, #ef4444)',
    paddingLeft: 9,
  },
  colOp: { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const },
  colSource: { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const },
  colModel: { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const },
  colStatus: {},
  colDuration: { fontVariantNumeric: 'tabular-nums' as const },
  colTime: { color: 'var(--pm-text-secondary, #64748b)' },
  colError: {
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap' as const,
    color: 'var(--pm-status-danger, #ef4444)',
  },
  colActions: { display: 'flex', gap: 4 },
  badge: { display: 'inline-block' },
  badgePulse: {
    animation: 'taskQueuePulse 1.5s ease-in-out infinite',
  },
  batchBar: {
    display: 'flex',
    gap: 8,
    padding: '12px 0',
    borderTop: '1px solid var(--pm-border, #e2e8f0)',
    marginTop: 8,
  },
};
