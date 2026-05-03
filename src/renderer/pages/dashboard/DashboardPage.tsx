import { useEffect, useState, useCallback, type CSSProperties } from 'react';
import { Button, Card, StatusBadge, EmptyState, LoadingState, PageShell, Section } from '../../design-system/components';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';

// ─── Types ─────────────────────────────────────────────────────────────────────

interface SourceItem {
  id: string;
  type: string;
  source: string;
  previewText: string;
  title: string;
  createdAt: number;
  status: string;
  tags: string[];
}

interface DashboardStats {
  todayCollected: number;
  todayDistilled: number;
  todayExported: number;
  inboxPending: number;
  shelfItems: number;
  recentItems: SourceItem[];
  clipboardWatching: boolean;
  clipboardPaused: boolean;
  aiProviderReady: boolean;
  vaultConfigured: boolean;
  markItDownAvailable: boolean;
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

function relativeTime(ts: number): string {
  const diff = Date.now() / 1000 - ts;
  if (diff < 60) return '刚刚';
  if (diff < 3600) return `${Math.floor(diff / 60)}分钟前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}小时前`;
  return `${Math.floor(diff / 86400)}天前`;
}

function sourceLabel(source: string): string {
  const map: Record<string, string> = {
    manual: '手动',
    clipboard: '剪贴板',
    screenshot: '截图',
    file: '文件',
    webpage: '网页',
    voice: '语音',
    ocr: 'OCR',
  };
  return map[source] || source;
}

function todayDateString(): string {
  const d = new Date();
  const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 ${weekdays[d.getDay()]}`;
}

function truncate(str: string, max: number): string {
  if (!str) return '';
  return str.length > max ? str.slice(0, max) + '...' : str;
}

function statusTone(status: string): 'neutral' | 'info' | 'success' | 'warning' | 'danger' | 'processing' {
  switch (status) {
    case 'collected':
    case 'inbox':
      return 'info';
    case 'distilled':
    case 'processed':
      return 'success';
    case 'exported':
      return 'success';
    case 'pending':
      return 'warning';
    case 'error':
      return 'danger';
    case 'processing':
      return 'processing';
    default:
      return 'neutral';
  }
}

function statusLabel(status: string): string {
  const map: Record<string, string> = {
    collected: '已收集',
    inbox: '收件箱',
    distilled: '已整理',
    processed: '已处理',
    exported: '已导出',
    pending: '待处理',
    error: '异常',
    processing: '处理中',
  };
  return map[status] || status;
}

// ─── Navigation ────────────────────────────────────────────────────────────────

const navigate = (view: string, options?: { id?: string }) => {
  window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view, ...options } }));
};

// ─── Styles ────────────────────────────────────────────────────────────────────

const styles = {
  root: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
  } as CSSProperties,

  // Welcome area
  welcome: {
    marginBottom: 24,
  } as CSSProperties,
  welcomeDate: {
    fontSize: 13,
    fontWeight: 500,
    color: 'var(--pm-text-tertiary)',
    marginBottom: 4,
  } as CSSProperties,
  welcomeTitle: {
    fontSize: 22,
    fontWeight: 600,
    color: 'var(--pm-text-primary)',
    marginBottom: 6,
  } as CSSProperties,
  welcomeSummary: {
    fontSize: 14,
    color: 'var(--pm-text-secondary)',
  } as CSSProperties,

  // Stat cards row
  statRow: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: 12,
    marginBottom: 24,
  } as CSSProperties,
  statCard: {
    background: 'rgba(255, 255, 255, 0.6)',
    border: '1px solid var(--pm-border-subtle)',
    borderRadius: 12,
    padding: '16px 18px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: 4,
  } as CSSProperties,
  statNumber: {
    fontSize: 28,
    fontWeight: 700,
    color: 'var(--pm-text-primary)',
    lineHeight: 1.1,
  } as CSSProperties,
  statLabel: {
    fontSize: 12,
    color: 'var(--pm-text-tertiary)',
    fontWeight: 500,
  } as CSSProperties,

  // Quick actions
  actionsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(4, 1fr)',
    gap: 10,
  } as CSSProperties,
  actionCard: {
    background: 'rgba(255, 255, 255, 0.6)',
    border: '1px solid var(--pm-border-subtle)',
    borderRadius: 10,
    padding: '14px 10px',
    display: 'flex',
    flexDirection: 'column' as const,
    alignItems: 'center',
    gap: 8,
    cursor: 'pointer',
    transition: 'all 0.15s ease',
    color: 'var(--pm-text-secondary)',
    fontSize: 12,
    fontWeight: 500,
  } as CSSProperties,
  actionCardPrimary: {
    background: 'var(--pm-btn-bg, #007AFF)',
    borderColor: 'var(--pm-btn-bg, #007AFF)',
    color: 'var(--pm-btn-color, #fff)',
  } as CSSProperties,

  // Recent items list
  recentList: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: 6,
  } as CSSProperties,
  recentItem: {
    background: 'rgba(255, 255, 255, 0.6)',
    border: '1px solid var(--pm-border-subtle)',
    borderRadius: 10,
    padding: '12px 14px',
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    cursor: 'pointer',
    transition: 'background 0.12s ease',
  } as CSSProperties,
  recentItemIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    background: 'var(--pm-bg-surface-soft, rgba(0,0,0,0.03))',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    color: 'var(--pm-text-tertiary)',
  } as CSSProperties,
  recentItemBody: {
    flex: 1,
    minWidth: 0,
  } as CSSProperties,
  recentItemTitle: {
    fontSize: 13,
    fontWeight: 500,
    color: 'var(--pm-text-primary)',
    whiteSpace: 'nowrap' as const,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  } as CSSProperties,
  recentItemMeta: {
    fontSize: 11,
    color: 'var(--pm-text-tertiary)',
    marginTop: 2,
    display: 'flex',
    alignItems: 'center',
    gap: 6,
  } as CSSProperties,
  recentItemRight: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    gap: 8,
  } as CSSProperties,

  // Pending area
  pendingCard: {
    background: 'rgba(255, 255, 255, 0.6)',
    border: '1px solid var(--pm-border-subtle)',
    borderRadius: 10,
    padding: '16px 18px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  } as CSSProperties,
  pendingInfo: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
  } as CSSProperties,
  pendingCount: {
    fontSize: 24,
    fontWeight: 700,
    color: 'var(--pm-text-primary)',
  } as CSSProperties,
  pendingLabel: {
    fontSize: 13,
    color: 'var(--pm-text-secondary)',
  } as CSSProperties,

  // System status
  statusGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(2, 1fr)',
    gap: 8,
  } as CSSProperties,
  statusItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 12,
    color: 'var(--pm-text-tertiary)',
    padding: '6px 0',
  } as CSSProperties,
  statusDot: {
    width: 7,
    height: 7,
    borderRadius: '50%',
    flexShrink: 0,
  } as CSSProperties,
  statusDotOk: {
    background: '#34C759',
  } as CSSProperties,
  statusDotWarn: {
    background: '#FF9F0A',
  } as CSSProperties,
  statusDotOff: {
    background: '#C7C7CC',
  } as CSSProperties,

  // Section spacing
  sectionGap: {
    marginBottom: 24,
  } as CSSProperties,
};

// ─── Icon helper for source type ───────────────────────────────────────────────

function typeIconName(type: string): string {
  const map: Record<string, string> = {
    text: 'text',
    image: 'image',
    link: 'act-link',
    file: 'filled-file-import',
    webpage: 'brand-web-clipper',
    voice: 'record',
    screenshot: 'capture',
  };
  return map[type] || 'text';
}

// ─── Component ─────────────────────────────────────────────────────────────────

export function DashboardPage(): JSX.Element {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  const loadStats = useCallback(async () => {
    try {
      const result = await window.acmind.dashboard.getStats();
      setStats(result as any);
    } catch {
      setStats(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadStats();
    const unsub = window.acmind.onRecordsChanged?.(() => {
      loadStats();
    });
    return () => {
      unsub?.();
    };
  }, [loadStats]);

  const handleScreenshot = useCallback(async () => {
    try {
      await window.acmind.capture.takeScreenshot();
    } catch {
      // silently ignore
    }
  }, []);

  // ── Loading state ──
  if (loading) {
    return (
      <div style={styles.root}>
        <ScrollContainer>
          <PageShell>
            <LoadingState title="加载中" description="正在获取工作台数据..." />
          </PageShell>
        </ScrollContainer>
      </div>
    );
  }

  const recentItems = stats?.recentItems?.slice(0, 10) ?? [];
  const hasRecent = recentItems.length > 0;
  const hasPending = (stats?.inboxPending ?? 0) > 0;

  return (
    <div style={styles.root}>
      <ScrollContainer>
        <PageShell>
          {/* ── 1. 顶部欢迎区 ── */}
          <div style={styles.welcome}>
            <div style={styles.welcomeDate}>{todayDateString()}</div>
            <div style={styles.welcomeTitle}>今日工作台</div>
            <div style={styles.welcomeSummary}>
              {stats
                ? `今天已收集 ${stats.todayCollected} 条内容，${stats.inboxPending} 条待整理`
                : '暂无数据'}
            </div>
          </div>

          {/* Stat cards */}
          <div style={styles.statRow}>
            <div style={styles.statCard}>
              <span style={styles.statNumber}>{stats?.todayCollected ?? 0}</span>
              <span style={styles.statLabel}>今日收集</span>
            </div>
            <div style={styles.statCard}>
              <span style={styles.statNumber}>{stats?.inboxPending ?? 0}</span>
              <span style={styles.statLabel}>待整理</span>
            </div>
            <div style={styles.statCard}>
              <span style={styles.statNumber}>{stats?.todayExported ?? 0}</span>
              <span style={styles.statLabel}>今日导出</span>
            </div>
          </div>

          {/* ── 2. 快捷操作区 ── */}
          <div style={styles.sectionGap}>
            <Section title="快捷操作" compact>
              <div style={styles.actionsGrid}>
                <div
                  style={{ ...styles.actionCard, ...styles.actionCardPrimary }}
                  onClick={() => navigate('capture-inbox')}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && navigate('capture-inbox')}
                >
                  <PinStackIcon name="act-quick-capture" size={20} />
                  <span>快速记录</span>
                </div>
                <div
                  style={styles.actionCard}
                  onClick={() => navigate('clipboard')}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && navigate('clipboard')}
                >
                  <PinStackIcon name="filled-clipboard" size={20} />
                  <span>剪贴板</span>
                </div>
                <div
                  style={styles.actionCard}
                  onClick={() => navigate('shelf')}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && navigate('shelf')}
                >
                  <PinStackIcon name="filled-projects" size={20} />
                  <span>书架</span>
                </div>
                <div
                  style={styles.actionCard}
                  onClick={handleScreenshot}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && handleScreenshot()}
                >
                  <PinStackIcon name="capture" size={20} />
                  <span>截图</span>
                </div>
                <div
                  style={styles.actionCard}
                  onClick={() => navigate('capture-inbox')}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && navigate('capture-inbox')}
                >
                  <PinStackIcon name="filled-inbox" size={20} />
                  <span>收件箱</span>
                </div>
                <div
                  style={styles.actionCard}
                  onClick={() => navigate('distill')}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && navigate('distill')}
                >
                  <PinStackIcon name="filled-ai-process" size={20} />
                  <span>开始整理</span>
                </div>
                <div
                  style={styles.actionCard}
                  onClick={() => navigate('export')}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && navigate('export')}
                >
                  <PinStackIcon name="filled-output" size={20} />
                  <span>导出</span>
                </div>
              </div>
            </Section>
          </div>

          {/* ── 3. 最近收集区 ── */}
          <div style={styles.sectionGap}>
            <Section title="最近收集" compact>
              {hasRecent ? (
                <div style={styles.recentList}>
                  {recentItems.map((item) => (
                    <div
                      key={item.id}
                      style={styles.recentItem}
                      onClick={() => navigate('edit', { id: item.id })}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => e.key === 'Enter' && navigate('edit', { id: item.id })}
                    >
                      <div style={styles.recentItemIcon}>
                        <PinStackIcon name={typeIconName(item.type) as any} size={16} />
                      </div>
                      <div style={styles.recentItemBody}>
                        <div style={styles.recentItemTitle}>
                          {item.title || truncate(item.previewText, 50)}
                        </div>
                        <div style={styles.recentItemMeta}>
                          <span>{sourceLabel(item.source)}</span>
                          <span>{relativeTime(item.createdAt)}</span>
                        </div>
                      </div>
                      <div style={styles.recentItemRight}>
                        <StatusBadge
                          tone={statusTone(item.status)}
                          label={statusLabel(item.status)}
                          dot={false}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <EmptyState
                  icon={<PinStackIcon name="empty-inbox" size={28} />}
                  title="暂无收集内容"
                  description="点击「快速记录」开始收集第一条内容"
                  action={{ label: '快速记录', onClick: () => navigate('capture-inbox') }}
                />
              )}
            </Section>
          </div>

          {/* ── 4. 待整理区 ── */}
          <div style={styles.sectionGap}>
            <Section title="待整理" compact>
              {hasPending ? (
                <div style={styles.pendingCard}>
                  <div style={styles.pendingInfo}>
                    <span style={styles.pendingCount}>{stats!.inboxPending}</span>
                    <span style={styles.pendingLabel}>条内容等待整理</span>
                  </div>
                  <Button variant="primary" size="sm" onClick={() => navigate('distill')}>
                    开始整理
                  </Button>
                </div>
              ) : (
                <EmptyState
                  icon={<PinStackIcon name="status-success" size={28} />}
                  title="全部整理完毕"
                  description="收件箱为空，所有内容已处理"
                />
              )}
            </Section>
          </div>

          {/* ── 5. 系统状态区 ── */}
          <div style={{ marginBottom: 16 }}>
            <Section title="系统状态" compact>
              <div style={styles.statusGrid}>
                {/* Clipboard */}
                <div style={styles.statusItem}>
                  <span
                    style={{
                      ...styles.statusDot,
                      ...(stats?.clipboardWatching
                        ? stats.clipboardPaused
                          ? styles.statusDotWarn
                          : styles.statusDotOk
                        : styles.statusDotOff),
                    }}
                  />
                  <span>
                    剪贴板：
                    {stats?.clipboardWatching
                      ? stats.clipboardPaused
                        ? '已暂停'
                        : '监听中'
                      : '未启动'}
                  </span>
                </div>

                {/* AI Provider */}
                <div style={styles.statusItem}>
                  <span
                    style={{
                      ...styles.statusDot,
                      ...(stats?.aiProviderReady ? styles.statusDotOk : styles.statusDotOff),
                    }}
                  />
                  <span>AI 服务：{stats?.aiProviderReady ? '就绪' : '未配置'}</span>
                </div>

                {/* Obsidian Vault */}
                <div style={styles.statusItem}>
                  <span
                    style={{
                      ...styles.statusDot,
                      ...(stats?.vaultConfigured ? styles.statusDotOk : styles.statusDotOff),
                    }}
                  />
                  <span>Obsidian：{stats?.vaultConfigured ? '已配置' : '未配置'}</span>
                </div>

                {/* MarkItDown */}
                <div style={styles.statusItem}>
                  <span
                    style={{
                      ...styles.statusDot,
                      ...(stats?.markItDownAvailable ? styles.statusDotOk : styles.statusDotOff),
                    }}
                  />
                  <span>MarkItDown：{stats?.markItDownAvailable ? '可用' : '未安装'}</span>
                </div>
              </div>
            </Section>
          </div>
        </PageShell>
      </ScrollContainer>
    </div>
  );
}
