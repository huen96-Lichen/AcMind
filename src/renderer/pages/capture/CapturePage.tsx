/**
 * CapturePage — 截图与贴图主页面 (Phase 2A + 2B)
 *
 * 功能：
 * - 截图按钮（触发全屏截图）
 * - 最近截图列表（缩略图 + 操作）
 * - 已钉图片列表
 * - 贴图到桌面
 * - OCR 文字提取
 * - 保存到 Inbox
 */

import { useState, useCallback } from 'react';
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
import { useCaptures } from '../../hooks/useCaptures';
import { useToast } from '../../components/shared/ToastViewport';
import type { SourceItem, PinnedImage } from '../../../shared/types';

export function CapturePage(): JSX.Element {
  const {
    recentCaptures,
    pinnedImages,
    loading,
    error,
    takeScreenshot,
    pinImage,
    closePinnedImage,
    savePinnedToInbox,
    ocrExtract,
    ocrSaveToInbox,
    refresh,
  } = useCaptures();

  const { addToast } = useToast();
  const [busyAction, setBusyAction] = useState<string | null>(null);

  // 截图
  const handleScreenshot = useCallback(async () => {
    setBusyAction('screenshot');
    try {
      const ok = await takeScreenshot();
      addToast(ok ? '截图已保存到收集箱' : '截图未完成，请检查屏幕录制权限', ok ? 'success' : 'error');
    } finally {
      setBusyAction(null);
    }
  }, [takeScreenshot, addToast]);

  // 钉图到桌面
  const handlePinToDesktop = useCallback(async (item: SourceItem) => {
    if (!item.contentPath) return;
    setBusyAction(`pin-${item.id}`);
    try {
      const pinned = await pinImage(item.contentPath, item.id);
      addToast(pinned ? '已钉到桌面' : '钉图失败', pinned ? 'success' : 'error');
    } finally {
      setBusyAction(null);
    }
  }, [pinImage, addToast]);

  // OCR 提取
  const handleOcr = useCallback(async (item: SourceItem) => {
    if (!item.contentPath) return;
    setBusyAction(`ocr-${item.id}`);
    try {
      const result = await ocrExtract(item.contentPath);
      if (result.error) {
        addToast(`OCR 失败: ${result.error}`, 'error');
      } else if (!result.text) {
        addToast('图片中未检测到文字', 'warning');
      } else {
        // 复制到剪贴板
        await navigator.clipboard.writeText(result.text);
        addToast('OCR 文字已复制到剪贴板', 'success');
      }
    } finally {
      setBusyAction(null);
    }
  }, [ocrExtract, addToast]);

  // 保存截图到 Inbox
  const handleSaveToInbox = useCallback(async (item: SourceItem) => {
    setBusyAction(`save-${item.id}`);
    try {
      // 截图已经是 SourceItem (status=inbox)，这里做确认提示
      addToast('截图已在收集箱中', 'success');
    } finally {
      setBusyAction(null);
    }
  }, [addToast]);

  // 关闭贴图
  const handleClosePinned = useCallback(async (id: string) => {
    setBusyAction(`close-pinned-${id}`);
    try {
      await closePinnedImage(id);
      addToast('贴图已关闭', 'success');
    } finally {
      setBusyAction(null);
    }
  }, [closePinnedImage, addToast]);

  // 保存贴图到 Inbox
  const handleSavePinnedToInbox = useCallback(async (id: string) => {
    setBusyAction(`save-pinned-${id}`);
    try {
      const ok = await savePinnedToInbox(id);
      addToast(ok ? '已保存到收集箱' : '保存失败', ok ? 'success' : 'error');
    } finally {
      setBusyAction(null);
    }
  }, [savePinnedToInbox, addToast]);

  if (loading) {
    return (
      <PageShell>
        <LoadingState title="加载截图数据" description="正在获取截图和贴图信息..." />
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
        title="截图与贴图"
        description="截图、钉图到桌面、OCR 文字提取"
        actions={
          <div className="flex items-center gap-2">
            <StatusBadge
              tone={pinnedImages.length > 0 ? 'info' : 'neutral'}
              label={`${pinnedImages.length} 个贴图`}
            />
            <Button
              variant="primary"
              leadingIcon={<AcMindIcon name="capture" size={16} />}
              busy={busyAction === 'screenshot'}
              onClick={() => void handleScreenshot()}
            >
              截图
            </Button>
          </div>
        }
      />

      {/* 已钉图片 */}
      {pinnedImages.length > 0 && (
        <Section title="已钉图片" description="钉在桌面上的截图">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {pinnedImages.map((pinned) => (
              <PinnedImageCard
                key={pinned.id}
                pinned={pinned}
                busy={busyAction}
                onClose={() => void handleClosePinned(pinned.id)}
                onSaveToInbox={() => void handleSavePinnedToInbox(pinned.id)}
              />
            ))}
          </div>
        </Section>
      )}

      {/* 最近截图 */}
      <Section
        title="最近截图"
        description="截图自动保存到收集箱"
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
        {recentCaptures.length === 0 ? (
          <EmptyState
            icon={<AcMindIcon name="capture" size={28} />}
            title="暂无截图"
            description="点击上方「截图」按钮开始捕获屏幕内容"
            action={{ label: '开始截图', onClick: () => void handleScreenshot() }}
          />
        ) : (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {recentCaptures.map((item) => (
              <CaptureCard
                key={item.id}
                item={item}
                busy={busyAction}
                onPinToDesktop={() => void handlePinToDesktop(item)}
                onOcr={() => void handleOcr(item)}
                onSaveToInbox={() => void handleSaveToInbox(item)}
              />
            ))}
          </div>
        )}
      </Section>
    </PageShell>
  );
}

// ── 截图卡片 ──────────────────────────────────────────────────────

interface CaptureCardProps {
  item: SourceItem;
  busy: string | null;
  onPinToDesktop: () => void;
  onOcr: () => void;
  onSaveToInbox: () => void;
}

function CaptureCard({ item, busy, onPinToDesktop, onOcr, onSaveToInbox }: CaptureCardProps): JSX.Element {
  const timeStr = new Date(item.createdAt * 1000).toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <Card variant="interactive" className="flex flex-col gap-3">
      {/* 缩略图 */}
      <div className="relative aspect-video overflow-hidden rounded-[8px] bg-[color:var(--pm-surface-muted)]">
        {item.contentPath ? (
          <img
            src={`file://${item.contentPath}`}
            alt={item.previewText || '截图'}
            className="h-full w-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="flex h-full items-center justify-center">
            <AcMindIcon name="image" size={32} />
          </div>
        )}
        <div className="absolute bottom-2 right-2">
          <StatusBadge tone="success" label={timeStr} dot={false} />
        </div>
      </div>

      {/* 信息 */}
      <div className="flex items-center justify-between">
        <span className="truncate text-[12px] text-[color:var(--pm-text-secondary)]">
          {item.previewText || '屏幕截图'}
        </span>
      </div>

      {/* 操作按钮 */}
      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<AcMindIcon name="pin-top" size={14} />}
          busy={busy === `pin-${item.id}`}
          onClick={onPinToDesktop}
          title="钉到桌面"
        >
          钉图
        </Button>
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<AcMindIcon name="text" size={14} />}
          busy={busy === `ocr-${item.id}`}
          onClick={onOcr}
          title="OCR 文字提取"
        >
          OCR
        </Button>
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<AcMindIcon name="filled-inbox" size={14} />}
          busy={busy === `save-${item.id}`}
          onClick={onSaveToInbox}
          title="已在收集箱"
        >
          收集箱
        </Button>
      </div>
    </Card>
  );
}

// ── 贴图卡片 ──────────────────────────────────────────────────────

interface PinnedImageCardProps {
  pinned: PinnedImage;
  busy: string | null;
  onClose: () => void;
  onSaveToInbox: () => void;
}

function PinnedImageCard({ pinned, busy, onClose, onSaveToInbox }: PinnedImageCardProps): JSX.Element {
  const timeStr = new Date(pinned.createdAt).toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <Card variant="selected" className="flex flex-col gap-3">
      {/* 缩略图 */}
      <div className="relative aspect-video overflow-hidden rounded-[8px] bg-[color:var(--pm-surface-muted)]">
        <img
          src={`file://${pinned.filePath}`}
          alt="贴图"
          className="h-full w-full object-cover"
          loading="lazy"
        />
        <div className="absolute bottom-2 right-2">
          <StatusBadge tone="info" label="钉在桌面" dot={false} />
        </div>
      </div>

      {/* 信息 */}
      <div className="flex items-center justify-between">
        <span className="text-[12px] text-[color:var(--pm-text-secondary)]">{timeStr}</span>
        <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">
          {pinned.width}×{pinned.height}
        </span>
      </div>

      {/* 操作按钮 */}
      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="sm"
          leadingIcon={<AcMindIcon name="filled-inbox" size={14} />}
          busy={busy === `save-pinned-${pinned.id}`}
          onClick={onSaveToInbox}
          title="保存到收集箱"
        >
          收集箱
        </Button>
        <Button
          variant="danger"
          size="sm"
          leadingIcon={<AcMindIcon name="close" size={14} />}
          busy={busy === `close-pinned-${pinned.id}`}
          onClick={onClose}
          title="关闭贴图"
        >
          关闭
        </Button>
      </div>
    </Card>
  );
}
