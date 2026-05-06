/**
 * ChatMessageBubble — 单个消息气泡组件
 *
 * 支持：
 * - user (右侧，品牌色)
 * - assistant (左侧，surface 色)
 * - system (居中，muted)
 * - 流式指示器
 * - ActionProposals 按钮
 * - 风险等级指示器
 */

import type { ReactNode } from 'react';
import type { ChatMessage, AgentActionProposal } from '../../../shared/types';
import { Button } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';

interface ChatMessageBubbleProps {
  message: ChatMessage;
  onActionClick?: (action: AgentActionProposal) => void;
  onActionConfirm?: (action: AgentActionProposal) => void;
}

export function ChatMessageBubble({ message, onActionClick, onActionConfirm }: ChatMessageBubbleProps): JSX.Element {
  const isUser = message.role === 'user';
  const isAssistant = message.role === 'assistant';
  const isSystem = message.role === 'system';
  const isStreaming = message.status === 'streaming';

  // Format timestamp
  const formatTime = (timestamp: number): string => {
    const date = new Date(timestamp * 1000);
    return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  };

  // Handle action click
  const handleActionClick = (action: AgentActionProposal) => {
    // 对于需要确认的操作，触发确认流程
    if (action.requiresConfirmation || action.riskLevel !== 'safe') {
      if (onActionConfirm) {
        onActionConfirm(action);
        return;
      }
    }

    if (onActionClick) {
      onActionClick(action);
    } else {
      // Default behavior: use acmind:navigate event
      if (action.type === 'navigate' && action.target) {
        window.dispatchEvent(
          new CustomEvent('acmind:navigate', { detail: { view: action.target, params: action.params } }),
        );
      }
    }
  };

  // System message (center, muted)
  if (isSystem) {
    return (
      <div className="flex justify-center py-2">
        <div className="max-w-[80%] rounded-full border border-[rgba(15,23,42,0.06)] bg-white/70 px-3 py-1.5 text-center text-xs text-[color:var(--pm-text-tertiary)] shadow-[0_8px_24px_rgba(15,23,42,0.04)]">
          {message.content}
        </div>
      </div>
    );
  }

  // User message (right, brand color)
  if (isUser) {
    return (
      <div className="flex justify-end py-2">
        <div className="flex max-w-[72%] flex-col items-end gap-1">
          <div className="rounded-[22px] rounded-tr-[8px] border border-[rgba(255,107,43,0.18)] bg-[linear-gradient(180deg,rgba(255,241,236,0.98),rgba(255,234,225,0.98))] px-4 py-3 text-[14px] leading-6 text-[color:var(--pm-text-primary)] shadow-[0_12px_30px_rgba(255,107,43,0.08)]">
            <div className="whitespace-pre-wrap">{message.content}</div>
          </div>
          <span className="text-xs text-[color:var(--pm-text-tertiary)]">{formatTime(message.createdAt)}</span>
        </div>
      </div>
    );
  }

  // Assistant message (left, surface color)
  return (
    <div className="flex justify-start py-2">
      <div className="flex max-w-[72%] gap-3">
        {/* Avatar */}
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-2xl bg-[color:var(--pm-primary-soft)] text-[color:var(--pm-primary)]">
          <AcMindIcon name="ai-workspace" size={16} className="text-accent" />
        </div>

        <div className="flex min-w-0 flex-col gap-1">
          {/* Message bubble */}
          <div className="rounded-[22px] rounded-tl-[8px] border border-[rgba(15,23,42,0.08)] bg-white/90 px-4 py-3 shadow-[0_12px_32px_rgba(15,23,42,0.06)]">
            <div className="agent-markdown text-[14px] leading-7 text-[color:var(--pm-text-primary)]">
              {renderMessageContent(message.content)}
              {isStreaming && (
                <span className="inline-flex ml-1">
                  <span
                    className="h-1.5 w-1.5 rounded-full bg-[color:var(--pm-primary)] animate-bounce"
                    style={{ animationDelay: '0ms' }}
                  />
                  <span
                    className="ml-0.5 h-1.5 w-1.5 rounded-full bg-[color:var(--pm-primary)] animate-bounce"
                    style={{ animationDelay: '150ms' }}
                  />
                  <span
                    className="ml-0.5 h-1.5 w-1.5 rounded-full bg-[color:var(--pm-primary)] animate-bounce"
                    style={{ animationDelay: '300ms' }}
                  />
                </span>
              )}
            </div>
          </div>

          {/* Metadata row */}
          <div className="flex items-center gap-2 text-xs text-[color:var(--pm-text-tertiary)]">
            <span>{formatTime(message.createdAt)}</span>
            {message.modelId && <span>· {message.modelId}</span>}
            {message.status === 'error' && (
              <span className="flex items-center gap-1 text-[color:var(--pm-danger)]">
                <AcMindIcon name="status-error" size={10} />
                错误
              </span>
            )}
            {message.status === 'interrupted' && (
              <span className="flex items-center gap-1 text-[color:var(--pm-warning)]">
                <AcMindIcon name="status-warning" size={10} />
                已中断
              </span>
            )}
          </div>

          {/* Error message */}
          {message.error && (
            <div className="rounded-lg border border-[rgba(220,38,38,0.14)] bg-[rgba(254,226,226,0.8)] px-3 py-2 text-xs text-[color:var(--pm-danger)]">
              {message.error}
            </div>
          )}

          {/* Action proposals */}
          {message.actionProposals && message.actionProposals.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-1">
              {message.actionProposals.map((action) => (
                <Button
                  key={action.id}
                  variant={getActionVariant(action.riskLevel)}
                  size="sm"
                  onClick={() => handleActionClick(action)}
                  leadingIcon={getActionIcon(action.type)}
                  trailingIcon={action.riskLevel !== 'safe' ? <RiskIndicator level={action.riskLevel} /> : undefined}
                  title={action.description}
                >
                  {action.label}
                </Button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function renderMessageContent(content: string): ReactNode {
  const blocks = parseMarkdownBlocks(content);
  if (blocks.length === 0) {
    return <p className="whitespace-pre-wrap">{content}</p>;
  }

  return blocks.map((block, index) => {
    switch (block.type) {
      case 'heading':
        return (
          <div
            key={index}
            className={
              block.level === 1
                ? 'mb-2 text-[18px] font-semibold leading-8'
                : block.level === 2
                  ? 'mb-2 text-[16px] font-semibold leading-7'
                  : 'mb-2 text-[15px] font-semibold leading-7'
            }
          >
            {renderInlineMarkdown(block.content)}
          </div>
        );
      case 'paragraph':
        return (
          <p key={index} className="mb-3 whitespace-pre-wrap last:mb-0">
            {renderInlineMarkdown(block.content)}
          </p>
        );
      case 'list':
        return (
          <ul key={index} className="mb-3 ml-5 list-disc space-y-1 last:mb-0">
            {block.items.map((item, itemIndex) => (
              <li key={itemIndex}>{renderInlineMarkdown(item)}</li>
            ))}
          </ul>
        );
      case 'quote':
        return (
          <blockquote
            key={index}
            className="mb-3 border-l-2 border-[rgba(255,107,43,0.24)] pl-3 italic text-[color:var(--pm-text-secondary)] last:mb-0"
          >
            {renderInlineMarkdown(block.content)}
          </blockquote>
        );
      case 'code':
        return (
          <pre
            key={index}
            className="mb-3 overflow-x-auto rounded-[16px] bg-[rgba(15,23,42,0.96)] px-4 py-3 text-[12px] leading-6 text-white last:mb-0"
          >
            <code>{block.content}</code>
          </pre>
        );
      default:
        return null;
    }
  });
}

function renderInlineMarkdown(text: string): ReactNode[] {
  const parts: ReactNode[] = [];
  const regex = /(`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*)/g;
  let lastIndex = 0;

  for (const match of text.matchAll(regex)) {
    const matchIndex = match.index ?? 0;
    if (matchIndex > lastIndex) {
      parts.push(text.slice(lastIndex, matchIndex));
    }

    const token = match[0];
    if (token.startsWith('**')) {
      parts.push(<strong key={`${matchIndex}-bold`}>{token.slice(2, -2)}</strong>);
    } else if (token.startsWith('*')) {
      parts.push(<em key={`${matchIndex}-italic`}>{token.slice(1, -1)}</em>);
    } else if (token.startsWith('`')) {
      parts.push(
        <code
          key={`${matchIndex}-code`}
          className="rounded bg-[rgba(15,23,42,0.06)] px-1.5 py-0.5 font-mono text-[12px] text-[color:var(--pm-text-primary)]"
        >
          {token.slice(1, -1)}
        </code>,
      );
    }

    lastIndex = matchIndex + token.length;
  }

  if (lastIndex < text.length) {
    parts.push(text.slice(lastIndex));
  }

  return parts;
}

type MarkdownBlock =
  | { type: 'heading'; level: 1 | 2 | 3; content: string }
  | { type: 'paragraph'; content: string }
  | { type: 'list'; items: string[] }
  | { type: 'quote'; content: string }
  | { type: 'code'; content: string };

function parseMarkdownBlocks(content: string): MarkdownBlock[] {
  const normalized = content.replace(/\r\n/g, '\n');
  const lines = normalized.split('\n');
  const blocks: MarkdownBlock[] = [];
  let paragraph: string[] = [];
  let listItems: string[] = [];
  let quoteLines: string[] = [];
  let codeLines: string[] = [];
  let inCode = false;

  const flushParagraph = () => {
    const text = paragraph.join(' ').trim();
    if (text) {
      blocks.push({ type: 'paragraph', content: text });
    }
    paragraph = [];
  };

  const flushList = () => {
    if (listItems.length > 0) {
      blocks.push({ type: 'list', items: listItems });
    }
    listItems = [];
  };

  const flushQuote = () => {
    const text = quoteLines.join(' ').trim();
    if (text) {
      blocks.push({ type: 'quote', content: text });
    }
    quoteLines = [];
  };

  const flushCode = () => {
    blocks.push({ type: 'code', content: codeLines.join('\n') });
    codeLines = [];
  };

  for (const line of lines) {
    if (line.startsWith('```')) {
      if (inCode) {
        flushCode();
        inCode = false;
      } else {
        flushParagraph();
        flushList();
        flushQuote();
        inCode = true;
      }
      continue;
    }

    if (inCode) {
      codeLines.push(line);
      continue;
    }

    if (/^#{1,3}\s+/.test(line)) {
      flushParagraph();
      flushList();
      flushQuote();
      const level = line.match(/^#{1,3}/)?.[0].length ?? 1;
      blocks.push({
        type: 'heading',
        level: Math.min(level, 3) as 1 | 2 | 3,
        content: line.replace(/^#{1,3}\s+/, '').trim(),
      });
      continue;
    }

    if (/^\s*[-*+]\s+/.test(line)) {
      flushParagraph();
      flushQuote();
      listItems.push(line.replace(/^\s*[-*+]\s+/, '').trim());
      continue;
    }

    if (/^>\s?/.test(line)) {
      flushParagraph();
      flushList();
      quoteLines.push(line.replace(/^>\s?/, '').trim());
      continue;
    }

    if (!line.trim()) {
      flushParagraph();
      flushList();
      flushQuote();
      continue;
    }

    paragraph.push(line.trim());
  }

  flushParagraph();
  flushList();
  flushQuote();
  if (inCode) {
    flushCode();
  }

  return blocks;
}

function getActionIcon(type: AgentActionProposal['type']): React.ReactNode {
  switch (type) {
    case 'navigate':
      return <AcMindIcon name="arrow-right" size={12} />;
    case 'open_file':
      return <AcMindIcon name="duplicate" size={12} />;
    case 'distill':
      return <AcMindIcon name="edit" size={12} />;
    case 'export':
      return <AcMindIcon name="act-output" size={12} />;
    case 'scan':
      return <AcMindIcon name="search" size={12} />;
    case 'run_skill':
      return <AcMindIcon name="ai-workspace" size={12} />;
    case 'create_task':
      return <AcMindIcon name="filled-flag" size={12} />;
    default:
      return <AcMindIcon name="spark" size={12} />;
  }
}

function getActionVariant(riskLevel: AgentActionProposal['riskLevel']): 'primary' | 'secondary' | 'danger' | 'ghost' {
  switch (riskLevel) {
    case 'safe':
      return 'secondary';
    case 'confirm':
      return 'primary';
    case 'danger':
      return 'danger';
    default:
      return 'secondary';
  }
}

function RiskIndicator({ level }: { level: AgentActionProposal['riskLevel'] }): JSX.Element {
  const colorClass = level === 'danger' ? 'text-danger' : 'text-warning';
  return (
    <span className={`inline-flex items-center justify-center w-2 h-2 rounded-full ${colorClass}`}>
      <span className="w-1.5 h-1.5 rounded-full bg-current" />
    </span>
  );
}
