import { Card } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';

interface AgentCapabilityCardProps {
  title: string;
  description: string;
  prompt: string;
  icon: string;
  onSelect: (prompt: string) => void;
}

export function AgentCapabilityCard({
  title,
  description,
  prompt,
  icon,
  onSelect,
}: AgentCapabilityCardProps): JSX.Element {
  return (
    <Card
      as="div"
      variant="interactive"
      role="button"
      tabIndex={0}
      className="group flex h-full w-full cursor-pointer flex-col items-start gap-3 rounded-[18px] p-4 text-left transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_16px_32px_rgba(15,23,42,0.08)] focus:outline-none focus:ring-2 focus:ring-[rgba(255,107,43,0.16)]"
      onClick={() => onSelect(prompt)}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          onSelect(prompt);
        }
      }}
    >
      <span className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-[color:var(--pm-primary-soft)] text-[color:var(--pm-primary)] transition-transform duration-200 group-hover:scale-[1.03]">
        <AcMindIcon name={icon as any} size={18} />
      </span>

      <div className="min-w-0">
        <h3 className="text-[14px] font-semibold leading-5 text-[color:var(--pm-text-primary)]">{title}</h3>
        <p className="mt-1 text-[12px] leading-5 text-[color:var(--pm-text-secondary)]">{description}</p>
      </div>
    </Card>
  );
}
