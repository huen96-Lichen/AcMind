import { useCallback, useEffect, useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { useToast } from '../../components/shared/ToastViewport';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ScheduledTask {
  id: string;
  type: 'auto_distill' | 'auto_export' | 'cleanup';
  name: string;
  cronExpr: string;
  config: Record<string, unknown>;
  enabled: boolean;
  lastRunAt: number | null;
  nextRunAt: number | null;
  nextRunAtEstimated: boolean;
  lastResult: {
    success: boolean;
    startedAt: number;
    finishedAt: number;
    itemsProcessed: number;
    error?: string;
    summary?: string;
  } | null;
  createdAt: number;
}

interface TaskExecutionResult {
  success: boolean;
  startedAt: number;
  finishedAt: number;
  itemsProcessed: number;
  error?: string;
  summary?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function cronToReadable(cron: string): string {
  const map: Record<string, string> = {
    '0 */2 * * *': '每2小时',
    '0 0 * * *': '每天午夜',
    '0 8 * * *': '每天早上8点',
    '0 20 * * *': '每天晚上8点',
    '0 0 * * 0': '每周日午夜',
    '0 0 1 * *': '每月1号',
  };
  return map[cron] || cron;
}

function typeLabel(type: string): string {
  const map: Record<string, string> = {
    auto_distill: '自动整理',
    auto_export: '自动导出',
    cleanup: '自动清理',
  };
  return map[type] || type;
}

function typeBadgeTone(type: string): 'info' | 'success' | 'warning' {
  const map: Record<string, 'info' | 'success' | 'warning'> = {
    auto_distill: 'info',
    auto_export: 'success',
    cleanup: 'warning',
  };
  return map[type] || 'info';
}

function relativeTime(ts: number | null): string {
  if (ts === null) return '—';
  const diff = Date.now() - ts;
  const absDiff = Math.abs(diff);
  const future = diff < 0;
  const minutes = Math.floor(absDiff / 60000);
  const hours = Math.floor(absDiff / 3600000);
  const days = Math.floor(absDiff / 86400000);
  let text: string;
  if (minutes < 1) text = '刚刚';
  else if (minutes < 60) text = `${minutes}分钟`;
  else if (hours < 24) text = `${hours}小时`;
  else text = `${days}天`;
  return future ? `${text}后` : `${text}前`;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

const scheduler = (window as unknown as { acmind: { scheduler: {
  getTasks(): Promise<ScheduledTask[]>;
  createTask(params: Partial<ScheduledTask>): Promise<ScheduledTask>;
  updateTask(id: string, params: Partial<ScheduledTask>): Promise<ScheduledTask>;
  deleteTask(id: string): Promise<void>;
  toggleTask(id: string): Promise<ScheduledTask>;
  runNow(id: string): Promise<TaskExecutionResult>;
} } }).acmind.scheduler;

export function AutomationPage(): JSX.Element {
  const { addToast } = useToast();
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showAddForm, setShowAddForm] = useState(false);

  // -- New task form state --
  const [newName, setNewName] = useState('');
  const [newType, setNewType] = useState<ScheduledTask['type']>('auto_distill');
  const [newCron, setNewCron] = useState('0 */2 * * *');
  const [newEnabled, setNewEnabled] = useState(false);
  const [creating, setCreating] = useState(false);

  const loadTasks = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await scheduler.getTasks();
      setTasks(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTasks();
  }, [loadTasks]);

  const handleToggle = useCallback(async (id: string) => {
    try {
      const updated = await scheduler.toggleTask(id);
      setTasks((prev) => prev.map((t) => (t.id === id ? updated : t)));
      addToast(updated.enabled ? '规则已启用' : '规则已关闭', 'info');
    } catch (err) {
      addToast(`切换失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    }
  }, [addToast]);

  const handleDelete = useCallback(async (id: string, name: string) => {
    if (!window.confirm(`确定要删除规则「${name}」吗？此操作不可撤销。`)) return;
    try {
      await scheduler.deleteTask(id);
      setTasks((prev) => prev.filter((t) => t.id !== id));
      addToast('规则已删除', 'info');
    } catch (err) {
      addToast(`删除失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    }
  }, [addToast]);

  const handleRunNow = useCallback(async (id: string) => {
    try {
      const result = await scheduler.runNow(id);
      if (result.success) {
        addToast(`执行成功: ${result.summary || `处理了 ${result.itemsProcessed} 项`}`, 'success');
      } else {
        addToast(`执行失败: ${result.error || '未知错误'}`, 'error');
      }
      // Refresh to update lastRunAt / lastResult
      loadTasks();
    } catch (err) {
      addToast(`执行失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    }
  }, [addToast, loadTasks]);

  const handleCreate = useCallback(async () => {
    if (!newName.trim()) {
      addToast('请输入规则名称', 'warning');
      return;
    }
    try {
      setCreating(true);
      const created = await scheduler.createTask({
        name: newName.trim(),
        type: newType,
        cronExpr: newCron,
        enabled: newEnabled,
      });
      setTasks((prev) => [...prev, created]);
      addToast('规则已创建', 'success');
      // Reset form
      setNewName('');
      setNewType('auto_distill');
      setNewCron('0 */2 * * *');
      setNewEnabled(false);
      setShowAddForm(false);
    } catch (err) {
      addToast(`创建失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setCreating(false);
    }
  }, [newName, newType, newCron, newEnabled, addToast]);

  // -- Render --

  const styles = getStyles();

  return (
    <PageShell>
      <PageHeader
        title="自动化规则"
        description="管理自动执行的任务规则"
      />

      <ScrollContainer>
        <div style={styles.container}>
          {/* Info banner */}
          <div style={styles.infoBanner}>
            自动化规则帮助 AcMind 自动执行常见操作。所有规则均可关闭，高风险操作默认关闭。
          </div>

          {/* Loading / Error / Empty states */}
          {loading && <LoadingState title="加载中" description="正在加载规则..." />}
          {error && <ErrorState title="加载失败" reason={error} suggestion="请稍后重试。" action={{ label: '重新加载', onClick: loadTasks }} />}
          {!loading && !error && tasks.length === 0 && (
            <EmptyState
              icon={<PinStackIcon name="settings" size={28} />}
              title="暂无自动化规则"
              description="点击下方按钮添加第一条规则"
            />
          )}

          {/* Task cards */}
          {!loading && !error && tasks.length > 0 && (
            <Section title={`规则列表 (${tasks.length})`}>
              <div style={styles.cardList}>
                {tasks.map((task) => (
                  <Card key={task.id} style={styles.card}>
                    {/* Header row */}
                    <div style={styles.cardHeader}>
                      <span style={styles.cardName}>{task.name}</span>
                      <StatusBadge tone={typeBadgeTone(task.type)} label={typeLabel(task.type)} />
                    </div>

                    {/* Schedule */}
                    <div style={styles.cardMeta}>
                      <span style={styles.metaLabel}>执行频率</span>
                      <span style={styles.metaValue}>{cronToReadable(task.cronExpr)}</span>
                    </div>

                    {/* Status toggle */}
                    <div style={styles.cardMeta}>
                      <span style={styles.metaLabel}>状态</span>
                      <button
                        onClick={() => handleToggle(task.id)}
                        style={{
                          ...styles.toggleBtn,
                          backgroundColor: task.enabled
                            ? 'color-mix(in srgb, var(--pm-status-success, #22c55e) 15%, transparent)'
                            : 'var(--pm-bg-secondary, #f4f4f5)',
                          color: task.enabled
                            ? 'var(--pm-status-success, #22c55e)'
                            : 'var(--pm-text-secondary, #71717a)',
                          borderColor: task.enabled
                            ? 'color-mix(in srgb, var(--pm-status-success, #22c55e) 30%, transparent)'
                            : 'var(--pm-border, #e4e4e7)',
                        }}
                      >
                        {task.enabled ? '已启用' : '已关闭'}
                      </button>
                    </div>

                    {/* Last run */}
                    <div style={styles.cardMeta}>
                      <span style={styles.metaLabel}>上次运行</span>
                      <span style={styles.metaValue}>
                        {task.lastRunAt ? (
                          <>
                            {relativeTime(task.lastRunAt)}
                            {task.lastResult && (
                              <StatusBadge
                                tone={task.lastResult.success ? 'success' : 'danger'}
                                label={task.lastResult.success ? '成功' : '失败'}
                              />
                            )}
                          </>
                        ) : (
                          '从未运行'
                        )}
                      </span>
                    </div>

                    {/* Next run */}
                    <div style={styles.cardMeta}>
                      <span style={styles.metaLabel}>下次运行</span>
                      <span style={styles.metaValue}>
                        {task.nextRunAt
                          ? `${relativeTime(task.nextRunAt)}${task.nextRunAtEstimated ? ' (预估)' : ''}`
                          : '—'}
                      </span>
                    </div>

                    {/* Last result summary */}
                    {task.lastResult?.summary && (
                      <div style={styles.cardMeta}>
                        <span style={styles.metaLabel}>上次结果</span>
                        <span style={styles.metaValue}>{task.lastResult.summary}</span>
                      </div>
                    )}
                    {task.lastResult?.error && (
                      <div style={styles.cardMeta}>
                        <span style={styles.metaLabel}>错误信息</span>
                        <span style={{ ...styles.metaValue, color: 'var(--pm-status-danger, #ef4444)' }}>
                          {task.lastResult.error}
                        </span>
                      </div>
                    )}

                    {/* Actions */}
                    <div style={styles.cardActions}>
                      <Button
                        variant="primary"
                        size="sm"
                        onClick={() => handleRunNow(task.id)}
                      >
                        立即运行
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleDelete(task.id, task.name)}
                        style={{ color: 'var(--pm-status-danger, #ef4444)' }}
                      >
                        删除
                      </Button>
                    </div>
                  </Card>
                ))}
              </div>
            </Section>
          )}

          {/* Add rule button / form */}
          {!loading && !error && (
            <div style={styles.addSection}>
              {!showAddForm ? (
                <Button variant="secondary" onClick={() => setShowAddForm(true)}>
                  添加规则
                </Button>
              ) : (
                <Card style={styles.addFormCard}>
                  <div style={styles.formTitle}>添加新规则</div>

                  <div style={styles.formRow}>
                    <label style={styles.formLabel}>规则名称</label>
                    <input
                      style={styles.formInput}
                      value={newName}
                      onChange={(e) => setNewName(e.target.value)}
                      placeholder="例如：每日自动整理"
                    />
                  </div>

                  <div style={styles.formRow}>
                    <label style={styles.formLabel}>规则类型</label>
                    <select
                      style={styles.formSelect}
                      value={newType}
                      onChange={(e) => setNewType(e.target.value as ScheduledTask['type'])}
                    >
                      <option value="auto_distill">自动整理</option>
                      <option value="auto_export">自动导出</option>
                      <option value="cleanup">自动清理</option>
                    </select>
                  </div>

                  <div style={styles.formRow}>
                    <label style={styles.formLabel}>Cron 表达式</label>
                    <input
                      style={styles.formInput}
                      value={newCron}
                      onChange={(e) => setNewCron(e.target.value)}
                      placeholder="0 */2 * * *"
                    />
                    <div style={styles.formHelp}>
                      常用示例：每2小时 = 0 */2 * * *，每天午夜 = 0 0 * * *，每天早上8点 = 0 8 * * *
                    </div>
                  </div>

                  <div style={styles.formRow}>
                    <label style={styles.formLabel}>启用状态</label>
                    <button
                      onClick={() => setNewEnabled((v) => !v)}
                      style={{
                        ...styles.toggleBtn,
                        backgroundColor: newEnabled
                          ? 'color-mix(in srgb, var(--pm-status-success, #22c55e) 15%, transparent)'
                          : 'var(--pm-bg-secondary, #f4f4f5)',
                        color: newEnabled
                          ? 'var(--pm-status-success, #22c55e)'
                          : 'var(--pm-text-secondary, #71717a)',
                        borderColor: newEnabled
                          ? 'color-mix(in srgb, var(--pm-status-success, #22c55e) 30%, transparent)'
                          : 'var(--pm-border, #e4e4e7)',
                      }}
                    >
                      {newEnabled ? '已启用' : '已关闭'}
                    </button>
                    <div style={styles.formHelp}>出于安全考虑，新规则默认关闭</div>
                  </div>

                  <div style={styles.formActions}>
                    <Button
                      variant="primary"
                      onClick={handleCreate}
                      disabled={creating || !newName.trim()}
                    >
                      {creating ? '创建中...' : '创建规则'}
                    </Button>
                    <Button variant="ghost" onClick={() => setShowAddForm(false)}>
                      取消
                    </Button>
                  </div>
                </Card>
              )}
            </div>
          )}
        </div>
      </ScrollContainer>
    </PageShell>
  );
}

// ---------------------------------------------------------------------------
// Styles (using CSS variables)
// ---------------------------------------------------------------------------

function getStyles() {
  return {
    container: {
      padding: '0 24px 32px',
      maxWidth: 720,
    } as React.CSSProperties,

    infoBanner: {
      padding: '12px 16px',
      borderRadius: 8,
      backgroundColor: 'color-mix(in srgb, var(--pm-status-info, #3b82f6) 8%, transparent)',
      border: '1px solid color-mix(in srgb, var(--pm-status-info, #3b82f6) 20%, transparent)',
      color: 'var(--pm-text-secondary, #52525b)',
      fontSize: 13,
      lineHeight: 1.6,
      marginBottom: 20,
    } as React.CSSProperties,

    cardList: {
      display: 'flex',
      flexDirection: 'column' as const,
      gap: 12,
    } as React.CSSProperties,

    card: {
      padding: 16,
    } as React.CSSProperties,

    cardHeader: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginBottom: 12,
    } as React.CSSProperties,

    cardName: {
      fontWeight: 600,
      fontSize: 15,
      color: 'var(--pm-text-primary, #18181b)',
    } as React.CSSProperties,

    cardMeta: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '4px 0',
    } as React.CSSProperties,

    metaLabel: {
      fontSize: 13,
      color: 'var(--pm-text-tertiary, #a1a1aa)',
      flexShrink: 0,
    } as React.CSSProperties,

    metaValue: {
      fontSize: 13,
      color: 'var(--pm-text-secondary, #52525b)',
      display: 'flex',
      alignItems: 'center',
      gap: 6,
    } as React.CSSProperties,

    toggleBtn: {
      padding: '2px 10px',
      borderRadius: 9999,
      border: '1px solid',
      fontSize: 12,
      cursor: 'pointer',
      transition: 'all 0.15s ease',
    } as React.CSSProperties,

    cardActions: {
      display: 'flex',
      gap: 8,
      marginTop: 12,
      paddingTop: 12,
      borderTop: '1px solid var(--pm-border, #e4e4e7)',
    } as React.CSSProperties,

    addSection: {
      marginTop: 24,
    } as React.CSSProperties,

    addFormCard: {
      padding: 20,
    } as React.CSSProperties,

    formTitle: {
      fontWeight: 600,
      fontSize: 15,
      color: 'var(--pm-text-primary, #18181b)',
      marginBottom: 16,
    } as React.CSSProperties,

    formRow: {
      marginBottom: 14,
    } as React.CSSProperties,

    formLabel: {
      display: 'block',
      fontSize: 13,
      fontWeight: 500,
      color: 'var(--pm-text-secondary, #52525b)',
      marginBottom: 4,
    } as React.CSSProperties,

    formInput: {
      width: '100%',
      padding: '8px 12px',
      borderRadius: 6,
      border: '1px solid var(--pm-border, #e4e4e7)',
      backgroundColor: 'var(--pm-bg-primary, #ffffff)',
      color: 'var(--pm-text-primary, #18181b)',
      fontSize: 13,
      outline: 'none',
      boxSizing: 'border-box' as const,
    } as React.CSSProperties,

    formSelect: {
      width: '100%',
      padding: '8px 12px',
      borderRadius: 6,
      border: '1px solid var(--pm-border, #e4e4e7)',
      backgroundColor: 'var(--pm-bg-primary, #ffffff)',
      color: 'var(--pm-text-primary, #18181b)',
      fontSize: 13,
      outline: 'none',
      boxSizing: 'border-box' as const,
    } as React.CSSProperties,

    formHelp: {
      fontSize: 12,
      color: 'var(--pm-text-tertiary, #a1a1aa)',
      marginTop: 4,
    } as React.CSSProperties,

    formActions: {
      display: 'flex',
      gap: 8,
      marginTop: 16,
    } as React.CSSProperties,
  };
}
