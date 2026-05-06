/**
 * FileConverterPage — 文件转 Markdown 主页面 (Phase 3)
 *
 * 功能：
 * - 选择本地文件（拖拽 / 文件选择器）
 * - 预览转换结果
 * - 保存到收集箱
 * - 历史转换任务列表
 */

import { useState, useCallback, useRef } from 'react';
import { AcMindIcon } from '../../design-system/icons';
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
} from '../../design-system/components';
import { useFileConverter } from '../../hooks/useFileConverter';
import { useToast } from '../../components/shared/ToastViewport';
import type { ProcessJob } from '../../../shared/types';

const SUPPORTED_EXTENSIONS = ['.pdf', '.docx', '.pptx', '.html', '.htm', '.txt', '.md', '.markdown'];

export function FileConverterPage(): JSX.Element {
  const { jobs, loading, error, convert, preview, saveToInbox, refresh } = useFileConverter();
  const { addToast } = useToast();

  const [busyAction, setBusyAction] = useState<string | null>(null);
  const [previewMarkdown, setPreviewMarkdown] = useState<string | null>(null);
  const [previewTitle, setPreviewTitle] = useState<string>('');
  const [previewEngine, setPreviewEngine] = useState<string>('');
  const [previewJobId, setPreviewJobId] = useState<string>('');
  const [previewFilePath, setPreviewFilePath] = useState<string>('');
  const [dragOver, setDragOver] = useState(false);

  const fileInputRef = useRef<HTMLInputElement>(null);

  // 选择文件
  const handleSelectFile = useCallback(async () => {
    try {
      const result = await window.acmind.dialog.openFile({
        title: '选择要转换的文件',
        filters: [
          { name: '支持的文件', extensions: SUPPORTED_EXTENSIONS.map((e) => e.replace('.', '')) },
          { name: '所有文件', extensions: ['*'] },
        ],
      });
      if (result && !result.canceled && result.filePaths?.length > 0) {
        await handleConvert(result.filePaths[0]);
      }
    } catch {
      // 用户取消
    }
  }, []);

  // 转换文件
  const handleConvert = useCallback(async (filePath: string) => {
    setBusyAction('convert');
    setPreviewMarkdown(null);
    try {
      const result = await convert(filePath);
      if (result.success && result.markdown) {
        setPreviewMarkdown(result.markdown);
        setPreviewTitle(result.title || filePath.split('/').pop() || '未命名');
        setPreviewEngine(result.engine || 'unknown');
        setPreviewJobId(result.jobId);
        setPreviewFilePath(filePath);
        addToast(`转换成功 (${result.engine})`, 'success');
      } else {
        addToast(`转换失败: ${result.error || '未知错误'}`, 'error');
      }
    } finally {
      setBusyAction(null);
    }
  }, [convert, addToast]);

  // 保存到收集箱
  const handleSaveToInbox = useCallback(async () => {
    if (!previewMarkdown || !previewJobId) return;
    setBusyAction('save');
    try {
      const item = await saveToInbox(previewJobId, previewMarkdown, previewTitle, previewFilePath);
      addToast(item ? '已保存到收集箱' : '保存失败', item ? 'success' : 'error');
    } finally {
      setBusyAction(null);
    }
  }, [previewMarkdown, previewJobId, previewTitle, previewFilePath, saveToInbox, addToast]);

  // 复制 Markdown
  const handleCopy = useCallback(async () => {
    if (!previewMarkdown) return;
    await navigator.clipboard.writeText(previewMarkdown);
    addToast('Markdown 已复制到剪贴板', 'success');
  }, [previewMarkdown, addToast]);

  // 拖拽处理
  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(true);
  }, []);

  const handleDragLeave = useCallback(() => {
    setDragOver(false);
  }, []);

  const handleDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const files = Array.from(e.dataTransfer.files);
    if (files.length > 0) {
      // Electron 拖拽的文件有 path 属性
      const filePath = (files[0] as File & { path?: string }).path;
      if (filePath) {
        await handleConvert(filePath);
      }
    }
  }, [handleConvert]);

  // 从历史任务查看
  const handleViewJob = useCallback(async (job: ProcessJob) => {
    const filePath = (job.metadata as Record<string, unknown>)?.filePath as string;
    if (!filePath) return;
    setBusyAction(`view-${job.id}`);
    try {
      const result = await preview(filePath);
      if (result.success && result.markdown) {
        setPreviewMarkdown(result.markdown);
        setPreviewTitle(result.title || filePath.split('/').pop() || '未命名');
        setPreviewEngine(result.engine || 'unknown');
        setPreviewJobId(job.id);
        setPreviewFilePath(filePath);
      } else {
        addToast(`预览失败: ${result.error || '未知错误'}`, 'error');
      }
    } finally {
      setBusyAction(null);
    }
  }, [preview, addToast]);

  if (loading) {
    return (
      <PageShell>
        <LoadingState title="加载文件转换" description="正在获取转换任务列表..." />
      </PageShell>
    );
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
        title="文件转换"
        description="将 PDF、DOCX、PPTX 等文件转换为 Markdown"
        actions={
          <Button
            variant="primary"
            leadingIcon={<AcMindIcon name="sb-results" size={16} />}
            busy={busyAction === 'convert'}
            onClick={() => void handleSelectFile()}
          >
            选择文件
          </Button>
        }
      />

      {/* 拖拽区域 */}
      <div
        className={`flex items-center justify-center rounded-[12px] border-2 border-dashed p-8 transition-colors ${
          dragOver
            ? 'border-[color:var(--pm-accent)] bg-[color:var(--pm-accent)]/5'
            : 'border-[color:var(--pm-border-subtle)] bg-[color:var(--pm-surface-muted)]'
        }`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={(e) => void handleDrop(e)}
      >
        <div className="flex flex-col items-center gap-2 text-center">
          <AcMindIcon name="sb-results" size={32} />
          <p className="text-[14px] text-[color:var(--pm-text-secondary)]">
            拖拽文件到此处，或点击上方按钮选择
          </p>
          <p className="text-[12px] text-[color:var(--pm-text-tertiary)]">
            支持: {SUPPORTED_EXTENSIONS.join(', ')}
          </p>
        </div>
      </div>

      {/* 隐藏的文件输入 */}
      <input
        ref={fileInputRef}
        type="file"
        className="hidden"
        accept={SUPPORTED_EXTENSIONS.join(',')}
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) {
            void handleConvert((file as File & { path?: string }).path || file.name);
          }
        }}
      />

      {/* 预览区域 */}
      {previewMarkdown !== null && (
        <Section
          title="转换结果"
          description={`引擎: ${previewEngine}`}
          action={
            <div className="flex items-center gap-2">
              <Button
                variant="ghost"
                size="sm"
                leadingIcon={<AcMindIcon name="copy" size={14} />}
                onClick={() => void handleCopy()}
              >
                复制
              </Button>
              <Button
                variant="primary"
                size="sm"
                leadingIcon={<AcMindIcon name="filled-inbox" size={14} />}
                busy={busyAction === 'save'}
                onClick={() => void handleSaveToInbox()}
              >
                保存到收集箱
              </Button>
            </div>
          }
        >
          <Card className="max-h-[400px] overflow-auto">
            <pre className="whitespace-pre-wrap break-words font-mono text-[13px] leading-[1.6] text-[color:var(--pm-text-primary)]">
              {previewMarkdown}
            </pre>
          </Card>
        </Section>
      )}

      {/* 历史任务 */}
      <Section
        title="转换历史"
        description={`共 ${jobs.length} 个任务`}
        action={
          <Button
            variant="ghost"
            size="sm"
            leadingIcon={<AcMindIcon name="status-running" size={14} />}
            onClick={() => void refresh()}
          >
            刷新
          </Button>
        }
      >
        {jobs.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="sb-results" size={28} />}
            title="暂无转换任务"
            description="选择文件开始转换"
            action={{ label: '选择文件', onClick: () => void handleSelectFile() }}
          />
        ) : (
          <div className="flex flex-col gap-2">
            {jobs.map((job) => (
              <JobRow
                key={job.id}
                job={job}
                busy={busyAction}
                onView={() => void handleViewJob(job)}
              />
            ))}
          </div>
        )}
      </Section>
    </PageShell>
  );
}

// ── 任务行 ──────────────────────────────────────────────────────

interface JobRowProps {
  job: ProcessJob;
  busy: string | null;
  onView: () => void;
}

function JobRow({ job, busy, onView }: JobRowProps): JSX.Element {
  const meta = job.metadata as Record<string, unknown> | undefined;
  const fileName = (meta?.filePath as string)?.split('/').pop() || '未知文件';
  const engine = (meta?.engine as string) || '';
  const charCount = (meta?.charCount as number) || 0;

  const timeStr = new Date(job.createdAt * 1000).toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });

  const statusTone = job.status === 'succeeded' ? 'success' : job.status === 'failed' ? 'danger' : job.status === 'running' ? 'info' : 'neutral';
  const statusLabel = job.status === 'succeeded' ? '成功' : job.status === 'failed' ? '失败' : job.status === 'running' ? '转换中' : job.status === 'queued' ? '排队中' : '已取消';

  return (
    <Card variant="interactive" className="flex items-center gap-3 p-3">
      <div className="flex h-8 w-8 items-center justify-center rounded-[6px] bg-[color:var(--pm-surface-muted)]">
        <AcMindIcon name="sb-results" size={16} />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="truncate text-[13px] font-medium text-[color:var(--pm-text-primary)]">{fileName}</span>
          <StatusBadge tone={statusTone} label={statusLabel} dot={false} />
        </div>
        <div className="flex items-center gap-3 text-[11px] text-[color:var(--pm-text-tertiary)]">
          <span>{timeStr}</span>
          {engine && <span>引擎: {engine}</span>}
          {charCount > 0 && <span>{charCount.toLocaleString()} 字符</span>}
        </div>
      </div>
      {job.status === 'succeeded' && (
        <Button
          variant="ghost"
          size="sm"
          busy={busy === `view-${job.id}`}
          onClick={onView}
        >
          查看
        </Button>
      )}
      {job.status === 'failed' && job.errorMessage && (
        <span className="max-w-[200px] truncate text-[11px] text-[color:var(--pm-text-error)]" title={job.errorMessage}>
          {job.errorMessage}
        </span>
      )}
    </Card>
  );
}
