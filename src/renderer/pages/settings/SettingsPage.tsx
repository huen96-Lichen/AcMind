import { useCallback, useEffect, useMemo, useState } from 'react';
import type {
  AppSettings,
  LogLevel,
  PermissionStatusSnapshot,
  ProviderConfig,
  TranscriptionLocalEngine,
  TranscriptionModelSize,
  TranscriptionProvider,
} from '../../../shared/types';
import type {
  DesktopMuseCapsuleSettings,
  CapsuleThemeColor,
  CapsuleStyle,
  CapsuleSize,
  CapsuleDefaultPosition,
  CapsuleClickAction,
  CapsuleDoubleClickAction,
  CapsuleHoverAction,
  CapsuleCaptureType,
  CapsuleDefaultAction,
  CapsuleDestination,
} from '../../../shared/capsuleSettings';
import { CAPSULE_THEME_COLORS, DEFAULT_CAPSULE_SETTINGS } from '../../../shared/capsuleSettings';
import { PinStackIcon } from '../../design-system/icons';
import { SettingGroupCard } from '../../design-system/primitives';
import { Button, StatusBadge } from '../../design-system/components';
import { AddProviderDialog } from './components/AddProviderDialog';
import { ProviderCard } from './components/ProviderCard';
import { EmptyState } from '../../components/shared/EmptyState';
import { useToast } from '../../components/shared/ToastViewport';

// ─── Settings Category Keys ──────────────────────────────────

type SettingsCategory =
  | 'general'
  | 'appearance'
  | 'privacy'
  | 'obsidian'
  | 'path-storage'
  | 'export-rules'
  | 'ai-models'
  | 'ai-default-tier'
  | 'capture-capsule'
  | 'advanced-logs'
  | 'advanced-data'
  | 'advanced-dev';

// ─── Group & Category Definitions ────────────────────────────

interface SettingsCategoryDef {
  key: SettingsCategory;
  title: string;
  icon: import('../../design-system/icons').PinStackIconName;
  disabled?: boolean;
  disabledLabel?: string;
}

interface SettingsGroupDef {
  key: string;
  title: string;
  categories: SettingsCategoryDef[];
  collapsed?: boolean;
}

interface WhisperModelRow {
  size: 'tiny' | 'base' | 'small';
  displayName: string;
  fileSize: string;
  description: string;
  cached: boolean;
}

interface WhisperRuntimeStatus {
  status: 'ready' | 'error';
  engine: string | null;
  message: string;
}

const SETTINGS_GROUPS: SettingsGroupDef[] = [
  {
    key: 'basics',
    title: '基础',
    categories: [
      { key: 'general', title: '通用', icon: 'all' },
      { key: 'appearance', title: '外观', icon: 'text' },
    ],
  },
  {
    key: 'capture',
    title: '收集',
    categories: [
      { key: 'capture-capsule', title: '收集入口', icon: 'duplicate' },
    ],
  },
  {
    key: 'knowledge',
    title: '资料库',
    categories: [
      { key: 'obsidian', title: 'Obsidian', icon: 'edit' },
      { key: 'path-storage', title: '路径与存储', icon: 'duplicate' },
      { key: 'export-rules', title: '入库规则', icon: 'text', disabled: true, disabledLabel: '主要配置在 Obsidian 页面完成' },
    ],
  },
  {
    key: 'ai',
    title: 'AI',
    categories: [
      { key: 'ai-models', title: '模型管理', icon: 'ai-workspace' },
      { key: 'ai-default-tier', title: '默认层级与回退策略', icon: 'settings' },
    ],
  },
  {
    key: 'privacy',
    title: '隐私',
    categories: [
      { key: 'privacy', title: '权限与本地优先', icon: 'help' },
    ],
  },
  {
    key: 'advanced',
    title: '高级',
    collapsed: true,
    categories: [
      { key: 'advanced-logs', title: '日志', icon: 'sb-settings' },
      { key: 'advanced-data', title: '数据维护', icon: 'duplicate', disabled: true, disabledLabel: '开发中' },
      { key: 'advanced-dev', title: '开发者选项', icon: 'settings', disabled: true, disabledLabel: '开发中' },
    ],
  },
];

// Flat list for lookup
const ALL_CATEGORIES = SETTINGS_GROUPS.flatMap((g) => g.categories);

// ─── Main SettingsPage Component ─────────────────────────────

export function SettingsPage(): JSX.Element {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [settingsError, setSettingsError] = useState<string | null>(null);
  const [permissions, setPermissions] = useState<PermissionStatusSnapshot | null>(null);
  const [providers, setProviders] = useState<ProviderConfig[]>([]);
  const [providersLoading, setProvidersLoading] = useState(false);
  const [whisperModels, setWhisperModels] = useState<WhisperModelRow[]>([]);
  const [whisperRuntime, setWhisperRuntime] = useState<WhisperRuntimeStatus | null>(null);
  const [providerDialogProvider, setProviderDialogProvider] = useState<ProviderConfig | null>(null);
  const [showProviderDialog, setShowProviderDialog] = useState(false);
  const [saving, setSaving] = useState(false);
  const [activeCategory, setActiveCategory] = useState<SettingsCategory>(() => {
    const tabParam = new URLSearchParams(window.location.search).get('tab');
    if (tabParam && ALL_CATEGORIES.some((c) => c.key === tabParam)) {
      return tabParam as SettingsCategory;
    }
    return 'general';
  });
  const [defaultStrategy, setDefaultStrategy] = useState<AppSettings['defaultTier']>('local_light');
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(() => {
    return new Set(SETTINGS_GROUPS.filter((g) => g.collapsed).map((g) => g.key));
  });
  const { addToast } = useToast();

  // Sync tab param from URL whenever it changes (e.g. navigating from TopBar while already on Settings)
  useEffect(() => {
    const readTab = (): SettingsCategory => {
      const tabParam = new URLSearchParams(window.location.search).get('tab');
      if (tabParam && ALL_CATEGORIES.some((c) => c.key === tabParam)) {
        return tabParam as SettingsCategory;
      }
      return 'general';
    };

    // Apply immediately on mount / re-run
    setActiveCategory(readTab());

    // Listen for popstate (back/forward)
    const onPopState = () => setActiveCategory(readTab());
    window.addEventListener('popstate', onPopState);

    // Poll for search param changes (history.pushState does not fire popstate)
    let lastSearch = window.location.search;
    const interval = setInterval(() => {
      const currentSearch = window.location.search;
      if (currentSearch !== lastSearch) {
        lastSearch = currentSearch;
        setActiveCategory(readTab());
      }
    }, 200);

    return () => {
      window.removeEventListener('popstate', onPopState);
      clearInterval(interval);
    };
  }, []);

  useEffect(() => {
    async function load(): Promise<void> {
      try {
        const [nextSettings, nextPermissions] = await Promise.all([
          window.pinmind.settings.get(),
          window.pinmind.permissions.getStatus('settings-return'),
        ]);
        setSettings(nextSettings);
        setPermissions(nextPermissions);
        setDefaultStrategy(nextSettings.defaultTier);
        setProviders(nextSettings.providers ?? []);
      } catch (err) {
        setSettingsError(err instanceof Error ? err.message : '加载设置失败');
        addToast('加载设置失败', 'error');
      }
    }

    void load();
  }, [addToast]);

  useEffect(() => {
    async function loadProviders(): Promise<void> {
      if (!window.pinmind) return;
      setProvidersLoading(true);
      try {
        const nextProviders = await window.pinmind.providers.list();
        setProviders(nextProviders);
      } catch {
        addToast('加载模型来源失败', 'error');
      } finally {
        setProvidersLoading(false);
      }
    }

    void loadProviders();
  }, [addToast]);

  useEffect(() => {
    async function loadWhisperModels(): Promise<void> {
      if (!settings || activeCategory !== 'ai-models' || settings.transcription.provider !== 'local') {
        return;
      }

      try {
        const [models, status] = await Promise.all([
          window.pinmind.whisper.getModels(),
          window.pinmind.whisper.getStatus(),
        ]);
        setWhisperModels(models as WhisperModelRow[]);
        setWhisperRuntime(status as WhisperRuntimeStatus);
      } catch {
        addToast('加载本地模型缓存状态失败', 'error');
      }
    }

    void loadWhisperModels();
  }, [settings, activeCategory, addToast]);

  const updateSetting = useCallback(
    async (patch: Partial<AppSettings>) => {
      if (!settings) return;

      setSaving(true);
      try {
        const updated = await window.pinmind.settings.update(patch);
        setSettings(updated);
        setSavedAt(Date.now());
        addToast('设置已自动保存', 'success');
        return updated;
      } catch {
        addToast('保存失败', 'error');
        return null;
      } finally {
        setSaving(false);
      }
    },
    [settings, addToast],
  );

  const updateTranscription = useCallback(
    async (patch: Partial<AppSettings['transcription']>) => {
      if (!settings) return;
      await updateSetting({
        transcription: {
          ...settings.transcription,
          ...patch,
        },
      });
    },
    [settings, updateSetting],
  );

  const handleLogLevelChange = useCallback(
    async (nextLevel: LogLevel) => {
      try {
        await window.pinmind.logger.setLevel(nextLevel);
      } catch {
        addToast('运行时日志级别切换失败', 'error');
        return;
      }
      await updateSetting({ logLevel: nextLevel });
    },
    [updateSetting, addToast],
  );

  const handleSaveAll = useCallback(async () => {
    if (!settings) return;
    setSaving(true);
    try {
      await window.pinmind.settings.update({
        ...settings,
        defaultTier: defaultStrategy as AppSettings['defaultTier'],
      });
      setSavedAt(Date.now());
      addToast('设置已自动保存', 'success');
    } catch {
      addToast('保存失败', 'error');
    } finally {
      setSaving(false);
    }
  }, [settings, defaultStrategy, addToast]);

  const toggleAiModel = useCallback((id: string) => {
    void (async () => {
      const provider = providers.find((item) => item.id === id);
      if (!provider) return;
      try {
        const nextProviders = await window.pinmind.providers.update(id, { enabled: !provider.enabled });
        const refreshedProviders = await window.pinmind.providers.list();
        setProviders(refreshedProviders);
        const updated = await updateSetting({ providers: refreshedProviders });
        if (updated) {
          setSettings(updated);
        }
        addToast(nextProviders.enabled ? '模型来源已启用' : '模型来源已停用', 'success');
      } catch {
        addToast('切换模型来源失败', 'error');
      }
    })();
  }, [providers, updateSetting, addToast]);

  const handleAddProvider = useCallback(() => {
    setProviderDialogProvider(null);
    setShowProviderDialog(true);
  }, []);

  const handleEditProvider = useCallback((provider: ProviderConfig) => {
    setProviderDialogProvider(provider);
    setShowProviderDialog(true);
  }, []);

  const handleDeleteProvider = useCallback(
    async (providerId: string) => {
      const provider = providers.find((item) => item.id === providerId);
      if (!provider) return;
      const confirmed = window.confirm(`确定要删除模型来源「${provider.name}」吗？`);
      if (!confirmed) return;

      try {
        await window.pinmind.providers.delete(providerId);
        const refreshedProviders = await window.pinmind.providers.list();
        setProviders(refreshedProviders);
        const updated = await updateSetting({ providers: refreshedProviders });
        if (updated) {
          setSettings(updated);
        }
        addToast('模型来源已删除', 'success');
      } catch {
        addToast('删除模型来源失败', 'error');
      }
    },
    [providers, updateSetting, addToast],
  );

  const handleTestProvider = useCallback(
    async (providerId: string) => {
      try {
        const result = await window.pinmind.providers.testConnection(providerId);
        addToast(
          result.ok
            ? `连接成功，延迟 ${result.latencyMs} ms`
            : `连接失败：${result.error ?? '未知错误'}`,
          result.ok ? 'success' : 'error',
        );
      } catch (error) {
        addToast(error instanceof Error ? error.message : '测试连接失败', 'error');
      }
    },
    [addToast],
  );

  const refreshWhisperModels = useCallback(async () => {
    try {
      const [models, status] = await Promise.all([
        window.pinmind.whisper.getModels(),
        window.pinmind.whisper.getStatus(),
      ]);
      setWhisperModels(models as WhisperModelRow[]);
      setWhisperRuntime(status as WhisperRuntimeStatus);
    } catch {
      addToast('刷新本地模型缓存失败', 'error');
    }
  }, [addToast]);

  const handleDownloadWhisperModel = useCallback(
    async (modelSize: WhisperModelRow['size']) => {
      try {
        await window.pinmind.whisper.downloadModel(modelSize);
        await refreshWhisperModels();
        addToast(`已下载 ${modelSize} 模型到本地`, 'success');
      } catch (error) {
        addToast(error instanceof Error ? error.message : '下载本地模型失败', 'error');
      }
    },
    [refreshWhisperModels, addToast],
  );

  const handleDeleteWhisperModel = useCallback(
    async (modelSize: WhisperModelRow['size']) => {
      try {
        await window.pinmind.whisper.deleteModel(modelSize);
        await refreshWhisperModels();
        addToast(`已删除 ${modelSize} 模型缓存`, 'success');
      } catch (error) {
        addToast(error instanceof Error ? error.message : '删除本地模型失败', 'error');
      }
    },
    [refreshWhisperModels, addToast],
  );

  const handleSaveProvider = useCallback(
    async (provider: ProviderConfig) => {
      try {
        const exists = providers.some((item) => item.id === provider.id);
        if (exists) {
          await window.pinmind.providers.update(provider.id, provider);
        } else {
          await window.pinmind.providers.add(provider);
        }
        const refreshedProviders = await window.pinmind.providers.list();
        setProviders(refreshedProviders);
        const updated = await updateSetting({ providers: refreshedProviders });
        if (updated) {
          setSettings(updated);
        }
        setProviderDialogProvider(null);
        setShowProviderDialog(false);
        addToast(exists ? '模型来源已更新' : '模型来源已新增', 'success');
      } catch (error) {
        addToast(error instanceof Error ? error.message : '保存模型来源失败', 'error');
        throw error;
      }
    },
    [providers, updateSetting, addToast],
  );

  const permissionItems = useMemo(() => permissions?.items ?? [], [permissions]);

  if (!settings) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-4">
        {settingsError ? (
          <>
            <span className="text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
              加载设置失败
            </span>
            <span className="text-[11px] max-w-[400px] text-center" style={{ color: 'var(--pm-text-tertiary)' }}>
              {settingsError}
            </span>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => window.location.reload()}
            >
              重新加载
            </Button>
          </>
        ) : (
          <span className="text-[13px] text-[color:var(--pm-text-tertiary)]">加载中...</span>
        )}
      </div>
    );
  }

  return (
    <div className="pinmind-settings-layout">
      {/* ─── Left: Category List ─────────────────────────── */}
      <aside className="pinmind-settings-sidebar">
        <div className="px-4 pt-5 pb-3">
          <h2 className="pinmind-page-title">
            设置
          </h2>
          <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
            调整 PinMind 的工作方式
          </p>
          <div className="pinmind-save-indicator is-visible" style={savedAt ? { opacity: 1 } : { opacity: 0 }}>
            <PinStackIcon name="check" size={12} />
            <span>已保存</span>
          </div>
        </div>

        <nav className="pinmind-settings-nav">
            {SETTINGS_GROUPS.map((group) => {
              const isCollapsed = collapsedGroups.has(group.key);
              return (
              <div key={group.key} className="flex flex-col gap-0.5">
                <button
                  type="button"
                  className="px-3 pt-3 pb-1 text-[11px] font-semibold uppercase tracking-wider flex items-center gap-1 cursor-pointer"
                  style={{ color: 'var(--pm-text-tertiary)', background: 'none', border: 'none' }}
                  onClick={() =>
                    setCollapsedGroups((prev) => {
                      const next = new Set(prev);
                      if (next.has(group.key)) {
                        next.delete(group.key);
                      } else {
                        next.add(group.key);
                      }
                      return next;
                    })
                  }
                >
                  <PinStackIcon
                    name="arrow-right"
                    size={10}
                    className={`transition-transform ${isCollapsed ? '' : 'rotate-90'}`}
                  />
                  {group.title}
                </button>
                {!isCollapsed && group.categories.map((cat) => {
                  const active = activeCategory === cat.key;
                  const isDisabled = cat.disabled;
                  return (
                    <button
                      key={cat.key}
                      type="button"
                      disabled={isDisabled}
                      onClick={() => !isDisabled && setActiveCategory(cat.key)}
                      className={`settings-nav-item motion-button ${active ? 'is-active' : ''} ${isDisabled ? 'is-disabled' : ''}`}
                      title={isDisabled ? cat.disabledLabel : undefined}
                    >
                      <span className="flex min-w-0 items-center" style={{ gridTemplateColumns: '24px 1fr', columnGap: 12, display: 'grid' }}>
                        <span className={`settings-nav-icon ${active ? 'is-active' : ''} ${isDisabled ? 'opacity-40' : ''}`}>
                          <PinStackIcon name={cat.icon} size={14} />
                        </span>
                        <span className="truncate text-[14px]">{cat.title}</span>
                      </span>
                      {isDisabled && (
                        <span className="ml-auto text-[10px] opacity-50" style={{ color: 'var(--pm-text-tertiary)' }}>
                          即将推出
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>
              );
            })}
          </nav>
        </aside>

        {/* ─── Right: Detail Panel ─────────────────────────── */}
        <main className="pinmind-settings-content">
          <div className="pinmind-settings-content-inner">
            {/* ── General ─────────────────────────────────── */}
            {activeCategory === 'general' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">通用</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    启动偏好与捕获行为。
                  </p>
                </div>

                {/* 启动与后台 */}
                <SettingGroupCard title="启动" description="应用启动方式。" icon="all">
                  <SettingsRow label="开机启动" description="登录后自动启动 PinMind。">
                    <ToggleSwitch
                      checked={settings.launchAtLogin}
                      onChange={(checked) => void updateSetting({ launchAtLogin: checked })}
                    />
                  </SettingsRow>
                  <SettingsRow label="最小化到菜单栏" description="启动时不显示主窗口。">
                    <ToggleSwitch
                      checked={settings.minimizeToTray}
                      onChange={(checked) => void updateSetting({ minimizeToTray: checked })}
                    />
                  </SettingsRow>
                </SettingGroupCard>

                {/* 捕获行为 */}
                <SettingGroupCard title="收集" description="内容收集的触发与处理方式。" icon="duplicate">
                  <SettingsRow label="后台监听剪贴板" description="应用在后台时持续监听剪贴板。">
                    <ToggleSwitch
                      checked={settings.backgroundClipboard}
                      onChange={(checked) => void updateSetting({ backgroundClipboard: checked })}
                    />
                  </SettingsRow>
                  <SettingsRow label="自动收集" description="复制文本后自动放入收集箱。">
                    <ToggleSwitch
                      checked={settings.autoCapture}
                      onChange={(checked) => void updateSetting({ autoCapture: checked })}
                    />
                  </SettingsRow>
                  <SettingsRow label="收集后提示" description="成功收集时弹出 Toast。">
                    <ToggleSwitch
                      checked={settings.showCaptureToast}
                      onChange={(checked) => void updateSetting({ showCaptureToast: checked })}
                    />
                  </SettingsRow>
                  <SettingsRow label="自动 AI 处理" description="收集后自动整理。">
                    <ToggleSwitch
                      checked={settings.autoAiProcess}
                      onChange={(checked) => void updateSetting({ autoAiProcess: checked })}
                    />
                  </SettingsRow>
                  <SettingsRow label="自动保存到资料库" description="整理完成后自动保存。">
                    <ToggleSwitch
                      checked={settings.autoExportObsidian}
                      onChange={(checked) => void updateSetting({ autoExportObsidian: checked })}
                    />
                  </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── AI Models ───────────────────────────────── */}
            {activeCategory === 'ai-models' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7 flex items-start justify-between gap-4">
                  <div>
                    <h3 className="pinmind-page-title">
                      AI 模型
                    </h3>
                    <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                      管理 AI 模型来源，启停状态实时同步。
                    </p>
                  </div>
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={handleAddProvider}
                    style={{
                      backgroundColor: 'var(--pm-brand-primary)',
                      color: '#fff',
                    }}
                  >
                    新增模型来源
                  </Button>
                </div>

                <SettingGroupCard
                  title="语音转写"
                  description="本地引擎或外部 API，共用胶囊录音面板。"
                  icon="settings"
                >
                  <SettingsRow label="转写方式" description="选择本地引擎或外部转写服务。">
                    <select
                      value={settings.transcription.provider}
                      onChange={(e) =>
                        void updateTranscription({
                          provider: e.target.value as TranscriptionProvider,
                        })
                      }
                      className="pm-ds-input min-w-[200px]"
                    >
                      <option value="local">本地引擎</option>
                      <option value="api">外部 API</option>
                    </select>
                  </SettingsRow>

                  {settings.transcription.provider === 'local' ? (
                    <>
                      <SettingsRow label="本地引擎" description="按优先级自动尝试可用的本地语音引擎。">
                        <select
                          value={settings.transcription.localEngine}
                          onChange={(e) =>
                            void updateTranscription({
                              localEngine: e.target.value as TranscriptionLocalEngine,
                            })
                          }
                          className="pm-ds-input min-w-[220px]"
                        >
                          <option value="whisper-ctranslate2">whisper-ctranslate2</option>
                          <option value="whisper">whisper</option>
                        </select>
                      </SettingsRow>
                      <SettingsRow label="本地模型" description="用于本地引擎的默认模型大小。">
                        <select
                          value={settings.transcription.localModel}
                          onChange={(e) =>
                            void updateTranscription({
                              localModel: e.target.value as TranscriptionModelSize,
                            })
                          }
                          className="pm-ds-input min-w-[200px]"
                        >
                          <option value="tiny">tiny - 最轻量</option>
                          <option value="base">base - 推荐</option>
                          <option value="small">small - 更高精度</option>
                        </select>
                      </SettingsRow>
                      <div className="flex items-start gap-2 rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.015)] px-3 py-2.5">
                        <PinStackIcon name="help" size={14} className="mt-0.5 shrink-0" style={{ color: 'var(--pm-text-tertiary)' }} />
                        <p className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                          本地转写会优先调用内置模型缓存，缺失时自动下载到本地目录。
                        </p>
                      </div>
                      <div className="flex flex-col gap-3 rounded-[16px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.015)] p-4">
                        <div className="flex items-center justify-between gap-3">
                          <div>
                            <div className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                              本地模型缓存
                            </div>
                            <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                              {whisperRuntime?.message ?? '模型会缓存到应用数据目录。'}
                            </div>
                          </div>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => void refreshWhisperModels()}
                          >
                            刷新
                          </Button>
                        </div>
                        <div className="flex flex-col gap-2">
                          {whisperModels.map((model) => (
                            <div
                              key={model.size}
                              className="flex flex-col gap-3 rounded-[14px] border border-[color:var(--pm-border-subtle)] bg-white px-3 py-3 shadow-[0_1px_2px_rgba(15,23,42,0.04)] sm:flex-row sm:items-center sm:justify-between"
                            >
                              <div className="min-w-0">
                                <div className="flex items-center gap-2">
                                  <div className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                                    {model.displayName}
                                  </div>
                                  <StatusBadge
                                    tone={model.cached ? 'success' : 'neutral'}
                                    label={model.cached ? '已缓存' : '未缓存'}
                                    dot={false}
                                  />
                                </div>
                                <div className="mt-1 text-[11px] text-[color:var(--pm-text-tertiary)]">
                                  {model.fileSize} · {model.description}
                                </div>
                              </div>
                              <div className="flex items-center gap-2">
                                <Button
                                  variant="secondary"
                                  size="sm"
                                  onClick={() => void handleDownloadWhisperModel(model.size)}
                                >
                                  {model.cached ? '重新下载' : '下载到本地'}
                                </Button>
                                {model.cached && (
                                  <Button
                                    variant="ghost"
                                    size="sm"
                                    onClick={() => void handleDeleteWhisperModel(model.size)}
                                  >
                                    删除缓存
                                  </Button>
                                )}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    </>
                  ) : (
                    <>
                      <SettingsRow label="API 地址" description="可填基础地址或完整转写接口。">
                        <input
                          value={settings.transcription.apiEndpoint}
                          onChange={(e) => void updateTranscription({ apiEndpoint: e.target.value })}
                          className="pm-ds-input min-w-[360px]"
                          placeholder="https://api.example.com/v1/audio/transcriptions"
                        />
                      </SettingsRow>
                      <SettingsRow label="API 模型" description="与服务端约定的模型 ID。">
                        <input
                          value={settings.transcription.apiModel}
                          onChange={(e) => void updateTranscription({ apiModel: e.target.value })}
                          className="pm-ds-input min-w-[220px]"
                          placeholder="whisper-1"
                        />
                      </SettingsRow>
                      <SettingsRow label="API Key" description="留空时不会发送鉴权头。">
                        <input
                          value={settings.transcription.apiKey ?? ''}
                          onChange={(e) => void updateTranscription({ apiKey: e.target.value })}
                          className="pm-ds-input min-w-[260px]"
                          type="password"
                          placeholder="sk-..."
                        />
                      </SettingsRow>
                      <SettingsRow label="默认语言" description="转写请求默认使用的语言。">
                        <input
                          value={settings.transcription.apiLanguage}
                          onChange={(e) => void updateTranscription({ apiLanguage: e.target.value })}
                          className="pm-ds-input w-28"
                          placeholder="zh"
                        />
                      </SettingsRow>
                      <SettingsRow label="翻译模式" description="将语音直接翻译为英文。">
                        <ToggleSwitch
                          checked={settings.transcription.apiTranslate}
                          onChange={(checked) => void updateTranscription({ apiTranslate: checked })}
                        />
                      </SettingsRow>
                      <SettingsRow label="超时" description="转写请求超时（毫秒）。">
                        <input
                          type="number"
                          min={5000}
                          step={1000}
                          value={settings.transcription.apiTimeoutMs}
                          onChange={(e) =>
                            void updateTranscription({ apiTimeoutMs: Number(e.target.value) || 30000 })
                          }
                          className="pm-ds-input w-32"
                        />
                      </SettingsRow>
                    </>
                  )}
                </SettingGroupCard>

                <SettingGroupCard title="模型来源" description="与 AI Console 共享同一份配置。" icon="ai-workspace">
                  {providersLoading ? (
                    <div className="py-8 text-center text-[13px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                      正在加载模型来源...
                    </div>
                  ) : providers.length === 0 ? (
                    <div className="flex flex-col items-center gap-3 py-8">
                      <p className="text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                        还没有模型来源
                      </p>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={handleAddProvider}
                      >
                        添加第一个来源
                      </Button>
                    </div>
                  ) : (
                    <div className="flex flex-col gap-3">
                      {providers.map((provider) => (
                        <ProviderCard
                          key={provider.id}
                          provider={provider}
                          onToggleEnabled={toggleAiModel}
                          onEdit={handleEditProvider}
                          onDelete={handleDeleteProvider}
                          onTest={handleTestProvider}
                        />
                      ))}
                    </div>
                  )}
                </SettingGroupCard>

                {/* Save Feedback */}
                {savedAt && (
                  <div className="flex items-center gap-2 rounded-[8px] border border-[color:var(--pm-status-success)] bg-[rgba(22,163,74,0.06)] px-3 py-2.5">
                    <PinStackIcon name="check" size={14} />
                    <div>
                      <p className="text-[12px] font-medium text-[color:var(--pm-status-success)]">
                        设置已自动保存
                      </p>
                      <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                        所有更改已成功保存到本地
                      </p>
                    </div>
                  </div>
                )}

                {/* Save Button */}
                <div className="flex items-center justify-end gap-3 pt-2">
                  {saving && (
                    <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                      保存中...
                    </span>
                  )}
                  <Button
                    variant="primary"
                    size="md"
                    onClick={() => void handleSaveAll()}
                    disabled={saving}
                    style={{
                      backgroundColor: 'var(--pm-brand-primary)',
                      color: '#fff',
                    }}
                  >
                    保存设置
                  </Button>
                </div>
              </div>
            )}

            {/* ── AI Default Tier ─────────────────────────── */}
            {activeCategory === 'ai-default-tier' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">默认层级与回退策略</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    新任务的默认模型强度。Provider 管理请前往「模型管理」。
                  </p>
                </div>
                <SettingGroupCard title="默认模型层级" description="新任务默认使用的模型强度。" icon="settings">
                  <SettingsRow label="默认处理策略" description="新任务默认使用的模型强度。">
                    <select
                      value={defaultStrategy}
                      onChange={(e) => setDefaultStrategy(e.target.value as AppSettings['defaultTier'])}
                      className="pm-ds-input min-w-[220px]"
                    >
                      <option value="local_light">本地轻量，隐私优先</option>
                      <option value="cloud_standard">云端标准，效果均衡</option>
                      <option value="cloud_strong">云端强力，复杂内容优先</option>
                    </select>
                  </SettingsRow>
                  <div className="flex items-start gap-2 rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.015)] px-3 py-2.5">
                    <PinStackIcon name="help" size={14} className="mt-0.5 shrink-0" style={{ color: 'var(--pm-text-tertiary)' }} />
                    <p className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                      模型不可用时自动尝试可用层级。
                    </p>
                  </div>
                </SettingGroupCard>

                {/* Save Feedback */}
                {savedAt && (
                  <div className="flex items-center gap-2 rounded-[8px] border border-[color:var(--pm-status-success)] bg-[rgba(22,163,74,0.06)] px-3 py-2.5">
                    <PinStackIcon name="check" size={14} />
                    <div>
                      <p className="text-[12px] font-medium text-[color:var(--pm-status-success)]">
                        设置已自动保存
                      </p>
                      <p className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                        所有更改已成功保存到本地
                      </p>
                    </div>
                  </div>
                )}

                {/* Save Button */}
                <div className="flex items-center justify-end gap-3 pt-2">
                  {saving && (
                    <span className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                      保存中...
                    </span>
                  )}
                  <Button
                    variant="primary"
                    size="md"
                    onClick={() => void handleSaveAll()}
                    disabled={saving}
                    style={{
                      backgroundColor: 'var(--pm-brand-primary)',
                      color: '#fff',
                    }}
                  >
                    保存设置
                  </Button>
                </div>
              </div>
            )}

            {/* ── Path & Storage ──────────────────────────── */}
            {activeCategory === 'path-storage' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">路径与存储</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    本地数据目录与扫描行为配置。
                  </p>
                </div>

                {/* 本地数据目录 */}
                <SettingGroupCard title="本地数据目录" description="PinMind 所有数据的存储位置。" icon="duplicate">
                  <div className="settings-row">
                    <div className="settings-row-copy">
                      <div className="settings-row-title">当前路径</div>
                      <code className="block max-w-[360px] truncate rounded-[8px] bg-[rgba(0,0,0,0.04)] px-2.5 py-1.5 text-[12px] text-[color:var(--pm-text-secondary)]" title={settings.storageRoot}>
                        {settings.storageRoot}
                      </code>
                    </div>
                    <div className="settings-row-control">
                      <div className="flex items-center gap-2">
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() => window.pinmind.app.openStorageRoot()}
                        >
                          打开
                        </Button>
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={async () => {
                            const folder = await window.pinmind.vault.pickFolder();
                            if (folder) {
                              await updateSetting({ storageRoot: folder });
                            }
                          }}
                        >
                          更改路径
                        </Button>
                      </div>
                    </div>
                  </div>
                </SettingGroupCard>

                {/* 扫描行为 */}
                <SettingGroupCard title="扫描行为" description="剪贴板监听的频率与范围。" icon="all">
                  <SettingsRow label="轮询间隔" description="剪贴板检查频率（毫秒）。">
                    <input
                      type="number"
                      min={100}
                      max={5000}
                      step={100}
                      value={settings.pollIntervalMs}
                      onChange={(e) => void updateSetting({ pollIntervalMs: Number(e.target.value) })}
                      className="pm-ds-input w-28"
                    />
                  </SettingsRow>
                  <SettingsRow label="扫描范围" description="全部应用或仅指定应用。">
                    <select
                      value={settings.scopeMode}
                      onChange={(e) =>
                        void updateSetting({ scopeMode: e.target.value as AppSettings['scopeMode'] })
                      }
                      className="pm-ds-input min-w-[180px]"
                    >
                      <option value="all">全部应用</option>
                      <option value="scoped">指定应用</option>
                    </select>
                  </SettingsRow>
                  <SettingsRow label="指定应用" description={'扫描范围为"指定应用"时生效。'}>
                    <input
                      value={settings.scopedApps.join(', ')}
                      onChange={(e) =>
                        void updateSetting({
                          scopedApps: e.target.value
                            .split(',')
                            .map((v) => v.trim())
                            .filter(Boolean),
                        })
                      }
                      className="pm-ds-input min-w-[260px]"
                      placeholder="应用一, 应用二"
                    />
                  </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Obsidian ────────────────────────────────── */}
            {activeCategory === 'obsidian' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">Obsidian</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    整理后内容保存到哪个资料库。
                  </p>
                </div>

                {/* Vault 路径 */}
                <SettingGroupCard title="Vault 路径" description="选择并校验 Obsidian 资料库目录。" icon="edit">
                  <div className="settings-row">
                    <div className="settings-row-copy">
                      <div className="settings-row-title">资料库路径</div>
                      <input
                        value={settings.vault.vaultPath}
                        onChange={(e) =>
                          void updateSetting({ vault: { ...settings.vault, vaultPath: e.target.value } })
                        }
                        className="pm-ds-input min-w-[280px] mt-1.5"
                        placeholder="选择或输入资料库目录"
                      />
                    </div>
                    <div className="settings-row-control">
                      <div className="flex items-center gap-2">
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={async () => {
                            const folder = await window.pinmind.vault.pickFolder();
                            if (folder) {
                              await updateSetting({ vault: { ...settings.vault, vaultPath: folder } });
                            }
                          }}
                        >
                          选择
                        </Button>
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={async () => {
                            const result = await window.pinmind.vault.validatePath(settings.vault.vaultPath);
                            addToast(result.message, result.valid ? 'success' : 'warning');
                          }}
                        >
                          校验
                        </Button>
                      </div>
                    </div>
                  </div>
                </SettingGroupCard>

                {/* 写入位置 */}
                <SettingGroupCard title="写入位置" description="笔记在资料库中的存放位置。" icon="duplicate">
                  <SettingsRow label="默认文件夹" description="写入资料库时的默认目录。">
                    <input
                      value={settings.vault.defaultFolder}
                      onChange={(e) =>
                        void updateSetting({ vault: { ...settings.vault, defaultFolder: e.target.value } })
                      }
                      className="pm-ds-input min-w-[220px]"
                    />
                  </SettingsRow>
                </SettingGroupCard>

                {/* 文件规则 */}
                <SettingGroupCard title="文件规则" description="文件命名、冲突与元数据策略。" icon="text">
                  <SettingsRow label="路径规则" description="Markdown 文件的落盘路径。">
                    <select
                      value={settings.vault.pathRule}
                      onChange={(e) =>
                        void updateSetting({
                          vault: { ...settings.vault, pathRule: e.target.value as AppSettings['vault']['pathRule'] },
                        })
                      }
                      className="pm-ds-input min-w-[220px]"
                    >
                      <option value="category_date">按分类和日期</option>
                      <option value="category_title">按分类和标题</option>
                      <option value="flat">全部放在默认文件夹</option>
                    </select>
                  </SettingsRow>
                  <SettingsRow label="冲突策略" description="文件名冲突时的处理方式。">
                    <select
                      value={settings.vault.conflictStrategy}
                      onChange={(e) =>
                        void updateSetting({
                          vault: {
                            ...settings.vault,
                            conflictStrategy: e.target.value as AppSettings['vault']['conflictStrategy'],
                          },
                        })
                      }
                      className="pm-ds-input min-w-[220px]"
                    >
                      <option value="rename">自动改名保留两份</option>
                      <option value="skip">跳过已有文件</option>
                      <option value="overwrite">覆盖已有文件</option>
                    </select>
                  </SettingsRow>
                  <SettingsRow label="自动 frontmatter" description="保存时自动生成 YAML frontmatter。">
                    <ToggleSwitch
                      checked={settings.vault.autoFrontmatter}
                      onChange={(checked) =>
                        void updateSetting({ vault: { ...settings.vault, autoFrontmatter: checked } })
                      }
                    />
                  </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Export Rules (disabled) ──────────────────── */}
            {activeCategory === 'export-rules' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">入库规则</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    只读预览 · 主要配置在「Obsidian」中完成
                  </p>
                </div>
                <SettingGroupCard title="入库规则" description="只读预览" icon="text">
                  <div className="flex flex-col gap-3">
                    <SettingsRow label="自动保存到资料库" description={`当前状态：${settings.autoExportObsidian ? '已开启' : '已关闭'}`}>
                      <StatusBadge tone="neutral" label={settings.autoExportObsidian ? '已开启' : '已关闭'} dot={false} style={{ opacity: 0.6 }} />
                    </SettingsRow>
                    <SettingsRow label="路径规则" description={settings.vault.pathRule}>
                      <StatusBadge tone="neutral" label={settings.vault.pathRule} dot={false} style={{ opacity: 0.6 }} />
                    </SettingsRow>
                    <SettingsRow label="冲突策略" description={settings.vault.conflictStrategy}>
                      <StatusBadge tone="neutral" label={settings.vault.conflictStrategy} dot={false} style={{ opacity: 0.6 }} />
                    </SettingsRow>
                    <SettingsRow label="自动 frontmatter" description={settings.vault.autoFrontmatter ? '已开启' : '已关闭'}>
                      <StatusBadge tone="neutral" label={settings.vault.autoFrontmatter ? '已开启' : '已关闭'} dot={false} style={{ opacity: 0.6 }} />
                    </SettingsRow>
                  </div>
                  <div className="flex items-start gap-2 rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.015)] px-3 py-2.5 mt-3">
                    <PinStackIcon name="help" size={14} className="mt-0.5 shrink-0" style={{ color: 'var(--pm-text-tertiary)' }} />
                    <p className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                      如需修改，请前往「资料库 → Obsidian」。
                    </p>
                  </div>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Capsule (捕获入口) ───────────────────────── */}
            {activeCategory === 'capture-capsule' && <CapsuleSettingsPanel settings={settings} onUpdateSetting={updateSetting} />}

            {/* ── Appearance ──────────────────────────────── */}
            {activeCategory === 'appearance' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">外观</h3>
                  <p className="mt-1 text-[13px] leading-5 text-[color:var(--pm-text-secondary)]">
                    主题与外观偏好。
                  </p>
                </div>
                <SettingGroupCard title="外观" description="主题与外观偏好。" icon="text">
                  <SettingsRow label="主题模式" description="暂未开放切换。">
                    <StatusBadge tone="neutral" label="暂未开放 · 跟随系统" dot={false} style={{ opacity: 0.6 }} />
                  </SettingsRow>

                  <SettingsRow
                    label="桌面灵感胶囊"
                    description="屏幕边缘的快捷捕获入口。详细配置在「捕获入口」。"
                  >
                    <ToggleSwitch
                      checked={settings.showFloatingButton}
                    onChange={(checked) => void updateSetting({ showFloatingButton: checked })}
                  />
                </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Privacy ─────────────────────────────────── */}
            {activeCategory === 'privacy' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">隐私与本地优先</h3>
                  <p className="mt-1 text-[13px] leading-5 text-[color:var(--pm-text-secondary)]">
                    macOS 权限状态。
                  </p>
                </div>
                <SettingGroupCard title="隐私与本地优先" description="macOS 权限状态。" icon="help">
                  {permissionItems.length === 0 ? (
                    <EmptyState
                      icon={'\u{1F512}'}
                      title="暂无权限信息"
                      description="刷新后会显示屏幕录制、辅助功能和磁盘访问状态。"
                    />
                  ) : (
                    <div className="flex flex-col">
                      {permissionItems.map((item) => (
                        <PermissionCard
                          key={item.key}
                          item={item}
                          onOpenSettings={() =>
                            void window.pinmind.permissions.openSettings(
                              item.settingsTarget ?? 'system-preferences',
                            )
                          }
                          onRefresh={async () => {
                            const snapshot = await window.pinmind.permissions.refresh('manual-refresh');
                            setPermissions(snapshot);
                          }}
                        />
                      ))}
                    </div>
                  )}
                </SettingGroupCard>
              </div>
            )}

            {/* ── Advanced Logs ────────────────────────────── */}
            {activeCategory === 'advanced-logs' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">日志</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    日志级别与运行时配置。
                  </p>
                </div>
                <SettingGroupCard title="日志" description="控制日志输出的详细程度。" icon="sb-settings">
                  <SettingsRow label="日志级别" description="修改后立即生效。">
                    <select
                      value={settings.logLevel}
                      onChange={(e) => void handleLogLevelChange(e.target.value as LogLevel)}
                      className="pm-ds-input min-w-[160px]"
                    >
                      <option value="debug">调试</option>
                      <option value="info">信息</option>
                      <option value="warn">警告</option>
                      <option value="error">错误</option>
                    </select>
                  </SettingsRow>
                </SettingGroupCard>
                <p className="text-[11px] px-1" style={{ color: 'var(--pm-text-tertiary)' }}>
                  设置变更会直接写入本地，无需手动保存。
                </p>
              </div>
            )}

            {/* ── Advanced Data (disabled) ─────────────────── */}
            {activeCategory === 'advanced-data' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">数据维护</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    数据库维护和备份功能正在开发中。
                  </p>
                </div>
                <SettingGroupCard title="数据维护" description="该功能尚未实现。" icon="duplicate">
                  <EmptyState
                    icon={'🔧'}
                    title="开发中"
                    description="后续版本提供。"
                  />
                </SettingGroupCard>
              </div>
            )}

            {/* ── Advanced Dev (disabled) ──────────────────── */}
            {activeCategory === 'advanced-dev' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="pinmind-page-title">开发者选项</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    开发者工具和调试选项正在开发中。
                  </p>
                </div>
                <SettingGroupCard title="开发者选项" description="该功能尚未实现。" icon="settings">
                  <EmptyState
                    icon={'🛠'}
                    title="开发中"
                    description="后续版本提供。当前可在 AI 控制台查看运行时信息。"
                  />
                </SettingGroupCard>
              </div>
            )}
          </div>
        </main>
        {showProviderDialog && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-[rgba(0,0,0,0.32)] p-6"
            onClick={() => {
              setShowProviderDialog(false);
              setProviderDialogProvider(null);
            }}
          >
            <div onClick={(event) => event.stopPropagation()}>
              <AddProviderDialog
                provider={providerDialogProvider}
                onSave={handleSaveProvider}
                onClose={() => {
                  setShowProviderDialog(false);
                  setProviderDialogProvider(null);
                }}
              />
            </div>
          </div>
        )}
      </div>
    );
  }

// ─── CapsuleSettingsPanel ─────────────────────────────────────

function CapsuleSettingsPanel({
  settings,
  onUpdateSetting,
}: {
  settings: AppSettings;
  onUpdateSetting: (patch: Partial<AppSettings>) => Promise<unknown>;
}): JSX.Element {
  const { addToast } = useToast();
  const capsule: DesktopMuseCapsuleSettings = settings.capsule ?? DEFAULT_CAPSULE_SETTINGS;

  const updateCapsule = useCallback(
    (patch: Partial<DesktopMuseCapsuleSettings>) => {
      const merged: DesktopMuseCapsuleSettings = {
        ...capsule,
        ...patch,
        startup: { ...capsule.startup, ...(patch.startup ?? {}) },
        appearance: { ...capsule.appearance, ...(patch.appearance ?? {}) },
        placement: { ...capsule.placement, ...(patch.placement ?? {}) },
        interaction: { ...capsule.interaction, ...(patch.interaction ?? {}) },
        quickCapture: { ...capsule.quickCapture, ...(patch.quickCapture ?? {}) },
        shortcuts: { ...capsule.shortcuts, ...(patch.shortcuts ?? {}) },
        notifications: { ...capsule.notifications, ...(patch.notifications ?? {}) },
      };
      void onUpdateSetting({ capsule: merged });
    },
    [capsule, onUpdateSetting],
  );

  const handleResetDefaults = useCallback(() => {
    void onUpdateSetting({ capsule: DEFAULT_CAPSULE_SETTINGS }).then(() => {
      addToast('已恢复默认设置', 'success');
    });
  }, [onUpdateSetting, addToast]);

  const handleResetPosition = useCallback(() => {
    const resetPlacement = { ...capsule.placement, lastPosition: undefined };
    updateCapsule({ placement: resetPlacement });
    addToast('胶囊位置已重置', 'success');
  }, [capsule.placement, updateCapsule, addToast]);

  return (
    <div className="flex flex-col gap-5">
      <div className="mt-7">
                  <h3 className="pinmind-page-title">
                    收集入口
                  </h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    配置桌面灵感胶囊的外观、行为和快捷键。
                  </p>
      </div>

      {/* ── 入口开关卡片 ──────────────────────────────── */}
      <SettingGroupCard title="入口开关" icon="duplicate">
        <SettingsRow
          label="启用桌面灵感入口"
          description="开启后，PinMind 会在桌面显示一个可快速记录灵感的小胶囊。"
        >
          <ToggleSwitch
            checked={capsule.enabled}
            onChange={(checked) => updateCapsule({ enabled: checked })}
          />
        </SettingsRow>
      </SettingGroupCard>

      {/* ── 启动与显示卡片 ────────────────────────────── */}
      <SettingGroupCard title="启动与显示" description="控制胶囊的自动显示和唤起行为。" icon="all">
        <SettingsRow label="开机后自动显示" description="系统启动后自动显示胶囊。">
          <ToggleSwitch
            checked={capsule.startup.showOnSystemStartup}
            onChange={(checked) =>
              updateCapsule({ startup: { ...capsule.startup, showOnSystemStartup: checked } })
            }
          />
        </SettingsRow>
        <SettingsRow label="启动 PinMind 后自动显示" description="打开应用后自动显示胶囊。">
          <ToggleSwitch
            checked={capsule.startup.showOnAppLaunch}
            onChange={(checked) =>
              updateCapsule({ startup: { ...capsule.startup, showOnAppLaunch: checked } })
            }
          />
        </SettingsRow>
        <SettingsRow label="贴边隐藏时自动唤起" description="鼠标靠近屏幕边缘时自动唤起隐藏的胶囊。">
          <ToggleSwitch
            checked={capsule.startup.autoWakeWhenEdgeHidden}
            onChange={(checked) =>
              updateCapsule({ startup: { ...capsule.startup, autoWakeWhenEdgeHidden: checked } })
            }
          />
        </SettingsRow>
        <SettingsRow label="显示未处理数量" description="在胶囊上显示待处理内容的数量角标。">
          <ToggleSwitch
            checked={capsule.startup.showPendingCount}
              onChange={(checked) =>
                updateCapsule({ startup: { ...capsule.startup, showPendingCount: checked } })
              }
            />
          </SettingsRow>
      </SettingGroupCard>

      {/* ── 外观设置卡片 ──────────────────────────────── */}
      <SettingGroupCard title="外观设置" description="自定义胶囊的视觉样式。" icon="text">
          {/* 主题色 */}
          <div className="pinmind-setting-row settings-row">
            <div className="settings-row-copy">
              <div className="settings-row-title">主题色</div>
              <div className="settings-row-desc">选择胶囊的主题颜色。</div>
            </div>
            <div className="settings-row-control">
              <div className="flex items-center gap-2">
              {(Object.entries(CAPSULE_THEME_COLORS) as [CapsuleThemeColor, string][]).map(
                ([key, color]) => (
                  <button
                    key={key}
                    type="button"
                    title={key}
                    className={`h-7 w-7 rounded-full border-2 transition-all duration-150 ${
                      capsule.appearance.themeColor === key
                        ? 'scale-110 border-[color:var(--pm-text-primary)] ring-2 ring-[rgba(0,0,0,0.1)]'
                        : 'border-transparent hover:scale-105'
                    }`}
                    style={{ backgroundColor: color }}
                    onClick={() =>
                      updateCapsule({
                        appearance: { ...capsule.appearance, themeColor: key },
                      })
                    }
                  />
                ),
              )}
              </div>
            </div>
          </div>

          {/* 样式 */}
          <SettingsRow label="样式" description="胶囊的视觉样式。">
            <select
              value={capsule.appearance.style}
              onChange={(e) =>
                updateCapsule({
                  appearance: { ...capsule.appearance, style: e.target.value as CapsuleStyle },
                })
              }
              className="pm-ds-input min-w-[180px]"
            >
              <option value="capsule">胶囊</option>
              <option value="circle">圆形</option>
              <option value="outline">线性描边</option>
              <option value="glass">毛玻璃</option>
            </select>
          </SettingsRow>

          {/* 透明度 */}
          <div className="settings-row">
            <div className="settings-row-copy">
              <div className="settings-row-title">透明度</div>
              <div className="settings-row-desc">
                胶囊的不透明度，当前 {Math.round(capsule.appearance.opacity * 100)}%。
              </div>
            </div>
            <div className="settings-row-control">
              <div className="flex items-center gap-3">
              <input
                type="range"
                min={60}
                max={100}
                step={1}
                value={Math.round(capsule.appearance.opacity * 100)}
                onChange={(e) =>
                  updateCapsule({
                    appearance: { ...capsule.appearance, opacity: Number(e.target.value) / 100 },
                  })
                }
                className="w-32 accent-[color:var(--pm-brand)]"
              />
              <span className="w-10 text-right text-[12px] text-[color:var(--pm-text-secondary)]">
                {Math.round(capsule.appearance.opacity * 100)}%
              </span>
              </div>
            </div>
          </div>

          {/* 尺寸 */}
          <div className="settings-row">
            <div className="settings-row-copy">
              <div className="settings-row-title">尺寸</div>
              <div className="settings-row-desc">胶囊的大小。</div>
            </div>
            <div className="settings-row-control">
              <div className="flex items-center gap-1">
                {(['small', 'medium', 'large'] as CapsuleSize[]).map((size) => (
                  <label key={size} className="flex items-center gap-1.5 px-2.5 py-1.5 text-[12px]">
                    <input
                      type="radio"
                      name="capsule-size"
                      value={size}
                      checked={capsule.appearance.size === size}
                      onChange={() =>
                        updateCapsule({
                          appearance: { ...capsule.appearance, size },
                        })
                      }
                      className="accent-[color:var(--pm-brand)]"
                    />
                    {size === 'small' ? '小' : size === 'medium' ? '中' : '大'}
                  </label>
                ))}
              </div>
            </div>
          </div>

          {/* 深色模式适配 */}
          <SettingsRow label="深色模式适配" description="在系统深色模式下自动调整胶囊外观。">
            <ToggleSwitch
              checked={capsule.appearance.adaptDarkMode}
              onChange={(checked) =>
                updateCapsule({
                  appearance: { ...capsule.appearance, adaptDarkMode: checked },
                })
              }
            />
          </SettingsRow>
      </SettingGroupCard>

      {/* ── 位置与贴边卡片 ────────────────────────────── */}
      <SettingGroupCard title="位置与贴边" description="控制胶囊在屏幕上的位置和贴边行为。" icon="duplicate">
          {/* 默认位置 */}
          <SettingsRow label="默认位置" description="胶囊在屏幕上的初始位置。">
            <select
              value={capsule.placement.defaultPosition}
              onChange={(e) =>
                updateCapsule({
                  placement: {
                    ...capsule.placement,
                    defaultPosition: e.target.value as CapsuleDefaultPosition,
                  },
                })
              }
              className="pm-ds-input min-w-[180px]"
            >
              <option value="right-center">右侧中部</option>
              <option value="right-bottom">右下角</option>
              <option value="left-center">左侧中部</option>
              <option value="left-bottom">左下角</option>
              <option value="bottom-center">底部中间</option>
              <option value="remember-last">记住上次位置</option>
            </select>
          </SettingsRow>

          {/* 允许拖动 */}
          <SettingsRow label="允许拖动" description="允许用户拖动胶囊到屏幕任意位置。">
            <ToggleSwitch
              checked={capsule.placement.allowDrag}
              onChange={(checked) =>
                updateCapsule({
                  placement: { ...capsule.placement, allowDrag: checked },
                })
              }
            />
          </SettingsRow>

          {/* 自动贴边 */}
          <SettingsRow label="自动贴边" description="松开拖动后自动吸附到最近的屏幕边缘。">
            <ToggleSwitch
              checked={capsule.placement.autoDockToEdge}
              onChange={(checked) =>
                updateCapsule({
                  placement: { ...capsule.placement, autoDockToEdge: checked },
                })
              }
            />
          </SettingsRow>

          {/* 贴边隐藏 */}
          <SettingsRow label="贴边隐藏" description="贴边后自动隐藏，仅露出小部分。">
            <ToggleSwitch
              checked={capsule.placement.edgeHidden}
              onChange={(checked) =>
                updateCapsule({
                  placement: { ...capsule.placement, edgeHidden: checked },
                })
              }
            />
          </SettingsRow>

          {/* 贴边露出宽度 */}
          <div className="settings-row">
            <div className="settings-row-copy">
              <div className="settings-row-title">贴边露出宽度</div>
              <div className="settings-row-desc">贴边隐藏时露出的像素宽度。</div>
            </div>
            <div className="settings-row-control">
              <div className="flex items-center gap-1">
                {([4, 6, 8, 12] as const).map((px) => (
                  <label key={px} className="flex items-center gap-1.5 px-2.5 py-1.5 text-[12px]">
                    <input
                      type="radio"
                      name="edge-visible-width"
                      value={px}
                      checked={capsule.placement.edgeVisibleWidth === px}
                      onChange={() =>
                        updateCapsule({
                          placement: { ...capsule.placement, edgeVisibleWidth: px },
                        })
                      }
                      className="accent-[color:var(--pm-brand)]"
                    />
                    {px}px
                  </label>
                ))}
              </div>
            </div>
          </div>

          {/* 避开屏幕边缘安全区 */}
          <SettingsRow label="避开屏幕边缘安全区" description="避免胶囊遮挡系统 UI 元素（如 Dock、菜单栏）。">
            <ToggleSwitch
              checked={capsule.placement.avoidSafeArea}
              onChange={(checked) =>
                updateCapsule({
                  placement: { ...capsule.placement, avoidSafeArea: checked },
                })
              }
            />
          </SettingsRow>
      </SettingGroupCard>

      {/* ── 交互设置卡片 ──────────────────────────────── */}
      <SettingGroupCard title="交互设置" description="自定义胶囊的点击、悬停和拖动行为。" icon="settings">
          {/* 点击动作 */}
          <SettingsRow label="点击动作" description="单击胶囊时的行为。">
            <select
              value={capsule.interaction.clickAction}
              onChange={(e) =>
                updateCapsule({
                  interaction: {
                    ...capsule.interaction,
                    clickAction: e.target.value as CapsuleClickAction,
                  },
                })
              }
              className="pm-ds-input min-w-[200px]"
            >
              <option value="expand-panel">展开输入面板</option>
              <option value="capture-clipboard">直接记录剪贴板</option>
              <option value="open-main-window">打开主窗口</option>
            </select>
          </SettingsRow>

          {/* 双击动作 */}
          <SettingsRow label="双击动作" description="双击胶囊时的行为。">
            <select
              value={capsule.interaction.doubleClickAction}
              onChange={(e) =>
                updateCapsule({
                  interaction: {
                    ...capsule.interaction,
                    doubleClickAction: e.target.value as CapsuleDoubleClickAction,
                  },
                })
              }
              className="pm-ds-input min-w-[200px]"
            >
              <option value="quick-screenshot">快速截图</option>
              <option value="quick-text">快速记录文本</option>
              <option value="open-main-window">打开主窗口</option>
              <option value="none">无操作</option>
            </select>
          </SettingsRow>

          {/* 悬停动作 */}
          <SettingsRow label="悬停动作" description="鼠标悬停在胶囊上时的行为。">
            <select
              value={capsule.interaction.hoverAction}
              onChange={(e) =>
                updateCapsule({
                  interaction: {
                    ...capsule.interaction,
                    hoverAction: e.target.value as CapsuleHoverAction,
                  },
                })
              }
              className="pm-ds-input min-w-[200px]"
            >
              <option value="peek-only">仅浮出提示</option>
              <option value="expand-panel">自动展开面板</option>
              <option value="none">无操作</option>
            </select>
          </SettingsRow>

          {/* 悬停延迟 */}
          <div className="settings-row">
            <div className="settings-row-copy">
              <div className="settings-row-title">悬停延迟</div>
              <div className="settings-row-desc">
                触发悬停动作前的等待时间，当前 {capsule.interaction.hoverDelayMs}ms。
              </div>
            </div>
            <div className="settings-row-control">
              <div className="flex items-center gap-3">
                <input
                  type="range"
                  min={100}
                  max={800}
                  step={50}
                  value={capsule.interaction.hoverDelayMs}
                  onChange={(e) =>
                    updateCapsule({
                      interaction: {
                        ...capsule.interaction,
                        hoverDelayMs: Number(e.target.value),
                      },
                    })
                  }
                  className="w-32 accent-[color:var(--pm-brand)]"
                />
                <span className="w-14 text-right text-[12px] text-[color:var(--pm-text-secondary)]">
                  {capsule.interaction.hoverDelayMs}ms
                </span>
              </div>
            </div>
          </div>

          {/* 失焦后自动收起 */}
          <SettingsRow label="失焦后自动收起" description="点击胶囊外部时自动收起展开的面板。">
            <ToggleSwitch
              checked={capsule.interaction.autoCollapseOnBlur}
              onChange={(checked) =>
                updateCapsule({
                  interaction: { ...capsule.interaction, autoCollapseOnBlur: checked },
                })
              }
            />
          </SettingsRow>

          {/* 拖动时透明度降低 */}
          <SettingsRow label="拖动时透明度降低" description="拖动胶囊时降低其透明度以减少视觉干扰。">
            <ToggleSwitch
              checked={capsule.interaction.reduceOpacityWhenDragging}
              onChange={(checked) =>
                updateCapsule({
                  interaction: { ...capsule.interaction, reduceOpacityWhenDragging: checked },
                })
              }
            />
          </SettingsRow>
      </SettingGroupCard>

      {/* ── 快捷记录偏好卡片 ──────────────────────────── */}
      <SettingGroupCard title="快捷记录偏好" description="配置捕获面板的默认输入方式和处理动作。" icon="duplicate">
          {/* 默认捕获方式 */}
          <SettingsRow label="默认捕获方式" description="打开捕获面板时的默认输入方式。">
            <select
              value={capsule.quickCapture.defaultCaptureType}
              onChange={(e) =>
                updateCapsule({
                  quickCapture: {
                    ...capsule.quickCapture,
                    defaultCaptureType: e.target.value as CapsuleCaptureType,
                  },
                })
              }
              className="pm-ds-input min-w-[180px]"
            >
              <option value="text">文本输入</option>
              <option value="screenshot">截图</option>
              <option value="voice">语音</option>
              <option value="clipboard">剪贴板</option>
            </select>
          </SettingsRow>

          {/* 默认处理动作 */}
          <SettingsRow label="默认处理动作" description="捕获内容后的默认处理方式。">
            <select
              value={capsule.quickCapture.defaultAction}
              onChange={(e) =>
                updateCapsule({
                  quickCapture: {
                    ...capsule.quickCapture,
                    defaultAction: e.target.value as CapsuleDefaultAction,
                  },
                })
              }
              className="pm-ds-input min-w-[180px]"
            >
              <option value="inbox">加入收集箱</option>
              <option value="ai-organize">直接 AI 整理</option>
              <option value="custom-flow">自定义流程</option>
            </select>
          </SettingsRow>

          {/* 默认输出位置 */}
          <SettingsRow label="默认输出位置" description="收集内容的默认保存位置。">
            <select
              value={capsule.quickCapture.defaultDestination}
              onChange={(e) =>
                updateCapsule({
                  quickCapture: {
                    ...capsule.quickCapture,
                    defaultDestination: e.target.value as CapsuleDestination,
                  },
                })
              }
              className="pm-ds-input min-w-[180px]"
            >
              <option value="pinmind-inbox">PinMind 收集箱</option>
              <option value="obsidian-inbox">Obsidian Inbox</option>
              <option value="project">指定项目</option>
            </select>
          </SettingsRow>

          {/* 捕获后清空输入框 */}
          <SettingsRow label="收集后清空输入框" description="成功收集后自动清空输入区域。">
            <ToggleSwitch
              checked={capsule.quickCapture.clearInputAfterCapture}
              onChange={(checked) =>
                updateCapsule({
                  quickCapture: { ...capsule.quickCapture, clearInputAfterCapture: checked },
                })
              }
            />
          </SettingsRow>

          {/* 捕获后显示通知 */}
          <SettingsRow label="收集后显示通知" description="成功收集后弹出系统通知。">
            <ToggleSwitch
              checked={capsule.quickCapture.showNotificationAfterCapture}
              onChange={(checked) =>
                updateCapsule({
                  quickCapture: { ...capsule.quickCapture, showNotificationAfterCapture: checked },
                })
              }
            />
          </SettingsRow>
      </SettingGroupCard>

      {/* ── 快捷键卡片 ────────────────────────────────── */}
      <SettingGroupCard title="快捷键" description="配置胶囊相关的全局快捷键。" icon="settings">
          <ShortcutRow
            label="显示/隐藏胶囊"
            value={capsule.shortcuts.toggleCapsule}
            onChange={(val) =>
              updateCapsule({
                shortcuts: { ...capsule.shortcuts, toggleCapsule: val },
              })
            }
          />
          <ShortcutRow
            label="快速记录文本"
            value={capsule.shortcuts.quickText}
            onChange={(val) =>
              updateCapsule({
                shortcuts: { ...capsule.shortcuts, quickText: val },
              })
            }
          />
          <ShortcutRow
            label="快速截图"
            value={capsule.shortcuts.quickScreenshot}
            onChange={(val) =>
              updateCapsule({
                shortcuts: { ...capsule.shortcuts, quickScreenshot: val },
              })
            }
          />
          <ShortcutRow
            label="语音输入"
            value={capsule.shortcuts.voiceInput}
            onChange={(val) =>
              updateCapsule({
                shortcuts: { ...capsule.shortcuts, voiceInput: val },
              })
            }
          />
          <ShortcutRow
            label="从剪贴板获取"
            value={capsule.shortcuts.clipboardCapture}
            onChange={(val) =>
              updateCapsule({
                shortcuts: { ...capsule.shortcuts, clipboardCapture: val },
              })
            }
          />
      </SettingGroupCard>

      {/* ── 通知设置卡片 ──────────────────────────────── */}
      <SettingGroupCard title="通知设置" description="配置各类事件的通知显示。" icon="help">
          <SettingsRow label="捕获成功提示" description="内容捕获成功时显示通知。">
            <ToggleSwitch
              checked={capsule.notifications.captureSuccess}
              onChange={(checked) =>
                updateCapsule({
                  notifications: { ...capsule.notifications, captureSuccess: checked },
                })
              }
            />
          </SettingsRow>
          <SettingsRow label="AI 处理完成通知" description="AI 整理完成后显示通知。">
            <ToggleSwitch
              checked={capsule.notifications.aiComplete}
              onChange={(checked) =>
                updateCapsule({
                  notifications: { ...capsule.notifications, aiComplete: checked },
                })
              }
            />
          </SettingsRow>
          <SettingsRow label="保存失败通知" description="内容保存失败时显示错误通知。">
            <ToggleSwitch
              checked={capsule.notifications.saveFailed}
              onChange={(checked) =>
                updateCapsule({
                  notifications: { ...capsule.notifications, saveFailed: checked },
                })
              }
            />
          </SettingsRow>
          <SettingsRow label="待处理数量提醒" description="定期提醒未处理的内容数量。">
            <ToggleSwitch
              checked={capsule.notifications.pendingReminder}
              onChange={(checked) =>
                updateCapsule({
                  notifications: { ...capsule.notifications, pendingReminder: checked },
                })
              }
            />
          </SettingsRow>
      </SettingGroupCard>

      {/* ── 更多卡片 ──────────────────────────────────── */}
      <SettingGroupCard title="更多" icon="settings">
          <div className="flex flex-wrap gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={handleResetDefaults}
          >
            恢复默认设置
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={handleResetPosition}
          >
            重置胶囊位置
          </Button>
          </div>
      </SettingGroupCard>
    </div>
  );
}

// ─── ShortcutRow ──────────────────────────────────────────────

function ShortcutRow({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}): JSX.Element {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(value);

  const handleSave = useCallback(() => {
    if (draft.trim()) {
      onChange(draft.trim());
    } else {
      setDraft(value);
    }
    setEditing(false);
  }, [draft, value, onChange]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter') {
        handleSave();
      } else if (e.key === 'Escape') {
        setDraft(value);
        setEditing(false);
      }
    },
    [handleSave, value],
  );

  return (
    <div className="settings-row">
      <div className="settings-row-copy">
        <div className="settings-row-title">{label}</div>
      </div>
      <div className="settings-row-control">
        {editing ? (
          <input
            autoFocus
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onBlur={handleSave}
            onKeyDown={handleKeyDown}
            className="pm-ds-input w-36"
          />
        ) : (
          <button
            type="button"
            onClick={() => {
              setDraft(value);
              setEditing(true);
            }}
            className="inline-flex items-center gap-1 rounded-[6px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.03)] px-2.5 py-1 text-[12px] text-[color:var(--pm-text-secondary)] transition-colors hover:border-[color:var(--pm-border)] hover:bg-[rgba(0,0,0,0.05)]"
          >
            <kbd className="font-mono text-[11px]">{value}</kbd>
            <PinStackIcon name="edit" size={11} className="text-[color:var(--pm-text-tertiary)]" />
          </button>
        )}
      </div>
    </div>
  );
}

// ─── SettingsRow ─────────────────────────────────────────────

function SettingsRow({
  label,
  description,
  children,
}: {
  label: string;
  description?: string;
  children: React.ReactNode;
}): JSX.Element {
  return (
    <div className="pinmind-setting-row settings-row">
      <div className="settings-row-copy">
        <div className="settings-row-title">{label}</div>
        {description ? <div className="settings-row-desc">{description}</div> : null}
      </div>
      <div className="settings-row-control">{children}</div>
    </div>
  );
}

// ─── ToggleSwitch ────────────────────────────────────────────

function ToggleSwitch({
  checked,
  onChange,
}: {
  checked: boolean;
  onChange: (checked: boolean) => void;
}): JSX.Element {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={`motion-toggle relative inline-flex shrink-0 rounded-full border transition-colors duration-200`}
      style={{
        width: 46,
        height: 28,
        padding: 0,
        backgroundColor: checked ? '#FF6A1A' : '#E5DED4',
        borderColor: checked ? '#FF6A1A' : '#E5DED4',
      }}
    >
      <span
        className="motion-toggle-knob inline-block rounded-full bg-white shadow-sm transition-transform duration-200"
        style={{
          width: 22,
          height: 22,
          marginTop: 2,
          marginLeft: 2,
          transform: checked ? 'translateX(20px)' : 'translateX(0)',
        }}
      />
    </button>
  );
}

// ─── PermissionCard ──────────────────────────────────────────

function PermissionCard({
  item,
  onOpenSettings,
  onRefresh,
}: {
  item: NonNullable<PermissionStatusSnapshot['items']>[number];
  onOpenSettings: () => void;
  onRefresh: () => Promise<void>;
}): JSX.Element {
  return (
    <div className="settings-row" style={{ alignItems: 'flex-start' }}>
      <div className="min-w-0">
        <div className="settings-row-title">{item.title}</div>
        <div className="settings-row-desc">{item.message}</div>
        <div className="mt-2 flex flex-wrap gap-2">
          {item.canOpenSystemSettings ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={onOpenSettings}
            >
              打开系统设置
            </Button>
          ) : null}
          <Button
            variant="ghost"
            size="sm"
            onClick={() => void onRefresh()}
          >
            刷新状态
          </Button>
        </div>
      </div>
      <div className="shrink-0" style={{ justifySelf: 'end' }}>
        <StatusBadge tone="neutral" label={item.state} dot={false} />
      </div>
    </div>
  );
}
