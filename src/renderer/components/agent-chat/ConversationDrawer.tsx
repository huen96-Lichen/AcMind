import { useMemo, useState } from 'react';
import { Button, Card, Input, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import type { ChatSession, ProviderConfig } from '../../../shared/types';

interface ConversationDrawerProps {
  open: boolean;
  sessions: ChatSession[];
  currentSessionId: string | null;
  providers: ProviderConfig[];
  onClose: () => void;
  onNewConversation: () => void | Promise<void>;
  onSelectSession: (sessionId: string) => void | Promise<void>;
  onDeleteSession: (sessionId: string) => void | Promise<void>;
}

type SessionBucket = '今天' | '昨天' | '更早';

function formatProviderLabel(provider?: ProviderConfig | null): string {
  if (!provider) return '未绑定 Provider';
  return `${provider.name} · ${provider.modelId}`;
}

function formatRelativeTime(timestamp: number): string {
  const diff = Math.floor(Date.now() / 1000 - timestamp);
  if (diff < 60) return '刚刚';
  if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} 小时前`;
  return new Date(timestamp * 1000).toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' });
}

function getBucket(timestamp: number): SessionBucket {
  const date = new Date(timestamp * 1000);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const yesterday = today - 24 * 60 * 60 * 1000;
  const sessionTime = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  if (sessionTime === today) return '今天';
  if (sessionTime === yesterday) return '昨天';
  return '更早';
}

export function ConversationDrawer({
  open,
  sessions,
  currentSessionId,
  providers,
  onClose,
  onNewConversation,
  onSelectSession,
  onDeleteSession,
}: ConversationDrawerProps): JSX.Element | null {
  const [query, setQuery] = useState('');

  const groupedSessions = useMemo(() => {
    const filtered = sessions
      .slice()
      .sort((a, b) => b.updatedAt - a.updatedAt)
      .filter((session) => {
        if (!query.trim()) return true;
        const provider = providers.find((item) => item.id === session.providerId);
        const haystack = [
          session.title,
          session.metadata.summary,
          session.metadata.lastCommand,
          provider?.name,
          provider?.modelId,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(query.trim().toLowerCase());
      });

    return {
      今天: filtered.filter((session) => getBucket(session.updatedAt) === '今天'),
      昨天: filtered.filter((session) => getBucket(session.updatedAt) === '昨天'),
      更早: filtered.filter((session) => getBucket(session.updatedAt) === '更早'),
    } satisfies Record<SessionBucket, ChatSession[]>;
  }, [providers, query, sessions]);

  if (!open) return null;

  return (
    <>
      <div className="fixed inset-0 z-20 bg-[rgba(15,23,42,0.18)] backdrop-blur-[1px]" onClick={onClose} />

      <aside
        className="fixed bottom-0 z-30 flex flex-col border-r border-[rgba(15,23,42,0.08)] bg-white/92 shadow-[0_24px_72px_rgba(15,23,42,0.12)] backdrop-blur-2xl transition-transform duration-300"
        style={{
          width: 'min(92vw, 380px)',
          left: 'var(--pm-sidebar-width, 216px)',
          top: 'var(--pm-topbar-height, 64px)',
        }}
      >
        <div className="border-b border-[rgba(15,23,42,0.06)] px-5 py-4">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[color:var(--pm-text-tertiary)]">
                会话历史
              </p>
              <h2 className="mt-1 text-[18px] font-semibold tracking-[-0.02em] text-[color:var(--pm-text-primary)]">
                最近对话
              </h2>
            </div>
            <Button variant="ghost" size="sm" onClick={onClose}>
              关闭
            </Button>
          </div>

          <div className="mt-4 flex gap-2">
            <Button
              variant="primary"
              size="sm"
              className="shrink-0"
              onClick={onNewConversation}
              leadingIcon={<AcMindIcon name="duplicate" size={14} />}
            >
              新对话
            </Button>
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜索会话标题 / 摘要"
              className="h-9 flex-1 rounded-[14px]"
            />
          </div>
        </div>

        <div className="flex-1 min-h-0 overflow-y-auto px-3 py-3">
          {(Object.keys(groupedSessions) as SessionBucket[]).map((bucket) => {
            const items = groupedSessions[bucket];
            if (items.length === 0) return null;

            return (
              <section key={bucket} className="mb-5">
                <div className="px-2 pb-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-[color:var(--pm-text-tertiary)]">
                  {bucket}
                </div>
                <div className="space-y-2">
                  {items.map((session) => {
                    const provider = providers.find((item) => item.id === session.providerId) ?? null;
                    const active = session.id === currentSessionId;
                    const summary =
                      session.metadata.summary?.trim() || session.metadata.lastCommand?.trim() || '暂无摘要';

                    return (
                      <button
                        key={session.id}
                        type="button"
                        onClick={() => {
                          void onSelectSession(session.id);
                          onClose();
                        }}
                        className={`w-full rounded-[18px] border p-3 text-left transition-all duration-200 ${
                          active
                            ? 'border-[rgba(255,107,43,0.22)] bg-[color:var(--pm-primary-soft)] shadow-[0_10px_24px_rgba(255,107,43,0.08)]'
                            : 'border-[rgba(15,23,42,0.06)] bg-white/80 hover:-translate-y-0.5 hover:shadow-[0_12px_28px_rgba(15,23,42,0.06)]'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <div className="truncate text-[13px] font-semibold text-[color:var(--pm-text-primary)]">
                              {session.title}
                            </div>
                            <div className="mt-1 line-clamp-2 text-[12px] leading-5 text-[color:var(--pm-text-secondary)]">
                              {summary}
                            </div>
                          </div>
                          <span className="shrink-0 text-[11px] text-[color:var(--pm-text-tertiary)]">
                            {formatRelativeTime(session.updatedAt)}
                          </span>
                        </div>
                        <div className="mt-2 flex items-center justify-between gap-2">
                          <span className="truncate text-[11px] text-[color:var(--pm-text-tertiary)]">
                            {formatProviderLabel(provider)}
                          </span>
                          <div className="flex items-center gap-1">
                            {active ? <StatusBadge tone="mock" label="当前" dot={false} /> : null}
                            <button
                              type="button"
                              onClick={(event) => {
                                event.stopPropagation();
                                void onDeleteSession(session.id);
                              }}
                              className="rounded-full p-1 text-[color:var(--pm-text-tertiary)] transition-colors hover:bg-[rgba(220,38,38,0.08)] hover:text-[color:var(--pm-danger)]"
                              title="删除会话"
                              aria-label="删除会话"
                            >
                              <AcMindIcon name="act-delete" size={12} />
                            </button>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </section>
            );
          })}

          {sessions.length === 0 ? (
            <Card className="mx-2 rounded-[20px] border border-[rgba(15,23,42,0.06)] bg-white/80 p-4 text-center">
              <div className="mx-auto mb-3 inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-[color:var(--pm-primary-soft)] text-[color:var(--pm-primary)]">
                <AcMindIcon name="ai-workspace" size={18} />
              </div>
              <p className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">还没有会话</p>
              <p className="mt-1 text-[12px] leading-5 text-[color:var(--pm-text-secondary)]">
                点击新对话，开始第一段沉浸式对话。
              </p>
            </Card>
          ) : null}
        </div>

        <div className="border-t border-[rgba(15,23,42,0.06)] px-5 py-3">
          <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">共 {sessions.length} 个会话</p>
        </div>
      </aside>
    </>
  );
}
