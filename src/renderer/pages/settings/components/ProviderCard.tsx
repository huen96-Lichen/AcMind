import type { ProviderConfig } from '../../../../shared/types';
import { Button, Card, StatusBadge } from '../../../design-system/components';

// ─── Types ───────────────────────────────────────────────────────────────────

interface ProviderCardProps {
  provider: ProviderConfig;
  onToggleEnabled?: (providerId: string) => void;
  onEdit: (provider: ProviderConfig) => void;
  onDelete: (providerId: string) => void;
  onTest: (providerId: string) => void;
}

// ─── Component ───────────────────────────────────────────────────────────────

/**
 * Provider display card showing configuration details and action buttons.
 * Visually disabled when provider.enabled is false.
 */
export function ProviderCard({ provider, onToggleEnabled, onEdit, onDelete, onTest }: ProviderCardProps): JSX.Element {
  const disabled = !provider.enabled;

  const tierLabels: Record<string, string> = {
    local_light: '本地轻量',
    cloud_standard: '云端标准',
    cloud_advanced: '云端高级',
  };

  return (
    <Card
      variant="base"
      padding={16}
      className={disabled ? 'opacity-55' : undefined}
    >
      {/* Header */}
      <div className="flex items-center gap-2 flex-wrap mb-3">
        <span className="text-[14px] font-semibold truncate" style={{ color: 'var(--pm-text-primary)' }}>
          {provider.name}
        </span>
        <StatusBadge
          tone={provider.type === 'ollama' ? 'success' : 'info'}
          label={provider.type === 'ollama' ? '本地' : '云端'}
          dot={false}
        />
        <StatusBadge
          tone={disabled ? 'neutral' : 'success'}
          label={disabled ? '已停用' : '已启用'}
          dot={!disabled}
        />
        <StatusBadge
          tone="neutral"
          label={tierLabels[provider.tier] ?? provider.tier}
          dot={false}
        />
      </div>

      {/* Body */}
      <div className="flex items-start gap-4 flex-wrap mb-3">
        <div className="min-w-0">
          <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            模型
          </span>
          <p className="text-[12px] font-medium truncate" style={{ color: 'var(--pm-text-secondary)' }}>
            {provider.modelId}
          </p>
        </div>
        <div className="min-w-0 flex-1">
          <span className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            接口地址
          </span>
          <p className="text-[12px] font-medium truncate" style={{ color: 'var(--pm-text-secondary)' }}>
            {provider.baseUrl}
          </p>
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2 flex-wrap">
        {onToggleEnabled ? (
          <Button
            variant="secondary"
            size="sm"
            onClick={() => onToggleEnabled(provider.id)}
          >
            {provider.enabled ? '停用' : '启用'}
          </Button>
        ) : null}
        <Button
          variant="secondary"
          size="sm"
          disabled={disabled}
          onClick={() => onTest(provider.id)}
        >
          测试连接
        </Button>
        <Button
          variant="secondary"
          size="sm"
          onClick={() => onEdit(provider)}
        >
          编辑
        </Button>
        <Button
          variant="danger"
          size="sm"
          onClick={() => onDelete(provider.id)}
        >
          删除
        </Button>
      </div>
    </Card>
  );
}
