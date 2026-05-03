import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, EmptyState, ErrorState, LoadingState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { useToast } from '../../components/shared/ToastViewport';
import { useClipboardItems, type ClipboardFilter } from '../../hooks/useClipboardItems';
import { useAI } from '../../hooks/useAI';
import type { ClipboardItem } from '../../../shared/types';

// ─── Constants ───────────────────────────────────────────────────────────────

const FILTER_OPTIONS: { value: ClipboardFilter; label: string }[] = [
  { value: 'all', label: '全部' },
  { value: 'text', label: '文本' },
  { value: 'url', label: '链接' },
  { value: 'image', label: '图片' },
];

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

function truncateText(text: string, maxLen = 120): string {
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen) + '…';
}

// ─── ClipboardCard ───────────────────────────────────────────────────────────

interface ClipboardCardProps {
  item: ClipboardItem;
  onCopy: (id: string) => void;
  onDelete: (id: string) => void;
  onPin: (id: string) => void;
  onUnpin: (id: string) => void;
  onSaveToInbox: (id: string) => void;
  aiActions: { id: string; name: string; inputTypes: string[] }[];
  onRunAiAction: (actionId: string, itemId: string) => void;
  aiRunning: boolean;
}

function ClipboardCard({ item, onCopy, onDelete, onPin, onUnpin, onSaveToInbox, aiActions, onRunAiAction, aiRunning }: ClipboardCardProps): JSX.Element {
  const isSaved = !!item.sourceItemId;
  const isUrl = item.contentType === 'url';
  const isImage = item.contentType === 'image';
  const [showAiMenu, setShowAiMenu] = useState(false);
  const aiMenuRef = useRef<HTMLDivElement>(null);

  const hasText = !!item.text?.trim();
  const applicableActions = aiActions.filter(a => a.inputTypes.length === 0 || a.inputTypes.includes('text'));

  useEffect(() => {
    if (!showAiMenu) return;
    const handler = (e: MouseEvent) => {
      if (aiMenuRef.current && !aiMenuRef.current.contains(e.target as Node)) {
        setShowAiMenu(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [showAiMenu]);

  return (
    <div className="acmind-card acmind-card-grouped" style={{ padding: 14 }}>
      {/* Header row */}
      <div className="flex items-center justify-between" style={{ marginBottom: 8 }}>
        <div className="flex items-center gap-2">
          <StatusBadge
            tone={isUrl ? 'info' : isImage ? 'processing' : 'neutral'}
            label={isUrl ? '链接' : isImage ? '图片' : '文本'}
          />
          {item.sourceApp && (
            <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
              {item.sourceApp}
            </span>
          )}
          {item.isPinned && (
            <PinStackIcon name="pin-top" size={12} style={{ color: 'var(--pm-brand)' }} />
          )}
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
        {isImage ? (
          <div
            className="flex items-center gap-2 rounded-[8px] px-3 py-2"
            style={{ background: 'var(--pm-bg-elevated)' }}
          >
            <PinStackIcon name="image" size={16} style={{ color: 'var(--pm-text-tertiary)' }} />
            <span className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>
              剪贴板图片
            </span>
          </div>
        ) : isUrl ? (
          <a
            href={item.text}
            target="_blank"
            rel="noopener noreferrer"
            className="block rounded-[8px] px-3 py-2 text-[13px] no-underline"
            style={{
              background: 'var(--pm-info-bg)',
              color: 'var(--pm-info)',
              wordBreak: 'break-all',
            }}
          >
            <span className="flex items-center gap-1.5">
              <PinStackIcon name="filled-link" size={13} />
              {truncateText(item.text || '', 100)}
            </span>
          </a>
        ) : (
          <p
            className="text-[13px] leading-5"
            style={{
              color: 'var(--pm-text-primary)',
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
            }}
          >
            {truncateText(item.text || '', 200)}
          </p>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center gap-1.5">
        {!isImage && (
          <Button
            variant="ghost"
            size="sm"
            leadingIcon={<PinStackIcon name="duplicate" size={14} />}
            onClick={() => onCopy(item.id)}
          >
            复制
          </Button>
        )}
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name={isSaved ? 'status-success' : 'filled-inbox'} size={14} />}
          onClick={() => onSaveToInbox(item.id)}
          disabled={isSaved}
        >
          {isSaved ? '已入库' : '保存'}
        </Button>
        {hasText && applicableActions.length > 0 && (
          <div className="relative" ref={aiMenuRef}>
            <Button
              variant="ghost"
              size="sm"
              leadingIcon={<PinStackIcon name="spark" size={14} />}
              onClick={() => setShowAiMenu(!showAiMenu)}
              disabled={aiRunning}
            >
              AI
            </Button>
            {showAiMenu && (
              <div
                className="absolute left-0 top-full mt-1 z-50 min-w-[160px] rounded-lg border py-1 shadow-lg"
                style={{
                  background: 'var(--pm-bg-surface)',
                  borderColor: 'var(--pm-border-subtle)',
                }}
              >
                {applicableActions.map((action) => (
                  <button
                    key={action.id}
                    type="button"
                    className="block w-full px-3 py-1.5 text-left text-[12px] hover:bg-[var(--pm-bg-elevated)]"
                    style={{ color: 'var(--pm-text-primary)' }}
                    onClick={() => { setShowAiMenu(false); onRunAiAction(action.id, item.id); }}
                  >
                    {action.name}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name={item.isPinned ? 'line-delete' : 'pin-top'} size={14} />}
          onClick={() => item.isPinned ? onUnpin(item.id) : onPin(item.id)}
        >
          {item.isPinned ? '取消固定' : '固定'}
        </Button>
        <div className="flex-1" />
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<PinStackIcon name="act-delete" size={14} />}
          onClick={() => onDelete(item.id)}
        />
      </div>
    </div>
  );
}

// ─── ClipboardPage ───────────────────────────────────────────────────────────

export function ClipboardPage(): JSX.Element {
  const { addToast } = useToast();
  const {
    items,
    loading,
    error,
    refresh,
    filter,
    setFilter,
    searchQuery,
    setSearchQuery,
    watching,
    paused,
    togglePause,
    copyItem,
    deleteItem,
    pinItem,
    unpinItem,
    saveToInbox,
    clearHistory,
  } = useClipboardItems();
  const { actions, runAction } = useAI();
  const [aiRunning, setAiRunning] = useState(false);

  const [confirmClear, setConfirmClear] = useState(false);

  const handleCopy = useCallback(async (id: string) => {
    const success = await copyItem(id);
    if (success) {
      addToast('已复制到剪贴板', 'success');
    } else {
      addToast('复制失败', 'error');
    }
  }, [copyItem, addToast]);

  const handleDelete = useCallback(async (id: string) => {
    const success = await deleteItem(id);
    if (success) {
      addToast('已删除', 'success');
    }
  }, [deleteItem, addToast]);

  const handlePin = useCallback(async (id: string) => {
    await pinItem(id);
    addToast('已固定', 'success');
  }, [pinItem, addToast]);

  const handleUnpin = useCallback(async (id: string) => {
    await unpinItem(id);
    addToast('已取消固定', 'success');
  }, [unpinItem, addToast]);

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

  const handleClearHistory = useCallback(async () => {
    if (!confirmClear) {
      setConfirmClear(true);
      setTimeout(() => setConfirmClear(false), 3000);
      return;
    }
    const success = await clearHistory();
    if (success) {
      addToast('已清空历史（固定项已保留）', 'success');
    }
    setConfirmClear(false);
  }, [confirmClear, clearHistory, addToast]);

  const handleRunAiAction = useCallback(async (actionId: string, itemId: string) => {
    const item = items.find(i => i.id === itemId);
    if (!item?.text?.trim()) {
      addToast('无可用文本内容', 'error');
      return;
    }
    setAiRunning(true);
    try {
      const result = await runAction(actionId, item.text);
      if (result.success) {
        addToast('AI 处理完成', 'success');
      } else {
        addToast(result.error || 'AI 处理失败', 'error');
      }
    } catch (err) {
      addToast(err instanceof Error ? err.message : 'AI 处理失败', 'error');
    } finally {
      setAiRunning(false);
    }
  }, [items, runAction, addToast]);

  // ── Render ──

  const statusLabel = !watching ? '已关闭' : paused ? '已暂停' : '监听中';
  const statusTone = !watching ? 'neutral' : paused ? 'warning' : 'success';

  return (
    <PageShell>
      <PageHeader
        title="剪贴板"
        description={`${items.length} 条记录`}
        actions={
          <div className="flex items-center gap-2">
            <StatusBadge tone={statusTone} label={statusLabel} />
            <Button
              variant="ghost"
              size="sm"
              leadingIcon={<PinStackIcon name={paused ? 'status-running' : 'status-warning'} size={14} />}
              onClick={togglePause}
            >
              {paused ? '恢复' : '暂停'}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              leadingIcon={<PinStackIcon name="act-delete" size={14} />}
              onClick={handleClearHistory}
            >
              {confirmClear ? '确认清空？' : '清空'}
            </Button>
          </div>
        }
      />

      <Section title="剪贴板历史">
        {/* Search & Filter */}
        <div className="flex items-center gap-3" style={{ marginBottom: 16 }}>
          <div className="flex-1">
            <input
              type="text"
              placeholder="搜索剪贴板内容…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="acmind-input"
              style={{ width: '100%' }}
            />
          </div>
          <div className="flex items-center gap-1">
            {FILTER_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                type="button"
                className={`acmind-btn acmind-btn-ghost motion-button ${filter === opt.value ? 'is-selected' : ''}`}
                style={{
                  height: 32,
                  paddingInline: 10,
                  fontSize: 12,
                  borderRadius: 8,
                  background: filter === opt.value ? 'var(--pm-brand-soft)' : undefined,
                  color: filter === opt.value ? 'var(--pm-brand)' : undefined,
                }}
                onClick={() => setFilter(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        {loading ? (
          <LoadingState title="加载中" description="正在读取剪贴板历史…" />
        ) : error ? (
          <ErrorState
            title="加载失败"
            reason={error}
            suggestion="请检查应用状态后重试"
            action={{ label: '重试', onClick: refresh }}
          />
        ) : items.length === 0 ? (
          <EmptyState
            icon={<PinStackIcon name="filled-clipboard" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title="还没有剪贴板记录"
            description="复制一段文字或链接，AcMind 会自动捕获并显示在这里。"
            action={{ label: '刷新', onClick: refresh }}
          />
        ) : (
          <div className="flex flex-col gap-2">
            {items.map((item) => (
              <ClipboardCard
                key={item.id}
                item={item}
                onCopy={handleCopy}
                onDelete={handleDelete}
                onPin={handlePin}
                onUnpin={handleUnpin}
                onSaveToInbox={handleSaveToInbox}
                aiActions={actions.filter(a => a.enabled).map(a => ({ id: a.id, name: a.name, inputTypes: a.inputTypes }))}
                onRunAiAction={handleRunAiAction}
                aiRunning={aiRunning}
              />
            ))}
          </div>
        )}
      </Section>
    </PageShell>
  );
}
