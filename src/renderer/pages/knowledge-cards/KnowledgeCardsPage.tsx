/**
 * KnowledgeCardsPage — 知识卡片浏览 + Vault 搜索 + 蒸馏笔记
 *
 * 功能：
 * - Knowledge Card 列表浏览
 * - Vault 关键词搜索
 * - DistilledNote 列表/详情
 */

import { useState, useCallback, useEffect } from 'react';
import { PinStackIcon } from '../../design-system/icons';
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
  Input,
} from '../../design-system/components';
import { useVaultSearch } from '../../hooks/useVaultSearch';
import { useDistilledNotes } from '../../hooks/useDistilledNotes';
import type { KnowledgeCard, KnowledgeEdge, VaultSearchResult, DistilledNote } from '../../../shared/types';

// ── Tab 定义 ─────────────────────────────────────────────────────

type TabKey = 'cards' | 'vault-search' | 'distilled';

const TABS: Array<{ key: TabKey; label: string; icon: 'ai-workspace' | 'sb-results' | 'sb-ai-process' }> = [
  { key: 'cards', label: '知识卡片', icon: 'ai-workspace' },
  { key: 'vault-search', label: 'Vault 搜索', icon: 'sb-results' },
  { key: 'distilled', label: '蒸馏笔记', icon: 'sb-ai-process' },
];

// ── Main Page ────────────────────────────────────────────────────

export function KnowledgeCardsPage(): JSX.Element {
  const [activeTab, setActiveTab] = useState<TabKey>('cards');

  return (
    <PageShell>
      <PageHeader
        title="知识库"
        description="浏览知识卡片、搜索 Obsidian Vault、管理蒸馏笔记"
        actions={
          <div className="flex gap-1">
            {TABS.map((tab) => (
              <Button
                key={tab.key}
                variant={activeTab === tab.key ? 'primary' : 'ghost'}
                size="sm"
                leadingIcon={<PinStackIcon name={tab.icon} size={14} />}
                onClick={() => setActiveTab(tab.key)}
              >
                {tab.label}
              </Button>
            ))}
          </div>
        }
      />

      {activeTab === 'cards' && <CardsSection />}
      {activeTab === 'vault-search' && <VaultSearchSection />}
      {activeTab === 'distilled' && <DistilledNotesSection />}
    </PageShell>
  );
}

// ── Cards Section ────────────────────────────────────────────────

function CardsSection(): JSX.Element {
  const [cards, setCards] = useState<KnowledgeCard[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedCard, setSelectedCard] = useState<KnowledgeCard | null>(null);
  const [edges, setEdges] = useState<KnowledgeEdge[]>([]);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await window.acmind.knowledgeCards.list({ limit: 200 });
      setCards(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const loadEdges = useCallback(async (cardId: string) => {
    try {
      const result = await window.acmind.graph.get({ cardId });
      setEdges(result.edges);
    } catch {
      setEdges([]);
    }
  }, []);

  const handleSelectCard = useCallback(async (card: KnowledgeCard) => {
    setSelectedCard(card);
    await loadEdges(card.id);
  }, [loadEdges]);

  if (loading) return <LoadingState title="加载中" description="正在加载知识卡片..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请检查数据连接后重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <div className="flex gap-4">
      {/* Card List */}
      <div className="flex-1 min-w-0">
        <Section title={`知识卡片 (${cards.length})`}>
          {cards.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="ai-workspace" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="暂无知识卡片"
              description="知识卡片会在 AI 处理内容时自动生成"
            />
          ) : (
            <div className="flex flex-col gap-2">
              {cards.map((card) => (
                <Card
                  key={card.id}
                  variant={selectedCard?.id === card.id ? 'selected' : 'interactive'}
                  className="cursor-pointer"
                  onClick={() => void handleSelectCard(card)}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <div className="text-[13px] font-medium truncate">{card.canonicalTitle || '未命名卡片'}</div>
                      <div className="text-[12px] text-[color:var(--pm-text-tertiary)] mt-1 line-clamp-2">
                        {card.summary || card.body?.slice(0, 120) || '无摘要'}
                      </div>
                      {card.tags && card.tags.length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-2">
                          {card.tags.slice(0, 5).map((tag) => (
                            <StatusBadge key={tag} tone="info" label={tag} dot={false} />
                          ))}
                        </div>
                      )}
                    </div>
                    <div className="text-[11px] text-[color:var(--pm-text-tertiary)] shrink-0">
                      {new Date(card.createdAt * 1000).toLocaleDateString()}
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </Section>
      </div>

      {/* Detail Panel */}
      {selectedCard && (
        <div className="w-80 shrink-0">
          <Card variant="elevated">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-[14px] font-semibold">卡片详情</h3>
              <Button variant="ghost" size="sm" onClick={() => setSelectedCard(null)}>
                <PinStackIcon name="close" size={14} />
              </Button>
            </div>
            <div className="text-[13px] font-medium mb-2">{selectedCard.canonicalTitle || '未命名卡片'}</div>
            <div className="text-[12px] text-[color:var(--pm-text-secondary)] whitespace-pre-wrap mb-3">
              {selectedCard.summary || selectedCard.body || '无内容'}
            </div>
            {selectedCard.tags && selectedCard.tags.length > 0 && (
              <div className="flex flex-wrap gap-1 mb-3">
                {selectedCard.tags.map((tag) => (
                  <StatusBadge key={tag} tone="info" label={tag} dot={false} />
                ))}
              </div>
            )}
            {edges.length > 0 && (
              <div>
                <div className="text-[11px] font-medium text-[color:var(--pm-text-tertiary)] mb-2">关联 ({edges.length})</div>
                {edges.map((edge) => (
                  <div key={edge.id} className="text-[12px] text-[color:var(--pm-text-secondary)] py-1 border-t border-[color:var(--pm-border-subtle)]">
                    {edge.relationType}: {edge.toKnowledgeCardId}
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>
      )}
    </div>
  );
}

// ── Vault Search Section ─────────────────────────────────────────

function VaultSearchSection(): JSX.Element {
  const { results, loading, error, search, clear } = useVaultSearch();
  const [keyword, setKeyword] = useState('');

  const handleSearch = useCallback(() => {
    if (keyword.trim()) {
      void search(keyword);
    }
  }, [keyword, search]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch();
    }
  }, [handleSearch]);

  return (
    <Section title="Obsidian Vault 搜索">
      <div className="flex gap-2 mb-4">
        <Input
          placeholder="输入关键词搜索 Vault 中的 Markdown 文件..."
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          onKeyDown={handleKeyDown}
          className="flex-1"
        />
        <Button variant="primary" onClick={handleSearch} busy={loading}>
          搜索
        </Button>
        {results.length > 0 && (
          <Button variant="ghost" onClick={clear}>
            清除
          </Button>
        )}
      </div>

      {error && <ErrorState title="搜索失败" reason={error} suggestion="请确认 Vault 路径已正确配置" />}

      {!loading && results.length === 0 && keyword && !error && (
        <EmptyState
          icon={<PinStackIcon name="sb-results" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="未找到匹配结果"
          description={`没有在 Vault 中找到包含 "${keyword}" 的文件`}
        />
      )}

      {!loading && !keyword && results.length === 0 && (
        <EmptyState
          icon={<PinStackIcon name="sb-results" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="搜索 Obsidian Vault"
          description="输入关键词搜索 Vault 中的 Markdown 文件内容"
        />
      )}

      {results.length > 0 && (
        <div className="flex flex-col gap-2">
          <div className="text-[12px] text-[color:var(--pm-text-tertiary)] mb-1">
            找到 {results.length} 个匹配文件
          </div>
          {results.map((result) => (
            <VaultSearchResultCard key={result.relativePath} result={result} keyword={keyword} />
          ))}
        </div>
      )}
    </Section>
  );
}

function VaultSearchResultCard({ result, keyword }: { result: VaultSearchResult; keyword: string }): JSX.Element {
  // Highlight keyword in snippet
  const highlightSnippet = (snippet: string, kw: string): JSX.Element => {
    const idx = snippet.toLowerCase().indexOf(kw.toLowerCase());
    if (idx === -1) return <>{snippet}</>;
    return (
      <>
        {snippet.slice(0, idx)}
        <mark className="bg-[color:var(--pm-accent-soft)] text-[color:var(--pm-accent)]">{snippet.slice(idx, idx + kw.length)}</mark>
        {snippet.slice(idx + kw.length)}
      </>
    );
  };

  return (
    <Card variant="interactive">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="text-[13px] font-medium truncate">{result.title}</div>
          <div className="text-[11px] text-[color:var(--pm-text-tertiary)] mt-0.5 truncate">{result.relativePath}</div>
          <div className="text-[12px] text-[color:var(--pm-text-secondary)] mt-1.5 line-clamp-2">
            {highlightSnippet(result.snippet, keyword)}
          </div>
        </div>
        <div className="flex flex-col items-end gap-1 shrink-0">
          <StatusBadge tone="info" label={`${result.matchCount} 处匹配`} dot={false} />
          <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">
            {formatFileSize(result.fileSize)}
          </div>
        </div>
      </div>
    </Card>
  );
}

// ── Distilled Notes Section ──────────────────────────────────────

function DistilledNotesSection(): JSX.Element {
  const { notes, loading, error, refresh, remove } = useDistilledNotes();
  const [selectedNote, setSelectedNote] = useState<DistilledNote | null>(null);

  if (loading) return <LoadingState title="加载中" description="正在加载蒸馏笔记..." />;
  if (error) return <ErrorState title="加载失败" reason={error} suggestion="请检查数据连接后重试" action={{ label: '重试', onClick: refresh }} />;

  return (
    <div className="flex gap-4">
      <div className="flex-1 min-w-0">
        <Section title={`蒸馏笔记 (${notes.length})`}>
          {notes.length === 0 ? (
            <EmptyState
              icon={<PinStackIcon name="sb-ai-process" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="暂无蒸馏笔记"
              description="蒸馏笔记会在 AI 处理内容时自动生成"
            />
          ) : (
            <div className="flex flex-col gap-2">
              {notes.map((note) => (
                <Card
                  key={note.id}
                  variant={selectedNote?.id === note.id ? 'selected' : 'interactive'}
                  className="cursor-pointer"
                  onClick={() => setSelectedNote(note)}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <div className="text-[13px] font-medium truncate">{note.title || '未命名笔记'}</div>
                      <div className="text-[12px] text-[color:var(--pm-text-tertiary)] mt-1 line-clamp-2">
                        {note.summary || '无摘要'}
                      </div>
                      {note.tags && note.tags.length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-2">
                          {note.tags.slice(0, 5).map((tag) => (
                            <StatusBadge key={tag} tone="success" label={tag} dot={false} />
                          ))}
                        </div>
                      )}
                    </div>
                    <div className="flex flex-col items-end gap-1 shrink-0">
                      <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                        {new Date(note.createdAt * 1000).toLocaleDateString()}
                      </div>
                      {note.suggestedFolder && (
                        <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                          📁 {note.suggestedFolder}
                        </div>
                      )}
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </Section>
      </div>

      {/* Detail Panel */}
      {selectedNote && (
        <div className="w-96 shrink-0">
          <Card variant="elevated">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-[14px] font-semibold">笔记详情</h3>
              <div className="flex gap-1">
                <Button
                  variant="danger"
                  size="sm"
                  onClick={async () => {
                    await remove(selectedNote.id);
                    setSelectedNote(null);
                  }}
                >
                  删除
                </Button>
                <Button variant="ghost" size="sm" onClick={() => setSelectedNote(null)}>
                  <PinStackIcon name="close" size={14} />
                </Button>
              </div>
            </div>
            <div className="text-[13px] font-medium mb-2">{selectedNote.title || '未命名笔记'}</div>
            <div className="text-[12px] text-[color:var(--pm-text-secondary)] mb-3">
              {selectedNote.summary || '无摘要'}
            </div>
            {selectedNote.bodyMarkdown && (
              <div className="text-[12px] text-[color:var(--pm-text-secondary)] whitespace-pre-wrap border-t border-[color:var(--pm-border-subtle)] pt-3 mt-3 max-h-64 overflow-y-auto">
                {selectedNote.bodyMarkdown}
              </div>
            )}
            {selectedNote.tags && selectedNote.tags.length > 0 && (
              <div className="flex flex-wrap gap-1 mt-3">
                {selectedNote.tags.map((tag) => (
                  <StatusBadge key={tag} tone="success" label={tag} dot={false} />
                ))}
              </div>
            )}
            {selectedNote.qualityFlags && selectedNote.qualityFlags.length > 0 && (
              <div className="mt-3">
                <div className="text-[11px] font-medium text-[color:var(--pm-text-tertiary)] mb-1">质量标记</div>
                <div className="flex flex-wrap gap-1">
                  {selectedNote.qualityFlags.map((flag) => (
                    <StatusBadge key={flag} tone="warning" label={flag} dot={false} />
                  ))}
                </div>
              </div>
            )}
            <div className="text-[11px] text-[color:var(--pm-text-tertiary)] mt-3 border-t border-[color:var(--pm-border-subtle)] pt-2">
              {selectedNote.modelProvider && `Provider: ${selectedNote.modelProvider}`}
              {selectedNote.modelName && ` · Model: ${selectedNote.modelName}`}
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}

// ── Helpers ──────────────────────────────────────────────────────

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
