/**
 * AIPage — AI Runtime 主页面 (Phase 4 增强)
 *
 * 功能：
 * - AI Action 管理（创建/编辑/删除/运行）
 * - AI Job 监控（任务列表/取消）
 * - Provider 健康检查
 * - 运行结果预览
 */

import { useState, useCallback } from 'react';
import { PinStackIcon } from '../../design-system/icons';
import {
  PageShell,
  PageHeader,
  Section,
  Button,
  Card,
  StatusBadge,
  EmptyState,
  ErrorState,
  LoadingState,
  Input,
} from '../../design-system/components';
import { useAI } from '../../hooks/useAI';
import { useToast } from '../../components/shared/ToastViewport';
import type { AIAction, AIActionType, AiTask, SourceType, ProcessedContent } from '../../../shared/types';

// ── Action 类型选项 ─────────────────────────────────────────────

const ACTION_TYPE_OPTIONS: Array<{ value: AIActionType; label: string; description: string }> = [
  { value: 'summarize', label: '摘要', description: '生成内容摘要' },
  { value: 'rewrite', label: '改写', description: '改写/润色文本' },
  { value: 'translate', label: '翻译', description: '翻译文本' },
  { value: 'extract_todos', label: '提取待办', description: '从文本中提取待办事项' },
  { value: 'to_markdown', label: '转 Markdown', description: '将内容转为 Markdown 格式' },
  { value: 'custom', label: '自定义', description: '自定义 AI 处理' },
];

const SOURCE_TYPE_OPTIONS: Array<{ value: SourceType; label: string }> = [
  { value: 'manual_text', label: '手动文本' },
  { value: 'clipboard_text', label: '剪贴板' },
  { value: 'webpage', label: '网页' },
  { value: 'screenshot', label: '截图' },
  { value: 'pdf', label: 'PDF' },
  { value: 'docx', label: 'DOCX' },
  { value: 'image', label: '图片' },
];

// ── Main Page ───────────────────────────────────────────────────

export function AIPage(): JSX.Element {
  const { actions, jobs, loading, error, createAction, deleteAction, runAction, cancelJob, refresh } = useAI();
  const { addToast } = useToast();

  const [showCreateForm, setShowCreateForm] = useState(false);
  const [runDialog, setRunDialog] = useState<{ action: AIAction; input: string } | null>(null);
  const [runResult, setRunResult] = useState<ProcessedContent | null>(null);
  const [busyAction, setBusyAction] = useState<string | null>(null);

  // 创建 Action
  const handleCreate = useCallback(async (params: { name: string; inputTypes: SourceType[]; actionType: AIActionType }) => {
    setBusyAction('create');
    try {
      const action = await createAction(params);
      addToast(action ? `已创建 Action: ${action.name}` : '创建失败', action ? 'success' : 'error');
      if (action) setShowCreateForm(false);
    } finally {
      setBusyAction(null);
    }
  }, [createAction, addToast]);

  // 删除 Action
  const handleDelete = useCallback(async (id: string, name: string) => {
    setBusyAction(`delete-${id}`);
    try {
      const ok = await deleteAction(id);
      addToast(ok ? `已删除: ${name}` : '删除失败', ok ? 'success' : 'error');
    } finally {
      setBusyAction(null);
    }
  }, [deleteAction, addToast]);

  // 运行 Action
  const handleRun = useCallback(async () => {
    if (!runDialog) return;
    setBusyAction(`run-${runDialog.action.id}`);
    setRunResult(null);
    try {
      const result = await runAction(runDialog.action.id, runDialog.input);
      if (result.success && result.content) {
        setRunResult(result.content);
        addToast(`处理完成 (${result.modelCall?.latencyMs ?? 0}ms, 质量: ${result.qualityScore ?? 0})`, 'success');
      } else {
        addToast(`运行失败: ${result.error || '未知错误'}`, 'error');
      }
    } finally {
      setBusyAction(null);
    }
  }, [runDialog, runAction, addToast]);

  // 取消 Job
  const handleCancelJob = useCallback(async (id: string) => {
    await cancelJob(id);
    addToast('已取消任务', 'info');
  }, [cancelJob, addToast]);

  if (loading) {
    return <PageShell><LoadingState title="加载 AI Runtime" description="正在获取配置..." /></PageShell>;
  }

  if (error) {
    return (
      <PageShell>
        <ErrorState
          title="加载失败"
          reason={error}
          suggestion="请检查应用状态后重试"
          action={{ label: '重试', onClick: () => void refresh() }}
        />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <PageHeader
        title="AI Runtime"
        description="管理 AI 动作、监控任务队列"
        actions={
          <Button
            variant="primary"
            leadingIcon={<PinStackIcon name="act-quick-capture" size={16} />}
            busy={busyAction === 'create'}
            onClick={() => setShowCreateForm(true)}
          >
            新建 Action
          </Button>
        }
      />

      {/* 创建 Action 表单 */}
      {showCreateForm && (
        <CreateActionForm
          onSubmit={(params) => void handleCreate(params)}
          onCancel={() => setShowCreateForm(false)}
          busy={busyAction === 'create'}
        />
      )}

      {/* 运行对话框 */}
      {runDialog && (
        <RunActionDialog
          action={runDialog.action}
          input={runDialog.input}
          onInputChange={(input) => setRunDialog({ ...runDialog, input })}
          onRun={() => void handleRun()}
          onClose={() => { setRunDialog(null); setRunResult(null); }}
          busy={busyAction === `run-${runDialog.action.id}`}
          result={runResult}
        />
      )}

      {/* Action 列表 */}
      <Section
        title="AI Actions"
        description={`共 ${actions.length} 个动作`}
      >
        {actions.length === 0 ? (
          <EmptyState
            icon={<PinStackIcon name="sb-ai-process" size={28} />}
            title="暂无 AI Action"
            description="创建 Action 来定义 AI 处理流程"
            action={{ label: '新建 Action', onClick: () => setShowCreateForm(true) }}
          />
        ) : (
          <div className="flex flex-col gap-2">
            {actions.map((action) => (
              <ActionRow
                key={action.id}
                action={action}
                busy={busyAction}
                onRun={() => setRunDialog({ action, input: '' })}
                onDelete={() => void handleDelete(action.id, action.name)}
              />
            ))}
          </div>
        )}
      </Section>

      {/* Job 监控 */}
      <Section
        title="任务队列"
        description={`共 ${jobs.length} 个任务`}
        action={
          <Button variant="ghost" size="sm" onClick={() => void refresh()}>
            刷新
          </Button>
        }
      >
        {jobs.length === 0 ? (
          <EmptyState
            icon={<PinStackIcon name="status-waiting" size={28} />}
            title="暂无任务"
            description="运行 AI Action 后会在此显示任务状态"
          />
        ) : (
          <div className="flex flex-col gap-2">
            {jobs.map((job) => (
              <JobRow
                key={job.id}
                job={job}
                onCancel={() => void handleCancelJob(job.id)}
              />
            ))}
          </div>
        )}
      </Section>
    </PageShell>
  );
}

// ── Action 行 ───────────────────────────────────────────────────

interface ActionRowProps {
  action: AIAction;
  busy: string | null;
  onRun: () => void;
  onDelete: () => void;
}

function ActionRow({ action, busy, onRun, onDelete }: ActionRowProps): JSX.Element {
  const typeLabel = ACTION_TYPE_OPTIONS.find((o) => o.value === action.actionType)?.label ?? action.actionType;
  const inputLabels = action.inputTypes.map((t) => SOURCE_TYPE_OPTIONS.find((o) => o.value === t)?.label ?? t).join(', ');

  return (
    <Card variant="interactive" className="flex items-center gap-3 p-3">
      <div className="flex h-8 w-8 items-center justify-center rounded-[6px] bg-[color:var(--pm-surface-muted)]">
        <PinStackIcon name="sb-ai-process" size={16} />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="truncate text-[13px] font-medium text-[color:var(--pm-text-primary)]">{action.name}</span>
          <StatusBadge tone="info" label={typeLabel} dot={false} />
          {!action.enabled && <StatusBadge tone="neutral" label="已禁用" dot={false} />}
        </div>
        <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">
          输入类型: {inputLabels || '全部'}
        </div>
      </div>
      <div className="flex items-center gap-1">
        <Button
          variant="primary"
          size="sm"
          busy={busy === `run-${action.id}`}
          onClick={onRun}
          disabled={!action.enabled}
        >
          运行
        </Button>
        <Button
          variant="ghost"
          size="sm"
          busy={busy === `delete-${action.id}`}
          onClick={onDelete}
        >
          删除
        </Button>
      </div>
    </Card>
  );
}

// ── Job 行 ──────────────────────────────────────────────────────

interface JobRowProps {
  job: AiTask;
  onCancel: () => void;
}

function JobRow({ job, onCancel }: JobRowProps): JSX.Element {
  const statusTone = job.status === 'done' ? 'success' : job.status === 'failed' ? 'danger' : job.status === 'running' ? 'info' : job.status === 'cancelled' ? 'neutral' : 'warning';
  const statusLabel = job.status === 'done' ? '完成' : job.status === 'failed' ? '失败' : job.status === 'running' ? '运行中' : job.status === 'cancelled' ? '已取消' : '排队中';

  const timeStr = new Date(job.createdAt).toLocaleString('zh-CN', {
    month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
  });

  const latency = job.finishedAt && job.startedAt ? job.finishedAt - job.startedAt : 0;

  return (
    <Card variant="interactive" className="flex items-center gap-3 p-3">
      <div className="flex h-8 w-8 items-center justify-center rounded-[6px] bg-[color:var(--pm-surface-muted)]">
        <PinStackIcon name="status-running" size={16} />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">{job.operation}</span>
          <StatusBadge tone={statusTone} label={statusLabel} dot={false} />
        </div>
        <div className="flex items-center gap-3 text-[11px] text-[color:var(--pm-text-tertiary)]">
          <span>{timeStr}</span>
          {job.model && <span>模型: {job.model}</span>}
          {latency > 0 && <span>{latency}ms</span>}
        </div>
        {job.error && (
          <div className="mt-1 text-[11px] text-[color:var(--pm-text-error)]">{job.error}</div>
        )}
      </div>
      {(job.status === 'running' || job.status === 'queued') && (
        <Button variant="ghost" size="sm" onClick={onCancel}>取消</Button>
      )}
    </Card>
  );
}

// ── 创建 Action 表单 ────────────────────────────────────────────

interface CreateActionFormProps {
  onSubmit: (params: { name: string; inputTypes: SourceType[]; actionType: AIActionType }) => void;
  onCancel: () => void;
  busy: boolean;
}

function CreateActionForm({ onSubmit, onCancel, busy }: CreateActionFormProps): JSX.Element {
  const [name, setName] = useState('');
  const [actionType, setActionType] = useState<AIActionType>('summarize');
  const [inputTypes, setInputTypes] = useState<SourceType[]>(['manual_text']);

  const toggleInputType = (t: SourceType) => {
    setInputTypes((prev) => prev.includes(t) ? prev.filter((x) => x !== t) : [...prev, t]);
  };

  return (
    <Card className="mb-4 p-4">
      <h3 className="mb-3 text-[14px] font-semibold text-[color:var(--pm-text-primary)]">新建 AI Action</h3>
      <div className="flex flex-col gap-3">
        <div>
          <label className="mb-1 block text-[12px] text-[color:var(--pm-text-secondary)]">名称</label>
          <Input
            value={name}
            onChange={(e) => setName((e.target as HTMLInputElement).value)}
            placeholder="例如: 摘要生成"
          />
        </div>
        <div>
          <label className="mb-1 block text-[12px] text-[color:var(--pm-text-secondary)]">类型</label>
          <div className="flex flex-wrap gap-2">
            {ACTION_TYPE_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                className={`rounded-[6px] px-3 py-1.5 text-[12px] transition-colors ${
                  actionType === opt.value
                    ? 'bg-[color:var(--pm-accent)] text-white'
                    : 'bg-[color:var(--pm-surface-muted)] text-[color:var(--pm-text-secondary)] hover:bg-[color:var(--pm-surface-hover)]'
                }`}
                onClick={() => setActionType(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>
        <div>
          <label className="mb-1 block text-[12px] text-[color:var(--pm-text-secondary)]">输入类型</label>
          <div className="flex flex-wrap gap-2">
            {SOURCE_TYPE_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                className={`rounded-[6px] px-3 py-1.5 text-[12px] transition-colors ${
                  inputTypes.includes(opt.value)
                    ? 'bg-[color:var(--pm-accent)] text-white'
                    : 'bg-[color:var(--pm-surface-muted)] text-[color:var(--pm-text-secondary)] hover:bg-[color:var(--pm-surface-hover)]'
                }`}
                onClick={() => toggleInputType(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onCancel}>取消</Button>
          <Button
            variant="primary"
            busy={busy}
            disabled={!name.trim() || inputTypes.length === 0}
            onClick={() => onSubmit({ name: name.trim(), inputTypes, actionType })}
          >
            创建
          </Button>
        </div>
      </div>
    </Card>
  );
}

// ── 运行 Action 对话框 ──────────────────────────────────────────

interface RunActionDialogProps {
  action: AIAction;
  input: string;
  onInputChange: (input: string) => void;
  onRun: () => void;
  onClose: () => void;
  busy: boolean;
  result: ProcessedContent | null;
}

function RunActionDialog({ action, input, onInputChange, onRun, onClose, busy, result }: RunActionDialogProps): JSX.Element {
  return (
    <Card className="mb-4 p-4">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-[14px] font-semibold text-[color:var(--pm-text-primary)]">
          运行: {action.name}
        </h3>
        <Button variant="ghost" size="sm" onClick={onClose}>关闭</Button>
      </div>
      <div className="flex flex-col gap-3">
        <div>
          <label className="mb-1 block text-[12px] text-[color:var(--pm-text-secondary)]">输入内容</label>
          <textarea
            className="h-[120px] w-full rounded-[8px] border border-[color:var(--pm-border-subtle)] bg-[color:var(--pm-surface-base)] p-3 text-[13px] text-[color:var(--pm-text-primary)] placeholder:text-[color:var(--pm-text-tertiary)] focus:border-[color:var(--pm-accent)] focus:outline-none"
            value={input}
            onChange={(e) => onInputChange(e.target.value)}
            placeholder="粘贴要处理的文本..."
          />
        </div>
        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={onClose}>取消</Button>
          <Button
            variant="primary"
            busy={busy}
            disabled={!input.trim()}
            onClick={onRun}
          >
            执行
          </Button>
        </div>
      </div>

      {/* 结果展示 */}
      {result && (
        <div className="mt-4 rounded-[8px] border border-[color:var(--pm-border-subtle)] bg-[color:var(--pm-surface-muted)] p-4">
          <h4 className="mb-2 text-[13px] font-semibold text-[color:var(--pm-text-primary)]">处理结果</h4>
          <div className="flex flex-col gap-2">
            <div>
              <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">标题</span>
              <p className="text-[13px] text-[color:var(--pm-text-primary)]">{result.title}</p>
            </div>
            <div>
              <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">摘要</span>
              <p className="text-[13px] text-[color:var(--pm-text-primary)]">{result.summary}</p>
            </div>
            {result.tags.length > 0 && (
              <div>
                <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">标签</span>
                <div className="flex flex-wrap gap-1">
                  {result.tags.map((tag) => (
                    <span key={tag} className="rounded-[4px] bg-[color:var(--pm-accent)]/10 px-2 py-0.5 text-[11px] text-[color:var(--pm-accent)]">
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
            )}
            <div>
              <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">正文</span>
              <pre className="mt-1 max-h-[200px] overflow-auto whitespace-pre-wrap break-words font-mono text-[12px] leading-[1.6] text-[color:var(--pm-text-primary)]">
                {result.body_markdown}
              </pre>
            </div>
          </div>
        </div>
      )}
    </Card>
  );
}
