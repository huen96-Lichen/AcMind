import { useCallback, useEffect, useState } from 'react';
import type { AppSettings } from '../../../../shared/types';
import {
  Button,
  Card,
  Section,
  StatusBadge,
} from '../../../design-system/components';
import { PinStackIcon } from '../../../design-system/icons';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface VaultStatus {
  path: string;
  valid: boolean;
  userMessage: string;
  checking: boolean;
}

interface TemplateStatus {
  specPackPath: string;
  loaded: boolean;
  profileCount: number;
  templateCount: number;
  activeProfileId: string;
  schemaVersion: string;
  checking: boolean;
}

interface ModelStatus {
  enabled: boolean;
  configuredModel: string;
  effectiveModel: string;
  connectionStatus: string;
  modelStatus: string;
  fallbackReason?: string;
  lastError?: string;
  checkedAt: number | null;
  checking: boolean;
}

interface RecentError {
  error_id: string;
  error_type: string;
  user_message: string;
  created_at: number;
  status: string;
}

// Phase 9.7: VaultKeeper 状态
interface VKStatus {
  available: boolean;
  connectionMethod: string;
  supportedJobTypes: string[];
  version?: string;
  error?: string;
  checkedAt: number;
  recentJobs: RecentError[];
  failedJobs: RecentError[];
  checking: boolean;
}

interface AdvancedControlPanelProps {
  settings: AppSettings;
  onUpdateSetting: (patch: Partial<AppSettings>) => void;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatTime(timestamp: number): string {
  if (!timestamp) return '—';
  return new Date(timestamp * 1000).toLocaleString('zh-CN');
}

const ERROR_TYPE_LABELS: Record<string, string> = {
  capture_failed: '捕获失败',
  process_failed: '处理失败',
  export_failed: '导出失败',
  permission_required: '权限不足',
  conflict_pending: '冲突待处理',
  template_missing: '模板缺失',
  vault_missing: '仓库未配置',
  model_unavailable: '模型不可用',
  vaultkeeper_unavailable: '服务不可用',
  external_job_failed: '外部任务失败',
  external_result_invalid: '外部结果无效',
  external_result_ingest_failed: '结果回填失败',
  unknown_error: '未知错误',
};

// ---------------------------------------------------------------------------
// InfoRow
// ---------------------------------------------------------------------------

function InfoRow({ label, value, danger }: { label: string; value: React.ReactNode; danger?: boolean }): JSX.Element {
  return (
    <div className="flex items-center justify-between py-1.5 text-[13px]">
      <span style={{ color: 'var(--pm-text-tertiary)', flexShrink: 0 }}>{label}</span>
      <span style={{ color: danger ? 'var(--pm-status-danger)' : 'var(--pm-text-primary)', textAlign: 'right', wordBreak: 'break-all', marginLeft: 16 }}>
        {value}
      </span>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Toggle Switch
// ---------------------------------------------------------------------------

function ToggleSwitch({
  label,
  description,
  checked,
  onChange,
}: {
  label: string;
  description: string;
  checked: boolean;
  onChange: (val: boolean) => void;
}): JSX.Element {
  return (
    <div className="flex items-center justify-between py-2">
      <div>
        <div className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>{label}</div>
        <div className="text-[11px] mt-0.5" style={{ color: 'var(--pm-text-tertiary)' }}>{description}</div>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        style={{
          width: 40,
          height: 22,
          borderRadius: 11,
          border: 'none',
          cursor: 'pointer',
          position: 'relative',
          transition: 'background 0.2s',
          background: checked ? 'var(--pm-brand-primary)' : 'var(--pm-text-tertiary)',
          opacity: checked ? 1 : 0.4,
          flexShrink: 0,
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 2,
            left: checked ? 20 : 2,
            width: 18,
            height: 18,
            borderRadius: '50%',
            background: '#fff',
            transition: 'left 0.2s',
            boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
          }}
        />
      </button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// AdvancedControlPanel
// ---------------------------------------------------------------------------

export function AdvancedControlPanel({ settings, onUpdateSetting }: AdvancedControlPanelProps): JSX.Element {
  const [vaultStatus, setVaultStatus] = useState<VaultStatus>({ path: '', valid: false, userMessage: '未检查', checking: true });
  const [templateStatus, setTemplateStatus] = useState<TemplateStatus>({ specPackPath: '', loaded: false, profileCount: 0, templateCount: 0, activeProfileId: '', schemaVersion: '', checking: true });
  const [modelStatus, setModelStatus] = useState<ModelStatus>({ enabled: false, configuredModel: '', effectiveModel: '', connectionStatus: '', modelStatus: '', checkedAt: null, checking: true });
  const [recentErrors, setRecentErrors] = useState<RecentError[]>([]);
  const [vkStatus, setVkStatus] = useState<VKStatus>({
    available: false,
    connectionMethod: 'unavailable',
    supportedJobTypes: [],
    checkedAt: 0,
    recentJobs: [],
    failedJobs: [],
    checking: true,
  });
  const [logsExpanded, setLogsExpanded] = useState(false);

  // Load all statuses on mount
  const loadStatuses = useCallback(async () => {
    // Vault status
    try {
      const vaultPath = settings.vault?.vaultPath ?? '';
      if (vaultPath) {
        const result = await window.pinmind.vault.validatePath(vaultPath);
        setVaultStatus({ path: vaultPath, valid: result.valid, userMessage: result.message ?? (result.valid ? '验证通过' : '验证未通过'), checking: false });
      } else {
        setVaultStatus({ path: '', valid: false, userMessage: '未配置仓库路径', checking: false });
      }
    } catch {
      setVaultStatus((prev) => ({ ...prev, checking: false, userMessage: '检查失败' }));
    }

    // Template status
    try {
      const info = await window.pinmind.outputSpec.getInfo();
      setTemplateStatus({
        specPackPath: info.specPackPath ?? '',
        loaded: info.loaded,
        profileCount: info.profileCount ?? 0,
        templateCount: info.templateCount ?? 0,
        activeProfileId: info.activeProfileId ?? '',
        schemaVersion: info.schemaVersion ?? '',
        checking: false,
      });
    } catch {
      setTemplateStatus((prev) => ({ ...prev, checking: false }));
    }

    // Model status
    try {
      const status = await window.pinmind.localModel.getRuntimeStatus();
      setModelStatus({
        enabled: status.enabled,
        configuredModel: status.configuredModel ?? '',
        effectiveModel: status.effectiveModel ?? '',
        connectionStatus: status.connectionStatus ?? '',
        modelStatus: status.modelStatus ?? '',
        fallbackReason: status.fallbackReason,
        lastError: status.lastError?.message,
        checkedAt: status.checkedAt ?? null,
        checking: false,
      });
    } catch {
      setModelStatus((prev) => ({ ...prev, checking: false }));
    }

    // Recent errors
    try {
      const errs = await window.pinmind.errors.list({ status: 'open', limit: 5 });
      setRecentErrors(errs.map((e: any) => ({
        error_id: e.error_id,
        error_type: e.error_type,
        user_message: e.user_message,
        created_at: e.created_at,
        status: e.status,
      })));
    } catch {
      // ignore
    }

    // Phase 9.7: VaultKeeper status
    try {
      const health = await window.pinmind.vk.checkHealth() as any;
      const recentJobs = await window.pinmind.vk.getRecentJobs(5) as any[];
      const failedJobs = await window.pinmind.vk.getFailedJobs() as any[];
      setVkStatus({
        available: health?.available ?? false,
        connectionMethod: health?.connection_method ?? 'unavailable',
        supportedJobTypes: health?.supported_job_types ?? [],
        version: health?.version,
        error: health?.error,
        checkedAt: health?.checked_at ?? 0,
        recentJobs: (recentJobs ?? []).map((e: any) => ({
          error_id: e.error_id,
          error_type: e.error_type,
          user_message: e.user_message,
          created_at: e.created_at,
          status: e.status,
        })),
        failedJobs: (failedJobs ?? []).map((e: any) => ({
          error_id: e.error_id,
          error_type: e.error_type,
          user_message: e.user_message,
          created_at: e.created_at,
          status: e.status,
        })),
        checking: false,
      });
    } catch {
      setVkStatus((prev) => ({ ...prev, checking: false }));
    }
  }, [settings.vault?.vaultPath]);

  useEffect(() => { void loadStatuses(); }, [loadStatuses]);

  const handleToggle = useCallback((key: keyof AppSettings, value: boolean) => {
    onUpdateSetting({ [key]: value });
  }, [onUpdateSetting]);

  return (
    <div className="flex flex-col gap-4">
      {/* ── 1. Automation Switches ── */}
      <Card variant="base" padding={16}>
        <Section title="自动化开关" compact>
          <ToggleSwitch
            label="自动收集"
            description="复制文本后自动放入收集箱"
            checked={settings.autoCapture ?? true}
            onChange={(v) => handleToggle('autoCapture', v)}
          />
          <ToggleSwitch
            label="自动整理"
            description="收集后自动整理内容"
            checked={settings.autoAiProcess ?? false}
            onChange={(v) => handleToggle('autoAiProcess', v)}
          />
          <ToggleSwitch
            label="自动入库"
            description="整理完成后自动保存到资料库"
            checked={settings.autoExportObsidian ?? false}
            onChange={(v) => handleToggle('autoExportObsidian', v)}
          />
        </Section>
      </Card>

      {/* ── 2. Vault Status ── */}
      <Card variant="base" padding={16}>
        <Section title="Vault 状态" compact>
          {vaultStatus.checking ? (
            <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>检查中...</span>
          ) : (
            <>
              <InfoRow
                label="仓库路径"
                value={vaultStatus.path ? (
                  <span className="cursor-pointer" style={{ color: 'var(--pm-brand-primary)' }} onClick={() => void navigator.clipboard.writeText(vaultStatus.path)}>
                    {vaultStatus.path}
                  </span>
                ) : '未配置'}
              />
              <InfoRow
                label="状态"
                value={
                  <span className="inline-flex items-center gap-1.5">
                    <StatusBadge tone={vaultStatus.valid ? 'success' : 'danger'} label={vaultStatus.userMessage} dot />
                  </span>
                }
                danger={!vaultStatus.valid}
              />
            </>
          )}
        </Section>
      </Card>

      {/* ── 3. Template Pack Status ── */}
      <Card variant="base" padding={16}>
        <Section title="模板包状态" compact>
          {templateStatus.checking ? (
            <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>检查中...</span>
          ) : (
            <>
              <InfoRow
                label="状态"
                value={
                  <span className="inline-flex items-center gap-1.5">
                    <StatusBadge
                      tone={templateStatus.loaded ? 'success' : 'warning'}
                      label={templateStatus.loaded ? '已加载' : '未加载（使用内置默认值）'}
                      dot
                    />
                  </span>
                }
              />
              <InfoRow label="模板包路径" value={templateStatus.specPackPath || '使用内置默认值'} />
              <InfoRow label="Profile 数量" value={`${templateStatus.profileCount} 个`} />
              <InfoRow label="模板数量" value={`${templateStatus.templateCount} 个`} />
              <InfoRow label="Schema 版本" value={templateStatus.schemaVersion || '—'} />
            </>
          )}
        </Section>
      </Card>

      {/* ── 4. Model Status ── */}
      <Card variant="base" padding={16}>
        <Section title="模型状态" compact>
          {modelStatus.checking ? (
            <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>检查中...</span>
          ) : (
            <>
              <InfoRow
                label="状态"
                value={
                  <StatusBadge
                    tone={
                      modelStatus.enabled
                        ? modelStatus.connectionStatus === 'reachable' ? 'success' : 'warning'
                        : 'neutral'
                    }
                    label={
                      modelStatus.enabled
                        ? modelStatus.connectionStatus === 'reachable'
                          ? '可用'
                          : modelStatus.connectionStatus === 'unreachable'
                            ? '不可达'
                            : '未知'
                        : '未启用'
                    }
                    dot
                  />
                }
              />
              <InfoRow label="配置模型" value={modelStatus.configuredModel || '未配置'} />
              <InfoRow label="实际模型" value={modelStatus.effectiveModel || '—'} />
              <InfoRow label="连接状态" value={modelStatus.connectionStatus || '—'} />
              <InfoRow label="模型状态" value={modelStatus.modelStatus || '—'} />
              {modelStatus.fallbackReason && (
                <InfoRow label="回退原因" value={modelStatus.fallbackReason} danger />
              )}
              {modelStatus.lastError && (
                <InfoRow label="最近错误" value={modelStatus.lastError} danger />
              )}
              {modelStatus.checkedAt && (
                <InfoRow label="检查时间" value={new Date(modelStatus.checkedAt).toLocaleString('zh-CN')} />
              )}
            </>
          )}
        </Section>
      </Card>

      {/* ── 4.5. VaultKeeper Status (Phase 9.7) ── */}
      <Card variant="base" padding={16}>
        <Section title="服务状态" compact>
          {vkStatus.checking ? (
            <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>检查中...</span>
          ) : (
            <>
              <InfoRow
                label="状态"
                value={
                  <StatusBadge
                    tone={vkStatus.available ? 'success' : 'warning'}
                    label={vkStatus.available ? '可用' : '不可用'}
                    dot
                  />
                }
              />
              <InfoRow
                label="连接方式"
                value={
                  vkStatus.connectionMethod === 'http' ? 'HTTP'
                  : vkStatus.connectionMethod === 'stdio' ? 'STDIO'
                  : '未连接'
                }
              />
              {vkStatus.version && <InfoRow label="版本" value={vkStatus.version} />}
              <InfoRow
                label="支持任务类型"
                value={
                  vkStatus.supportedJobTypes.length > 0
                    ? vkStatus.supportedJobTypes.join(', ')
                    : '无'
                }
              />
              {vkStatus.error && <InfoRow label="错误信息" value={vkStatus.error} danger />}
              {vkStatus.checkedAt > 0 && (
                <InfoRow label="检查时间" value={formatTime(vkStatus.checkedAt)} />
              )}

              {/* 失败任务 */}
              {vkStatus.failedJobs.length > 0 && (
                <div className="mt-3">
                  <div className="text-[12px] font-semibold mb-2" style={{ color: 'var(--pm-status-danger)' }}>
                    失败任务 ({vkStatus.failedJobs.length})
                  </div>
                  <div className="flex flex-col gap-1">
                    {vkStatus.failedJobs.map((job) => (
                      <div
                        key={job.error_id}
                        className="flex items-center justify-between px-2 py-1.5 rounded-lg text-[11px]"
                        style={{ background: 'color-mix(in srgb, var(--pm-status-danger) 6%, transparent)' }}
                      >
                        <span className="flex-1 mr-2" style={{ color: 'var(--pm-text-secondary)' }}>
                          {job.user_message}
                        </span>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => void window.pinmind.vk.resubmitJob(job.error_id)}
                        >
                          重试
                        </Button>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* 刷新按钮 */}
              <div className="mt-3">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setVkStatus((prev) => ({ ...prev, checking: true }));
                    void loadStatuses();
                  }}
                >
                  刷新服务状态
                </Button>
              </div>
            </>
          )}
        </Section>
      </Card>

      {/* ── 5. Recent Errors ── */}
      <Card variant="base" padding={16}>
        <Section title="最近错误" compact>
          {recentErrors.length === 0 ? (
            <span className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
              没有待处理的错误，系统运行正常。
            </span>
          ) : (
            <div className="flex flex-col gap-2">
              {recentErrors.map((err) => (
                <div
                  key={err.error_id}
                  className="px-2.5 py-2 rounded-lg text-[12px]"
                  style={{
                    background: 'color-mix(in srgb, var(--pm-status-danger) 6%, transparent)',
                    border: '1px solid color-mix(in srgb, var(--pm-status-danger) 12%, transparent)',
                  }}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-[11px] font-semibold" style={{ color: 'var(--pm-status-danger)' }}>
                      {ERROR_TYPE_LABELS[err.error_type] ?? err.error_type}
                    </span>
                    <span className="text-[10px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                      {formatTime(err.created_at)}
                    </span>
                  </div>
                  <div style={{ color: 'var(--pm-text-secondary)' }}>{err.user_message}</div>
                </div>
              ))}
              <Button
                variant="ghost"
                size="sm"
                onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'errors' } }))}
              >
                查看全部错误
              </Button>
            </div>
          )}
        </Section>
      </Card>

      {/* ── 6. Quick Links ── */}
      <Card variant="base" padding={16}>
        <Section title="快捷入口" compact>
          <div className="flex flex-col gap-2">
            <QuickLink
              label="处理历史"
              description="查看整理和入库的执行记录"
              onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'history' } }))}
            />
            <QuickLink
              label="错误回看"
              description="查看和处理自动化流程中的失败内容"
              onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'errors' } }))}
            />
            <QuickLink
              label="刷新状态"
              description="重新检查 Vault、模板包和模型状态"
              onClick={() => void loadStatuses()}
            />
          </div>
        </Section>
      </Card>

      {/* ── 7. Logs Entry (collapsed by default) ── */}
      <Card variant="base" padding={16}>
        <Section title="开发者日志" compact>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setLogsExpanded(!logsExpanded)}
          >
            {logsExpanded ? '收起日志' : '展开日志设置'}
          </Button>
          {logsExpanded && (
            <div className="mt-2 text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
              <p>日志级别可在「高级 → 错误日志」中调整。</p>
              <p className="mt-1">
                当前级别：<strong style={{ color: 'var(--pm-text-primary)' }}>{settings.logLevel ?? 'info'}</strong>
              </p>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => window.dispatchEvent(new CustomEvent('pinmind:navigate', { detail: { view: 'settings', tab: 'advanced-logs' } }))}
              >
                前往日志设置
              </Button>
            </div>
          )}
        </Section>
      </Card>
    </div>
  );
}

// ---------------------------------------------------------------------------
// QuickLink
// ---------------------------------------------------------------------------

function QuickLink({ label, description, onClick }: { label: string; description: string; onClick: () => void }): JSX.Element {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex items-center justify-between px-3 py-2.5 rounded-lg cursor-pointer text-left w-full motion-interactive"
      style={{
        border: '1px solid var(--pm-border-subtle)',
        background: 'transparent',
      }}
    >
      <div>
        <div className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>{label}</div>
        <div className="text-[11px] mt-0.5" style={{ color: 'var(--pm-text-tertiary)' }}>{description}</div>
      </div>
      <PinStackIcon name="arrow-right" size={14} style={{ color: 'var(--pm-text-tertiary)', flexShrink: 0 }} />
    </button>
  );
}
