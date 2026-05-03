import { useState } from 'react';
import type { AiTier, ProviderConfig } from '../../../../shared/types';
import { Button, Card, Input } from '../../../design-system/components';

// ─── Types ───────────────────────────────────────────────────────────────────

interface AddProviderDialogProps {
  provider?: ProviderConfig | null;
  defaultType?: 'ollama' | 'openai_compatible';
  defaultTier?: AiTier;
  defaultName?: string;
  defaultBaseUrl?: string;
  defaultModelId?: string;
  onSave: (data: ProviderConfig) => Promise<void>;
  onClose: () => void;
}

interface FormData {
  name: string;
  type: 'ollama' | 'openai_compatible';
  tier: AiTier;
  baseUrl: string;
  apiKey: string;
  modelId: string;
}

// ─── Component ───────────────────────────────────────────────────────────────

/**
 * Add/Edit provider dialog with form validation.
 * Auto-fills baseUrl for Ollama type.
 */
export function AddProviderDialog({
  provider,
  defaultType = 'ollama',
  defaultTier,
  defaultName,
  defaultBaseUrl,
  defaultModelId,
  onSave,
  onClose,
}: AddProviderDialogProps): JSX.Element {
  const isEdit = !!provider;

  const [form, setForm] = useState<FormData>({
    name: provider?.name ?? defaultName ?? '',
    type: provider?.type ?? defaultType,
    tier: provider?.tier ?? defaultTier ?? (defaultType === 'openai_compatible' ? 'cloud_standard' : 'local_light'),
    baseUrl: provider?.baseUrl ?? defaultBaseUrl ?? (defaultType === 'openai_compatible' ? 'https://api.openai.com/v1' : 'http://localhost:11434'),
    apiKey: provider?.apiKey ?? '',
    modelId: provider?.modelId ?? defaultModelId ?? '',
  });

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleTypeChange = (type: 'ollama' | 'openai_compatible') => {
    const update: Partial<FormData> = { type };
    if (type === 'ollama') {
      update.baseUrl = 'http://localhost:11434';
      update.tier = 'local_light';
    } else {
      update.baseUrl = form.baseUrl.trim() && form.baseUrl !== 'http://localhost:11434'
        ? form.baseUrl
        : 'https://api.openai.com/v1';
      update.tier = form.tier === 'local_light' ? 'cloud_standard' : form.tier;
    }
    setForm((prev) => ({ ...prev, ...update }));
  };

  const validate = (): string | null => {
    if (!form.name.trim()) return '名称不能为空';
    if (!form.baseUrl.trim()) return '接口地址不能为空';
    if (!form.modelId.trim()) return '模型 ID 不能为空';
    if (form.type === 'openai_compatible' && !form.apiKey.trim()) {
      return '云端模型需要填写 API 密钥';
    }
    return null;
  };

  const handleSubmit = async () => {
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    try {
      setSaving(true);
      setError(null);

      const config: ProviderConfig = {
        id: provider?.id ?? crypto.randomUUID(),
        name: form.name.trim(),
        type: form.type,
        tier: form.tier,
        baseUrl: form.baseUrl.trim(),
        apiKey: form.apiKey.trim() || undefined,
        modelId: form.modelId.trim(),
        enabled: provider?.enabled ?? true,
        capabilities: provider?.capabilities ?? [],
      };

      await onSave(config);
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  };

  const updateField = <K extends keyof FormData>(key: K, value: FormData[K]) => {
    setForm((prev) => ({ ...prev, [key]: value }));
    setError(null);
  };

  return (
    <Card variant="base" padding={20} className="flex flex-col gap-4" style={{ maxWidth: 480, width: '100%' }}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <h3 className="text-[14px] font-semibold" style={{ color: 'var(--pm-text-primary)' }}>
          {isEdit ? '编辑模型来源' : '新增模型来源'}
        </h3>
        <Button variant="ghost" size="sm" onClick={onClose}>
          &times;
        </Button>
      </div>

      {/* Error */}
      {error && (
        <div
          className="text-[12px] p-3 rounded-lg"
          style={{
            background: 'color-mix(in srgb, var(--pm-status-danger) 8%, transparent)',
            color: 'var(--pm-status-danger)',
            border: '1px solid color-mix(in srgb, var(--pm-status-danger) 16%, transparent)',
          }}
        >
          {error}
        </div>
      )}

      {/* Form */}
      <div className="flex flex-col gap-3">
        <FormField label="名称 *">
          <Input
            type="text"
            placeholder="例如：本地模型"
            value={form.name}
            onChange={(e) => updateField('name', e.target.value)}
          />
        </FormField>

        <FormField label="类型 *">
          <select
            className="pm-ds-input w-full"
            value={form.type}
            onChange={(e) => handleTypeChange(e.target.value as 'ollama' | 'openai_compatible')}
          >
            <option value="ollama">Ollama（本地）</option>
            <option value="openai_compatible">OpenAI 兼容（云端）</option>
          </select>
        </FormField>

        <FormField label="整理方式 *">
          <select
            className="pm-ds-input w-full"
            value={form.tier}
            onChange={(e) => updateField('tier', e.target.value as AiTier)}
          >
            <option value="local_light">本地轻量</option>
            <option value="cloud_standard">云端标准</option>
            <option value="cloud_advanced">云端高级</option>
          </select>
        </FormField>

        <FormField label="接口地址 *">
          <Input
            type="text"
            placeholder="http://localhost:11434"
            value={form.baseUrl}
            onChange={(e) => updateField('baseUrl', e.target.value)}
          />
        </FormField>

        <FormField label={`API 密钥 ${form.type === 'openai_compatible' ? '*' : '(可选)'}`}>
          <Input
            type="password"
            placeholder={form.type === 'openai_compatible' ? 'sk-...' : '本地模型可留空'}
            value={form.apiKey}
            onChange={(e) => updateField('apiKey', e.target.value)}
          />
        </FormField>

        <FormField label="模型 ID *">
          <Input
            type="text"
            placeholder="例如：llama3 / gpt-4o-mini"
            value={form.modelId}
            onChange={(e) => updateField('modelId', e.target.value)}
          />
        </FormField>
      </div>

      {/* Actions */}
      <div className="flex items-center justify-end gap-2 pt-2">
        <Button
          variant="secondary"
          size="sm"
          onClick={onClose}
          disabled={saving}
        >
          取消
        </Button>
        <Button
          variant="primary"
          size="sm"
          onClick={handleSubmit}
          disabled={saving}
        >
          {saving ? '保存中...' : isEdit ? '更新' : '新增'}
        </Button>
      </div>
    </Card>
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function FormField({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="text-[11px] font-medium mb-1 block" style={{ color: 'var(--pm-text-tertiary)' }}>
        {label}
      </label>
      {children}
    </div>
  );
}
