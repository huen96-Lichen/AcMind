/**
 * ChatComposer — 输入区域组件
 *
 * 支持：
 * - 自动调整高度的 Textarea
 * - Send 按钮 (Cmd+Enter 快捷键)
 * - Stop 按钮 (生成中)
 * - 快捷命令芯片
 *
 * 既支持受控输入，也兼容旧的内部状态模式，方便 Agent 主页和旧面板共用。
 */

import { useState, useRef, useCallback, useEffect } from 'react';
import { Button } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { QUICK_COMMANDS } from './QuickCommandTemplates';

interface ChatComposerProps {
  onSend: (content: string) => Promise<boolean | void> | boolean | void;
  onStop?: () => void;
  sending: boolean;
  placeholder?: string;
  quickCommands?: Array<{ label: string; value: string }>;
  value?: string;
  onValueChange?: (value: string) => void;
  onQuickCommandClick?: (value: string) => void | Promise<void>;
  className?: string;
}

export function ChatComposer({
  onSend,
  onStop,
  sending,
  placeholder = '输入消息...',
  quickCommands,
  value,
  onValueChange,
  onQuickCommandClick,
  className,
}: ChatComposerProps): JSX.Element {
  const [internalValue, setInternalValue] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const isControlled = typeof value === 'string';
  const content = isControlled ? value : internalValue;
  const commands = quickCommands ?? QUICK_COMMANDS.map((cmd) => ({ label: cmd.label, value: cmd.prompt }));

  // Auto-resize textarea
  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;

    textarea.style.height = 'auto';
    const newHeight = Math.min(textarea.scrollHeight, 200); // Max 200px
    textarea.style.height = `${newHeight}px`;
  }, [content]);

  // Handle send
  const handleSend = useCallback(async () => {
    const trimmed = content.trim();
    if (!trimmed || sending) return;

    const result = await onSend(trimmed);
    if (result === false) {
      return;
    }

    if (isControlled) {
      onValueChange?.('');
    } else {
      setInternalValue('');
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto';
      }
    }
  }, [content, isControlled, onSend, onValueChange, sending]);

  // Handle keydown (Cmd+Enter / Ctrl+Enter)
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
        e.preventDefault();
        void handleSend();
      }
    },
    [handleSend],
  );

  // Handle quick command click
  const handleQuickCommand = useCallback(
    (command: string) => {
      if (sending) return;
      if (onQuickCommandClick) {
        void onQuickCommandClick(command);
        return;
      }
      void onSend(command);
    },
    [onQuickCommandClick, onSend, sending],
  );

  return (
    <div
      className={`border-t border-[rgba(15,23,42,0.06)] bg-[linear-gradient(to_top,rgba(248,249,251,0.96),rgba(248,249,251,0.72),transparent)] px-8 pb-7 pt-4 ${className ?? ''}`}
    >
      {/* Quick commands */}
      {!sending && commands.length > 0 && (
        <div className="mb-3 flex flex-wrap gap-2">
          {commands.map((cmd) => (
            <button
              key={cmd.value}
              type="button"
              onClick={() => handleQuickCommand(cmd.value)}
              className="shrink-0 rounded-full border border-[rgba(15,23,42,0.08)] bg-white/80 px-3 py-1.5 text-[12px] text-[color:var(--pm-text-secondary)] transition-all hover:-translate-y-0.5 hover:border-[rgba(255,107,43,0.18)] hover:bg-[color:var(--pm-primary-soft)] hover:text-[color:var(--pm-primary)]"
            >
              {cmd.label}
            </button>
          ))}
        </div>
      )}

      {/* Input area */}
      <div className="mx-auto flex max-w-[980px] items-end gap-3 rounded-[22px] border border-[rgba(15,23,42,0.08)] bg-white/86 p-3 shadow-[0_18px_56px_rgba(15,23,42,0.08)] backdrop-blur-xl">
        <textarea
          ref={textareaRef}
          value={content}
          onChange={(e) => {
            if (isControlled) {
              onValueChange?.(e.target.value);
            } else {
              setInternalValue(e.target.value);
            }
          }}
          onKeyDown={handleKeyDown}
          placeholder={placeholder}
          disabled={sending}
          rows={1}
          className="min-h-[44px] max-h-[200px] flex-1 resize-none rounded-[18px] border border-[rgba(15,23,42,0.08)] bg-[rgba(248,249,251,0.72)] px-4 py-3 text-[14px] text-[color:var(--pm-text-primary)] outline-none transition-all placeholder:text-[color:var(--pm-text-placeholder)] focus:border-[rgba(255,107,43,0.26)] focus:bg-white focus:shadow-[0_0_0_4px_rgba(255,107,43,0.08)] disabled:opacity-50"
        />

        {/* Send / Stop button */}
        {sending ? (
          <Button
            variant="danger"
            size="md"
            onClick={onStop}
            leadingIcon={<AcMindIcon name="act-delete" size={16} />}
            className="h-11 shrink-0 rounded-[16px] px-4"
          >
            停止
          </Button>
        ) : (
          <Button
            variant="primary"
            size="md"
            onClick={() => void handleSend()}
            disabled={!content.trim()}
            className="h-11 shrink-0 rounded-[16px] px-4"
          >
            发送
          </Button>
        )}
      </div>

      {/* Hint */}
      <div className="mt-2 flex items-center gap-1 text-[12px] text-[color:var(--pm-text-tertiary)]">
        <AcMindIcon name="edit" size={10} />
        <span>输入 /help 查看命令，Cmd + Enter 发送</span>
      </div>
    </div>
  );
}
