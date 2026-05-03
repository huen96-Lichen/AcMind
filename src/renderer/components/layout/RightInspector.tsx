import { useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { PinStackIcon } from '../../design-system/icons';
import type { ShellSnapshot } from '../../hooks/useShellSnapshot';
import { ScrollContainer } from '../shared/ScrollContainer';
import { EmptyState } from '../shared/EmptyState';
import { ImagePreview } from '../shared/ImagePreview';
import { useSelectedItem } from '../../context/SelectedItemContext';
import type { CaptureItem } from '../../../shared/types';

interface RightInspectorProps {
  activeView: string;
  snapshot: ShellSnapshot;
  onNavigate: (view: string, options?: { tab?: string; id?: string }) => void;
}

type InspectorTab = 'detail' | 'ai-result' | 'metadata' | 'logs';

const TABS: { key: InspectorTab; label: string }[] = [
  { key: 'detail', label: '详情' },
  { key: 'ai-result', label: 'AI 处理结果' },
  { key: 'metadata', label: '元数据' },
  { key: 'logs', label: '日志' },
];

export function RightInspector({ activeView, snapshot, onNavigate }: RightInspectorProps): JSX.Element {
  const [activeTab, setActiveTab] = useState<InspectorTab>('detail');
  const { selectedItem } = useSelectedItem();

  const workspaceName = snapshot.settings?.profile?.workspaceName ?? '知识库';

  return (
    <aside className="flex h-full w-[380px] min-w-[360px] max-w-[420px] flex-col border-l border-[color:var(--border-light)] bg-[color:var(--pm-bg-panel)] backdrop-blur-[20px]">
      <div className="shrink-0 flex items-center justify-between border-b border-[color:var(--border-light)] px-5 py-4">
        <div className="min-w-0">
          <p className="pinmind-section-eyebrow">详情面板</p>
          <h3 className="truncate text-[18px] font-[650] leading-[26px] text-[color:var(--text-title)]">
            {selectedItem ? (selectedItem.title || '未命名内容') : '选择一条内容查看详情'}
          </h3>
          <p className="mt-1 text-[11px] text-[color:var(--pm-text-tertiary)]">
            {selectedItem ? `当前内容将写入 ${workspaceName}` : '左侧内容队列中的记录会在这里展开'}
          </p>
        </div>
        {selectedItem ? (
          <button
            type="button"
            className="pinmind-topbar-icon-btn"
            aria-label="关闭"
            onClick={() => onNavigate('capture-inbox')}
          >
            <PinStackIcon name="close" size={16} />
          </button>
        ) : null}
      </div>

      <div className="pinmind-tab-bar">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setActiveTab(tab.key)}
            className={`pinmind-tab-item motion-button ${activeTab === tab.key ? 'active' : ''}`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <ScrollContainer className="flex-1 min-h-0">
        {selectedItem ? (
          <div className="flex flex-col gap-4 p-4">
            {activeTab === 'detail' && <DetailTab item={selectedItem} onNavigate={onNavigate} />}
            {activeTab === 'ai-result' && <AiResultTab item={selectedItem} />}
            {activeTab === 'metadata' && <MetadataTab item={selectedItem} />}
            {activeTab === 'logs' && <LogsTab />}
          </div>
        ) : (
          <EmptyInspector activeView={activeView} />
        )}
      </ScrollContainer>

      {selectedItem ? (
        <div className="shrink-0 border-t border-[color:var(--border-light)] px-5 py-3">
          <div className="flex gap-2">
            <button
              type="button"
              className="pinmind-btn pinmind-btn-primary motion-button flex-1 text-[12px]"
              onClick={() => onNavigate('edit', { id: selectedItem.id })}
            >
              去整理
            </button>
            <button
              type="button"
              className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
              onClick={() => onNavigate('edit', { id: selectedItem.id })}
            >
              确认入库
            </button>
          </div>
        </div>
      ) : null}
    </aside>
  );
}

function DetailTab({ item, onNavigate }: { item: CaptureItem; onNavigate: RightInspectorProps['onNavigate'] }): JSX.Element {
  const sourceLabel = item.sourceUrl ? extractDomain(item.sourceUrl) : item.type === 'image' ? '截图' : '手动输入';
  const summary = useMemo(() => summarizeContent(item), [item]);
  const sourcePath = item.filePath || item.sourceUrl || '—';
  const [copiedSummary, setCopiedSummary] = useState(false);

  return (
    <div className="flex flex-col gap-4">
      <InspectorCard title="内容预览" eyebrow="DETAIL">
        <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-3">
          {item.type === 'image' && item.filePath ? (
            <ImagePreview filePath={item.filePath} title={item.title} />
          ) : (
            <p className="whitespace-pre-wrap text-[12px] leading-[1.7] text-[color:var(--pm-text-secondary)]">
              {item.rawText || item.sourceUrl || '暂无内容'}
            </p>
          )}
        </div>
      </InspectorCard>

      <InspectorCard title="信息" eyebrow="INFO">
        <div className="grid grid-cols-2 gap-2">
          <MiniInfo label="状态" value={formatStatus(item.status)} />
          <MiniInfo label="来源" value={sourceLabel} />
          <MiniInfo label="字数" value={item.rawText ? `${item.rawText.length} 字` : '—'} />
          <MiniInfo label="类型" value={formatType(item.type)} />
          <MiniInfo label="捕获时间" value={formatTime(item.capturedAt)} />
          <MiniInfo label="路径" value={shortenPath(sourcePath)} />
        </div>
      </InspectorCard>

      <InspectorCard title="AI 建议" eyebrow="AI">
        <div className="flex flex-col gap-3">
          <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-3">
            <p className="text-[11px] font-semibold uppercase tracking-[0.06em] text-[color:var(--pm-text-tertiary)]">
              可能标题
            </p>
            <p className="mt-1 text-[13px] font-medium text-[color:var(--text-title)]">
              {suggestTitle(item)}
            </p>
            <p className="mt-2 text-[12px] leading-[1.65] text-[color:var(--pm-text-secondary)]">
              {summary}
            </p>
          </div>
          <div>
            <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.06em] text-[color:var(--pm-text-tertiary)]">
              推荐标签
            </p>
            <div className="flex flex-wrap gap-2">
              {suggestTags(item).map((tag) => (
                <span key={tag} className="pinmind-badge" style={{ background: 'var(--pm-brand-soft)', color: 'var(--pm-brand-text)', borderColor: 'var(--pm-brand-border)' }}>
                  #{tag}
                </span>
              ))}
            </div>
          </div>
        </div>
      </InspectorCard>

      <InspectorCard title="快捷操作" eyebrow="ACTION">
        <div className="grid grid-cols-2 gap-2">
          <button
            type="button"
            className="pinmind-btn pinmind-btn-primary motion-button text-[12px]"
            onClick={() => onNavigate('edit', { id: item.id })}
          >
            去整理
          </button>
          <button
            type="button"
            className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
            onClick={() => onNavigate('edit', { id: item.id })}
          >
            整理后输出
          </button>
          <button
            type="button"
            className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
            onClick={() => window.open(item.sourceUrl || 'about:blank', '_blank')}
            disabled={!item.sourceUrl}
          >
            打开来源
          </button>
          <button
            type="button"
            className="pinmind-btn pinmind-btn-secondary motion-button text-[12px]"
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(summary);
                setCopiedSummary(true);
                window.setTimeout(() => setCopiedSummary(false), 1400);
              } catch {
                // noop
              }
            }}
          >
            {copiedSummary ? '已复制' : '复制摘要'}
          </button>
        </div>
      </InspectorCard>

      <InspectorCard title="输出信息" eyebrow="OUTPUT">
        <div className="flex flex-col gap-2">
          <Row label="完整路径" value={sourcePath} mono />
          <Row label="来源 URL" value={item.sourceUrl || '—'} mono />
          <Row label="更新时间" value={formatTime(item.updatedAt)} />
        </div>
      </InspectorCard>
    </div>
  );
}

function AiResultTab({ item }: { item: CaptureItem }): JSX.Element {
  const summary = useMemo(() => summarizeContent(item), [item]);

  return (
    <InspectorCard title="AI 处理结果" eyebrow="AI RESULT">
      <div className="flex flex-col gap-3">
        <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.06em] text-[color:var(--pm-text-tertiary)]">
            摘要
          </p>
          <p className="mt-2 text-[13px] leading-[1.7] text-[color:var(--pm-text-secondary)]">
            {summary}
          </p>
        </div>
        <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.06em] text-[color:var(--pm-text-tertiary)]">
            状态
          </p>
          <div className="mt-2 flex items-center gap-2">
            <span className="pinmind-status-badge" style={{ color: 'var(--pm-status-info)', borderColor: 'color-mix(in srgb, var(--pm-status-info) 30%, transparent)', background: 'color-mix(in srgb, var(--pm-status-info) 8%, transparent)' }}>
              {formatStatus(item.status)}
            </span>
            <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">
              结果会在整理页中继续完善
            </span>
          </div>
        </div>
      </div>
    </InspectorCard>
  );
}

function MetadataTab({ item }: { item: CaptureItem }): JSX.Element {
  return (
    <InspectorCard title="元数据" eyebrow="META">
      <div className="flex flex-col gap-2">
        <Row label="标题" value={item.title || '未命名'} />
        <Row label="类型" value={formatType(item.type)} />
        <Row label="状态" value={formatStatus(item.status)} />
        <Row label="来源" value={item.sourceUrl ? extractDomain(item.sourceUrl) : item.type === 'image' ? '截图' : '手动输入'} />
        <Row label="捕获时间" value={formatTime(item.capturedAt)} />
        <Row label="更新时间" value={formatTime(item.updatedAt)} />
        <Row label="完整路径" value={item.filePath || item.sourceUrl || '—'} mono />
      </div>
    </InspectorCard>
  );
}

function LogsTab(): JSX.Element {
  return (
    <InspectorCard title="日志" eyebrow="LOG">
      <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-4 text-[12px] leading-[1.7] text-[color:var(--pm-text-tertiary)]">
        暂无日志记录。
      </div>
    </InspectorCard>
  );
}

function EmptyInspector({ activeView }: { activeView: string }): JSX.Element {
  const hint = activeView === 'capture-inbox'
    ? '在左侧内容队列中选择任意条目'
    : '切换到内容页后即可查看对应条目';
  return (
    <div className="flex h-full items-center justify-center p-6">
      <EmptyState
        icon={<PinStackIcon name="panel" size={24} />}
        title="选择一条内容查看详情"
        description={hint}
      />
    </div>
  );
}

function InspectorCard({ title, eyebrow, children }: { title: string; eyebrow: string; children: ReactNode }): JSX.Element {
  return (
    <section className="pinmind-section-panel flex flex-col gap-3 p-4">
      <div>
        <p className="pinmind-section-eyebrow">{eyebrow}</p>
        <h4 className="text-[16px] font-[650] leading-[24px] text-[color:var(--text-title)]">{title}</h4>
      </div>
      {children}
    </section>
  );
}

function MiniInfo({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-3">
      <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">{label}</p>
      <p className="mt-1 text-[12px] font-medium leading-[1.5] text-[color:var(--text-title)] break-words">{value}</p>
    </div>
  );
}

function Row({ label, value, mono }: { label: string; value: string; mono?: boolean }): JSX.Element {
  return (
    <div className="flex items-start justify-between gap-4 rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] px-3 py-2.5">
      <span className="shrink-0 text-[11px] text-[color:var(--pm-text-tertiary)]">{label}</span>
      <span className={`max-w-[210px] text-right text-[12px] text-[color:var(--pm-text-secondary)] ${mono ? 'font-mono break-all' : 'break-words'}`}>
        {value}
      </span>
    </div>
  );
}

function formatTime(value: number): string {
  return new Date(value * 1000).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function formatStatus(status: string): string {
  switch (status) {
    case 'pending':
      return '待整理';
    case 'distilling':
      return '处理中';
    case 'distilled':
      return '已整理';
    case 'exported':
      return '已写入';
    case 'archived':
      return '已归档';
    case 'failed':
      return '失败';
    case 'ignored':
      return '已忽略';
    default:
      return status;
  }
}

function formatType(type: string): string {
  switch (type) {
    case 'image':
      return '图片';
    case 'link':
      return '链接';
    case 'text':
      return '文本';
    default:
      return type;
  }
}

function extractDomain(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
}

function shortenPath(value: string): string {
  if (!value) return '—';
  if (value.startsWith('~/')) return value;
  if (value.startsWith('/Users/')) {
    const parts = value.split('/');
    return '~/' + parts.slice(3).join('/');
  }
  return value;
}

function suggestTitle(item: CaptureItem): string {
  if (item.title && !item.title.startsWith('/') && !item.title.includes('\\')) {
    return item.title;
  }
  if (item.type === 'image') {
    return `图片捕获 · ${new Date(item.capturedAt * 1000).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}`;
  }
  const firstLine = (item.rawText || item.sourceUrl || '').split('\n')[0]?.trim();
  if (firstLine) return firstLine.slice(0, 60);
  return '未命名捕获';
}

function summarizeContent(item: CaptureItem): string {
  if (item.rawText) {
    return item.rawText.replace(/\s+/g, ' ').slice(0, 140) || '暂无摘要';
  }
  if (item.sourceUrl) {
    return `来自 ${extractDomain(item.sourceUrl)} 的网页内容，建议整理为要点与行动项。`;
  }
  return '尚未生成 AI 结果，等待整理。';
}

function suggestTags(item: CaptureItem): string[] {
  const source = `${item.title ?? ''} ${item.rawText ?? ''} ${item.sourceUrl ?? ''}`.toLowerCase();
  const tags = new Set<string>();
  if (source.includes('学习')) tags.add('学习方法');
  if (source.includes('项目') || source.includes('需求')) tags.add('项目');
  if (source.includes('ai') || source.includes('模型')) tags.add('AI');
  if (source.includes('工作') || source.includes('任务')) tags.add('待办');
  if (item.type === 'image') tags.add('截图');
  return Array.from(tags).slice(0, 3);
}
