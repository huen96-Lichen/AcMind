/**
 * ChatEmptyState — 空状态组件
 *
 * 显示：
 * - 图标 + 标题 + 描述
 * - 快捷命令按钮
 * - Mock 模式指示器
 */

import { Button } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';

interface ChatEmptyStateProps {
  onNewSession?: () => void;
  onQuickCommand?: (command: string) => void;
  mockMode?: boolean;
}

const QUICK_COMMANDS = [
  { label: '整理暂存', value: '整理暂存', icon: 'filled-inbox' as const },
  { label: '总结内容', value: '总结内容', icon: 'filled-ai-process' as const },
  { label: '生成待办', value: '生成待办', icon: 'filled-flag' as const },
];

export function ChatEmptyState({ onNewSession, onQuickCommand, mockMode = false }: ChatEmptyStateProps): JSX.Element {
  return (
    <div className="flex flex-col items-center justify-center h-full p-8 text-center">
      {/* Icon */}
      <div className="w-16 h-16 rounded-2xl bg-accent-soft flex items-center justify-center mb-4">
        <AcMindIcon name="ai-workspace" size={32} className="text-accent" />
      </div>

      {/* Title */}
      <h3 className="text-lg font-semibold text-text-primary mb-2">开始新的对话</h3>

      {/* Description */}
      <p className="text-sm text-text-secondary max-w-xs mb-6">与 AI 助手交流，整理知识、生成待办、获取建议</p>

      {/* Mock mode indicator */}
      {mockMode && (
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-mock-soft text-mock text-xs mb-6">
          <AcMindIcon name="status-processing" size={12} />
          <span>Mock 模式已开启</span>
        </div>
      )}

      {/* Quick commands */}
      <div className="flex flex-wrap justify-center gap-2 mb-6">
        {QUICK_COMMANDS.map((cmd) => (
          <Button
            key={cmd.value}
            variant="secondary"
            size="sm"
            onClick={() => onQuickCommand?.(cmd.value)}
            leadingIcon={<AcMindIcon name={cmd.icon} size={14} />}
          >
            {cmd.label}
          </Button>
        ))}
      </div>

      {/* New session button */}
      {onNewSession && (
        <Button
          variant="primary"
          size="md"
          onClick={onNewSession}
          leadingIcon={<AcMindIcon name="duplicate" size={16} />}
        >
          新建对话
        </Button>
      )}
    </div>
  );
}
