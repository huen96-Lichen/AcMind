import { forwardRef, useState, type ButtonHTMLAttributes, type ChangeEvent, type CSSProperties, type HTMLAttributes, type InputHTMLAttributes, type ReactNode, type Ref } from 'react';
import { AcMindIcon } from '../icons';
import { DESIGN_TOKENS, type ThemeMode } from '../tokens';

function classNames(...values: Array<string | false | null | undefined>): string {
  return values.filter(Boolean).join(' ');
}

function getThemeColors(mode: ThemeMode = 'light') {
  return DESIGN_TOKENS.color[mode];
}

function resolveButtonVars(variant: ButtonVariant, mode: ThemeMode = 'light'): CSSProperties {
  const colors = getThemeColors(mode);
  switch (variant) {
    case 'primary':
      return {
        '--pm-btn-bg': colors.accent,
        '--pm-btn-bg-hover': colors.accentHover,
        '--pm-btn-border': colors.accent,
        '--pm-btn-border-hover': colors.accentHover,
        '--pm-btn-color': colors.textInverse,
        '--pm-btn-shadow': colors.shadowNeutral,
        '--pm-btn-shadow-hover': colors.shadowFloating,
      } as CSSProperties;
    case 'secondary':
      return {
        '--pm-btn-bg': colors.surface,
        '--pm-btn-bg-hover': mode === 'dark' ? '#343436' : '#ffffff',
        '--pm-btn-border': colors.borderStrong,
        '--pm-btn-border-hover': colors.accent,
        '--pm-btn-color': colors.textPrimary,
        '--pm-btn-shadow': 'none',
      } as CSSProperties;
    case 'plain':
      return {
        '--pm-btn-bg': 'transparent',
        '--pm-btn-bg-hover': mode === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(17,24,39,0.03)',
        '--pm-btn-border': 'transparent',
        '--pm-btn-border-hover': 'transparent',
        '--pm-btn-color': colors.textSecondary,
        '--pm-btn-shadow': 'none',
      } as CSSProperties;
    case 'ghost':
      return {
        '--pm-btn-bg': 'transparent',
        '--pm-btn-bg-hover': mode === 'dark' ? 'rgba(255,255,255,0.08)' : 'rgba(17,24,39,0.04)',
        '--pm-btn-border': 'transparent',
        '--pm-btn-border-hover': 'transparent',
        '--pm-btn-color': colors.textPrimary,
        '--pm-btn-shadow': 'none',
      } as CSSProperties;
    case 'danger':
      return {
        '--pm-btn-bg': colors.dangerSoft,
        '--pm-btn-bg-hover': mode === 'dark' ? 'rgba(248, 113, 113, 0.18)' : 'rgba(220, 38, 38, 0.1)',
        '--pm-btn-border': mode === 'dark' ? 'rgba(248, 113, 113, 0.22)' : 'rgba(220, 38, 38, 0.18)',
        '--pm-btn-border-hover': colors.danger,
        '--pm-btn-color': colors.danger,
        '--pm-btn-shadow': 'none',
      } as CSSProperties;
    case 'icon':
      return {
        '--pm-btn-bg': mode === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.9)',
        '--pm-btn-bg-hover': mode === 'dark' ? 'rgba(255,255,255,0.12)' : '#ffffff',
        '--pm-btn-border': colors.borderSubtle,
        '--pm-btn-border-hover': colors.borderStrong,
        '--pm-btn-color': colors.textSecondary,
        '--pm-btn-shadow': 'none',
      } as CSSProperties;
  }
}

function resolveCardVars(variant: CardVariant, mode: ThemeMode = 'light'): CSSProperties {
  const colors = getThemeColors(mode);
  switch (variant) {
    case 'interactive':
      return {
        '--pm-card-bg': colors.surface,
        '--pm-card-bg-hover': mode === 'dark' ? '#313133' : '#ffffff',
        '--pm-card-border': colors.borderSubtle,
        '--pm-card-border-hover': colors.borderStrong,
        '--pm-card-shadow': colors.shadowNeutral,
        '--pm-card-shadow-hover': colors.shadowFloating,
      } as CSSProperties;
    case 'selected':
      return {
        '--pm-card-bg': colors.accentSoft,
        '--pm-card-bg-hover': colors.accentSoft,
        '--pm-card-border': colors.accent,
        '--pm-card-border-hover': colors.accent,
        '--pm-card-shadow': 'none',
      } as CSSProperties;
    case 'elevated':
      return {
        '--pm-card-bg': colors.elevated,
        '--pm-card-bg-hover': colors.elevated,
        '--pm-card-border': colors.borderStrong,
        '--pm-card-border-hover': colors.borderStrong,
        '--pm-card-shadow': colors.shadowFloating,
      } as CSSProperties;
    case 'grouped':
      return {
        '--pm-card-bg': colors.surfaceMuted,
        '--pm-card-bg-hover': colors.surfaceMuted,
        '--pm-card-border': 'transparent',
        '--pm-card-border-hover': 'transparent',
        '--pm-card-shadow': 'none',
      } as CSSProperties;
    case 'base':
    default:
      return {
        '--pm-card-bg': colors.surface,
        '--pm-card-bg-hover': colors.surface,
        '--pm-card-border': colors.borderSubtle,
        '--pm-card-border-hover': colors.borderSubtle,
        '--pm-card-shadow': colors.shadowNeutral,
      } as CSSProperties;
  }
}

function resolveBadgeVars(tone: StatusBadgeTone, mode: ThemeMode = 'light'): CSSProperties {
  const colors = getThemeColors(mode);
  switch (tone) {
    case 'info':
      return {
        '--pm-badge-bg': colors.infoSoft,
        '--pm-badge-color': colors.info,
        '--pm-badge-border': mode === 'dark' ? 'rgba(96, 165, 250, 0.24)' : 'rgba(29, 78, 216, 0.16)',
      } as CSSProperties;
    case 'success':
      return {
        '--pm-badge-bg': colors.successSoft,
        '--pm-badge-color': colors.success,
        '--pm-badge-border': mode === 'dark' ? 'rgba(74, 222, 128, 0.22)' : 'rgba(21, 128, 61, 0.16)',
      } as CSSProperties;
    case 'warning':
      return {
        '--pm-badge-bg': colors.warningSoft,
        '--pm-badge-color': colors.warning,
        '--pm-badge-border': mode === 'dark' ? 'rgba(251, 191, 36, 0.22)' : 'rgba(146, 64, 14, 0.16)',
      } as CSSProperties;
    case 'danger':
      return {
        '--pm-badge-bg': colors.dangerSoft,
        '--pm-badge-color': colors.danger,
        '--pm-badge-border': mode === 'dark' ? 'rgba(248, 113, 113, 0.22)' : 'rgba(220, 38, 38, 0.16)',
      } as CSSProperties;
    case 'processing':
      return {
        '--pm-badge-bg': colors.infoSoft,
        '--pm-badge-color': colors.info,
        '--pm-badge-border': mode === 'dark' ? 'rgba(96, 165, 250, 0.22)' : 'rgba(29, 78, 216, 0.14)',
      } as CSSProperties;
    case 'mock':
      return {
        '--pm-badge-bg': colors.mockSoft,
        '--pm-badge-color': colors.mock,
        '--pm-badge-border': colors.borderSubtle,
      } as CSSProperties;
    case 'disabled':
      return {
        '--pm-badge-bg': mode === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(17,24,39,0.04)',
        '--pm-badge-color': colors.textDisabled,
        '--pm-badge-border': 'transparent',
      } as CSSProperties;
    case 'neutral':
    default:
      return {
        '--pm-badge-bg': mode === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(17,24,39,0.04)',
        '--pm-badge-color': colors.textSecondary,
        '--pm-badge-border': colors.borderSubtle,
      } as CSSProperties;
  }
}

export type ButtonVariant = 'primary' | 'secondary' | 'plain' | 'ghost' | 'danger' | 'icon';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  leadingIcon?: ReactNode;
  trailingIcon?: ReactNode;
  mode?: ThemeMode;
  busy?: boolean;
}

export const Button = forwardRef(function Button(
  {
    variant = 'secondary',
    size = 'md',
    leadingIcon,
    trailingIcon,
    mode = 'light',
    busy = false,
    disabled,
    className,
    children,
    ...rest
  }: ButtonProps,
  ref: Ref<HTMLButtonElement>,
): JSX.Element {
  const sizeClass = size === 'sm' ? 'pm-ds-button-sm' : size === 'lg' ? 'pm-ds-button-lg' : 'pm-ds-button-md';
  const iconOnly = variant === 'icon';
  const isDisabled = disabled || busy;

  return (
    <button
      ref={ref}
      type="button"
      className={classNames('pm-ds-button motion-button', `pm-ds-button-${variant}`, sizeClass, iconOnly && 'pm-ds-button-icon', className)}
      style={resolveButtonVars(variant, mode)}
      disabled={isDisabled}
      aria-busy={busy || undefined}
      {...rest}
    >
      {busy ? <span className="pm-ds-spinner" aria-hidden="true" /> : leadingIcon}
      {children ? <span className="pm-ds-button-label">{children}</span> : null}
      {!busy ? trailingIcon : null}
    </button>
  );
});

export type CardVariant = 'base' | 'grouped' | 'interactive' | 'selected' | 'elevated';

export interface CardProps extends HTMLAttributes<HTMLElement> {
  variant?: CardVariant;
  mode?: ThemeMode;
  padding?: number;
  as?: 'div' | 'section' | 'article' | 'li';
}

export function Card({
  variant = 'base',
  mode = 'light',
  padding = DESIGN_TOKENS.space.card,
  as: Element = 'div',
  className,
  style,
  children,
  ...rest
}: CardProps): JSX.Element {
  return (
    <Element
      className={classNames('pm-ds-card', variant !== 'base' && `pm-ds-card-${variant}`, className)}
      style={{
        padding,
        ...resolveCardVars(variant, mode),
        ...style,
      }}
      {...rest}
    >
      {children}
    </Element>
  );
}

export type StatusBadgeTone = 'neutral' | 'info' | 'success' | 'warning' | 'danger' | 'processing' | 'disabled' | 'mock';

export interface StatusBadgeProps extends HTMLAttributes<HTMLSpanElement> {
  tone?: StatusBadgeTone;
  label: string;
  mode?: ThemeMode;
  dot?: boolean;
}

export function StatusBadge({
  tone = 'neutral',
  label,
  mode = 'light',
  dot = true,
  className,
  ...rest
}: StatusBadgeProps): JSX.Element {
  return (
    <span className={classNames('pm-ds-badge', `pm-ds-badge-${tone}`, className)} style={resolveBadgeVars(tone, mode)} {...rest}>
      {dot ? <span className="pm-ds-badge-dot" aria-hidden="true" /> : null}
      <span>{label}</span>
    </span>
  );
}

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  description?: string;
}

export const Input = forwardRef(function Input(
  { className, ...rest }: InputProps,
  ref: Ref<HTMLInputElement>,
): JSX.Element {
  return <input ref={ref} className={classNames('pm-ds-input', className)} {...rest} />;
});

export interface SearchFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type' | 'size'> {
  label?: string;
  description?: string;
  onSearch?: (value: string) => void;
  onClear?: () => void;
  submitLabel?: string;
  mode?: ThemeMode;
}

export function SearchField({
  className,
  value,
  defaultValue,
  onSearch,
  onClear,
  submitLabel = '搜索',
  mode = 'light',
  onKeyDown,
  onChange,
  ...rest
}: SearchFieldProps): JSX.Element {
  const isControlled = typeof value === 'string';
  const [internalValue, setInternalValue] = useState<string>(typeof defaultValue === 'string' ? defaultValue : typeof value === 'string' ? value : '');
  const currentValue = isControlled ? value : internalValue;
  return (
    <div className={classNames('pm-ds-search-field', className)} style={{ '--pm-search-placeholder': getThemeColors(mode).textTertiary } as CSSProperties}>
      <span className="pm-ds-search-icon" aria-hidden="true">
        <AcMindIcon name="search" size={14} />
      </span>
      <input
        type="search"
        className="pm-ds-input pm-ds-search-input"
        value={currentValue}
        onKeyDown={(event) => {
          onKeyDown?.(event);
          if (event.defaultPrevented) {
            return;
          }
          if (event.key === 'Enter') {
            onSearch?.(currentValue);
          }
        }}
        onChange={(event) => {
          if (!isControlled) {
            setInternalValue(event.target.value);
          }
          onChange?.(event);
        }}
        {...rest}
      />
      {currentValue && onClear ? (
        <Button
          variant="ghost"
          size="sm"
          className="pm-ds-search-clear"
          onClick={onClear}
          aria-label="清除搜索内容"
          title="清除搜索内容"
        >
          <AcMindIcon name="close" size={12} />
        </Button>
      ) : onSearch ? (
        <Button
          variant="secondary"
          size="sm"
          className="pm-ds-search-submit"
          onClick={() => onSearch(currentValue)}
        >
          {submitLabel}
        </Button>
      ) : null}
    </div>
  );
}

export interface PageShellProps extends HTMLAttributes<HTMLDivElement> {
  title?: string;
}

export function PageShell({ className, style, children, ...rest }: PageShellProps): JSX.Element {
  return (
    <div
      className={classNames('pm-ds-page-shell', className)}
      style={{
        padding: DESIGN_TOKENS.space.page,
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}

export interface PageHeaderProps extends HTMLAttributes<HTMLElement> {
  eyebrow?: string;
  title: string;
  description?: string;
  actions?: ReactNode;
  meta?: ReactNode;
}

export function PageHeader({ eyebrow, title, description, actions, meta, className, ...rest }: PageHeaderProps): JSX.Element {
  return (
    <header className={classNames('pm-ds-page-header', className)} {...rest}>
      <div className="min-w-0">
        {eyebrow ? <div className="pm-ds-eyebrow">{eyebrow}</div> : null}
        <div className="pm-ds-page-title-row">
          <h1 className="pm-ds-page-title">{title}</h1>
          {meta ? <div className="pm-ds-page-meta">{meta}</div> : null}
        </div>
        {description ? <p className="pm-ds-page-description">{description}</p> : null}
      </div>
      {actions ? <div className="pm-ds-page-actions">{actions}</div> : null}
    </header>
  );
}

export interface SectionProps extends HTMLAttributes<HTMLElement> {
  title: string;
  description?: string;
  eyebrow?: string;
  action?: ReactNode;
  as?: 'section' | 'div';
  compact?: boolean;
}

export function Section({
  title,
  description,
  eyebrow,
  action,
  as: Element = 'section',
  compact = false,
  className,
  children,
  ...rest
}: SectionProps): JSX.Element {
  return (
    <Element className={classNames('pm-ds-section', compact && 'pm-ds-section-compact', className)} {...rest}>
      <div className="pm-ds-section-header">
        <div className="min-w-0">
          {eyebrow ? <div className="pm-ds-eyebrow">{eyebrow}</div> : null}
          <h2 className="pm-ds-section-title">{title}</h2>
          {description ? <p className="pm-ds-section-description">{description}</p> : null}
        </div>
        {action ? <div className="shrink-0">{action}</div> : null}
      </div>
      <div className="pm-ds-section-body">{children}</div>
    </Element>
  );
}

export interface EmptyStateProps {
  icon?: ReactNode;
  title: string;
  description?: string;
  action?: {
    label: string;
    onClick: () => void;
  };
  mode?: ThemeMode;
}

export function EmptyState({ icon, title, description, action, mode = 'light' }: EmptyStateProps): JSX.Element {
  return (
    <Card variant="elevated" mode={mode} className="pm-ds-state-card">
      <div className="pm-ds-state-icon">{icon ?? <AcMindIcon name="empty-inbox" size={28} />}</div>
      <div className="pm-ds-state-title">{title}</div>
      {description ? <div className="pm-ds-state-description">{description}</div> : null}
      {action ? (
        <div className="pm-ds-state-action">
          <Button variant="primary" onClick={action.onClick}>
            {action.label}
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

export interface LoadingStateProps {
  title: string;
  description: string;
  mode?: ThemeMode;
}

export function LoadingState({ title, description, mode = 'light' }: LoadingStateProps): JSX.Element {
  return (
    <Card variant="elevated" mode={mode} className="pm-ds-state-card">
      <div className="pm-ds-spinner pm-ds-spinner-large" aria-hidden="true" />
      <div className="pm-ds-state-title">{title}</div>
      <div className="pm-ds-state-description">{description}</div>
    </Card>
  );
}

export interface ErrorStateProps {
  title: string;
  reason: string;
  suggestion: string;
  action?: {
    label: string;
    onClick: () => void;
  };
  mode?: ThemeMode;
}

export function ErrorState({ title, reason, suggestion, action, mode = 'light' }: ErrorStateProps): JSX.Element {
  return (
    <Card variant="elevated" mode={mode} className="pm-ds-state-card">
      <div className="pm-ds-state-icon pm-ds-state-icon-danger">
        <AcMindIcon name="status-error" size={28} />
      </div>
      <div className="pm-ds-state-title">{title}</div>
      <div className="pm-ds-state-description">{reason}</div>
      <div className="pm-ds-state-hint">{suggestion}</div>
      {action ? (
        <div className="pm-ds-state-action">
          <Button variant="primary" onClick={action.onClick}>
            {action.label}
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

export function normalizeSearchValue(event: ChangeEvent<HTMLInputElement>): string {
  return event.target.value;
}
