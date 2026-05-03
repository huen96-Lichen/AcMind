import { useEffect, useState, useCallback, type CSSProperties } from 'react';
import { Button, Card, StatusBadge, PageHeader, PageShell, Section } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';

// ─── Types ──────────────────────────────────────────────────────────────────────

type UtilityStatus = 'enabled' | 'paused' | 'disabled' | 'requires_permission' | 'error';

interface UtilityItem {
  id: string;
  name: string;
  description: string;
  icon: string;
  status: UtilityStatus;
  action: 'navigate' | 'toggle';
  target?: string;
  onActivate?: () => void;
}

// ─── Status badge config ───────────────────────────────────────────────────────

const STATUS_CONFIG: Record<UtilityStatus, { label: string; tone: 'success' | 'warning' | 'danger' | 'neutral' }> = {
  enabled: { label: '运行中', tone: 'success' },
  paused: { label: '已暂停', tone: 'warning' },
  disabled: { label: '未启用', tone: 'neutral' },
  requires_permission: { label: '需要权限', tone: 'warning' },
  error: { label: '错误', tone: 'danger' },
};

// ─── Navigation helper ─────────────────────────────────────────────────────────

const navigate = (view: string) => {
  window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view } }));
};

// ─── Component ──────────────────────────────────────────────────────────────────

export function UtilitiesPage(): JSX.Element {
  const [items, setItems] = useState<UtilityItem[]>([]);
  const [loading, setLoading] = useState(true);

  const loadStatuses = useCallback(async () => {
    try {
      const utilities: UtilityItem[] = [
        {
          id: 'clipboard',
          name: '剪贴板历史',
          description: '自动记录复制内容，支持文本、图片、链接',
          icon: 'duplicate',
          status: 'disabled',
          action: 'navigate',
          target: 'clipboard',
        },
        {
          id: 'shelf',
          name: '拖拽暂存架',
          description: '拖拽文件、文本到 Shelf 临时暂存',
          icon: 'filled-file-import',
          status: 'paused',
          action: 'navigate',
          target: 'shelf',
        },
        {
          id: 'capture',
          name: '截图与贴图',
          description: '区域截图、全屏截图、贴图到桌面',
          icon: 'capture',
          status: 'enabled',
          action: 'navigate',
          target: 'capture',
        },
        {
          id: 'capsule',
          name: '桌面胶囊',
          description: '桌面常驻入口，快速收集灵感和信息',
          icon: 'act-quick-capture',
          status: 'disabled',
          action: 'toggle',
          onActivate: () => {
            try { window.acmind.capsule.toggle(); } catch { /* no-op */ }
          },
        },
        {
          id: 'quick-input',
          name: '快速记录',
          description: '随手记录想法、文字、链接',
          icon: 'sb-inbox',
          status: 'enabled',
          action: 'navigate',
          target: 'capture-inbox',
        },
      ];

      // Clipboard status
      try {
        const clipStatus = await window.acmind.clipboard.getStatus();
        if (clipStatus.enabled) {
          utilities[0].status = 'enabled';
        } else {
          utilities[0].status = 'disabled';
        }
      } catch {
        utilities[0].status = 'disabled';
      }

      // Shelf status
      try {
        const shelfResult = await window.acmind.shelf.listItems();
        utilities[1].status = (shelfResult.items?.length ?? 0) > 0 ? 'enabled' : 'paused';
      } catch {
        utilities[1].status = 'paused';
      }

      // Capsule status
      try {
        const capsuleStatus = await window.acmind.capsule.getStatus();
        utilities[3].status = capsuleStatus ? 'enabled' : 'disabled';
      } catch {
        utilities[3].status = 'disabled';
      }

      setItems(utilities);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadStatuses();
  }, [loadStatuses]);

  const handleCardClick = (item: UtilityItem) => {
    if (item.action === 'navigate' && item.target) {
      navigate(item.target);
    } else if (item.action === 'toggle' && item.onActivate) {
      item.onActivate();
    }
  };

  if (loading) {
    return (
      <PageShell>
        <ScrollContainer>
          <div className="flex items-center justify-center" style={{ minHeight: 320 }}>
            <div className="pm-ds-spinner pm-ds-spinner-large" aria-hidden="true" />
          </div>
        </ScrollContainer>
      </PageShell>
    );
  }

  return (
    <PageShell>
      <ScrollContainer>
        <PageHeader
          title="Mac 工具箱"
          description="桌面信息收集与管理工具"
        />

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4" style={{ marginTop: 24 }}>
          {items.map((item) => {
            const statusConf = STATUS_CONFIG[item.status];
            return (
              <Card
                key={item.id}
                variant="interactive"
                className="cursor-pointer"
                style={cardStyle}
                onClick={() => handleCardClick(item)}
              >
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
                  {/* Icon */}
                  <div style={iconWrapperStyle}>
                    <PinStackIcon name={item.icon as any} size={22} />
                  </div>

                  {/* Content */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                      <span style={nameStyle}>{item.name}</span>
                      <StatusBadge tone={statusConf.tone} label={statusConf.label} />
                    </div>
                    <p style={descStyle}>{item.description}</p>
                    <div style={{ marginTop: 12 }}>
                      <Button
                        variant="ghost"
                        size="sm"
                        leadingIcon={<PinStackIcon name="arrow-right" size={12} />}
                        onClick={(e) => {
                          e.stopPropagation();
                          handleCardClick(item);
                        }}
                      >
                        {item.action === 'toggle' ? '切换' : '打开'}
                      </Button>
                    </div>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>

        {/* Permission info */}
        <Section
          title="权限说明"
          description="部分功能需要系统权限才能正常工作"
          compact
          style={{ marginTop: 32 }}
        >
          <div style={permListStyle}>
            <div style={permItemStyle}>
              <PinStackIcon name="filled-clipboard" size={14} />
              <span style={permTextStyle}>
                剪贴板读取：AcMind 需要辅助功能权限来监听剪贴板变化
              </span>
            </div>
            <div style={permItemStyle}>
              <PinStackIcon name="capture" size={14} />
              <span style={permTextStyle}>
                屏幕录制：截图功能需要屏幕录制权限
              </span>
            </div>
          </div>
        </Section>
      </ScrollContainer>
    </PageShell>
  );
}

// ─── Inline styles ──────────────────────────────────────────────────────────────

const cardStyle: CSSProperties = {
  borderRadius: 12,
  padding: 18,
};

const iconWrapperStyle: CSSProperties = {
  width: 40,
  height: 40,
  borderRadius: 10,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  flexShrink: 0,
  background: 'var(--pm-bg-surface-soft, rgba(17,24,39,0.04))',
  color: 'var(--pm-text-primary)',
};

const nameStyle: CSSProperties = {
  fontSize: 14,
  fontWeight: 600,
  color: 'var(--pm-text-primary)',
  lineHeight: '20px',
};

const descStyle: CSSProperties = {
  fontSize: 12,
  color: 'var(--pm-text-tertiary)',
  lineHeight: '18px',
  marginTop: 4,
  margin: 0,
};

const permListStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  gap: 10,
};

const permItemStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 10,
  color: 'var(--pm-text-tertiary)',
};

const permTextStyle: CSSProperties = {
  fontSize: 12,
  lineHeight: '18px',
};
