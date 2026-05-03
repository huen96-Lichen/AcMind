import { useCallback, useState } from 'react';
import { Button, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import type { PinStackIconName } from '../../design-system/icons';
import { useToast } from '../../components/shared/ToastViewport';
import { useShelfItems } from '../../hooks/useShelfItems';
import type { ShelfItem } from '../../../shared/types';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatTime(timestamp: number): string {
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);
  const diffHour = Math.floor(diffMs / 3600000);

  if (diffMin < 1) return '刚刚';
  if (diffMin < 60) return `${diffMin} 分钟前`;
  if (diffHour < 24) return `${diffHour} 小时前`;

  const isToday = date.toDateString() === now.toDateString();
  if (isToday) {
    return `今天 ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }
  return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
}

function getOriginLabel(origin?: ShelfItem['origin']): string {
  switch (origin) {
    case 'drag_drop': return '拖拽';
    case 'clipboard': return '剪贴板';
    case 'capture': return '采集';
    case 'manual': return '手动';
    default: return '未知';
  }
}

function getOriginIcon(origin?: ShelfItem['origin']): PinStackIconName {
  switch (origin) {
    case 'drag_drop': return 'filled-file-import';
    case 'clipboard': return 'filled-clipboard';
    case 'capture': return 'act-quick-capture';
    case 'manual': return 'text';
    default: return 'act-quick-capture';
  }
}

// ─── ShelfCard ───────────────────────────────────────────────────────────────

interface ShelfCardProps {
  item: ShelfItem;
  onRemove: (id: string) => void;
  onSaveToInbox: (id: string) => void;
}

function ShelfCard({ item, onRemove, onSaveToInbox }: ShelfCardProps): JSX.Element {
  const isSaved = item.status === 'saved_to_inbox';
  const hasFiles = item.assetFileIds.length > 0;

  return (
    <div className="acmind-card acmind-card-grouped" style={{ padding: 14 }}>
      {/* Header row */}
      <div className="flex items-center justify-between" style={{ marginBottom: 8 }}>
        <div className="flex items-center gap-2">
          <StatusBadge
            tone={hasFiles ? 'info' : 'neutral'}
            label={hasFiles ? `${item.assetFileIds.length} 个文件` : '文本'}
          />
          <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            {getOriginLabel(item.origin)}
          </span>
          {isSaved && (
            <StatusBadge tone="success" label="已入库" />
          )}
        </div>
        <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
          {formatTime(item.createdAt)}
        </span>
      </div>

      {/* Content preview */}
      <div style={{ marginBottom: 10 }}>
        <div
          className="flex items-center gap-2 rounded-[8px] px-3 py-2"
          style={{ background: 'var(--pm-bg-elevated)' }}
        >
          <PinStackIcon name={getOriginIcon(item.origin)} size={16} style={{ color: 'var(--pm-text-tertiary)' }} />
          <span className="text-[13px] truncate" style={{ color: 'var(--pm-text-primary)' }}>
            {item.label || '未命名项目'}
          </span>
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-1.5">
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name={isSaved ? 'status-success' : 'filled-inbox'} size={14} />}
          onClick={() => onSaveToInbox(item.id)}
          disabled={isSaved}
        >
          {isSaved ? '已入库' : '保存到收集箱'}
        </Button>
        <div className="flex-1" />
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name="act-delete" size={14} />}
          onClick={() => onRemove(item.id)}
        />
      </div>
    </div>
  );
}

// ─── ShelfPage ───────────────────────────────────────────────────────────────

export function ShelfPage(): JSX.Element {
  const { addToast } = useToast();
  const {
    items,
    loading,
    error,
    refresh,
    addFiles,
    addText,
    removeItem,
    saveToInbox,
  } = useShelfItems();

  const [showAddText, setShowAddText] = useState(false);
  const [textInput, setTextInput] = useState('');

  const handleRemove = useCallback(async (id: string) => {
    const success = await removeItem(id);
    if (success) {
      addToast('已移除', 'success');
    }
  }, [removeItem, addToast]);

  const handleSaveToInbox = useCallback(async (id: string) => {
    const result = await saveToInbox(id);
    if (result.alreadySaved) {
      addToast('该项目已保存到收集箱', 'info');
    } else if (result.success) {
      addToast('已保存到收集箱', 'success');
    } else {
      addToast('保存失败', 'error');
    }
  }, [saveToInbox, addToast]);

  const handleAddText = useCallback(async () => {
    if (!textInput.trim()) return;
    const success = await addText(textInput.trim());
    if (success) {
      addToast('已添加到 Shelf', 'success');
      setTextInput('');
      setShowAddText(false);
    } else {
      addToast('添加失败', 'error');
    }
  }, [textInput, addText, addToast]);

  const handleDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();

    const files = Array.from(e.dataTransfer.files);
    if (files.length > 0) {
      // In Electron, file.path gives the real filesystem path
      const filePaths = files.map(f => (f as File & { path?: string }).path || f.name);
      const success = await addFiles(filePaths);
      if (success) {
        addToast(`已添加 ${files.length} 个文件到 Shelf`, 'success');
      } else {
        addToast('添加文件失败', 'error');
      }
    }
  }, [addFiles, addToast]);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  }, []);

  // ── Render ──

  return (
    <PageShell>
      <PageHeader
        title="Shelf"
        description={`${items.length} 个临时项目`}
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="ghost"
              size="sm"
              leadingIcon={<PinStackIcon name="text" size={14} />}
              onClick={() => setShowAddText(!showAddText)}
            >
              添加文本
            </Button>
          </div>
        }
      />

      <Section title="临时文件架">
        {/* Drop zone */}
        <div
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          className="flex items-center justify-center rounded-[10px] border-2 border-dashed transition-colors"
          style={{
            borderColor: 'var(--pm-border)',
            padding: '24px 16px',
            marginBottom: 16,
            background: 'var(--pm-bg-elevated)',
          }}
        >
          <div className="flex flex-col items-center gap-2">
            <PinStackIcon name="filled-file-import" size={24} style={{ color: 'var(--pm-text-tertiary)' }} />
            <span className="text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
              拖拽文件到这里，或使用上方按钮添加文本
            </span>
          </div>
        </div>

        {/* Add text input */}
        {showAddText && (
          <div className="flex gap-2" style={{ marginBottom: 16 }}>
            <input
              type="text"
              placeholder="输入文本内容…"
              value={textInput}
              onChange={(e) => setTextInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') handleAddText(); }}
              className="acmind-input flex-1"
            />
            <Button
              variant="primary"
              size="sm"
              onClick={handleAddText}
              disabled={!textInput.trim()}
            >
              添加
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => { setShowAddText(false); setTextInput(''); }}
            >
              取消
            </Button>
          </div>
        )}

        {/* Content */}
        {loading ? (
          <LoadingState title="加载中" description="正在读取 Shelf…" />
        ) : error ? (
          <ErrorState
            title="加载失败"
            reason={error}
            suggestion="请检查应用状态后重试"
            action={{ label: '重试', onClick: refresh }}
          />
        ) : items.length === 0 ? (
          <EmptyState
            icon={<PinStackIcon name="empty-inbox" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="Shelf 是空的"
            description="拖拽文件到这里临时存放，或点击「添加文本」手动添加内容。"
            action={{ label: '刷新', onClick: refresh }}
          />
        ) : (
          <div className="flex flex-col gap-2">
            {items.map((item) => (
              <ShelfCard
                key={item.id}
                item={item}
                onRemove={handleRemove}
                onSaveToInbox={handleSaveToInbox}
              />
            ))}
          </div>
        )}
      </Section>
    </PageShell>
  );
}
