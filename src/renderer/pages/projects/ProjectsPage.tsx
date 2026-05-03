/**
 * ProjectsPage — 项目空间管理
 *
 * 功能：
 * - 项目列表浏览（网格卡片）
 * - 新建项目（内联表单）
 * - 归档/取消归档、删除项目
 */

import { useCallback, useEffect, useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { useToast } from '../../components/shared/ToastViewport';

// ─── Types ───────────────────────────────────────────────────────────────────

interface KnowledgeProject {
  id: string;
  name: string;
  description?: string;
  status: 'active' | 'paused' | 'archived';
  color?: string;
  createdAt: number;
  updatedAt: number;
}

// ─── Constants ───────────────────────────────────────────────────────────────

const STATUS_CONFIG: Record<KnowledgeProject['status'], { label: string; tone: 'success' | 'warning' | 'neutral' }> = {
  active: { label: '进行中', tone: 'success' },
  paused: { label: '已暂停', tone: 'warning' },
  archived: { label: '已归档', tone: 'neutral' },
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatRelativeTime(timestamp: number): string {
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);
  const diffHour = Math.floor(diffMs / 3600000);
  const diffDay = Math.floor(diffMs / 86400000);

  if (diffMin < 1) return '刚刚';
  if (diffMin < 60) return `${diffMin} 分钟前`;
  if (diffHour < 24) return `${diffHour} 小时前`;
  if (diffDay < 30) return `${diffDay} 天前`;
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

// ─── Main Page ───────────────────────────────────────────────────────────────

export function ProjectsPage(): JSX.Element {
  const { addToast } = useToast();
  const [projects, setProjects] = useState<KnowledgeProject[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ── Create form state ──
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [creating, setCreating] = useState(false);

  // ── Load projects ──
  const loadProjects = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const list = await window.acmind.projects.list();
      setProjects(list as KnowledgeProject[]);
    } catch (err: any) {
      setError(err?.message || '加载项目列表失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadProjects();
  }, [loadProjects]);

  // ── Create project ──
  const handleCreate = useCallback(async () => {
    if (!newName.trim()) return;
    setCreating(true);
    try {
      await window.acmind.projects.create({
        name: newName.trim(),
        description: newDescription.trim() || undefined,
      });
      addToast('项目已创建', 'success');
      setNewName('');
      setNewDescription('');
      setShowCreateForm(false);
      await loadProjects();
    } catch (err: any) {
      addToast(err?.message || '创建失败', 'error');
    } finally {
      setCreating(false);
    }
  }, [newName, newDescription, loadProjects, addToast]);

  // ── Toggle archive ──
  const handleToggleArchive = useCallback(async (project: KnowledgeProject) => {
    try {
      const newStatus = project.status === 'archived' ? 'active' : 'archived';
      await window.acmind.projects.update({
        id: project.id,
        status: newStatus,
      });
      addToast(newStatus === 'archived' ? '已归档' : '已取消归档', 'success');
      await loadProjects();
    } catch (err: any) {
      addToast(err?.message || '操作失败', 'error');
    }
  }, [loadProjects, addToast]);

  // ── Delete project ──
  const handleDelete = useCallback(async (project: KnowledgeProject) => {
    const confirmed = window.confirm(`确定要删除项目「${project.name}」吗？此操作不可撤销。`);
    if (!confirmed) return;
    try {
      await window.acmind.projects.delete(project.id);
      addToast('项目已删除', 'success');
      await loadProjects();
    } catch (err: any) {
      addToast(err?.message || '删除失败', 'error');
    }
  }, [loadProjects, addToast]);

  // ── Render ──

  return (
    <PageShell>
      <PageHeader
        title="项目空间"
        description="按项目组织你的知识和内容"
        actions={
          <Button
            variant="primary"
            size="sm"
            leadingIcon={<PinStackIcon name="filled-logs" size={14} />}
            onClick={() => setShowCreateForm(!showCreateForm)}
          >
            新建项目
          </Button>
        }
      />

      <Section title="">
        {/* Create form */}
        {showCreateForm && (
          <div
            className="flex flex-col gap-3 rounded-[12px] border p-4"
            style={{
              borderColor: 'var(--pm-border)',
              background: 'var(--pm-bg-elevated)',
              marginBottom: 16,
            }}
          >
            <input
              type="text"
              placeholder="项目名称"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              className="acmind-input"
              autoFocus
            />
            <textarea
              placeholder="项目描述（可选）"
              value={newDescription}
              onChange={(e) => setNewDescription(e.target.value)}
              className="acmind-input"
              rows={2}
              style={{ resize: 'vertical' }}
            />
            <div className="flex items-center gap-2">
              <Button
                variant="primary"
                size="sm"
                onClick={handleCreate}
                disabled={!newName.trim() || creating}
              >
                {creating ? '创建中…' : '创建'}
              </Button>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  setShowCreateForm(false);
                  setNewName('');
                  setNewDescription('');
                }}
              >
                取消
              </Button>
            </div>
          </div>
        )}

        {/* Content */}
        {loading ? (
          <LoadingState title="加载中" description="正在读取项目列表…" />
        ) : error ? (
          <ErrorState
            title="加载失败"
            reason={error}
            suggestion="请检查应用状态后重试"
            action={{ label: '重试', onClick: loadProjects }}
          />
        ) : projects.length === 0 ? (
          <EmptyState
            icon={<PinStackIcon name="empty-inbox" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="还没有项目"
            description="点击「新建项目」创建你的第一个项目空间。"
          />
        ) : (
          <div
            className="grid gap-3"
            style={{ gridTemplateColumns: 'repeat(2, 1fr)' }}
          >
            {projects.map((project) => (
              <div
                key={project.id}
                className="acmind-card acmind-card-grouped"
                style={{ padding: 14, borderRadius: 12 }}
              >
                {/* Header */}
                <div className="flex items-start justify-between" style={{ marginBottom: 8 }}>
                  <div className="flex-1 min-w-0">
                    <div
                      className="text-[16px] font-semibold truncate"
                      style={{ color: 'var(--pm-text-primary)' }}
                    >
                      {project.name}
                    </div>
                    {project.description && (
                      <div
                        className="text-[12px] mt-1 line-clamp-2"
                        style={{ color: 'var(--pm-text-secondary)' }}
                      >
                        {project.description}
                      </div>
                    )}
                  </div>
                </div>

                {/* Meta row */}
                <div className="flex items-center gap-2" style={{ marginBottom: 10 }}>
                  <StatusBadge tone={STATUS_CONFIG[project.status].tone} label={STATUS_CONFIG[project.status].label} />
                  <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                    {formatRelativeTime(project.updatedAt)}
                  </span>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-1.5">
                  <Button
                    variant="ghost"
                    size="sm"
                    leadingIcon={
                      <PinStackIcon
                        name={project.status === 'archived' ? 'filled-logs' : 'filled-search'}
                        size={14}
                      />
                    }
                    onClick={() => handleToggleArchive(project)}
                  >
                    {project.status === 'archived' ? '取消归档' : '归档'}
                  </Button>
                  <div className="flex-1" />
                  <Button
                    variant="ghost"
                    size="sm"
                    leadingIcon={<PinStackIcon name="act-delete" size={14} />}
                    onClick={() => handleDelete(project)}
                  />
                </div>
              </div>
            ))}
          </div>
        )}
      </Section>
    </PageShell>
  );
}
