import { useCallback, useEffect, useMemo, useState } from 'react';
import { VaultConfigPanel } from '../../components/export/VaultConfigPanel';
import { ExportHistory } from '../../components/export/ExportHistory';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import {
  Button,
  EmptyState,
  ErrorState,
  LoadingState,
  PageHeader,
  PageShell,
  Section,
  SearchField,
  StatusBadge,
} from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { useExportRecords } from '../../hooks/useExportRecords';
import type { DistilledOutput, ExportRecord, SourceItem } from '../../../shared/types';

// ─── Types ───────────────────────────────────────────────────────────────────

type ExportTab = 'export' | 'vault-config' | 'history';

type OutputStatus = '已写入' | '待写入' | '写入失败';

type StatusFilter = '全部' | OutputStatus;

type SourceFilter = '全部' | string;

interface ExportTableRow {
  id: string;
  title: string;
  status: OutputStatus;
  outputPath: string;
  outputTime: string;
  source: string;
  record?: ExportRecord;
  output?: DistilledOutput;
  sourceItem?: SourceItem;
}

// ─── Status Mapping ──────────────────────────────────────────────────────────

const STATUS_TONE: Record<OutputStatus, 'success' | 'warning' | 'danger'> = {
  '已写入': 'success',
  '待写入': 'warning',
  '写入失败': 'danger',
};

// ─── Format helpers ──────────────────────────────────────────────────────────

function formatTime(ts: number): string {
  const d = new Date(ts * 1000);
  return d.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ─── Right Detail Panel ──────────────────────────────────────────────────────

interface DetailPanelProps {
  row: ExportTableRow;
  onClose: () => void;
  onRetry: (recordId: string) => void;
}

function DetailPanel({ row, onClose, onRetry }: DetailPanelProps): JSX.Element {
  const [copied, setCopied] = useState(false);
  const [lineage, setLineage] = useState<{
    sourceItem: SourceItem | null;
    distilledOutput: DistilledOutput | null;
  } | null>(null);

  // Load lineage data when a record row is selected
  useEffect(() => {
    if (!row.record?.id) {
      setLineage({ sourceItem: row.sourceItem ?? null, distilledOutput: row.output ?? null });
      return;
    }
    window.acmind.export
      .getWithLineage(row.record.id)
      .then((result) => {
        setLineage({
          sourceItem: result.sourceItem ?? row.sourceItem ?? null,
          distilledOutput: result.distilledOutput ?? row.output ?? null,
        });
      })
      .catch(() => {
        setLineage({ sourceItem: row.sourceItem ?? null, distilledOutput: row.output ?? null });
      });
  }, [row.record?.id, row.sourceItem, row.output]);

  const resolvedSourceItem = lineage?.sourceItem ?? row.sourceItem;
  const resolvedOutput = lineage?.distilledOutput ?? row.output;

  const handleCopyPath = async () => {
    try {
      await navigator.clipboard.writeText(row.outputPath);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // ignore
    }
  };

  const handleOpenInObsidian = async () => {
    if (row.record) {
      try {
        await window.acmind.export.revealInVault(row.record.id);
      } catch {
        // ignore
      }
    }
  };

  const handleRetry = () => {
    if (row.record) {
      onRetry(row.record.id);
    }
  };

  const isFailed = row.status === '写入失败';
  const isPending = row.status === '待写入';

  return (
    <div
      className="flex flex-col h-full"
      style={{
        width: 320,
        minWidth: 320,
        borderLeft: '0.5px solid var(--pm-border-subtle)',
        background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.5))',
      }}
    >
      {/* Header */}
      <div
        className="flex items-center justify-between px-5 py-3"
        style={{
          borderBottom: '0.5px solid var(--pm-border-subtle)',
        }}
      >
        <span
          className="text-[13px] font-semibold"
          style={{ color: 'var(--pm-text-primary)' }}
        >
          写入详情
        </span>
        <Button
          variant="ghost"
          size="sm"
          onClick={onClose}
        >
          <AcMindIcon name="close" size={14} />
        </Button>
      </div>

      <ScrollContainer>
        <div className="p-5 flex flex-col gap-4">
          {/* Title + Status + Source */}
          <div>
            <h3
              className="text-[14px] font-semibold mb-2"
              style={{ color: 'var(--pm-text-primary)' }}
            >
              {row.title}
            </h3>
            <div className="flex items-center gap-2 mb-1">
              <StatusBadge tone={STATUS_TONE[row.status]} label={row.status} />
              <span
                className="text-[11px]"
                style={{ color: 'var(--pm-text-tertiary)' }}
              >
                来源: {row.source}
              </span>
            </div>
          </div>

          {/* Action buttons */}
          <div className="flex items-center gap-2">
            <Button
              variant="primary"
              size="sm"
              leadingIcon={<AcMindIcon name="panel" size={14} />}
              onClick={handleOpenInObsidian}
              style={{ flex: 1 }}
            >
              在 Obsidian 中打开
            </Button>
            <Button
              variant="secondary"
              size="sm"
              leadingIcon={<AcMindIcon name="copy" size={14} />}
              onClick={handleCopyPath}
            >
              {copied ? '已复制' : '复制路径'}
            </Button>
            {(isFailed || isPending) && (
              <Button
                variant="primary"
                size="sm"
                onClick={handleRetry}
              >
                重试写入 Obsidian
              </Button>
            )}
          </div>

          {/* Output info */}
          <div
            className="rounded-[10px] p-4"
            style={{
              background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.7))',
              border: '0.5px solid var(--pm-border-subtle)',
            }}
          >
            <div
              className="text-[11px] font-semibold uppercase tracking-wider mb-2"
              style={{ color: 'var(--pm-text-tertiary)' }}
            >
              写入信息
            </div>
            <div className="flex flex-col gap-1.5">
              <InfoRow label="文件名" value={row.outputPath.split('/').pop() ?? row.outputPath} />
              <InfoRow label="路径" value={row.outputPath} />
              <InfoRow label="项目" value={row.record?.vaultPath ?? '-'} />
              <InfoRow label="模板" value={row.record?.frontmatter?.template as string ?? '默认模板'} />
              <InfoRow label="时间" value={row.outputTime} />
              <InfoRow
                label="最后尝试"
                value={row.record ? formatTime(row.record.exportedAt) : '-'}
              />
            </div>
          </div>

          {/* Lineage info: SourceItem + DistilledOutput */}
          {(resolvedSourceItem || resolvedOutput) && (
            <div
              className="rounded-[10px] p-4"
              style={{
                background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.7))',
                border: '0.5px solid var(--pm-border-subtle)',
              }}
            >
              <div
                className="text-[11px] font-semibold uppercase tracking-wider mb-2"
                style={{ color: 'var(--pm-text-tertiary)' }}
              >
                关联链路
              </div>
              <div className="flex flex-col gap-1.5">
                {resolvedSourceItem && (
                  <>
                    <InfoRow label="SourceItem" value={resolvedSourceItem.id.slice(0, 12) + '...'} />
                    <InfoRow label="类型" value={resolvedSourceItem.type} />
                    <InfoRow label="状态" value={resolvedSourceItem.status} />
                    {resolvedSourceItem.captureItemId && (
                      <InfoRow label="CaptureItem" value={resolvedSourceItem.captureItemId.slice(0, 12) + '...'} />
                    )}
                  </>
                )}
                {resolvedOutput && (
                  <>
                    <InfoRow label="DistilledOutput" value={resolvedOutput.id.slice(0, 12) + '...'} />
                    <InfoRow label="审阅状态" value={resolvedOutput.reviewStatus ?? 'pending'} />
                    {resolvedOutput.suggestedTitle && (
                      <InfoRow label="AI 标题" value={resolvedOutput.suggestedTitle} />
                    )}
                    {resolvedOutput.summary && (
                      <InfoRow label="AI 摘要" value={resolvedOutput.summary.slice(0, 80) + (resolvedOutput.summary.length > 80 ? '...' : '')} />
                    )}
                  </>
                )}
              </div>
            </div>
          )}

          {/* Output description */}
          <div
            className="rounded-[10px] p-4"
            style={{
              background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.7))',
              border: '0.5px solid var(--pm-border-subtle)',
            }}
          >
            <div
              className="text-[11px] font-semibold uppercase tracking-wider mb-2"
              style={{ color: 'var(--pm-text-tertiary)' }}
            >
              写入说明
            </div>
            <p
              className="text-[12px] leading-relaxed m-0"
              style={{ color: 'var(--pm-text-secondary)' }}
            >
              {row.record?.status === 'success'
                ? '该笔记已成功写入 Obsidian 知识库。'
                : row.record?.status === 'failed'
                  ? '该笔记写入时遇到错误，请检查错误信息后重试。'
                  : row.record?.status === 'conflict'
                    ? '该笔记写入时遇到文件冲突，请手动处理。'
                    : '该笔记尚未写入，等待处理中。'}
            </p>
          </div>

          {/* Error block (only for failed) */}
          {isFailed && (
            <div
              className="rounded-[10px] p-4"
              style={{
                background: 'color-mix(in srgb, var(--pm-status-danger) 6%, transparent)',
                border: '0.5px solid color-mix(in srgb, var(--pm-status-danger) 16%, transparent)',
              }}
            >
              <div
                className="text-[11px] font-semibold uppercase tracking-wider mb-2"
                style={{ color: 'var(--pm-status-danger)' }}
              >
                错误信息
              </div>
              <div className="flex flex-col gap-1.5">
                <InfoRow
                  label="上次失败时间"
                  value={row.record ? formatTime(row.record.exportedAt) : '-'}
                  danger
                />
                <InfoRow
                  label="错误原因"
                  value={row.record?.frontmatter?.error as string ?? '未知错误'}
                  danger
                />
                <div className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                  <span className="font-medium" style={{ color: 'var(--pm-text-secondary)' }}>
                    解决建议：
                  </span>{' '}
                  请检查知识库路径配置是否正确，确认文件权限，然后重试写入。
                </div>
                <div className="flex items-center gap-2 mt-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'settings', tab: 'advanced-logs' } }))}
                  >
                    查看日志
                  </Button>
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={handleRetry}
                  >
                    重试写入 Obsidian
                  </Button>
                </div>
              </div>
            </div>
          )}

          {/* Related logs */}
          <div
            className="rounded-[10px] p-4"
            style={{
              background: 'var(--pm-bg-surface-soft, rgba(255, 255, 255, 0.7))',
              border: '0.5px solid var(--pm-border-subtle)',
            }}
          >
            <div
              className="text-[11px] font-semibold uppercase tracking-wider mb-2"
              style={{ color: 'var(--pm-text-tertiary)' }}
            >
              相关日志
            </div>
            <div
              className="text-[11px] leading-relaxed"
              style={{ color: 'var(--pm-text-tertiary)' }}
            >
              {row.record
                ? `[${formatTime(row.record.exportedAt)}] 写入 ${row.record.status === 'success' ? '成功' : row.record.status === 'failed' ? '失败' : '冲突'} - ${row.record.relativeFilePath}`
                : '暂无日志记录'}
            </div>
          </div>
        </div>
      </ScrollContainer>
    </div>
  );
}

function InfoRow({ label, value, danger }: { label: string; value: string; danger?: boolean }): JSX.Element {
  return (
    <div className="flex items-start gap-2">
      <span
        className="text-[11px] flex-shrink-0"
        style={{
          color: danger ? 'var(--pm-status-danger)' : 'var(--pm-text-tertiary)',
          width: 60,
        }}
      >
        {label}
      </span>
      <span
        className="text-[11px] break-all"
        style={{
          color: danger ? 'var(--pm-status-danger)' : 'var(--pm-text-secondary)',
        }}
      >
        {value}
      </span>
    </div>
  );
}

// ─── Pagination ──────────────────────────────────────────────────────────────

interface PaginationProps {
  total: number;
  page: number;
  pageSize: number;
  onPageChange: (page: number) => void;
}

function Pagination({ total, page, pageSize, onPageChange }: PaginationProps): JSX.Element {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  if (totalPages <= 1) return <></>;

  const pages: number[] = [];
  for (let i = 1; i <= totalPages; i++) {
    pages.push(i);
  }

  return (
    <div className="flex items-center justify-between px-4 py-2">
      <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
        共 {total} 条
      </span>
      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="sm"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
        >
          上一页
        </Button>
        {pages.map((p) => (
          <Button
            key={p}
            variant={p === page ? 'primary' : 'ghost'}
            size="sm"
            onClick={() => onPageChange(p)}
          >
            {p}
          </Button>
        ))}
        <Button
          variant="ghost"
          size="sm"
          disabled={page >= totalPages}
          onClick={() => onPageChange(page + 1)}
        >
          下一页
        </Button>
      </div>
      <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
        {totalPages} 页 / {pageSize} 条每页
      </span>
    </div>
  );
}

// ─── Filter Select ───────────────────────────────────────────────────────────

function FilterSelect<T extends string>({
  value,
  options,
  onChange,
}: {
  value: T;
  options: T[];
  onChange: (v: T) => void;
}): JSX.Element {
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value as T)}
      style={{
        height: 38,
        padding: '0 24px 0 8px',
        fontSize: 12,
        borderRadius: 12,
        border: '1px solid color-mix(in srgb, var(--pm-border-subtle) 70%, transparent)',
        background: 'rgba(255, 255, 255, 0.7)',
        color: 'var(--pm-text-secondary)',
        outline: 'none',
        cursor: 'pointer',
        appearance: 'none',
        backgroundImage: `url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L5 5L9 1' stroke='%23999' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E")`,
        backgroundRepeat: 'no-repeat',
        backgroundPosition: 'right 8px center',
      }}
    >
      {options.map((opt) => (
        <option key={opt} value={opt}>
          {opt}
        </option>
      ))}
    </select>
  );
}

// ─── ExportPage ──────────────────────────────────────────────────────────────

export function ExportPage(): JSX.Element {
  // ── State ────────────────────────────────────────────────────────────────
  const [activeTab, setActiveTab] = useState<ExportTab>('export');
  const [items, setItems] = useState<Array<{ output: DistilledOutput; sourceItem: SourceItem }>>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

  // Table state
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('全部');
  const [sourceFilter, setSourceFilter] = useState<SourceFilter>('全部');
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedRow, setSelectedRow] = useState<ExportTableRow | null>(null);
  const pageSize = 10;

  // Export records hook
  const { records: exportRecords, refresh: refreshRecords } = useExportRecords();

  // ── Data Loading ─────────────────────────────────────────────────────────
  const loadExportableItems = useCallback(async () => {
    try {
      setError(null);
      setLoading(true);
      const distilledItems = await window.acmind.sourceItems.list({ status: 'distilled' });
      const acceptedOutputs = (await window.acmind.distilledOutputs.list({}))
        .filter((output) => output.reviewStatus === 'accepted' || output.reviewStatus === 'edited');

      const mapped = await Promise.all(
        acceptedOutputs.map(async (output) => {
          const sourceItem = distilledItems.find((si) => si.id === output.sourceItemId);
          return { output, sourceItem: sourceItem ?? null };
        }),
      );

      setItems(
        mapped.filter(
          (m): m is { output: DistilledOutput; sourceItem: SourceItem } => m.sourceItem !== null,
        ),
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      // Phase 1: 友好化常见错误提示
      if (msg.includes('Vault path does not exist')) {
        setError('写入路径不存在，请检查设置中的 Vault 路径是否正确');
      } else if (msg.includes('not configured')) {
        setError('写入路径未设置，请先在设置中配置 Obsidian Vault 路径');
      } else if (msg.includes('EACCES') || msg.includes('permission')) {
        setError('文件写入失败：没有写入权限，请检查目录权限');
      } else {
        setError(msg);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadExportableItems();
  }, [loadExportableItems]);

  useEffect(() => {
    const unsubscribe = window.acmind.onRecordsChanged(() => {
      void loadExportableItems();
    });
    return unsubscribe;
  }, [loadExportableItems]);

  // ── Build Table Rows ─────────────────────────────────────────────────────
  const tableRows = useMemo<ExportTableRow[]>(() => {
    const rows: ExportTableRow[] = [];

    // Add export records as "已写入" or "写入失败"
    for (const record of exportRecords) {
      const matchedItem = items.find((i) => i.output.id === record.distilledOutputId);
      const status: OutputStatus =
        record.status === 'success' ? '已写入' : record.status === 'failed' ? '写入失败' : '待写入';
      rows.push({
        id: record.id,
        title:
          matchedItem?.output.suggestedTitle ??
          matchedItem?.sourceItem.previewText ??
          record.relativeFilePath.split('/').pop() ??
          '未命名',
        status,
        outputPath: `${record.vaultPath}/${record.relativeFilePath}`,
        outputTime: formatTime(record.exportedAt),
        source: matchedItem?.sourceItem.sourceApp ?? matchedItem?.sourceItem.source ?? '未知',
        record,
        output: matchedItem?.output,
        sourceItem: matchedItem?.sourceItem,
      });
    }

    // Add items that don't have export records yet as "待写入"
    const exportedOutputIds = new Set(exportRecords.map((r) => r.distilledOutputId));
    for (const item of items) {
      if (!exportedOutputIds.has(item.output.id)) {
        rows.push({
          id: `pending-${item.output.id}`,
          title: item.output.suggestedTitle ?? item.sourceItem.previewText ?? '未命名',
          status: '待写入',
          outputPath: '-',
          outputTime: formatTime(item.output.createdAt),
          source: item.sourceItem.sourceApp ?? item.sourceItem.source ?? '未知',
          output: item.output,
          sourceItem: item.sourceItem,
        });
      }
    }

    // Sort by time descending
    rows.sort((a, b) => {
      const ta = a.record?.exportedAt ?? a.output?.createdAt ?? 0;
      const tb = b.record?.exportedAt ?? b.output?.createdAt ?? 0;
      return tb - ta;
    });

    return rows;
  }, [exportRecords, items]);

  // ── Available sources for filter ─────────────────────────────────────────
  const availableSources = useMemo<string[]>(() => {
    const sources = new Set(tableRows.map((r) => r.source).filter(Boolean));
    return Array.from(sources).sort();
  }, [tableRows]);

  // ── Filtered rows ────────────────────────────────────────────────────────
  const filteredRows = useMemo(() => {
    return tableRows.filter((row) => {
      // Search
      if (searchQuery) {
        const q = searchQuery.toLowerCase();
        if (
          !row.title.toLowerCase().includes(q) &&
          !row.outputPath.toLowerCase().includes(q)
        ) {
          return false;
        }
      }
      // Status filter
      if (statusFilter !== '全部' && row.status !== statusFilter) {
        return false;
      }
      // Source filter
      if (sourceFilter !== '全部' && row.source !== sourceFilter) {
        return false;
      }
      return true;
    });
  }, [tableRows, searchQuery, statusFilter, sourceFilter]);

  // ── Paginated rows ───────────────────────────────────────────────────────
  const paginatedRows = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredRows.slice(start, start + pageSize);
  }, [filteredRows, currentPage, pageSize]);

  // Reset page when filters change
  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, statusFilter, sourceFilter]);

  // ── Actions ──────────────────────────────────────────────────────────────
  const handleExportSelected = async () => {
    if (selectedIds.size === 0) return;
    try {
      // Phase 1: 导出前检查 vault path 是否已设置
      const appSettings = await window.acmind.settings.get();
      const vaultPath = appSettings?.vault?.vaultPath;
      if (!vaultPath) {
        setError('写入路径未设置，请先在设置中配置 Obsidian Vault 路径');
        return;
      }

      setExporting(true);
      setError(null);
      const ids = Array.from(selectedIds);

      // V2.1: 优先走 pipeline retry（逐条自动整理 + 写入）
      if (window.acmind?.pipeline) {
        let succeeded = 0;
        let failed = 0;
        let firstError = '';

        for (const id of ids) {
          // 尝试通过 exportRecord 找到 sourceItemId
          const record = exportRecords.find((r: { distilledOutputId: string }) => r.distilledOutputId === id);
          if (record?.sourceItemId) {
            const result = await window.acmind.pipeline.retryExport(record.sourceItemId);
            if (result.success) {
              succeeded++;
            } else {
              failed++;
              if (!firstError) firstError = result.error ?? '未知错误';
            }
          } else {
            // 无 sourceItemId，回退到 legacy 单条写入
            try {
              const legacyRecord = await window.acmind.export.single(id);
              if (legacyRecord.status === 'success' || legacyRecord.status === 'conflict') {
                succeeded++;
              } else {
                failed++;
                if (!firstError) firstError = legacyRecord.error ?? '未知错误';
              }
            } catch (legacyError) {
              failed++;
              if (!firstError) {
                firstError = legacyError instanceof Error ? legacyError.message : String(legacyError);
              }
            }
          }
        }

        if (failed > 0) {
          const detail = failed === 1 ? firstError : `${failed} 条失败，首条: ${firstError}`;
          if (detail.includes('Vault path does not exist')) {
            setError('写入路径不存在，请检查设置中的 Vault 路径是否正确');
          } else if (detail.includes('EACCES') || detail.includes('permission')) {
            setError('文件写入失败：没有写入权限，请检查目录权限');
          } else {
            setError(detail);
          }
        } else if (succeeded > 0) {
          // 全部成功
        }

        setSelectedIds(new Set());
        await loadExportableItems();
        await refreshRecords();
        return;
      }

      // Fallback: legacy export.batch
      const records = await window.acmind.export.batch(ids);

      // Phase 1: 根据 records.status 汇总结果，杜绝 false-success
      const succeeded = records.filter((r) => r.status === 'success').length;
      const conflicted = records.filter((r) => r.status === 'conflict').length;
      const failed = records.filter((r) => r.status === 'failed');
      const failedCount = failed.length;

      if (failedCount > 0) {
        // 取第一条失败记录的 error 作为展示
        const firstError = failed[0].error || '未知错误';
        const detail = failedCount === 1
          ? firstError
          : `${failedCount} 条失败，首条: ${firstError}`;
        if (detail.includes('Vault path does not exist')) {
          setError('写入路径不存在，请检查设置中的 Vault 路径是否正确');
        } else if (detail.includes('EACCES') || detail.includes('permission')) {
          setError('文件写入失败：没有写入权限，请检查目录权限');
        } else {
          setError(detail);
        }
      } else if (conflicted > 0 && succeeded === 0) {
        setError(`${conflicted} 条文件已存在，已跳过`);
      } else if (conflicted > 0) {
        // 有成功也有冲突，不算错误，用 toast 即可
      }

      setSelectedIds(new Set());
      await loadExportableItems();
      await refreshRecords();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setExporting(false);
    }
  };

  const toggleItem = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const selectAll = () => {
    if (selectedIds.size === items.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(items.map((i) => i.output.id)));
    }
  };

  const handleRefresh = async () => {
    await loadExportableItems();
    await refreshRecords();
  };

  const handleRetryRecord = async (recordId: string) => {
    try {
      // V2.1: 优先走 pipeline retry（自动重新整理 + 写入）
      const record = exportRecords.find((r: { id: string }) => r.id === recordId);
      if (record?.sourceItemId && window.acmind?.pipeline) {
        const result = await window.acmind.pipeline.retryExport(record.sourceItemId);
        if (result.success) {
          await refreshRecords();
          return;
        }
        // Pipeline retry failed, fall through to legacy retry
      }
      // Fallback: legacy export retry
      await window.acmind.export.retry(recordId);
      await refreshRecords();
    } catch {
      // ignore
    }
  };

  const handleRevealInVault = async (recordId: string) => {
    try {
      await window.acmind.export.revealInVault(recordId);
    } catch {
      // ignore
    }
  };

  // ── Tab config ───────────────────────────────────────────────────────────
  const tabs: { key: ExportTab; label: string }[] = [
    { key: 'export', label: '写入记录' },
    { key: 'vault-config', label: '知识库设置' },
    { key: 'history', label: '历史记录' },
  ];

  // ── Render: Vault Config Tab ─────────────────────────────────────────────
  if (activeTab === 'vault-config') {
    return (
      <PageShell>
        <div className="acmind-tab-bar">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              type="button"
              className={`acmind-tab-item ${activeTab === tab.key ? 'active' : ''}`}
              onClick={() => setActiveTab(tab.key)}
            >
              {tab.label}
            </button>
          ))}
        </div>
        <div className="flex-1 min-h-0">
          <VaultConfigPanel />
        </div>
      </PageShell>
    );
  }

  // ── Render: History Tab ──────────────────────────────────────────────────
  if (activeTab === 'history') {
    return (
      <PageShell>
        <div className="acmind-tab-bar">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              type="button"
              className={`acmind-tab-item ${activeTab === tab.key ? 'active' : ''}`}
              onClick={() => setActiveTab(tab.key)}
            >
              {tab.label}
            </button>
          ))}
        </div>
        <div className="flex-1 min-h-0">
          <ExportHistory />
        </div>
      </PageShell>
    );
  }

  // ── Render: Export Records Tab (main) ────────────────────────────────────
  return (
    <PageShell className="flex h-full flex-col gap-4 p-0">
      <div className="px-6 pt-5">
        <PageHeader
          eyebrow="资料库"
          title="入库记录"
          description="查看已入库的 Markdown 文件、来源内容和 Obsidian 写入位置。"
          actions={(
            <div className="flex items-center gap-2">
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="refresh" size={14} />} onClick={handleRefresh}>
                刷新
              </Button>
              <FilterSelect
                value={activeTab}
                options={tabs.map((t) => t.key)}
                onChange={(v) => setActiveTab(v as ExportTab)}
              />
            </div>
          )}
        />
      </div>

      <div className="px-6">
        <Section title="筛选" description="按标题、状态和来源查看导出结果。" compact>
          <div
            className="grid items-center gap-3"
            style={{
              gridTemplateColumns: 'minmax(0, 1fr) 140px 140px',
            }}
          >
            <SearchField
              placeholder="搜索标题或写入路径..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full"
            />
            <FilterSelect
              value={statusFilter}
              options={['全部', '已写入', '待写入', '写入失败']}
              onChange={(v) => setStatusFilter(v as StatusFilter)}
            />
            <FilterSelect
              value={sourceFilter}
              options={['全部', ...availableSources]}
              onChange={(v) => setSourceFilter(v as SourceFilter)}
            />
          </div>
        </Section>
      </div>

      {/* ── Main Content: Table + Detail Panel ─────────────────────────── */}
      <div className="flex flex-1 min-h-0">
        {/* Table area */}
        <div className="flex flex-col flex-1 min-w-0">
          {/* Table header */}
          <div
            className="flex items-center px-4 py-2"
            style={{
              borderBottom: '1px solid color-mix(in srgb, var(--pm-border-subtle) 60%, transparent)',
              background: 'color-mix(in srgb, var(--pm-bg-secondary) 50%, transparent)',
            }}
          >
            <div style={{ width: 40, flexShrink: 0 }} className="flex items-center justify-center">
              <input
                type="checkbox"
                checked={selectedIds.size === items.length && items.length > 0}
                onChange={selectAll}
                className="accent-sky-500"
              />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center" style={{ fontSize: 11, fontWeight: 600, color: 'var(--pm-text-tertiary)' }}>
                <span style={{ width: '30%', flexShrink: 0 }}>标题</span>
                <span style={{ width: 100, flexShrink: 0 }}>写入状态</span>
                <span style={{ flex: 1, minWidth: 0 }}>写入路径</span>
                <span style={{ width: 130, flexShrink: 0 }}>写入时间</span>
                <span style={{ width: 80, flexShrink: 0 }}>来源</span>
                <span style={{ width: 80, flexShrink: 0, textAlign: 'center' }}>操作</span>
              </div>
            </div>
          </div>

          {/* Table body */}
          <ScrollContainer>
            {loading ? (
              <div className="p-4">
                <LoadingState title="正在加载写入记录" description="正在读取写入结果和待写入内容。" />
              </div>
            ) : error ? (
              <div className="p-4">
                <ErrorState
                  title="写入记录加载失败"
                  reason={error}
                  suggestion="请稍后重试，或先检查 Obsidian Vault 路径和权限。"
                  action={{ label: '重新加载', onClick: handleRefresh }}
                />
              </div>
            ) : filteredRows.length === 0 ? (
              <div className="p-4">
                <EmptyState
                  icon={<AcMindIcon name="filled-output" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
                  title="还没有入库记录"
                  description="完成整理并确认入库后，文件会出现在这里。"
                  action={{
                    label: '去收集箱',
                    onClick: () =>
                      window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: 'capture-inbox' })),
                  }}
                />
              </div>
            ) : (
              <div className="flex flex-col gap-2 p-3">
                {paginatedRows.map((row) => {
                  const fileName = row.outputPath !== '-' ? row.outputPath.split('/').pop() ?? row.outputPath : '';
                  const dirPath = row.outputPath !== '-' ? row.outputPath.substring(0, row.outputPath.lastIndexOf('/')) : '';
                  return (
                    <div
                      key={row.id}
                      className={`acmind-export-card motion-interactive ${selectedRow?.id === row.id ? 'is-selected' : ''}`}
                      onClick={() => setSelectedRow(selectedRow?.id === row.id ? null : row)}
                    >
                      {/* Top row: checkbox + title + status + actions */}
                      <div className="flex items-center gap-3">
                        {/* Checkbox */}
                        <div className="flex items-center justify-center" style={{ width: 32, flexShrink: 0 }}>
                          {row.output && (
                            <input
                              type="checkbox"
                              checked={selectedIds.has(row.output.id)}
                              onChange={(e) => {
                                e.stopPropagation();
                                toggleItem(row.output!.id);
                              }}
                              className="accent-sky-500"
                            />
                          )}
                        </div>

                        {/* Title */}
                        <span
                          className="truncate flex-1 min-w-0"
                          style={{
                            color: 'var(--pm-text-primary)',
                            fontWeight: 500,
                            fontSize: 13,
                          }}
                        >
                          {row.title}
                        </span>

                        {/* Status */}
                        <span style={{ flexShrink: 0 }}>
                          <StatusBadge tone={STATUS_TONE[row.status]} label={row.status} />
                        </span>

                        {/* Actions */}
                        <span style={{ flexShrink: 0 }}>
                          <div className="flex items-center gap-1">
                            {row.record && row.status === '已写入' && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleRevealInVault(row.record!.id);
                                }}
                                title="在 Obsidian 中打开"
                              >
                                打开
                              </Button>
                            )}
                            {(row.status === '写入失败' || row.status === '待写入') && row.record && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleRetryRecord(row.record!.id);
                                }}
                                title="重试写入 Obsidian"
                              >
                                重试写入
                              </Button>
                            )}
                          </div>
                        </span>
                      </div>

                      {/* Bottom row: path + time + source */}
                      <div className="flex items-center gap-4" style={{ paddingLeft: 32 }}>
                        {/* Output path (truncated) */}
                        {row.outputPath !== '-' && (
                          <span
                            className="line-clamp-2"
                            style={{
                              flex: 1,
                              minWidth: 0,
                              color: 'var(--pm-text-tertiary)',
                              fontSize: 11,
                              display: '-webkit-box',
                              WebkitLineClamp: 2,
                              WebkitBoxOrient: 'vertical',
                              overflow: 'hidden',
                            }}
                            title={row.outputPath}
                          >
                            {fileName}
                            {dirPath && (
                              <span style={{ color: 'var(--pm-text-disabled)', marginLeft: 6 }}>
                                {dirPath}
                              </span>
                            )}
                          </span>
                        )}
                        {/* Time */}
                        <span
                          style={{
                            flexShrink: 0,
                            color: 'var(--pm-text-tertiary)',
                            fontSize: 11,
                          }}
                        >
                          {row.outputTime}
                        </span>
                        {/* Source */}
                        <span
                          style={{
                            flexShrink: 0,
                            color: 'var(--pm-text-tertiary)',
                            fontSize: 11,
                          }}
                        >
                          {row.source}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </ScrollContainer>

          {/* Pagination */}
          {filteredRows.length > 0 && (
            <div
              style={{
                borderTop: '1px solid color-mix(in srgb, var(--pm-border-subtle) 60%, transparent)',
              }}
            >
              <Pagination
                total={filteredRows.length}
                page={currentPage}
                pageSize={pageSize}
                onPageChange={setCurrentPage}
              />
            </div>
          )}

          {/* Batch action bar — legacy fallback for items not yet auto-exported */}
          {selectedIds.size > 0 && (
            <div
              className="flex items-center justify-between px-4 py-2"
              style={{
                borderTop: '1px solid color-mix(in srgb, var(--pm-border-subtle) 60%, transparent)',
                background: 'color-mix(in srgb, var(--pm-bg-secondary) 50%, white 50%)',
              }}
            >
              <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                已选择 {selectedIds.size} 条 · 手动补救写入
              </span>
              <Button
                variant="secondary"
                size="sm"
                disabled={exporting}
                onClick={handleExportSelected}
              >
                {exporting ? '正在写入...' : `手动写入 ${selectedIds.size} 条`}
              </Button>
            </div>
          )}
        </div>

        {/* Right detail panel */}
        {selectedRow && (
          <DetailPanel
            row={selectedRow}
            onClose={() => setSelectedRow(null)}
            onRetry={handleRetryRecord}
          />
        )}
      </div>
    </PageShell>
  );
}
