import { useCallback, useEffect, useState } from 'react';
import { ScrollContainer } from '../shared/ScrollContainer';
import type { VaultConfig } from '../../../shared/types';

// ─── Component ───────────────────────────────────────────────────────────────

export function VaultConfigPanel(): JSX.Element {
  const [config, setConfig] = useState<VaultConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [validating, setValidating] = useState(false);
  const [validationResult, setValidationResult] = useState<{ valid: boolean; message: string } | null>(null);

  const loadConfig = useCallback(async () => {
    try {
      setError(null);
      const settings = await window.acmind.settings.get();
      setConfig(settings.vault);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadConfig();
  }, [loadConfig]);

  const updateField = <K extends keyof VaultConfig>(key: K, value: VaultConfig[K]) => {
    if (!config) return;
    setConfig((prev) => (prev ? { ...prev, [key]: value } : prev));
    setValidationResult(null);
  };

  const handlePickFolder = async () => {
    try {
      const path = await window.acmind.vault.pickFolder();
      if (path) {
        updateField('vaultPath', path);
      }
    } catch {
      // Folder picker cancelled
    }
  };

  const handleSave = async () => {
    if (!config) return;
    try {
      setSaving(true);
      setError(null);
      await window.acmind.vault.updateConfig(config);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  };

  const handleValidate = async () => {
    if (!config?.vaultPath) return;
    try {
      setValidating(true);
      const result = await window.acmind.vault.validatePath(config.vaultPath);
      setValidationResult(result);
    } catch (err) {
      setValidationResult({
        valid: false,
        message: err instanceof Error ? err.message : '校验失败',
      });
    } finally {
      setValidating(false);
    }
  };

  if (loading) {
    return (
      <ScrollContainer>
        <div className="flex items-center justify-center py-8">
          <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
            正在加载知识库配置...
          </span>
        </div>
      </ScrollContainer>
    );
  }

  if (!config) {
    return (
      <ScrollContainer>
        <div className="p-4">
          <div
            className="text-[12px] p-3 rounded-lg"
            style={{
              background: 'rgba(201, 75, 75, 0.08)',
              color: 'var(--pm-status-danger)',
              border: '1px solid rgba(201, 75, 75, 0.16)',
            }}
          >
            {error ?? '加载知识库配置失败。'}
          </div>
        </div>
      </ScrollContainer>
    );
  }

  return (
    <ScrollContainer>
      <div className="p-4">
        <div className="acmind-vault-config flex flex-col gap-5">
          {/* Error */}
          {error && (
            <div
              className="text-[12px] p-3 rounded-lg"
              style={{
                background: 'rgba(201, 75, 75, 0.08)',
                color: 'var(--pm-status-danger)',
                border: '1px solid rgba(201, 75, 75, 0.16)',
              }}
            >
              {error}
            </div>
          )}

          {/* Vault Path */}
          <div>
            <label className="acmind-field-label">知识库路径</label>
            <div className="flex items-center gap-2 mt-1">
              <input
                type="text"
                className="acmind-field flex-1"
                value={config.vaultPath}
                onChange={(e) => updateField('vaultPath', e.target.value)}
                placeholder="选择或输入知识库路径"
              />
              <button
                type="button"
                className="acmind-btn acmind-btn-secondary motion-button"
                onClick={handlePickFolder}
              >
                选择
              </button>
            </div>
            {validationResult && (
              <div
                className="text-[11px] mt-1"
                style={{
                  color: validationResult.valid ? 'var(--pm-status-success)' : 'var(--pm-status-danger)',
                }}
              >
                {validationResult.message}
              </div>
            )}
          </div>

          {/* Default Folder */}
          <div>
                <label className="acmind-field-label">默认文件夹</label>
            <input
              type="text"
              className="acmind-field w-full mt-1"
              value={config.defaultFolder}
              onChange={(e) => updateField('defaultFolder', e.target.value)}
              placeholder="AcMind"
            />
          </div>

          {/* Path Rule */}
          <div>
            <label className="acmind-field-label">路径规则</label>
            <select
              className="acmind-field acmind-field-select w-full mt-1"
              value={config.pathRule}
              onChange={(e) =>
                updateField(
                  'pathRule',
                  e.target.value as VaultConfig['pathRule'],
                )
              }
            >
              <option value="category_date">分类 / 日期</option>
              <option value="category_title">分类 / 标题</option>
              <option value="flat">平铺</option>
            </select>
          </div>

          {/* Conflict Strategy */}
          <div>
            <label className="acmind-field-label">冲突策略</label>
            <select
              className="acmind-field acmind-field-select w-full mt-1"
              value={config.conflictStrategy}
              onChange={(e) =>
                updateField(
                  'conflictStrategy',
                  e.target.value as VaultConfig['conflictStrategy'],
                )
              }
            >
              <option value="rename">重命名</option>
              <option value="skip">跳过</option>
              <option value="overwrite">覆盖</option>
            </select>
          </div>

          {/* Auto Frontmatter */}
          <div className="flex items-center justify-between">
            <div>
              <label className="acmind-field-label">自动 frontmatter</label>
              <p className="text-[11px] mt-0.5" style={{ color: 'var(--pm-text-tertiary)' }}>
                写入时自动补充 YAML frontmatter
              </p>
            </div>
            <button
              type="button"
              className={`acmind-icon-button motion-toggle ${config.autoFrontmatter ? 'acmind-icon-button-accent' : 'acmind-icon-button-soft'}`}
              onClick={() => updateField('autoFrontmatter', !config.autoFrontmatter)}
              role="switch"
              aria-checked={config.autoFrontmatter}
            >
              <span
                className="inline-block w-8 h-5 rounded-full relative transition-colors"
                style={{
                  background: config.autoFrontmatter
                    ? 'var(--pm-brand-primary)'
                    : 'color-mix(in srgb, var(--pm-border-default) 60%, transparent)',
                }}
              >
                <span
                  className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow-sm transition-transform"
                  style={{
                    left: config.autoFrontmatter ? 14 : 2,
                    transition: 'transform var(--motion-base) var(--ease-standard)',
                  }}
                />
              </span>
            </button>
          </div>

          {/* Actions */}
          <div className="flex items-center justify-end gap-2 pt-2">
            <button
              type="button"
              className="acmind-btn acmind-btn-secondary motion-button"
              onClick={handleValidate}
              disabled={!config.vaultPath || validating}
            >
              {validating ? '正在校验...' : '校验路径'}
            </button>
            <button
              type="button"
              className="acmind-btn acmind-btn-primary motion-button"
              onClick={handleSave}
              disabled={saving}
            >
              {saving ? '保存中...' : '保存配置'}
            </button>
          </div>
        </div>
      </div>
    </ScrollContainer>
  );
}
