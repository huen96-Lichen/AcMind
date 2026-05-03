/**
 * DatasetsPage — 数据集管理
 *
 * 功能：
 * - 数据集列表浏览（网格卡片）
 * - 新建数据集（内联表单，选择用途）
 * - 添加已确认的蒸馏内容到数据集
 * - 导出数据集（JSONL / Markdown）
 * - 删除数据集
 */

import { useCallback, useEffect, useState } from 'react';
import { Button, Card, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { useToast } from '../../components/shared/ToastViewport';

// ─── Types ───────────────────────────────────────────────────────────────────

interface Dataset {
  id: string;
  name: string;
  description?: string;
  purpose: 'fine_tune' | 'rag' | 'evaluation' | 'archive';
  status: 'draft' | 'ready' | 'exported' | 'archived';
  itemCount: number;
  createdAt: number;
  updatedAt: number;
}

interface DistilledOutput {
  id: string;
  title?: string;
  sourceType?: string;
  reviewStatus?: string;
  createdAt?: number;
  [key: string]: any;
}

// ─── Constants ───────────────────────────────────────────────────────────────

const PURPOSE_LABELS: Record<Dataset['purpose'], string> = {
  fine_tune: '微调',
  rag: 'RAG 检索',
  evaluation: '评测',
  archive: '归档',
};

const STATUS_LABELS: Record<Dataset['status'], { label: string; tone: 'neutral' | 'success' | 'warning' | 'info' }> = {
  draft: { label: '草稿', tone: 'neutral' },
  ready: { label: '就绪', tone: 'success' },
  exported: { label: '已导出', tone: 'info' },
  archived: { label: '已归档', tone: 'neutral' },
};

const PURPOSE_OPTIONS: Array<{ value: Dataset['purpose']; label: string }> = [
  { value: 'fine_tune', label: '微调' },
  { value: 'rag', label: 'RAG 检索' },
  { value: 'evaluation', label: '评测' },
  { value: 'archive', label: '归档' },
];

const EXPORT_FORMATS = ['JSONL', 'Markdown'] as const;
type ExportFormat = typeof EXPORT_FORMATS[number];

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

// ─── Add Items Dialog ────────────────────────────────────────────────────────

interface AddItemsDialogProps {
  datasetId: string;
  onClose: () => void;
  onAdded: () => void;
}

function AddItemsDialog({ datasetId, onClose, onAdded }: AddItemsDialogProps): JSX.Element {
  const { addToast } = useToast();
  const [items, setItems] = useState<DistilledOutput[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    (async () => {
      setLoading(true);
      try {
        const list = await window.acmind.distilledOutputs.list({ reviewStatus: 'accepted' });
        setItems(list as DistilledOutput[]);
      } catch {
        addToast('加载蒸馏内容失败', 'error');
      } finally {
        setLoading(false);
      }
    })();
  }, [addToast]);

  const toggleItem = useCallback((id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const toggleAll = useCallback(() => {
    if (selected.size === items.length) {
      setSelected(new Set());
    } else {
      setSelected(new Set(items.map((i) => i.id)));
    }
  }, [items, selected.size]);

  const handleConfirm = useCallback(async () => {
    if (selected.size === 0) return;
    setAdding(true);
    try {
      const count = await window.acmind.datasets.addItems({
        datasetId,
        items: Array.from(selected).map((id) => ({
          sourceType: 'distilled_output',
          sourceId: id,
        })),
      });
      addToast(`已添加 ${count} 条内容`, 'success');
      onAdded();
      onClose();
    } catch (err: any) {
      addToast(err?.message || '添加失败', 'error');
    } finally {
      setAdding(false);
    }
  }, [datasetId, selected, onAdded, onClose, addToast]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: 'rgba(0,0,0,0.4)' }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="flex flex-col rounded-[12px] border shadow-lg"
        style={{
          background: 'var(--pm-bg-primary)',
          borderColor: 'var(--pm-border)',
          width: 480,
          maxHeight: '70vh',
        }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b" style={{ borderColor: 'var(--pm-border)' }}>
          <span className="text-[14px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
            添加内容
          </span>
          <Button variant="ghost" size="sm" onClick={onClose}>
            关闭
          </Button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-4">
          {loading ? (
            <LoadingState title="加载中" description="正在读取已确认的蒸馏内容…" />
          ) : items.length === 0 ? (
            <EmptyState
              title="暂无可添加内容"
              description="需要先在蒸馏流程中确认内容后才能添加到数据集。"
            />
          ) : (
            <div className="flex flex-col gap-1">
              <div className="flex items-center gap-2 mb-2">
                <button
                  className="text-[12px] underline"
                  style={{ color: 'var(--pm-text-secondary)' }}
                  onClick={toggleAll}
                >
                  {selected.size === items.length ? '取消全选' : '全选'}
                </button>
                <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                  已选 {selected.size} / {items.length}
                </span>
              </div>
              {items.map((item) => (
                <label
                  key={item.id}
                  className="flex items-center gap-2 rounded-[8px] px-3 py-2 cursor-pointer transition-colors"
                  style={{
                    background: selected.has(item.id) ? 'var(--pm-bg-elevated)' : 'transparent',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={selected.has(item.id)}
                    onChange={() => toggleItem(item.id)}
                  />
                  <div className="flex-1 min-w-0">
                    <div className="text-[13px] truncate" style={{ color: 'var(--pm-text-primary)' }}>
                      {item.title || item.id}
                    </div>
                    {item.sourceType && (
                      <div className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                        {item.sourceType}
                      </div>
                    )}
                  </div>
                </label>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-2 px-4 py-3 border-t" style={{ borderColor: 'var(--pm-border)' }}>
          <Button variant="secondary" size="sm" onClick={onClose}>
            取消
          </Button>
          <Button
            variant="primary"
            size="sm"
            onClick={handleConfirm}
            disabled={selected.size === 0 || adding}
          >
            {adding ? '添加中…' : `添加 ${selected.size} 条`}
          </Button>
        </div>
      </div>
    </div>
  );
}

// ─── Export Dialog ───────────────────────────────────────────────────────────

interface ExportDialogProps {
  datasetId: string;
  datasetName: string;
  onClose: () => void;
}

function ExportDialog({ datasetId, datasetName, onClose }: ExportDialogProps): JSX.Element {
  const { addToast } = useToast();
  const [format, setFormat] = useState<ExportFormat>('JSONL');
  const [includeExcluded, setIncludeExcluded] = useState(false);
  const [exporting, setExporting] = useState(false);

  const handleExport = useCallback(async () => {
    setExporting(true);
    try {
      const result = await window.acmind.datasets.exportDataset({
        datasetId,
        format: format.toLowerCase() as 'jsonl' | 'markdown',
        includeExcluded,
      });
      addToast(`已导出 ${result.count} 条到 ${result.path}`, 'success');
      onClose();
    } catch (err: any) {
      addToast(err?.message || '导出失败', 'error');
    } finally {
      setExporting(false);
    }
  }, [datasetId, format, includeExcluded, onClose, addToast]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: 'rgba(0,0,0,0.4)' }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="flex flex-col rounded-[12px] border shadow-lg"
        style={{
          background: 'var(--pm-bg-primary)',
          borderColor: 'var(--pm-border)',
          width: 400,
        }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b" style={{ borderColor: 'var(--pm-border)' }}>
          <span className="text-[14px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
            导出数据集
          </span>
          <Button variant="ghost" size="sm" onClick={onClose}>
            关闭
          </Button>
        </div>

        {/* Body */}
        <div className="flex flex-col gap-3 p-4">
          <div className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>
            数据集：{datasetName}
          </div>

          <div className="flex flex-col gap-1.5">
            <span className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>导出格式</span>
            <div className="flex gap-2">
              {EXPORT_FORMATS.map((f) => (
                <button
                  key={f}
                  className="rounded-[8px] border px-3 py-1.5 text-[13px] transition-colors"
                  style={{
                    borderColor: format === f ? 'var(--pm-accent)' : 'var(--pm-border)',
                    background: format === f ? 'var(--pm-bg-elevated)' : 'transparent',
                    color: format === f ? 'var(--pm-text-primary)' : 'var(--pm-text-secondary)',
                  }}
                  onClick={() => setFormat(f)}
                >
                  {f}
                </button>
              ))}
            </div>
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={includeExcluded}
              onChange={(e) => setIncludeExcluded(e.target.checked)}
            />
            <span className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>
              包含已排除的内容
            </span>
          </label>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-2 px-4 py-3 border-t" style={{ borderColor: 'var(--pm-border)' }}>
          <Button variant="secondary" size="sm" onClick={onClose}>
            取消
          </Button>
          <Button variant="primary" size="sm" onClick={handleExport} disabled={exporting}>
            {exporting ? '导出中…' : '导出'}
          </Button>
        </div>
      </div>
    </div>
  );
}

// ─── Main Page ───────────────────────────────────────────────────────────────

export function DatasetsPage(): JSX.Element {
  const { addToast } = useToast();
  const [datasets, setDatasets] = useState<Dataset[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ── Create form state ──
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newPurpose, setNewPurpose] = useState<Dataset['purpose']>('fine_tune');
  const [creating, setCreating] = useState(false);

  // ── Dialog state ──
  const [addItemsDatasetId, setAddItemsDatasetId] = useState<string | null>(null);
  const [exportDataset, setExportDataset] = useState<{ id: string; name: string } | null>(null);

  // ── Load datasets ──
  const loadDatasets = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const list = await window.acmind.datasets.list();
      setDatasets(list as any);
    } catch (err: any) {
      setError(err?.message || '加载数据集列表失败');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadDatasets();
  }, [loadDatasets]);

  // ── Create dataset ──
  const handleCreate = useCallback(async () => {
    if (!newName.trim()) return;
    setCreating(true);
    try {
      await window.acmind.datasets.create({
        name: newName.trim(),
        description: newDescription.trim() || undefined,
        purpose: newPurpose,
      });
      addToast('数据集已创建', 'success');
      setNewName('');
      setNewDescription('');
      setNewPurpose('fine_tune');
      setShowCreateForm(false);
      await loadDatasets();
    } catch (err: any) {
      addToast(err?.message || '创建失败', 'error');
    } finally {
      setCreating(false);
    }
  }, [newName, newDescription, newPurpose, loadDatasets, addToast]);

  // ── Delete dataset ──
  const handleDelete = useCallback(async (dataset: Dataset) => {
    const confirmed = window.confirm(`确定要删除数据集「${dataset.name}」吗？此操作不可撤销。`);
    if (!confirmed) return;
    try {
      await window.acmind.datasets.delete(dataset.id);
      addToast('数据集已删除', 'success');
      await loadDatasets();
    } catch (err: any) {
      addToast(err?.message || '删除失败', 'error');
    }
  }, [loadDatasets, addToast]);

  // ── Render ──

  return (
    <PageShell>
      <PageHeader
        title="数据集"
        description="为未来个人模型准备高质量训练数据"
        actions={
          <Button
            variant="primary"
            size="sm"
            leadingIcon={<PinStackIcon name="filled-logs" size={14} />}
            onClick={() => setShowCreateForm(!showCreateForm)}
          >
            新建数据集
          </Button>
        }
      />

      <Section title="">
        {/* Safety banner */}
        <div
          className="flex items-start gap-2 rounded-[8px] px-3 py-2.5"
          style={{
            background: 'var(--pm-bg-elevated)',
            marginBottom: 16,
          }}
        >
          <PinStackIcon name="status-info" size={14} style={{ color: 'var(--pm-text-tertiary)', marginTop: 1 }} />
          <span className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>
            数据集仅包含经过确认的内容。默认不上传云端，不做真实模型训练。
          </span>
        </div>

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
              placeholder="数据集名称"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              className="acmind-input"
              autoFocus
            />
            <textarea
              placeholder="描述（可选）"
              value={newDescription}
              onChange={(e) => setNewDescription(e.target.value)}
              className="acmind-input"
              rows={2}
              style={{ resize: 'vertical' }}
            />
            <div className="flex flex-col gap-1.5">
              <span className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>用途</span>
              <div className="flex gap-2">
                {PURPOSE_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    className="rounded-[8px] border px-3 py-1.5 text-[13px] transition-colors"
                    style={{
                      borderColor: newPurpose === opt.value ? 'var(--pm-accent)' : 'var(--pm-border)',
                      background: newPurpose === opt.value ? 'var(--pm-bg-elevated)' : 'transparent',
                      color: newPurpose === opt.value ? 'var(--pm-text-primary)' : 'var(--pm-text-secondary)',
                    }}
                    onClick={() => setNewPurpose(opt.value)}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
            </div>
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
                  setNewPurpose('fine_tune');
                }}
              >
                取消
              </Button>
            </div>
          </div>
        )}

        {/* Content */}
        {loading ? (
          <LoadingState title="加载中" description="正在读取数据集列表…" />
        ) : error ? (
          <ErrorState
            title="加载失败"
            reason={error}
            suggestion="请检查应用状态后重试"
            action={{ label: '重试', onClick: loadDatasets }}
          />
        ) : datasets.length === 0 ? (
          <EmptyState
            icon={<PinStackIcon name="empty-inbox" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="还没有数据集"
            description="点击「新建数据集」创建你的第一个训练数据集。"
          />
        ) : (
          <div
            className="grid gap-3"
            style={{ gridTemplateColumns: 'repeat(2, 1fr)' }}
          >
            {datasets.map((dataset) => (
              <div
                key={dataset.id}
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
                      {dataset.name}
                    </div>
                    {dataset.description && (
                      <div
                        className="text-[12px] mt-1 line-clamp-2"
                        style={{ color: 'var(--pm-text-secondary)' }}
                      >
                        {dataset.description}
                      </div>
                    )}
                  </div>
                </div>

                {/* Meta row */}
                <div className="flex items-center gap-2 flex-wrap" style={{ marginBottom: 10 }}>
                  <StatusBadge tone="neutral" label={PURPOSE_LABELS[dataset.purpose]} />
                  <StatusBadge tone={STATUS_LABELS[dataset.status].tone} label={STATUS_LABELS[dataset.status].label} />
                  <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                    {dataset.itemCount} 条
                  </span>
                  <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                    {formatRelativeTime(dataset.updatedAt)}
                  </span>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-1.5">
                  <Button
                    variant="ghost"
                    size="sm"
                    leadingIcon={<PinStackIcon name="filled-logs" size={14} />}
                    onClick={() => setAddItemsDatasetId(dataset.id)}
                  >
                    添加内容
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    leadingIcon={<PinStackIcon name="filled-file-import" size={14} />}
                    onClick={() => setExportDataset({ id: dataset.id, name: dataset.name })}
                  >
                    导出
                  </Button>
                  <div className="flex-1" />
                  <Button
                    variant="ghost"
                    size="sm"
                    leadingIcon={<PinStackIcon name="act-delete" size={14} />}
                    onClick={() => handleDelete(dataset)}
                  />
                </div>
              </div>
            ))}
          </div>
        )}
      </Section>

      {/* Add Items Dialog */}
      {addItemsDatasetId && (
        <AddItemsDialog
          datasetId={addItemsDatasetId}
          onClose={() => setAddItemsDatasetId(null)}
          onAdded={loadDatasets}
        />
      )}

      {/* Export Dialog */}
      {exportDataset && (
        <ExportDialog
          datasetId={exportDataset.id}
          datasetName={exportDataset.name}
          onClose={() => setExportDataset(null)}
        />
      )}
    </PageShell>
  );
}
