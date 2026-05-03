import type { ReactNode } from 'react';
import { PinStackIcon, type PinStackIconName } from './icons';

interface SectionHeaderProps {
  eyebrow?: string;
  title: string;
  description?: string;
  action?: ReactNode;
}

export function SectionHeader({ eyebrow, title, description, action }: SectionHeaderProps): JSX.Element {
  return (
    <div className="flex items-start justify-between gap-4">
      <div className="min-w-0">
        {eyebrow ? <div className="pinmind-section-eyebrow">{eyebrow}</div> : null}
        <h2 className="pinmind-section-title">{title}</h2>
        {description ? <p className="pinmind-section-description">{description}</p> : null}
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </div>
  );
}

interface SidebarItemProps {
  icon: PinStackIconName;
  label: string;
  active?: boolean;
  meta?: ReactNode;
  onClick: () => void;
}

export function SidebarItem({ icon, label, active = false, meta, onClick }: SidebarItemProps): JSX.Element {
  return (
    <button type="button" onClick={onClick} className={`pinmind-sidebar-item motion-button ${active ? 'is-active' : ''}`}>
      <span className="flex min-w-0 items-center gap-3">
        <span className={`pinmind-sidebar-icon ${active ? 'is-active' : ''}`}>
          <PinStackIcon name={icon} size={16} />
        </span>
        <span className="truncate text-left">{label}</span>
      </span>
      {meta ? <span className="shrink-0 text-[11px] text-[color:var(--pm-text-tertiary)]">{meta}</span> : null}
    </button>
  );
}

interface FieldShellProps {
  label: string;
  description?: string;
  children: ReactNode;
}

export function FieldShell({ label, description, children }: FieldShellProps): JSX.Element {
  return (
    <label className="block">
      <span className="pinmind-field-label">{label}</span>
      {description ? <span className="pinmind-field-help">{description}</span> : null}
      <div className="mt-2">{children}</div>
    </label>
  );
}

export function CardHeaderActions({ children }: { children: ReactNode }): JSX.Element {
  return <div className="pinmind-card-header-actions">{children}</div>;
}

interface SettingsNavItemProps {
  icon: PinStackIconName;
  label: string;
  active?: boolean;
  badge?: string;
  onClick: () => void;
}

export function SettingsNavItem({ icon, label, active = false, badge, onClick }: SettingsNavItemProps): JSX.Element {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`settings-nav-item motion-button w-full text-left ${active ? 'is-active' : ''}`}
    >
      <span className="flex min-w-0 items-center gap-2.5">
        <span className={`settings-nav-icon ${active ? 'is-active' : ''}`}>
          <PinStackIcon name={icon} size={15} />
        </span>
        <span className="truncate text-[13px]">{label}</span>
      </span>
      {badge ? (
        <span className="settings-nav-badge">{badge}</span>
      ) : null}
    </button>
  );
}

export function BetaBadge(): JSX.Element {
  return (
    <span className="settings-beta-badge">Beta</span>
  );
}

interface EmptyStateProps {
  icon?: string;
  title: string;
  description?: string;
  action?: ReactNode;
}

export function EmptyState({ icon, title, description, action }: EmptyStateProps): JSX.Element {
  return (
    <div className="settings-empty-state">
      {icon ? <div className="settings-empty-state-icon">{icon}</div> : null}
      <div className="settings-empty-state-title">{title}</div>
      {description ? <div className="settings-empty-state-desc">{description}</div> : null}
      {action ? <div className="settings-empty-state-action">{action}</div> : null}
    </div>
  );
}

/* ===== Status Capsule (product-ization) ===== */

interface StatusCapsuleProps {
  tone: 'success' | 'warning' | 'danger' | 'neutral';
  label: string;
  onClick?: () => void;
}

export function StatusCapsule({ tone, label, onClick }: StatusCapsuleProps): JSX.Element {
  const dotColor: Record<string, string> = {
    success: 'var(--pm-success)',
    warning: 'var(--pm-warning)',
    danger: 'var(--pm-danger)',
    neutral: 'var(--pm-text-disabled)',
  };

  return (
    <button
      type="button"
      onClick={onClick}
      className={`pinmind-status-capsule tone-${tone} motion-button`}
    >
      <span className="pinmind-status-capsule-dot" style={{ background: dotColor[tone] }} />
      <span>{label}</span>
    </button>
  );
}

/* ===== Setting Group Card ===== */

interface SettingGroupCardProps {
  title: string;
  description?: string;
  icon?: PinStackIconName;
  children: ReactNode;
}

export function SettingGroupCard({ title, description, icon, children }: SettingGroupCardProps): JSX.Element {
  return (
    <div className="pinmind-setting-group-card">
      <div className="pinmind-setting-group-card-header">
        <div className="flex items-center gap-2.5">
          {icon && (
            <span className="flex h-7 w-7 items-center justify-center rounded-[8px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">
              <PinStackIcon name={icon} size={14} />
            </span>
          )}
          <div>
            <h3 className="text-[13px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>{title}</h3>
            {description && <p className="text-[11px] mt-0.5" style={{ color: 'var(--pm-text-tertiary)' }}>{description}</p>}
          </div>
        </div>
      </div>
      <div className="pinmind-setting-group-card-body">{children}</div>
    </div>
  );
}

/* ===== Onboarding Step Card ===== */

interface OnboardingStepCardProps {
  step: number;
  title: string;
  description: string;
  action?: { label: string; onClick: () => void };
  completed?: boolean;
}

export function OnboardingStepCard({ step, title, description, action, completed }: OnboardingStepCardProps): JSX.Element {
  return (
    <div className={`pinmind-onboarding-step ${completed ? 'opacity-60' : ''}`}>
      <span
        className="pinmind-onboarding-step-number"
        style={completed ? { background: 'var(--pm-success-bg)', color: 'var(--pm-success)' } : undefined}
      >
        {completed ? <PinStackIcon name="check" size={14} /> : step}
      </span>
      <div className="flex-1 min-w-0">
        <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>{title}</p>
        <p className="text-[11px] mt-1 leading-5" style={{ color: 'var(--pm-text-secondary)' }}>{description}</p>
        {action && !completed && (
          <button
            type="button"
            className="pinmind-btn pinmind-btn-ghost motion-button mt-2"
            style={{ height: 28, fontSize: 11, paddingInline: 10 }}
            onClick={action.onClick}
          >
            {action.label}
          </button>
        )}
      </div>
    </div>
  );
}
