import { useCallback, useEffect, useState } from 'react';
import { Button, Card, EmptyState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { useAgentTasks } from '../../hooks/useAgentTasks';
import type { AgentTask, AgentTaskEvent, ScheduledAgentTask } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------

type StatusTone = 'neutral' | 'info' | 'success' | 'warning' | 'danger' | 'processing' | 'disabled' | 'mock';

const STATUS_CONFIG: Record<AgentTask['status'], { label: string; tone: StatusTone }> = {
  pending: { label: '等待中', tone: 'neutral' },
  running: { label: '运行中', tone: 'processing' },
  completed: { label: '已完成', tone: 'success' },
  failed: { label: '失败', tone: 'danger' },
  cancelled: { label: '已取消', tone: 'warning' },
};

const SCHEDULED_STATUS_CONFIG: Record<NonNullable<ScheduledAgentTask['lastRunStatus']>, { label: string; tone: StatusTone }> = {
  success: { label: '成功', tone: 'success' },
  error: { label: '失败', tone: 'danger' },
  timeout: { label: '超时', tone: 'warning' },
};

// Cron presets
const CRON_PRESETS = [
  { label: '每小时', value: '0 * * * *' },
  { label: '每天 9:00', value: '0 9 * * *' },
  { label: '每天 18:00', value: '0 18 * * *' },
  { label: '每周一 9:00', value: '0 9 * * 1' },
  { label: '每周五 18:00', value: '0 18 * * 5' },
  { label: '每月 1 日 9:00', value: '0 9 1 * *' },
];

function formatTime(ts?: number): string {
  if (!ts) return '-';
  return new Date(ts * 1000).toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ---------------------------------------------------------------------------
// CreateTaskDialog
// ---------------------------------------------------------------------------

function CreateTaskDialog({
  open,
  onClose,
  onSubmit,
}: {
  open: boolean;
  onClose: () => void;
  onSubmit: (params: { name: string; skillName: string }) => void;
}) {
  const [name, setName] = useState('');
  const [skillName, setSkillName] = useState('scan_inbox');

  if (!open) return null;

  const handleSubmit = () => {
    if (!name.trim()) return;
    onSubmit({ name: name.trim(), skillName });
    setName('');
    setSkillName('scan_inbox');
    onClose();
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 100,
      }}
      onClick={onClose}
    >
      <Card
        style={{
          width: 420,
          padding: 24,
          background: 'var(--pm-bg-canvas)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 16, color: 'var(--text-title)' }}>
          创建新任务
        </h3>

        <div style={{ marginBottom: 12 }}>
          <label style={{ display: 'block', fontSize: 13, fontWeight: 500, marginBottom: 4, color: 'var(--text-secondary)' }}>
            任务名称
          </label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="例如：扫描暂存池"
            style={{
              width: '100%',
              padding: '8px 12px',
              borderRadius: 8,
              border: '1px solid var(--border-light)',
              background: 'var(--pm-bg-canvas)',
              color: 'var(--text-title)',
              fontSize: 14,
              outline: 'none',
              boxSizing: 'border-box',
            }}
          />
        </div>

        <div style={{ marginBottom: 16 }}>
          <label style={{ display: 'block', fontSize: 13, fontWeight: 500, marginBottom: 4, color: 'var(--text-secondary)' }}>
            技能
          </label>
          <select
            value={skillName}
            onChange={(e) => setSkillName(e.target.value)}
            style={{
              width: '100%',
              padding: '8px 12px',
              borderRadius: 8,
              border: '1px solid var(--border-light)',
              background: 'var(--pm-bg-canvas)',
              color: 'var(--text-title)',
              fontSize: 14,
              outline: 'none',
              boxSizing: 'border-box',
            }}
          >
            <option value="scan_inbox">扫描暂存池</option>
            <option value="check_acmind">检查系统状态</option>
            <option value="scan_obsidian_inbox">扫描 Obsidian Inbox</option>
            <option value="web_scraper">网页抓取</option>
            <option value="file_search">文件搜索</option>
            <option value="markdown_generator">Markdown 生成</option>
          </select>
        </div>

        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <Button variant="ghost" onClick={onClose}>取消</Button>
          <Button variant="primary" onClick={handleSubmit} disabled={!name.trim()}>创建</Button>
        </div>
      </Card>
    </div>
  );
}

// ---------------------------------------------------------------------------
// CreateScheduledTaskDialog
// ---------------------------------------------------------------------------

function CreateScheduledTaskDialog({
  open,
  onClose,
  onSubmit,
}: {
  open: boolean;
  onClose: () => void;
  onSubmit: (params: { name: string; cronExpression: string; skillName: string }) => void;
}) {
  const [name, setName] = useState('');
  const [skillName, setSkillName] = useState('scan_inbox');
  const [cronExpression, setCronExpression] = useState('0 9 * * *');

  if (!open) return null;

  const handlePresetClick = (preset: typeof CRON_PRESETS[0]) => {
    setCronExpression(preset.value);
  };

  const handleSubmit = () => {
    if (!name.trim()) return;
    onSubmit({ name: name.trim(), cronExpression, skillName });
    setName('');
    setSkillName('scan_inbox');
    setCronExpression('0 9 * * *');
    onClose();
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 100,
      }}
      onClick={onClose}
    >
      <Card
        style={{
          width: 480,
          padding: 24,
          background: 'var(--pm-bg-canvas)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <h3 style={{ fontSize: 16, fontWeight: 600, marginBottom: 16, color: 'var(--text-title)' }}>
          创建定时任务
        </h3>

        <div style={{ marginBottom: 12 }}>
          <label style={{ display: 'block', fontSize: 13, fontWeight: 500, marginBottom: 4, color: 'var(--text-secondary)' }}>
            任务名称
          </label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="例如：每日扫描暂存池"
            style={{
              width: '100%',
              padding: '8px 12px',
              borderRadius: 8,
              border: '1px solid var(--border-light)',
              background: 'var(--pm-bg-canvas)',
              color: 'var(--text-title)',
              fontSize: 14,
              outline: 'none',
              boxSizing: 'border-box',
            }}
          />
        </div>

        <div style={{ marginBottom: 12 }}>
          <label style={{ display: 'block', fontSize: 13, fontWeight: 500, marginBottom: 4, color: 'var(--text-secondary)' }}>
            技能
          </label>
          <select
            value={skillName}
            onChange={(e) => setSkillName(e.target.value)}
            style={{
              width: '100%',
              padding: '8px 12px',
              borderRadius: 8,
              border: '1px solid var(--border-light)',
              background: 'var(--pm-bg-canvas)',
              color: 'var(--text-title)',
              fontSize: 14,
              outline: 'none',
              boxSizing: 'border-box',
            }}
          >
            <option value="scan_inbox">扫描暂存池</option>
            <option value="check_acmind">检查系统状态</option>
            <option value="scan_obsidian_inbox">扫描 Obsidian Inbox</option>
            <option value="web_scraper">网页抓取</option>
            <option value="file_search">文件搜索</option>
            <option value="markdown_generator">Markdown 生成</option>
          </select>
        </div>

        <div style={{ marginBottom: 12 }}>
          <label style={{ display: 'block', fontSize: 13, fontWeight: 500, marginBottom: 4, color: 'var(--text-secondary)' }}>
            Cron 表达式
          </label>
          <input
            type="text"
            value={cronExpression}
            onChange={(e) => setCronExpression(e.target.value)}
            placeholder="0 9 * * *"
            style={{
              width: '100%',
              padding: '8px 12px',
              borderRadius: 8,
              border: '1px solid var(--border-light)',
              background: 'var(--pm-bg-canvas)',
              color: 'var(--text-title)',
              fontSize: 14,
              outline: 'none',
              boxSizing: 'border-box',
              fontFamily: 'monospace',
            }}
          />
        </div>

        <div style={{ marginBottom: 16 }}>
          <label style={{ display: 'block', fontSize: 13, fontWeight: 500, marginBottom: 4, color: 'var(--text-secondary)' }}>
            快捷预设
          </label>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {CRON_PRESETS.map((preset) => (
              <button
                key={preset.value}
                type="button"
                onClick={() => handlePresetClick(preset)}
                style={{
                  padding: '4px 10px',
                  borderRadius: 6,
                  border: cronExpression === preset.value ? '1px solid var(--pm-brand)' : '1px solid var(--border-light)',
                  background: cronExpression === preset.value ? 'var(--pm-brand-soft)' : 'var(--pm-bg-subtle)',
                  color: cronExpression === preset.value ? 'var(--pm-brand)' : 'var(--text-secondary)',
                  fontSize: 12,
                  cursor: 'pointer',
                }}
              >
                {preset.label}
              </button>
            ))}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <Button variant="ghost" onClick={onClose}>取消</Button>
          <Button variant="primary" onClick={handleSubmit} disabled={!name.trim()}>创建</Button>
        </div>
      </Card>
    </div>
  );
}

// ---------------------------------------------------------------------------
// TaskEventList
// ---------------------------------------------------------------------------

function TaskEventList({ taskId, getHistory }: { taskId: string; getHistory: (id: string) => Promise<AgentTaskEvent[]> }) {
  const [events, setEvents] = useState<AgentTaskEvent[]>([]);
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    if (!expanded) return;
    getHistory(taskId).then(setEvents);
  }, [expanded, taskId, getHistory]);

  if (!expanded) {
    return (
      <button
        type="button"
        onClick={() => setExpanded(true)}
        style={{
          background: 'none',
          border: 'none',
          color: 'var(--pm-brand)',
          cursor: 'pointer',
          fontSize: 12,
          padding: '4px 0',
        }}
      >
        查看执行记录
      </button>
    );
  }

  return (
    <div style={{ marginTop: 8 }}>
      <button
        type="button"
        onClick={() => setExpanded(false)}
        style={{
          background: 'none',
          border: 'none',
          color: 'var(--text-muted)',
          cursor: 'pointer',
          fontSize: 12,
          padding: '4px 0',
          marginBottom: 4,
        }}
      >
        收起记录
      </button>
      {events.length === 0 ? (
        <p style={{ fontSize: 12, color: 'var(--text-muted)' }}>暂无执行记录</p>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          {events.map((evt) => (
            <div
              key={evt.id}
              style={{
                fontSize: 12,
                padding: '4px 8px',
                borderRadius: 4,
                background: 'var(--pm-bg-subtle)',
                color: 'var(--text-secondary)',
              }}
            >
              <span style={{ color: 'var(--text-muted)', marginRight: 8 }}>
                {formatTime(evt.createdAt)}
              </span>
              <span style={{ fontWeight: 500, marginRight: 8 }}>
                [{evt.eventType}]
              </span>
              {evt.description}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// TaskCard
// ---------------------------------------------------------------------------

function TaskCard({
  task,
  onRunNow,
  onCancel,
  onDelete,
  getHistory,
}: {
  task: AgentTask;
  onRunNow: (id: string) => void;
  onCancel: (id: string) => void;
  onDelete: (id: string) => void;
  getHistory: (id: string) => Promise<AgentTaskEvent[]>;
}) {
  const statusCfg = STATUS_CONFIG[task.status];

  return (
    <Card style={{ padding: 16 }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-title)' }}>
              {task.name}
            </span>
            <StatusBadge tone={statusCfg.tone} label={statusCfg.label} />
          </div>
          {task.skillName && (
            <p style={{ fontSize: 12, color: 'var(--text-muted)', margin: 0 }}>
              技能: {task.skillName}
            </p>
          )}
          <div style={{ display: 'flex', gap: 16, marginTop: 4, fontSize: 12, color: 'var(--text-muted)' }}>
            <span>创建: {formatTime(task.createdAt)}</span>
            {task.completedAt && <span>完成: {formatTime(task.completedAt)}</span>}
          </div>
          {task.error && (
            <p style={{ fontSize: 12, color: 'var(--pm-danger)', margin: '4px 0 0' }}>
              错误: {task.error}
            </p>
          )}
          {task.result && (
            <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: '4px 0 0', maxWidth: 400, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              结果: {task.result}
            </p>
          )}
          <TaskEventList taskId={task.id} getHistory={getHistory} />
        </div>

        <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
          {(task.status === 'pending' || task.status === 'failed' || task.status === 'completed') && (
            <Button variant="ghost" size="sm" onClick={() => onRunNow(task.id)}>
              执行
            </Button>
          )}
          {task.status === 'running' && (
            <Button variant="ghost" size="sm" onClick={() => onCancel(task.id)}>
              取消
            </Button>
          )}
          <Button variant="ghost" size="sm" onClick={() => onDelete(task.id)}>
            删除
          </Button>
        </div>
      </div>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// ScheduledTaskCard
// ---------------------------------------------------------------------------

function ScheduledTaskCard({
  task,
  onToggle,
  onRunNow,
  onDelete,
}: {
  task: ScheduledAgentTask;
  onToggle: (id: string, enabled: boolean) => void;
  onRunNow: (id: string) => void;
  onDelete: (id: string) => void;
}) {
  const statusCfg = task.lastRunStatus ? SCHEDULED_STATUS_CONFIG[task.lastRunStatus] : null;

  return (
    <Card style={{ padding: 16 }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-title)' }}>
              {task.name}
            </span>
            <StatusBadge tone={task.enabled ? 'success' : 'disabled'} label={task.enabled ? '已启用' : '已禁用'} />
            {statusCfg && <StatusBadge tone={statusCfg.tone} label={statusCfg.label} />}
          </div>
          <p style={{ fontSize: 12, color: 'var(--text-muted)', margin: 0 }}>
            技能: {task.skillName}
          </p>
          <div style={{ display: 'flex', gap: 16, marginTop: 4, fontSize: 12, color: 'var(--text-muted)' }}>
            <span style={{ fontFamily: 'monospace' }}>Cron: {task.cronExpression}</span>
            {task.lastRunAt && <span>上次运行: {formatTime(task.lastRunAt)}</span>}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => onToggle(task.id, !task.enabled)}
          >
            {task.enabled ? '禁用' : '启用'}
          </Button>
          <Button variant="ghost" size="sm" onClick={() => onRunNow(task.id)}>
            立即执行
          </Button>
          <Button variant="ghost" size="sm" onClick={() => onDelete(task.id)}>
            删除
          </Button>
        </div>
      </div>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// AgentTasksPage
// ---------------------------------------------------------------------------

export function AgentTasksPage(): JSX.Element {
  const {
    tasks,
    loading,
    error,
    createTask,
    runNow,
    cancelTask,
    deleteTask,
    getHistory,
  } = useAgentTasks();

  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showCreateScheduledDialog, setShowCreateScheduledDialog] = useState(false);
  const [scheduledTasks, setScheduledTasks] = useState<ScheduledAgentTask[]>([]);

  // Load scheduled tasks
  useEffect(() => {
    const loadScheduledTasks = async () => {
      const result = await window.acmind.scheduledAgentTasks.list();
      if (result.success) {
        setScheduledTasks(result.tasks);
      }
    };
    loadScheduledTasks();

    // Subscribe to changes
    const unsubscribe = window.acmind.scheduledAgentTasks.onTaskChanged(() => {
      loadScheduledTasks();
    });

    return unsubscribe;
  }, []);

  const handleCreate = useCallback(async (params: { name: string; skillName: string }) => {
    // Use a default session ID for standalone tasks
    await createTask({
      sessionId: '__standalone__',
      name: params.name,
      skillName: params.skillName,
    });
    setShowCreateDialog(false);
  }, [createTask]);

  const handleCreateScheduled = useCallback(async (params: { name: string; cronExpression: string; skillName: string }) => {
    await window.acmind.scheduledAgentTasks.create({
      name: params.name,
      cronExpression: params.cronExpression,
      skillName: params.skillName,
    });
    setShowCreateScheduledDialog(false);
  }, []);

  const handleToggleScheduled = useCallback(async (id: string, enabled: boolean) => {
    await window.acmind.scheduledAgentTasks.update(id, { enabled });
  }, []);

  const handleRunScheduledNow = useCallback(async (id: string) => {
    await window.acmind.scheduledAgentTasks.runNow(id);
  }, []);

  const handleDeleteScheduled = useCallback(async (id: string) => {
    await window.acmind.scheduledAgentTasks.delete(id);
  }, []);

  if (loading && tasks.length === 0) {
    return (
      <PageShell>
        <PageHeader title="定时任务" description="Agent 任务执行与管理" />
        <LoadingState title="加载中" description="正在加载任务列表..." />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <PageHeader
        title="定时任务"
        description="Agent 任务执行与管理"
        actions={
          <div style={{ display: 'flex', gap: 8 }}>
            <Button variant="secondary" onClick={() => setShowCreateScheduledDialog(true)}>
              创建定时任务
            </Button>
            <Button variant="primary" onClick={() => setShowCreateDialog(true)}>
              新建任务
            </Button>
          </div>
        }
      />

      {error && (
        <div style={{ padding: '0 0 12px' }}>
          <div style={{ padding: 12, borderRadius: 8, background: 'var(--pm-danger-soft)', color: 'var(--pm-danger)', fontSize: 13 }}>
            {error}
          </div>
        </div>
      )}

      {/* Scheduled Tasks Section */}
      {scheduledTasks.length > 0 && (
        <Section title="定时任务">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {scheduledTasks.map(task => (
              <ScheduledTaskCard
                key={task.id}
                task={task}
                onToggle={handleToggleScheduled}
                onRunNow={handleRunScheduledNow}
                onDelete={handleDeleteScheduled}
              />
            ))}
          </div>
        </Section>
      )}

      <Section title="任务列表">
        {tasks.length === 0 ? (
          <EmptyState
            title="暂无任务"
            description="点击「新建任务」创建第一个 Agent 任务，或点击「创建定时任务」设置自动执行。"
          />
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {tasks.map(task => (
              <TaskCard
                key={task.id}
                task={task}
                onRunNow={runNow}
                onCancel={cancelTask}
                onDelete={deleteTask}
                getHistory={getHistory}
              />
            ))}
          </div>
        )}
      </Section>

      <CreateTaskDialog
        open={showCreateDialog}
        onClose={() => setShowCreateDialog(false)}
        onSubmit={handleCreate}
      />

      <CreateScheduledTaskDialog
        open={showCreateScheduledDialog}
        onClose={() => setShowCreateScheduledDialog(false)}
        onSubmit={handleCreateScheduled}
      />
    </PageShell>
  );
}
