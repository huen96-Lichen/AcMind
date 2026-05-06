import { useCallback, useEffect, useMemo, useState } from 'react';
import type {
  AppSettings,
  LogLevel,
  PermissionStatusSnapshot,
  ProviderConfig,
  TranscriptionLocalEngine,
  TranscriptionModelSize,
  TranscriptionProvider,
  DictationDiagnosticItem,
  DictationDiagnosticReport,
  VoicePolishMode,
  DictationSettings,
} from '../../../shared/types';
import { DEFAULT_DICTATION_SETTINGS } from '../../../shared/types';
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
import { AcMindIcon } from '../../design-system/icons';
import { SettingGroupCard } from '../../design-system/primitives';
import { Button, StatusBadge } from '../../design-system/components';
import { AddProviderDialog } from './components/AddProviderDialog';
import { HotkeyRecorder } from './components/HotkeyRecorder';
import { ProviderCard } from './components/ProviderCard';
import { EmptyState } from '../../components/shared/EmptyState';
import { useToast } from '../../components/shared/ToastViewport';
import { AgentChatSettings } from './components/AgentChatSettings';

// ─── Settings Category Keys ──────────────────────────────────
// 设置分组：基础 / Agent / 日程表 / 工作台 / 自动工具 / 桌面组件 / 语音 / 知识库 / 高级

type SettingsCategory =
  // 基础
  | 'general'
  | 'appearance'
  | 'shortcuts'
  // Agent
  | 'agent-chat'
  | 'agent-behavior'
  | 'ai-models'
  | 'ai-default-tier'
  // 日程表
  | 'schedule-general'
  | 'schedule-reminder'
  | 'schedule-calendar'
  | 'schedule-email'
  // 工作台
  | 'capture-capsule'
  | 'workbench-rules'
  // 自动工具
  | 'auto-tools-general'
  | 'auto-tools-ocr'
  // 桌面组件
  | 'desktop-widgets'
  // 语音
  | 'voice-input'
  | 'dictation'
  // 知识库
  | 'obsidian'
  | 'export-rules'
  // 高级
  | 'advanced-logs'
  | 'advanced-data'
  | 'advanced-dev';

// ─── Group & Category Definitions ────────────────────────────

interface SettingsCategoryDef {
  key: SettingsCategory;
  title: string;
  icon: import('../../design-system/icons').AcMindIconName;
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
 
// 设置分组：基础 / Agent / 日程表 / 工作台 / 自动工具 / 桌面组件 / 语音 / 知识库 / 高级
const SETTINGS_GROUPS: SettingsGroupDef[] = [
  {
    key: 'basics',
    title: '基础',
    categories: [
      { key: 'general', title: '启动', icon: 'all' },
      { key: 'appearance', title: '外观', icon: 'text' },
      { key: 'shortcuts', title: '快捷键', icon: 'settings' },
    ],
  },
  {
    key: 'agent',
    title: 'Agent',
    categories: [
      { key: 'agent-chat', title: '默认模型', icon: 'ai-workspace' },
      { key: 'agent-behavior', title: 'Agent 行为', icon: 'sb-inbox' },
      { key: 'ai-models', title: '模型管理', icon: 'ai-workspace' },
      { key: 'ai-default-tier', title: '默认层级与回退策略', icon: 'settings' },
    ],
  },
  {
    key: 'schedule',
    title: '日程表',
    categories: [
      { key: 'schedule-general', title: '日程管家', icon: 'clock' },
      { key: 'schedule-reminder', title: '提醒方式', icon: 'sb-results' },
      { key: 'schedule-calendar', title: '日历视图', icon: 'filled-home' },
      { key: 'schedule-email', title: '邮件发送', icon: 'filled-link' },
    ],
  },
  {
    key: 'workbench',
    title: '工作台',
    categories: [
      { key: 'capture-capsule', title: '收集规则', icon: 'duplicate' },
      { key: 'workbench-rules', title: '整理与审阅规则', icon: 'sb-ai-process' },
    ],
  },
  {
    key: 'auto-tools',
    title: '自动工具',
    categories: [
      { key: 'auto-tools-general', title: '工具总览', icon: 'line-file-import' },
      { key: 'auto-tools-ocr', title: 'OCR 与文件转换', icon: 'image' },
    ],
  },
  {
    key: 'desktop-widgets',
    title: '桌面组件',
    categories: [
      { key: 'desktop-widgets', title: '桌面组件', icon: 'all' },
    ],
  },
  {
    key: 'voice',
    title: '语音',
    categories: [
      { key: 'voice-input', title: '录音设备', icon: 'record' },
      { key: 'dictation', title: '语音转文字', icon: 'spark' },
    ],
  },
  {
    key: 'knowledge',
    title: '知识库',
    categories: [
      { key: 'obsidian', title: 'Obsidian Vault', icon: 'sb-obsidian' },
      { key: 'export-rules', title: '入库规则', icon: 'text' },
    ],
  },
  {
    key: 'advanced',
    title: '高级',
    collapsed: true,
    categories: [
      { key: 'advanced-logs', title: '日志', icon: 'sb-settings' },
      { key: 'advanced-data', title: '数据维护', icon: 'duplicate' },
      { key: 'advanced-dev', title: '开发者选项', icon: 'settings' },
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
  const [downloadingWhisperModel, setDownloadingWhisperModel] = useState<WhisperModelRow['size'] | null>(null);
  const [whisperDownloadProgress, setWhisperDownloadProgress] = useState<number | null>(null);
  const [whisperDownloadError, setWhisperDownloadError] = useState<string | null>(null);
  const [lastWhisperFailedModelSize, setLastWhisperFailedModelSize] = useState<WhisperModelRow['size'] | null>(null);
  const [repairingWhisper, setRepairingWhisper] = useState(false);
  const [runningDictationDiagnostics, setRunningDictationDiagnostics] = useState(false);
  const [dictationDiagnostics, setDictationDiagnostics] = useState<DictationDiagnosticReport | null>(null);
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
          window.acmind.settings.get(),
          window.acmind.permissions.getStatus('settings-return'),
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
      if (!window.acmind) return;
      setProvidersLoading(true);
      try {
        const nextProviders = await window.acmind.providers.list();
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
          window.acmind.whisper.getModels(),
          window.acmind.whisper.getStatus(),
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
    async (patch: Partial<AppSettings>): Promise<AppSettings | null> => {
      if (!settings) return null;

      setSaving(true);
      try {
        const updated = await window.acmind.settings.update(patch);
        setSettings(updated);
        setSavedAt(Date.now());
        addToast('设置已自动保存', 'success');
        // Notify shell to refresh snapshot (e.g. sidebar nav depends on settings)
        window.dispatchEvent(new CustomEvent('acmind:settings-updated'));
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

  const commitDictationHotkey = useCallback(
    async (nextHotkey: string) => {
      if (!settings) return;
      const sanitized = nextHotkey.trim() || DEFAULT_CAPSULE_SETTINGS.shortcuts.voiceInput;
      const currentHotkey = settings.capsule.shortcuts.voiceInput ?? DEFAULT_CAPSULE_SETTINGS.shortcuts.voiceInput;
      if (sanitized === currentHotkey) {
        return;
      }
      await updateSetting({
        capsule: {
          ...settings.capsule,
          shortcuts: {
            ...settings.capsule.shortcuts,
            voiceInput: sanitized,
          },
        },
      });
    },
    [settings, updateSetting],
  );

  const handleLogLevelChange = useCallback(
    async (nextLevel: LogLevel) => {
      try {
        await window.acmind.logger.setLevel(nextLevel);
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
      await window.acmind.settings.update({
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
        const nextProviders = await window.acmind.providers.update(id, { enabled: !provider.enabled });
        const refreshedProviders = await window.acmind.providers.list();
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
        await window.acmind.providers.delete(providerId);
        const refreshedProviders = await window.acmind.providers.list();
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
        const result = await window.acmind.providers.testConnection(providerId);
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
        window.acmind.whisper.getModels(),
        window.acmind.whisper.getStatus(),
      ]);
      setWhisperModels(models as WhisperModelRow[]);
      setWhisperRuntime(status as WhisperRuntimeStatus);
    } catch {
      addToast('刷新本地模型缓存失败', 'error');
    }
  }, [addToast]);

  const handleDownloadWhisperModel = useCallback(
    async (modelSize: WhisperModelRow['size']) => {
      setWhisperDownloadError(null);
      setLastWhisperFailedModelSize(null);
      setWhisperDownloadProgress(0);
      setDownloadingWhisperModel(modelSize);
      try {
        await window.acmind.whisper.downloadModel(modelSize, (progress) => {
          setWhisperDownloadProgress(progress);
        });
        setWhisperDownloadProgress(100);
        await refreshWhisperModels();
        addToast(`已下载 ${modelSize} 模型到本地`, 'success');
      } catch (error) {
        const message = error instanceof Error ? error.message : '下载本地模型失败';
        setWhisperDownloadError(message);
        setLastWhisperFailedModelSize(modelSize);
        addToast(message, 'error');
      } finally {
        setDownloadingWhisperModel(null);
        window.setTimeout(() => setWhisperDownloadProgress(null), 900);
      }
    },
    [refreshWhisperModels, addToast],
  );

  const handleDeleteWhisperModel = useCallback(
    async (modelSize: WhisperModelRow['size']) => {
      try {
        await window.acmind.whisper.deleteModel(modelSize);
        await refreshWhisperModels();
        addToast(`已删除 ${modelSize} 模型缓存`, 'success');
      } catch (error) {
        addToast(error instanceof Error ? error.message : '删除本地模型失败', 'error');
      }
    },
    [refreshWhisperModels, addToast],
  );

  const handleRunDictationDiagnostics = useCallback(async () => {
    setRunningDictationDiagnostics(true);
    try {
      const report = await window.acmind.voice.getDictationDiagnostics() as DictationDiagnosticReport;

      const browserMicItem: DictationDiagnosticItem = {
        key: 'browser_microphone',
        label: '浏览器麦克风',
        ok: false,
        message: '无法检查浏览器麦克风。',
      };

      if (!navigator.mediaDevices?.getUserMedia) {
        browserMicItem.message = '当前环境不支持 getUserMedia，无法直接采集麦克风。';
      } else {
        try {
          const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
          stream.getTracks().forEach((track) => track.stop());
          browserMicItem.ok = true;
          browserMicItem.message = '浏览器可以正常获取麦克风权限。';
        } catch (error) {
          browserMicItem.message = error instanceof Error ? error.message : '麦克风权限或设备不可用。';
        }
      }

      const otherItems = (report?.items ?? []).filter((item) => item.key !== 'browser_microphone');
      const items = [browserMicItem, ...otherItems];
      const nextReport: DictationDiagnosticReport = {
        ok: items.every((item) => item.ok),
        checkedAt: Date.now(),
        items,
      };

      setDictationDiagnostics(nextReport);
      addToast(nextReport.ok ? '语音听写自检通过' : '语音听写自检发现问题', nextReport.ok ? 'success' : 'warning');
    } catch (error) {
      addToast(error instanceof Error ? error.message : '语音听写自检失败', 'error');
      setDictationDiagnostics({
        ok: false,
        checkedAt: Date.now(),
        items: [],
      });
    } finally {
      setRunningDictationDiagnostics(false);
    }
  }, [addToast]);

  const handleRequestMicrophoneAccess = useCallback(async () => {
    try {
      const result = await window.acmind.voice.requestMicrophoneAccess();
      addToast(result.message, result.granted ? 'success' : 'warning');
      await handleRunDictationDiagnostics();
    } catch (error) {
      addToast(error instanceof Error ? error.message : '请求麦克风权限失败', 'error');
    }
  }, [addToast, handleRunDictationDiagnostics]);

  const handleInstallLocalAsr = useCallback(async () => {
    setWhisperDownloadError(null);
    setLastWhisperFailedModelSize(null);
    setWhisperDownloadProgress(0);
    setRepairingWhisper(true);
    try {
      await window.acmind.whisper.repair((progress) => {
        setWhisperDownloadProgress(progress);
      });
      setWhisperDownloadProgress(100);
      await refreshWhisperModels();
      await handleRunDictationDiagnostics();
      addToast('本地 ASR 已安装并校验完成', 'success');
    } catch (error) {
      const message = error instanceof Error ? error.message : '安装本地 ASR 失败';
      setWhisperDownloadError(message);
      addToast(message, 'error');
    } finally {
      setRepairingWhisper(false);
      window.setTimeout(() => setWhisperDownloadProgress(null), 900);
    }
  }, [refreshWhisperModels, addToast, handleRunDictationDiagnostics]);

  const handleOpenWhisperCacheDir = useCallback(async () => {
    try {
      const result = await window.acmind.whisper.openCacheDir();
      if (!result || typeof result !== 'object' || result.success === false) {
        addToast((result as { error?: string } | undefined)?.error ?? '打开缓存目录失败', 'error');
        return;
      }
      addToast('已打开本地模型缓存目录', 'success');
    } catch (error) {
      addToast(error instanceof Error ? error.message : '打开缓存目录失败', 'error');
    }
  }, [addToast]);

  const handleCopyRecorderInstallCommand = useCallback(async () => {
    try {
      const command = 'brew install sox';
      await navigator.clipboard.writeText(command);
      addToast(`已复制命令：${command}`, 'success');
    } catch (error) {
      addToast(error instanceof Error ? error.message : '复制安装命令失败', 'error');
    }
  }, [addToast]);

  const handleSaveProvider = useCallback(
    async (provider: ProviderConfig) => {
      try {
        const exists = providers.some((item) => item.id === provider.id);
        if (exists) {
          await window.acmind.providers.update(provider.id, provider);
        } else {
          await window.acmind.providers.add(provider);
        }
        const refreshedProviders = await window.acmind.providers.list();
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
  const showBundledWhisperModels = Boolean(
    settings && settings.transcription.provider === 'local' && settings.transcription.localEngine === 'whisper',
  );
  const dictationDiagnosticItems = dictationDiagnostics?.items ?? [];
  const whisperBusy = downloadingWhisperModel !== null || repairingWhisper;
  const whisperProgressLabel = repairingWhisper
    ? '正在安装/校验本地 ASR'
    : downloadingWhisperModel
      ? `正在下载 ${downloadingWhisperModel} 模型`
      : whisperDownloadProgress === 100
        ? '处理完成'
        : '正在检查本地转写环境';
  const canInstallLocalAsr = settings?.transcription.provider === 'local';

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
    <div className="acmind-settings-layout">
      {/* ─── Left: Category List ─────────────────────────── */}
      <aside className="acmind-settings-sidebar">
        <div className="px-4 pt-5 pb-3">
          <h2 className="acmind-page-title">
            设置
          </h2>
          <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
            调整 AcMind 的工作方式
          </p>
          <div className="acmind-save-indicator is-visible" style={savedAt ? { opacity: 1 } : { opacity: 0 }}>
            <AcMindIcon name="check" size={12} />
            <span>已保存</span>
          </div>
        </div>

        <nav className="acmind-settings-nav">
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
                  <AcMindIcon
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
                          <AcMindIcon name={cat.icon} size={14} />
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
        <main className="acmind-settings-content">
          <div className="acmind-settings-content-inner">
            {/* ── General ─────────────────────────────────── */}
            {activeCategory === 'general' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">通用</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    启动偏好与捕获行为。
                  </p>
                </div>

                {/* 启动与后台 */}
                <SettingGroupCard title="启动" description="应用启动方式。" icon="all">
                  <SettingsRow label="开机启动" description="登录后自动启动 AcMind。">
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
                    <h3 className="acmind-page-title">
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
                          <option value="whisper-ctranslate2">whisper-ctranslate2 - 速度优先</option>
                          <option value="whisper">openai-whisper - 可下载模型</option>
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
                        <AcMindIcon name="help" size={14} className="mt-0.5 shrink-0" style={{ color: 'var(--pm-text-tertiary)' }} />
                        <p className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                          本地转写会优先调用内置模型缓存，缺失时自动下载到本地目录。
                        </p>
                      </div>
                      {(whisperDownloadProgress !== null || whisperDownloadError) && (
                        <div className="flex flex-col gap-2 rounded-[14px] border border-[color:var(--pm-border-subtle)] bg-white px-3 py-3">
                          {whisperDownloadError ? (
                            <div className="flex flex-col gap-2">
                              <div className="text-[12px] font-medium text-[color:var(--pm-danger)]">
                                {whisperDownloadError}
                              </div>
                              <div className="flex items-center gap-2">
                                {lastWhisperFailedModelSize && (
                                  <Button
                                    variant="secondary"
                                    size="sm"
                                    onClick={() => void handleDownloadWhisperModel(lastWhisperFailedModelSize)}
                                    disabled={whisperBusy}
                                  >
                                    重试下载
                                  </Button>
                                )}
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => void handleOpenWhisperCacheDir()}
                                  disabled={whisperBusy}
                                >
                                  打开缓存目录
                                </Button>
                              </div>
                            </div>
                          ) : (
                            <div className="flex flex-col gap-2">
                              <div className="flex items-center justify-between gap-3 text-[12px] text-[color:var(--pm-text-secondary)]">
                                <span>{whisperProgressLabel}</span>
                                <span>{Math.max(0, Math.min(100, Math.round(whisperDownloadProgress ?? 0)))}%</span>
                              </div>
                              <div className="h-2 overflow-hidden rounded-full bg-[rgba(15,23,42,0.08)]">
                                <div
                                  className="h-full rounded-full bg-[var(--pm-accent-orange)] transition-all duration-300"
                                  style={{ width: `${Math.max(0, Math.min(100, whisperDownloadProgress ?? 0))}%` }}
                                />
                              </div>
                            </div>
                          )}
                        </div>
                      )}
                      {showBundledWhisperModels ? (
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
                            <div className="flex items-center gap-2">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => void handleOpenWhisperCacheDir()}
                                disabled={whisperBusy}
                              >
                                打开缓存目录
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => void handleInstallLocalAsr()}
                                disabled={whisperBusy}
                              >
                                {repairingWhisper ? '安装中...' : '一键安装并校验'}
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => void refreshWhisperModels()}
                                disabled={whisperBusy}
                              >
                                刷新
                              </Button>
                            </div>
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
                                    disabled={whisperBusy}
                                  >
                                    {downloadingWhisperModel === model.size
                                      ? '下载中...'
                                      : whisperDownloadError && lastWhisperFailedModelSize === model.size
                                        ? '重试下载'
                                      : model.cached
                                        ? '重新下载'
                                        : '下载到本地'}
                                  </Button>
                                  {model.cached && (
                                    <Button
                                      variant="ghost"
                                      size="sm"
                                      onClick={() => void handleDeleteWhisperModel(model.size)}
                                      disabled={whisperBusy}
                                    >
                                      删除缓存
                                    </Button>
                                  )}
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      ) : (
                        <div className="flex flex-col gap-3 rounded-[16px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.015)] p-4">
                          <div>
                            <div className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                              当前引擎：whisper-ctranslate2
                            </div>
                            <div className="mt-1 text-[11px] text-[color:var(--pm-text-tertiary)]">
                              这个引擎会在首次转写时自动拉取模型，不在这里单独管理模型缓存。若你想手动下载和缓存模型，请切换到 openai-whisper。
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            <Button
                              variant="secondary"
                              size="sm"
                              onClick={() => void updateTranscription({ localEngine: 'whisper' })}
                            >
                              切换到 openai-whisper
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => void handleInstallLocalAsr()}
                              disabled={whisperBusy}
                            >
                              {repairingWhisper ? '安装中...' : '一键安装并校验'}
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => void refreshWhisperModels()}
                              disabled={whisperBusy}
                            >
                              重新检查
                            </Button>
                          </div>
                        </div>
                      )}
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
                    <AcMindIcon name="check" size={14} />
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
                  <h3 className="acmind-page-title">默认层级与回退策略</h3>
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
                    <AcMindIcon name="help" size={14} className="mt-0.5 shrink-0" style={{ color: 'var(--pm-text-tertiary)' }} />
                    <p className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                      模型不可用时自动尝试可用层级。
                    </p>
                  </div>
                </SettingGroupCard>

                {/* Save Feedback */}
                {savedAt && (
                  <div className="flex items-center gap-2 rounded-[8px] border border-[color:var(--pm-status-success)] bg-[rgba(22,163,74,0.06)] px-3 py-2.5">
                    <AcMindIcon name="check" size={14} />
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

            {/* ── Agent Chat ─────────────────────────────── */}
            {activeCategory === 'agent-chat' && settings && (
              <AgentChatSettings
                settings={settings}
                onUpdate={updateSetting}
                providers={providers}
              />
            )}

            {/* ── 日程管家（总览） ────────────────────────────── */}
            {activeCategory === 'schedule-general' && settings && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">日程管家</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    管理提醒、周期任务和自动执行规则。
                  </p>
                </div>

                {/* Obsidian 自动整理 */}
                <SettingGroupCard title="Obsidian 自动整理" description="定时自动整理 Obsidian 资料库。" icon="sb-obsidian">
                  <SettingsRow label="启用自动整理" description="按设定时间自动执行整理任务">
                    <ToggleSwitch
                      checked={settings.scheduleManager?.obsidianAutoCleanup ?? false}
                      onChange={(checked) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, obsidianAutoCleanup: checked } })
                      }
                    />
                  </SettingsRow>
                  <SettingsRow label="整理时间" description="每天执行自动整理的时间">
                    <input
                      type="time"
                      value={settings.scheduleManager?.obsidianCleanupTime ?? '01:00'}
                      onChange={(e) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, obsidianCleanupTime: e.target.value } })
                      }
                      className="pm-ds-input min-w-[120px]"
                    />
                  </SettingsRow>
                </SettingGroupCard>

                {/* 周期任务默认确认策略 */}
                <SettingGroupCard title="周期任务" description="重复任务的默认执行策略。" icon="sb-ai-process">
                  <SettingsRow label="自动确认" description="周期任务到期后自动执行，无需手动确认">
                    <ToggleSwitch
                      checked={settings.scheduleManager?.autoConfirmRecurring ?? false}
                      onChange={(checked) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, autoConfirmRecurring: checked } })
                      }
                    />
                  </SettingsRow>
                  <SettingsRow label="执行失败通知" description="任务执行失败时的通知方式">
                    <select
                      value={settings.scheduleManager?.failureNotification ?? 'desktop'}
                      onChange={(e) =>
                        void updateSetting({
                          scheduleManager: { ...settings.scheduleManager, failureNotification: e.target.value as 'none' | 'desktop' | 'email' },
                        })
                      }
                      className="pm-ds-input min-w-[160px]"
                    >
                      <option value="none">不通知</option>
                      <option value="desktop">桌面通知</option>
                      <option value="email">邮件通知</option>
                    </select>
                  </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── 提醒方式 ───────────────────────────────────── */}
            {activeCategory === 'schedule-reminder' && settings && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">提醒方式</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    默认的提醒通知方式。
                  </p>
                </div>

                <SettingGroupCard title="提醒方式" description="默认的提醒通知方式。" icon="sb-results">
                  <SettingsRow label="桌面通知" description="通过系统通知栏显示提醒">
                    <ToggleSwitch
                      checked={settings.scheduleManager?.desktopNotification ?? true}
                      onChange={(checked) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, desktopNotification: checked } })
                      }
                    />
                  </SettingsRow>
                  <SettingsRow label="声音提醒" description="提醒时播放提示音">
                    <ToggleSwitch
                      checked={settings.scheduleManager?.soundNotification ?? true}
                      onChange={(checked) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, soundNotification: checked } })
                      }
                    />
                  </SettingsRow>
                  <SettingsRow label="顶部 Notch 提醒" description="在桌面顶部 Notch 区域显示提醒状态">
                    <ToggleSwitch
                      checked={settings.scheduleManager?.notchReminder ?? true}
                      onChange={(checked) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, notchReminder: checked } })
                      }
                    />
                  </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── 日历视图 ───────────────────────────────────── */}
            {activeCategory === 'schedule-calendar' && settings && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">日历视图</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    日历展示和交互偏好。
                  </p>
                </div>

                <SettingGroupCard title="日历视图" description="日历展示和交互偏好。" icon="filled-home">
                  <SettingsRow label="默认视图" description="打开日程表时的默认视图">
                    <select
                      value={settings.scheduleManager?.defaultCalendarView ?? 'week'}
                      onChange={(e) =>
                        void updateSetting({
                          scheduleManager: { ...settings.scheduleManager, defaultCalendarView: e.target.value as 'day' | 'week' | 'month' },
                        })
                      }
                      className="pm-ds-input min-w-[160px]"
                    >
                      <option value="day">日视图</option>
                      <option value="week">周视图</option>
                      <option value="month">月视图</option>
                    </select>
                  </SettingsRow>
                  <SettingsRow label="一周起始日" description="日历中每周的第一天">
                    <select
                      value={settings.scheduleManager?.weekStart ?? 'monday'}
                      onChange={(e) =>
                        void updateSetting({
                          scheduleManager: { ...settings.scheduleManager, weekStart: e.target.value as 'sunday' | 'monday' },
                        })
                      }
                      className="pm-ds-input min-w-[160px]"
                    >
                      <option value="monday">周一</option>
                      <option value="sunday">周日</option>
                    </select>
                  </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── 邮件发送 ───────────────────────────────────── */}
            {activeCategory === 'schedule-email' && settings && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">邮件发送</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    定时邮件任务的发送配置。
                  </p>
                </div>

                <SettingGroupCard title="邮件发送" description="定时邮件任务的发送配置。" icon="filled-link">
                  <SettingsRow label="SMTP 服务器" description="邮件发送服务器地址">
                    <input
                      value={settings.scheduleManager?.smtpHost ?? ''}
                      onChange={(e) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, smtpHost: e.target.value } })
                      }
                      className="pm-ds-input min-w-[220px]"
                      placeholder="smtp.example.com"
                    />
                  </SettingsRow>
                  <SettingsRow label="发件人邮箱" description="定时邮件的发件人地址">
                    <input
                      value={settings.scheduleManager?.smtpFrom ?? ''}
                      onChange={(e) =>
                        void updateSetting({ scheduleManager: { ...settings.scheduleManager, smtpFrom: e.target.value } })
                      }
                      className="pm-ds-input min-w-[220px]"
                      placeholder="reminder@example.com"
                    />
                  </SettingsRow>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Obsidian ────────────────────────────────── */}
            {activeCategory === 'obsidian' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">Obsidian</h3>
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
                            const folder = await window.acmind.vault.pickFolder();
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
                            const result = await window.acmind.vault.validatePath(settings.vault.vaultPath);
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
                  <h3 className="acmind-page-title">入库规则</h3>
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
                    <AcMindIcon name="help" size={14} className="mt-0.5 shrink-0" style={{ color: 'var(--pm-text-tertiary)' }} />
                    <p className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                      如需修改，请前往「资料库 → Obsidian」。
                    </p>
                  </div>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Capsule (捕获入口) ───────────────────────── */}
            {activeCategory === 'capture-capsule' && <CapsuleSettingsPanel settings={settings} onUpdateSetting={updateSetting} />}

            {/* ── 自动工具（总览） ────────────────────────────── */}
            {activeCategory === 'auto-tools-general' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">自动工具</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    AcMind 可调用的处理能力总览。
                  </p>
                </div>

                <SettingGroupCard title="工具能力" description="所有可用的自动工具。" icon="line-file-import">
                  <div className="flex flex-col gap-2">
                    {[
                      { label: '文件转 Markdown', desc: 'PDF、DOCX、PPTX 等文件转换' },
                      { label: 'OCR 图像识别', desc: '识别图片中的文字内容' },
                      { label: '语音转文字', desc: 'Whisper 本地模型语音转写' },
                      { label: '网页正文提取', desc: '提取网页正文并转换为 Markdown' },
                      { label: '剪贴板监听', desc: '监听系统剪贴板变化' },
                      { label: '截图捕获', desc: '快速截图并处理' },
                      { label: '文件夹监听', desc: '监听指定文件夹的文件变化' },
                      { label: '自动化任务', desc: '配置和管理工作流自动化' },
                    ].map((item) => (
                      <div key={item.label} className="flex items-center justify-between rounded-[8px] px-3 py-2">
                        <div>
                          <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>{item.label}</p>
                          <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>{item.desc}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </SettingGroupCard>
              </div>
            )}

            {/* ── OCR 与文件转换 ────────────────────────────── */}
            {activeCategory === 'auto-tools-ocr' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">OCR 与文件转换</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    OCR 识别和文件格式转换的配置。
                  </p>
                </div>
                <SettingGroupCard title="OCR 与文件转换" description="OCR 识别和文件转换工具配置。" icon="image">
                  <EmptyState
                    icon={<AcMindIcon name="image" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
                    title="OCR 与文件转换"
                    description="相关配置即将开放。"
                  />
                </SettingGroupCard>
              </div>
            )}

            {/* ── 桌面组件 ───────────────────────────────────── */}
            {activeCategory === 'desktop-widgets' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">桌面组件</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    日程小组件、提醒浮窗、顶部 Notch 提醒等桌面展示组件。
                  </p>
                </div>

                <SettingGroupCard title="桌面组件" description="桌面辅助展示组件。" icon="all">
                  <div className="flex flex-col gap-2">
                    {[
                      { label: '日程小组件', desc: '在桌面展示今日日程' },
                      { label: '提醒浮窗', desc: '提醒到期时弹出浮窗通知' },
                      { label: '顶部 Notch 提醒', desc: '在桌面顶部 Notch 区域显示提醒状态' },
                    ].map((item) => (
                      <div key={item.label} className="flex items-center justify-between rounded-[8px] px-3 py-2">
                        <div>
                          <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>{item.label}</p>
                          <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>{item.desc}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </SettingGroupCard>

                <SettingGroupCard title="桌面工具" description="剪贴板历史、暂存架、截图等桌面辅助能力。" icon="all">
                  <div className="flex flex-col gap-2">
                    {[
                      { view: 'clipboard', label: '剪贴板历史', desc: '查看和管理剪贴板历史记录' },
                      { view: 'shelf', label: '拖拽暂存架', desc: '拖拽文件到桌面暂存架' },
                      { view: 'capture', label: '截图与贴图', desc: '快速截图和贴图工具' },
                      { view: 'capture-inbox', label: '快速记录', desc: '快速记录想法和灵感' },
                    ].map((item) => (
                      <button
                        key={item.view}
                        type="button"
                        className="flex items-center justify-between rounded-[8px] px-3 py-2 text-left transition-colors hover:bg-[color:var(--pm-bg-subtle)]"
                        onClick={() => {
                          window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: item.view } }));
                        }}
                      >
                        <div>
                          <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>{item.label}</p>
                          <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>{item.desc}</p>
                        </div>
                        <AcMindIcon name="arrow-right" size={14} style={{ color: 'var(--pm-text-tertiary)' }} />
                      </button>
                    ))}
                    <button
                      type="button"
                      className="flex items-center justify-between rounded-[8px] px-3 py-2 text-left transition-colors hover:bg-[color:var(--pm-bg-subtle)]"
                      onClick={() => {
                        window.dispatchEvent(new CustomEvent('acmind:toggle-capsule'));
                      }}
                    >
                      <div>
                        <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>桌面胶囊</p>
                        <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>切换桌面胶囊显示</p>
                      </div>
                      <AcMindIcon name="arrow-right" size={14} style={{ color: 'var(--pm-text-tertiary)' }} />
                    </button>
                  </div>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Appearance ──────────────────────────────── */}
            {activeCategory === 'appearance' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">外观</h3>
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


            {/* ── Dictation (OpenLess-inspired) ────────────────── */}
            {activeCategory === 'dictation' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">语音听写</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    按全局快捷键录音，AI 自动润色后插入光标位置。灵感来自 OpenLess。
                  </p>
                </div>

                <SettingGroupCard title="启用" description="开启后可使用快捷键触发语音听写" icon="spark">
                  <SettingsRow label="启用语音听写" description="全局快捷键触发录音，松开后自动转写并插入。快捷键可在下面自定义。">
                    <ToggleSwitch
                      checked={settings?.dictation?.enabled ?? false}
                      onChange={(checked) => {
                        void updateSetting({
                          dictation: { ...(settings?.dictation ?? DEFAULT_DICTATION_SETTINGS), enabled: checked },
                        });
                      }}
                    />
                  </SettingsRow>
                </SettingGroupCard>

                {settings?.dictation?.enabled && (
                  <>
                    <SettingGroupCard title="润色模式" description="选择语音转文字后的 AI 润色方式" icon="all">
                      <SettingsRow label="默认模式" description="录音结束后自动使用的润色模式。">
                        <select
                          value={settings?.dictation?.defaultMode ?? 'light'}
                          onChange={(e) => {
                            void updateSetting({
                              dictation: { ...settings?.dictation ?? DEFAULT_DICTATION_SETTINGS, defaultMode: e.target.value as VoicePolishMode },
                            });
                          }}
                          className="w-36 rounded-[6px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.03)] px-2.5 py-1 text-[13px] text-[color:var(--pm-text-primary)] outline-none focus:border-[color:var(--pm-border)]"
                        >
                          <option value="raw">原文（不润色）</option>
                          <option value="light">轻度润色</option>
                          <option value="structured">清晰结构</option>
                          <option value="formal">正式表达</option>
                        </select>
                      </SettingsRow>
                      <SettingsRow label="启用的模式" description="勾选后可在胶囊中切换使用。">
                        <div className="flex flex-wrap gap-2">
                          {(['raw', 'light', 'structured', 'formal'] as VoicePolishMode[]).map((mode) => {
                            const labels: Record<VoicePolishMode, string> = { raw: '原文', light: '轻度', structured: '结构', formal: '正式' };
                            const isActive = settings?.dictation?.enabledModes?.includes(mode) ?? false;
                            return (
                              <button
                                key={mode}
                                type="button"
                                onClick={() => {
                                  const current = (settings?.dictation ?? DEFAULT_DICTATION_SETTINGS).enabledModes ?? ['raw', 'light', 'structured', 'formal'];
                                  const next = isActive ? current.filter((m) => m !== mode) : [...current, mode];
                                  void updateSetting({ dictation: { ...settings?.dictation ?? DEFAULT_DICTATION_SETTINGS, enabledModes: next } });
                                }}
                                className={`rounded-full px-3 py-1 text-[12px] font-medium transition-colors ${
                                  isActive
                                    ? 'bg-[color:var(--pm-accent)] text-white'
                                    : 'bg-[color:var(--pm-bg-subtle)] text-[color:var(--pm-text-secondary)] hover:bg-[color:var(--pm-bg-hover)]'
                                }`}
                              >
                                {labels[mode]}
                              </button>
                            );
                          })}
                        </div>
                      </SettingsRow>
                    </SettingGroupCard>

                    <SettingGroupCard title="快捷键" description="全局快捷键，在任何应用中生效" icon="all">
                      <SettingsRow label="听写快捷键" description="点击录制后，直接按下想要的组合键，松开后自动保存并立即生效。">
                        <HotkeyRecorder
                          value={settings?.capsule?.shortcuts?.voiceInput ?? DEFAULT_CAPSULE_SETTINGS.shortcuts.voiceInput}
                          defaultValue={DEFAULT_CAPSULE_SETTINGS.shortcuts.voiceInput}
                          onCommit={commitDictationHotkey}
                        />
                      </SettingsRow>
                      <SettingsRow label="翻译模式" description="录音中按住 Shift 切换为翻译输出。">
                        <div className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                          录音时按住 Shift 自动切换
                        </div>
                      </SettingsRow>
                    </SettingGroupCard>

                    <SettingGroupCard title="语言" description="配置工作和翻译语言" icon="all">
                      <SettingsRow label="工作语言" description="用于 AI 润色上下文。">
                        <div className="flex flex-wrap gap-1.5">
                          {['zh-CN', 'en', 'ja', 'ko'].map((lang) => {
                            const isActive = settings?.dictation?.workingLanguages?.includes(lang) ?? false;
                            const langLabels: Record<string, string> = { 'zh-CN': '中文', en: 'English', ja: '日本語', ko: '한국어' };
                            return (
                              <button
                                key={lang}
                                type="button"
                                onClick={() => {
                                  const current = (settings?.dictation ?? DEFAULT_DICTATION_SETTINGS).workingLanguages ?? ['zh-CN', 'en'];
                                  const next = isActive ? current.filter((l) => l !== lang) : [...current, lang];
                                  void updateSetting({ dictation: { ...settings?.dictation ?? DEFAULT_DICTATION_SETTINGS, workingLanguages: next } });
                                }}
                                className={`rounded-full px-2.5 py-0.5 text-[12px] transition-colors ${
                                  isActive
                                    ? 'bg-[color:var(--pm-accent)] text-white'
                                    : 'bg-[color:var(--pm-bg-subtle)] text-[color:var(--pm-text-secondary)] hover:bg-[color:var(--pm-bg-hover)]'
                                }`}
                              >
                                {langLabels[lang] ?? lang}
                              </button>
                            );
                          })}
                        </div>
                      </SettingsRow>
                      <SettingsRow label="翻译目标语言" description="翻译模式下的输出语言。">
                        <select
                          value={settings?.dictation?.translationTargetLanguage ?? 'en'}
                          onChange={(e) => {
                            void updateSetting({
                              dictation: { ...settings?.dictation ?? DEFAULT_DICTATION_SETTINGS, translationTargetLanguage: e.target.value },
                            });
                          }}
                          className="w-36 rounded-[6px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.03)] px-2.5 py-1 text-[13px] text-[color:var(--pm-text-primary)] outline-none focus:border-[color:var(--pm-border)]"
                        >
                          <option value="en">English</option>
                          <option value="zh-CN">中文</option>
                          <option value="ja">日本語</option>
                          <option value="ko">한국어</option>
                        </select>
                      </SettingsRow>
                    </SettingGroupCard>

                    <SettingGroupCard title="粘贴行为" description="文本插入到光标位置的方式" icon="all">
                      <SettingsRow label="恢复剪贴板" description="粘贴后自动恢复之前的剪贴板内容。">
                        <ToggleSwitch
                          checked={settings?.dictation?.restoreClipboard ?? true}
                          onChange={(checked) => {
                            void updateSetting({
                              dictation: { ...settings?.dictation ?? DEFAULT_DICTATION_SETTINGS, restoreClipboard: checked },
                            });
                          }}
                        />
                      </SettingsRow>
                    </SettingGroupCard>

                    <SettingGroupCard title="依赖检查" description="语音听写需要以下系统组件" icon="all">
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <div className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                            一键自检
                          </div>
                          <div className="mt-1 text-[11px] text-[color:var(--pm-text-tertiary)]">
                            会检查浏览器麦克风、录音工具、本地/外部 ASR 配置和本地转写运行态。
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          {canInstallLocalAsr && (
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => void handleInstallLocalAsr()}
                              disabled={whisperBusy}
                            >
                              {repairingWhisper ? '安装中...' : '安装/校验本地 ASR'}
                            </Button>
                          )}
                          <Button
                            variant="secondary"
                            size="sm"
                            onClick={() => void handleRunDictationDiagnostics()}
                            disabled={runningDictationDiagnostics}
                          >
                            {runningDictationDiagnostics ? '检测中...' : '立即自检'}
                          </Button>
                        </div>
                      </div>

                      <div className="mt-4 flex flex-col gap-2">
                        <SettingsRow label="ASR 服务" description="语音转文字服务（Whisper / 火山引擎 / OpenAI-compatible）。">
                          <div className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                            {settings.transcription.provider === 'local'
                              ? `本地 ${settings.transcription.localEngine} · ${settings.transcription.localModel}`
                              : '外部 API'}
                          </div>
                        </SettingsRow>
                        <SettingsRow label="录音工具" description="macOS 需要 sox 或 rec，Linux 需要 sox 或 arecord。">
                          <div className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                            由自检按钮自动探测
                          </div>
                        </SettingsRow>
                        <SettingsRow label="AI 润色" description="非原文模式下会调用 LLM API。">
                          <div className="text-[12px]" style={{ color: 'var(--pm-text-tertiary)' }}>
                            {settings.ai?.apiKey ? '已配置' : '未配置'}
                          </div>
                        </SettingsRow>
                      </div>

                      {dictationDiagnostics && (
                        <div className="mt-4 flex flex-col gap-2 rounded-[14px] border border-[color:var(--pm-border-subtle)] bg-[rgba(0,0,0,0.015)] p-4">
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              <div className="text-[13px] font-medium text-[color:var(--pm-text-primary)]">
                                自检结果
                              </div>
                              <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">
                                {dictationDiagnostics.ok ? '全部通过' : canInstallLocalAsr ? '本地 ASR 可一键安装/校验' : '存在未满足的依赖或权限'}
                              </div>
                            </div>
                            <StatusBadge tone={dictationDiagnostics.ok ? 'success' : 'warning'} label={dictationDiagnostics.ok ? '通过' : '需处理'} dot={false} />
                          </div>

                          <div className="flex flex-col gap-2">
                            {dictationDiagnosticItems.map((item) => (
                              <div
                                key={item.key}
                                className="flex flex-col gap-1 rounded-[12px] border border-[color:var(--pm-border-subtle)] bg-white px-3 py-2.5"
                              >
                                <div className="flex items-center justify-between gap-3">
                                  <div className="text-[12px] font-medium text-[color:var(--pm-text-primary)]">
                                    {item.label}
                                  </div>
                                  <StatusBadge tone={item.ok ? 'success' : 'danger'} label={item.ok ? '通过' : '失败'} dot={false} />
                                </div>
                                <div className="text-[11px] leading-5 text-[color:var(--pm-text-tertiary)]">
                                  {item.message}
                                </div>
                                {!item.ok && item.key === 'browser_microphone' && (
                                  <div className="mt-1 flex items-center gap-2">
                                    <Button
                                      variant="secondary"
                                      size="sm"
                                      onClick={() => void handleRequestMicrophoneAccess()}
                                      disabled={runningDictationDiagnostics}
                                    >
                                      请求麦克风权限
                                    </Button>
                                  </div>
                                )}
                                {!item.ok && item.key === 'recorder_tool' && (
                                  <div className="mt-1 flex items-center gap-2">
                                    <Button
                                      variant="secondary"
                                      size="sm"
                                      onClick={() => void handleCopyRecorderInstallCommand()}
                                    >
                                      复制安装命令
                                    </Button>
                                  </div>
                                )}
                              </div>
                            ))}
                          </div>
                        </div>
                      )}
                    </SettingGroupCard>
                  </>
                )}
              </div>
            )}

            {/* ── Advanced Logs ────────────────────────────── */}
            {activeCategory === 'advanced-logs' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">日志</h3>
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

            {/* ── Advanced Data ─────────────────────────────── */}
            {activeCategory === 'advanced-data' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">数据维护</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    管理本地数据、清理缓存、导出备份。危险操作需要二次确认。
                  </p>
                </div>
                <SettingGroupCard title="数据目录" description="查看和管理 AcMind 数据存储位置" icon="duplicate">
                  <div className="flex flex-col gap-3">
                    <div className="flex items-center justify-between">
                      <span className="text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>数据目录</span>
                      <code className="text-[12px] px-2 py-0.5 rounded" style={{ background: 'var(--pm-bg-surface-soft, rgba(0,0,0,0.04))' }}>
                        {settings?.storageRoot || '未配置'}
                      </code>
                    </div>
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={async () => {
                        try {
                          await window.acmind.app.openPath(settings?.storageRoot || '');
                        } catch (e) {
                          addToast('无法打开数据目录', 'error');
                        }
                      }}
                    >
                      打开数据目录
                    </Button>
                  </div>
                </SettingGroupCard>

                <SettingGroupCard title="数据清理" description="清理不需要的临时数据" icon="duplicate">
                  <div className="flex flex-col gap-3">
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={async () => {
                        if (!window.confirm('确定要清理 Clipboard 历史记录吗？此操作不可撤销。')) return;
                        try {
                          await window.acmind.clipboard.clearHistory();
                          addToast('Clipboard 历史已清理', 'success');
                        } catch (e) {
                          addToast('清理失败', 'error');
                        }
                      }}
                    >
                      清理 Clipboard 历史
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={async () => {
                        if (!window.confirm('确定要清理 Shelf 临时项吗？此操作不可撤销。')) return;
                        try {
                          const items = await window.acmind.shelf.listItems();
                          for (const item of (items.items || [])) {
                            try { await window.acmind.shelf.removeItem(item.id); } catch { /* skip */ }
                          }
                          addToast('Shelf 已清理', 'success');
                        } catch (e) {
                          addToast('清理失败', 'error');
                        }
                      }}
                    >
                      清理 Shelf 临时项
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={async () => {
                        if (!window.confirm('确定要清理已解决的错误记录吗？')) return;
                        try {
                          await window.acmind.errors.clearResolved();
                          addToast('已清理错误记录', 'success');
                        } catch (e) {
                          addToast('清理失败', 'error');
                        }
                      }}
                    >
                      清理已解决错误
                    </Button>
                  </div>
                </SettingGroupCard>

                <SettingGroupCard title="数据备份" description="导出数据库备份和设置" icon="duplicate">
                  <div className="flex flex-col gap-3">
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={async () => {
                        try {
                          await (window.acmind.settings as any).exportBackup();
                          addToast('备份已导出', 'success');
                        } catch (e) {
                          addToast('备份导出失败', 'error');
                        }
                      }}
                    >
                      导出备份
                    </Button>
                  </div>
                </SettingGroupCard>
              </div>
            )}

            {/* ── Advanced Dev ──────────────────────────────── */}
            {activeCategory === 'advanced-dev' && (
              <div className="flex flex-col gap-5">
                <div className="mt-7">
                  <h3 className="acmind-page-title">开发者选项</h3>
                  <p className="mt-1 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    诊断信息和调试工具。仅在需要排查问题时使用。
                  </p>
                </div>
                <SettingGroupCard title="应用信息" description="当前版本和运行环境" icon="settings">
                  <div className="flex flex-col gap-2 text-[13px]" style={{ color: 'var(--pm-text-secondary)' }}>
                    <div className="flex justify-between">
                      <span>版本</span>
                      <span>{(window as any).__ACMIND_VERSION__ || '未知'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>平台</span>
                      <span>{navigator.platform || '未知'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>数据目录</span>
                      <span className="truncate max-w-[200px]">{settings?.storageRoot || '未知'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Electron</span>
                      <span>{navigator.userAgent.includes('Electron') ? '是' : '否'}</span>
                    </div>
                  </div>
                </SettingGroupCard>

                <SettingGroupCard title="诊断" description="复制诊断信息用于问题排查" icon="settings">
                  <div className="flex flex-col gap-3">
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={async () => {
                        try {
                          const stats = await window.acmind.dashboard.getStats();
                          const info = [
                            `AcMind Diagnostics`,
                            `Version: ${(window as any).__ACMIND_VERSION__ || 'unknown'}`,
                            `Platform: ${navigator.platform}`,
                            `DataDir: ${settings?.storageRoot || 'unknown'}`,
                            `TodayCollected: ${stats?.todayCollected ?? '?'}`,
                            `InboxPending: ${stats?.inboxPending ?? '?'}`,
                            `ClipboardWatching: ${stats?.clipboardWatching ? 'yes' : 'no'}`,
                            `AIProviderReady: ${stats?.aiProviderReady ? 'yes' : 'no'}`,
                            `VaultConfigured: ${stats?.vaultConfigured ? 'yes' : 'no'}`,
                          ].join('\n');
                          await navigator.clipboard.writeText(info);
                          addToast('诊断信息已复制到剪贴板', 'success');
                        } catch (e) {
                          addToast('获取诊断信息失败', 'error');
                        }
                      }}
                    >
                      复制诊断信息
                    </Button>
                  </div>
                </SettingGroupCard>

                <SettingGroupCard title="日志" description="查看应用日志" icon="settings">
                  <div className="flex flex-col gap-3">
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={async () => {
                        try {
                          await window.acmind.app.openPath(settings?.storageRoot || '');
                        } catch (e) {
                          addToast('无法打开日志目录', 'error');
                        }
                      }}
                    >
                      打开日志目录
                    </Button>
                  </div>
                </SettingGroupCard>

                <SettingGroupCard title="高级功能入口" description="这里放置 AI 服务、任务队列、数据集、诊断等高级能力。普通使用无需频繁调整。" icon="filled-cloud">
                  <div className="flex flex-col gap-2">
                    {[
                      { view: 'ai', label: 'AI Console', desc: 'AI 服务状态与配置' },
                      { view: 'task-queue', label: '任务队列', desc: '查看和管理后台任务' },
                      { view: 'datasets', label: '数据集', desc: '管理训练数据集' },
                      { view: 'automation', label: '自动化', desc: '自动化规则与流程' },
                    ].map((item) => (
                      <button
                        key={item.view}
                        type="button"
                        className="flex items-center justify-between rounded-[8px] px-3 py-2 text-left transition-colors hover:bg-[color:var(--pm-bg-subtle)]"
                        onClick={() => {
                          window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: item.view } }));
                        }}
                      >
                        <div>
                          <p className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>{item.label}</p>
                          <p className="text-[11px]" style={{ color: 'var(--pm-text-tertiary)' }}>{item.desc}</p>
                        </div>
                        <AcMindIcon name="arrow-right" size={14} style={{ color: 'var(--pm-text-tertiary)' }} />
                      </button>
                    ))}
                  </div>
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
                  <h3 className="acmind-page-title">
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
          description="开启后，AcMind 会在桌面显示一个可快速记录灵感的小胶囊。"
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
        <SettingsRow label="启动 AcMind 后自动显示" description="打开应用后自动显示胶囊。">
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
          <div className="acmind-setting-row settings-row">
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
              <option value="acmind-inbox">AcMind 收集箱</option>
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
            <AcMindIcon name="edit" size={11} className="text-[color:var(--pm-text-tertiary)]" />
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
    <div className="acmind-setting-row settings-row">
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
