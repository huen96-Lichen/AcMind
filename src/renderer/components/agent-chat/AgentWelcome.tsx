import { Card, StatusBadge, Button } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { AgentCapabilityCard } from './AgentCapabilityCard';

interface AgentWelcomeProps {
  onCapabilitySelect: (prompt: string) => void;
  onNewConversation: () => void;
  mockMode: boolean;
}

const CAPABILITIES = [
  {
    title: '整理会议纪要',
    description: '把今天的会议、语音或碎片整理成清晰摘要',
    prompt: '请帮我整理今天的会议、语音和碎片，输出一份结构化会议纪要。',
    icon: 'edit',
  },
  {
    title: '分析数据',
    description: '分析表格、截图或文本里的趋势和问题',
    prompt: '请帮我分析这组数据、截图或文本里的趋势、异常和问题，并给出建议。',
    icon: 'search',
  },
  {
    title: '头脑风暴',
    description: '帮我发散产品点子、命名和方案',
    prompt: '请围绕当前目标帮我发散产品点子、命名和方案，尽量给出多个方向。',
    icon: 'spark',
  },
  {
    title: '写作助手',
    description: '生成 PRD、交接文档、任务单和博客',
    prompt: '请帮我生成一份 PRD、交接文档、任务单或博客初稿，优先给出可直接使用的结构。',
    icon: 'act-output',
  },
] as const;

export function AgentWelcome({ onCapabilitySelect, onNewConversation, mockMode }: AgentWelcomeProps): JSX.Element {
  return (
    <Card
      variant="elevated"
      className="w-full max-w-[760px] rounded-[28px] border border-[rgba(15,23,42,0.08)] bg-white/72 p-11 shadow-[0_24px_80px_rgba(15,23,42,0.06)] backdrop-blur-xl"
    >
      <div className="flex flex-col items-center text-center">
        <div className="mb-5 inline-flex h-16 w-16 items-center justify-center rounded-[22px] bg-[color:var(--pm-primary-soft)] text-[color:var(--pm-primary)] shadow-[0_12px_32px_rgba(255,107,43,0.15)]">
          <AcMindIcon name="ai-workspace" size={32} />
        </div>

        <div className="flex flex-wrap items-center justify-center gap-2">
          {mockMode ? (
            <StatusBadge tone="mock" label="Mock 模式" dot={false} />
          ) : (
            <StatusBadge tone="success" label="真实模型" dot={false} />
          )}
        </div>

        <h2 className="mt-5 text-[28px] font-semibold tracking-[-0.02em] text-[color:var(--pm-text-primary)]">
          你好，Arthur
        </h2>
        <p className="mt-3 max-w-[560px] text-[15px] leading-7 text-[color:var(--pm-text-secondary)]">
          我可以帮你整理资料、发起任务、搜索知识库、生成文档。直接说你想做什么，或者先从下面的能力入口开始。
        </p>

        <div className="mt-8 grid w-full gap-3 sm:grid-cols-2">
          {CAPABILITIES.map((item) => (
            <AgentCapabilityCard
              key={item.title}
              title={item.title}
              description={item.description}
              prompt={item.prompt}
              icon={item.icon}
              onSelect={onCapabilitySelect}
            />
          ))}
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <Button
            variant="primary"
            size="md"
            onClick={onNewConversation}
            leadingIcon={<AcMindIcon name="duplicate" size={16} />}
          >
            新对话
          </Button>
          <Button
            variant="secondary"
            size="md"
            onClick={() => onCapabilitySelect('请帮我整理今天收集的内容，并尽量提炼成可以直接执行的下一步。')}
          >
            继续整理
          </Button>
        </div>
      </div>
    </Card>
  );
}
