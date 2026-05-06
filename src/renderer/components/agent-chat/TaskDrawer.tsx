import { useMemo } from 'react';
import { Button, Card, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import type { AgentTask, ChatSession } from '../../../shared/types';

interface TaskDrawerProps {
  open: boolean;
  tasks: AgentTask[];
  sessions: ChatSession[];
  selectedTaskId: string | null;
  onClose: () => void;
  onSelectTask: (taskId: string) => void;
  onRunNow: (taskId: string) => void | Promise<void>;
  onCancelTask: (taskId: string) => void | Promise<void>;
  onOpenSession: (sessionId: string) => void | Promise<void>;
  onOpenTaskPage: () => void;
}

function formatTime(ts?: number): string {
  if (!ts) return '-';
  return new Date(ts * 1000).toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function statusTone(
  status: AgentTask['status'],
): 'neutral' | 'info' | 'success' | 'warning' | 'danger' | 'processing' | 'disabled' | 'mock' {
  switch (status) {
    case 'pending':
      return 'neutral';
    case 'running':
      return 'processing';
    case 'completed':
      return 'success';
    case 'failed':
      return 'danger';
    case 'cancelled':
      return 'warning';
    default:
      return 'neutral';
  }
}

export function TaskDrawer({
  open,
  tasks,
  sessions,
  selectedTaskId,
  onClose,
  onSelectTask,
  onRunNow,
  onCancelTask,
  onOpenSession,
  onOpenTaskPage,
}: TaskDrawerProps): JSX.Element | null {
  const selectedTask = useMemo(() => {
    if (selectedTaskId) {
      return tasks.find((task) => task.id === selectedTaskId) ?? null;
    }
    return tasks[0] ?? null;
  }, [selectedTaskId, tasks]);

  const pendingCount = tasks.filter((task) => task.status === 'pending').length;
  const runningCount = tasks.filter((task) => task.status === 'running').length;
  const completedCount = tasks.filter((task) => task.status === 'completed').length;

  if (!open) return null;

  return (
    <>
      <div className="fixed inset-0 z-20 bg-[rgba(15,23,42,0.18)] backdrop-blur-[1px]" onClick={onClose} />

      <aside
        className="fixed bottom-0 right-0 z-30 flex flex-col border-l border-[rgba(15,23,42,0.08)] bg-white/92 shadow-[0_24px_72px_rgba(15,23,42,0.12)] backdrop-blur-2xl"
        style={{
          width: 'min(92vw, 420px)',
          top: 'var(--pm-topbar-height, 64px)',
        }}
      >
        <div className="border-b border-[rgba(15,23,42,0.06)] px-5 py-4">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[color:var(--pm-text-tertiary)]">
                待处理任务
              </p>
              <h2 className="mt-1 text-[18px] font-semibold tracking-[-0.02em] text-[color:var(--pm-text-primary)]">
                任务详情
              </h2>
            </div>
            <Button variant="ghost" size="sm" onClick={onClose}>
              关闭
            </Button>
          </div>

          <div className="mt-3 flex flex-wrap gap-2">
            <StatusBadge tone="neutral" label={`待处理 ${pendingCount}`} dot={false} />
            <StatusBadge tone="processing" label={`运行中 ${runningCount}`} dot={false} />
            <StatusBadge tone="success" label={`已完成 ${completedCount}`} dot={false} />
          </div>

          <div className="mt-4 flex gap-2">
            <Button variant="secondary" size="sm" className="flex-1" onClick={onOpenTaskPage}>
              打开任务页
            </Button>
            <Button
              variant="primary"
              size="sm"
              className="flex-1"
              onClick={() => selectedTask && onRunNow(selectedTask.id)}
              disabled={!selectedTask}
            >
              立即运行
            </Button>
          </div>
        </div>

        <div className="flex-1 min-h-0 overflow-y-auto px-3 py-3">
          <div className="space-y-2">
            {tasks.length > 0 ? (
              tasks.map((task) => {
                const session = sessions.find((item) => item.id === task.sessionId);
                const active = task.id === selectedTask?.id;
                return (
                  <button
                    key={task.id}
                    type="button"
                    onClick={() => onSelectTask(task.id)}
                    className={`w-full rounded-[18px] border p-3 text-left transition-all duration-200 ${
                      active
                        ? 'border-[rgba(255,107,43,0.22)] bg-[color:var(--pm-primary-soft)] shadow-[0_10px_24px_rgba(255,107,43,0.08)]'
                        : 'border-[rgba(15,23,42,0.06)] bg-white/80 hover:-translate-y-0.5 hover:shadow-[0_12px_28px_rgba(15,23,42,0.06)]'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="truncate text-[13px] font-semibold text-[color:var(--pm-text-primary)]">
                          {task.name}
                        </div>
                        <div className="mt-1 truncate text-[11px] text-[color:var(--pm-text-tertiary)]">
                          {session?.title || '未关联会话'}
                        </div>
                      </div>
                      <StatusBadge tone={statusTone(task.status)} label={task.status} dot={false} />
                    </div>
                    <div className="mt-2 flex items-center justify-between gap-2">
                      <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                        {task.skillName || '未指定技能'}
                      </span>
                      <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                        {formatTime(task.updatedAt)}
                      </span>
                    </div>
                  </button>
                );
              })
            ) : (
              <Card className="mx-2 rounded-[20px] border border-[rgba(15,23,42,0.06)] bg-white/80 p-4 text-center">
                <div className="mx-auto mb-3 inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-[color:var(--pm-primary-soft)] text-[color:var(--pm-primary)]">
                  <AcMindIcon name="filled-flag" size={18} />
                </div>
                <p className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">暂无任务</p>
                <p className="mt-1 text-[12px] leading-5 text-[color:var(--pm-text-secondary)]">
                  你发起的任务会显示在这里，便于随时查看结果和日志。
                </p>
              </Card>
            )}
          </div>

          {selectedTask ? (
            <Card className="mt-4 rounded-[22px] border border-[rgba(15,23,42,0.06)] bg-white/85 p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[color:var(--pm-text-tertiary)]">
                    选中任务
                  </p>
                  <h3 className="mt-1 truncate text-[15px] font-semibold text-[color:var(--pm-text-primary)]">
                    {selectedTask.name}
                  </h3>
                </div>
                <StatusBadge tone={statusTone(selectedTask.status)} label={selectedTask.status} dot={false} />
              </div>

              <div className="mt-4 grid gap-3">
                <div className="rounded-[16px] border border-[rgba(15,23,42,0.06)] bg-[rgba(17,24,39,0.02)] p-3">
                  <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">会话</p>
                  <button
                    type="button"
                    className="mt-1 text-left text-[13px] font-medium text-[color:var(--pm-primary)]"
                    onClick={() => onOpenSession(selectedTask.sessionId)}
                  >
                    {sessions.find((item) => item.id === selectedTask.sessionId)?.title || '打开关联会话'}
                  </button>
                </div>

                <div className="grid gap-3 sm:grid-cols-2">
                  <div className="rounded-[16px] border border-[rgba(15,23,42,0.06)] bg-[rgba(17,24,39,0.02)] p-3">
                    <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">技能</p>
                    <p className="mt-1 text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                      {selectedTask.skillName || '未指定'}
                    </p>
                  </div>
                  <div className="rounded-[16px] border border-[rgba(15,23,42,0.06)] bg-[rgba(17,24,39,0.02)] p-3">
                    <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">更新时间</p>
                    <p className="mt-1 text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                      {formatTime(selectedTask.updatedAt)}
                    </p>
                  </div>
                </div>

                <div className="rounded-[16px] border border-[rgba(15,23,42,0.06)] bg-[rgba(17,24,39,0.02)] p-3">
                  <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">输入参数</p>
                  <pre className="mt-2 max-h-[120px] overflow-auto whitespace-pre-wrap break-words text-[11px] leading-5 text-[color:var(--pm-text-secondary)]">
                    {JSON.stringify(selectedTask.inputParams ?? {}, null, 2)}
                  </pre>
                </div>

                <div className="rounded-[16px] border border-[rgba(15,23,42,0.06)] bg-[rgba(17,24,39,0.02)] p-3">
                  <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">结果</p>
                  <p className="mt-2 whitespace-pre-wrap text-[13px] leading-6 text-[color:var(--pm-text-secondary)]">
                    {selectedTask.result || selectedTask.error || '暂无结果'}
                  </p>
                </div>
              </div>

              <div className="mt-4 flex gap-2">
                <Button
                  variant="secondary"
                  size="sm"
                  className="flex-1"
                  onClick={() => onOpenSession(selectedTask.sessionId)}
                >
                  查看会话
                </Button>
                <Button variant="secondary" size="sm" className="flex-1" onClick={() => onCancelTask(selectedTask.id)}>
                  取消任务
                </Button>
              </div>
            </Card>
          ) : null}
        </div>
      </aside>
    </>
  );
}
