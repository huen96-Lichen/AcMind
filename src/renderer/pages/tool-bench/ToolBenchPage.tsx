import { useState, useEffect, useCallback } from 'react';
import { Button, Card, EmptyState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { ScrollContainer } from '../../components/shared/ScrollContainer';
import { useToast } from '../../components/shared/ToastViewport';
import { ZToolsPage } from '../ztools/ZToolsPage';
import type { GithubToolProject, LocalScriptTool, ToolProjectCategory, LocalScriptSafetyLevel } from '../../../shared/types';

// ─── Types ──────────────────────────────────────────────────────────────────

type ToolType = 'builtin' | 'github' | 'script' | 'web' | 'ai' | 'workflow';
type ToolStatus = 'ready' | 'not_configured' | 'coming_soon';

interface ToolCard {
  id: string;
  name: string;
  description: string;
  type: ToolType;
  status: ToolStatus;
  tags: string[];
  icon: string;
  primaryActionLabel: string;
  targetView?: string;
  agentCallable?: boolean;
}

interface WorkflowTemplate {
  id: string;
  name: string;
  description: string;
  steps: string[];
  icon: string;
}

// ─── Constants ──────────────────────────────────────────────────────────────

type ToolBenchTab = 'overview' | 'file-converter' | 'ocr' | 'audio-transcription' | 'webpage-parser' | 'clipboard' | 'screenshot' | 'folder-watch' | 'automation' | 'local-models' | 'runtime-status';

const TABS: { key: ToolBenchTab; label: string; icon: string }[] = [
  { key: 'overview', label: '工具总览', icon: 'all' },
  { key: 'file-converter', label: '文件转 Markdown', icon: 'feat-markdown' },
  { key: 'ocr', label: 'OCR 图像识别', icon: 'image' },
  { key: 'audio-transcription', label: '语音转文字', icon: 'record' },
  { key: 'webpage-parser', label: '网页正文提取', icon: 'brand-web-clipper' },
  { key: 'clipboard', label: '剪贴板监听', icon: 'filled-clipboard' },
  { key: 'screenshot', label: '截图捕获', icon: 'capture' },
  { key: 'folder-watch', label: '文件夹监听', icon: 'sb-inbox' },
  { key: 'automation', label: '自动化任务', icon: 'sb-ai-process' },
  { key: 'local-models', label: '本地模型', icon: 'ai-workspace' },
  { key: 'runtime-status', label: '运行状态', icon: 'sb-settings' },
];

// Agent-first: 内置工具增加 agentCallable 标记
const BUILTIN_TOOLS: ToolCard[] = [
  { id: 'file-converter', name: '文件转 Markdown', description: '将 PDF、DOCX、PPTX 等文件转换为 Markdown 格式', type: 'builtin', status: 'ready', tags: ['转换', 'Markdown'], icon: 'feat-markdown', primaryActionLabel: '打开', targetView: 'file-converter' },
  { id: 'ocr', name: '图片 OCR', description: '识别图片中的文字内容，支持多语言', type: 'builtin', status: 'ready', tags: ['OCR', '图片'], icon: 'image', primaryActionLabel: '打开' },
  { id: 'audio-transcription', name: '音频转文字', description: '将语音录音转为文字，支持 Whisper 本地模型', type: 'builtin', status: 'ready', tags: ['语音', '转写'], icon: 'record', primaryActionLabel: '打开', targetView: 'voice-dictionary' },
  { id: 'webpage-parser', name: '网页转 Markdown', description: '提取网页正文内容并转换为 Markdown', type: 'builtin', status: 'ready', tags: ['网页', 'Markdown'], icon: 'brand-web-clipper', primaryActionLabel: '打开' },
  { id: 'markdown-cleaner', name: 'Markdown 清洗', description: '清理和格式化 Markdown 文本', type: 'builtin', status: 'coming_soon', tags: ['Markdown', '清洗'], icon: 'text', primaryActionLabel: '即将支持' },
  { id: 'screenshot-pin', name: '截图 Pin', description: '快速截图并 Pin 到暂存池', type: 'builtin', status: 'ready', tags: ['截图', '捕获'], icon: 'capture', primaryActionLabel: '截图', targetView: 'capture' },
  { id: 'voice-pin', name: '语音 Pin', description: '录制语音并 Pin 到暂存池', type: 'builtin', status: 'ready', tags: ['语音', '捕获'], icon: 'record', primaryActionLabel: '录制', targetView: 'voice-dictionary' },
];

// Agent 可调用工具列表
const AGENT_CALLABLE_TOOLS = ['file-converter', 'ocr', 'audio-transcription', 'webpage-parser', 'screenshot-pin', 'voice-pin'];

const WORKFLOW_TEMPLATES: WorkflowTemplate[] = [
  { id: 'wf-web', name: '网页资料整理', description: '从 URL 提取网页正文，转为 Markdown，AI 摘要后存入暂存池', steps: ['URL → 网页正文提取', '→ Markdown', '→ AI 摘要', '→ 暂存池'], icon: 'brand-web-clipper' },
  { id: 'wf-file', name: '文件入库', description: '将 PDF / DOCX 转为 Markdown，经 AI 蒸馏后导出到 Obsidian', steps: ['PDF / DOCX', '→ Markdown', '→ AI 蒸馏', '→ Obsidian'], icon: 'feat-file-import' },
  { id: 'wf-voice', name: '语音灵感', description: '录音后经 ASR 转写，AI 润色后存为语音 Pin', steps: ['录音', '→ ASR 转写', '→ AI 润色', '→ 语音 Pin', '→ 暂存池'], icon: 'record' },
  { id: 'wf-screenshot', name: '截图理解', description: '截图后经 OCR 识别，AI 摘要后存入暂存池', steps: ['截图', '→ OCR', '→ AI 摘要', '→ 暂存池'], icon: 'capture' },
];

const STATUS_LABELS: Record<ToolStatus, { label: string; tone: 'success' | 'warning' | 'neutral' }> = {
  ready: { label: '可用', tone: 'success' },
  not_configured: { label: '需要配置', tone: 'warning' },
  coming_soon: { label: '即将支持', tone: 'neutral' },
};

const PROJECT_STATUS_LABELS: Record<string, { label: string; tone: 'success' | 'warning' | 'danger' | 'neutral' }> = {
  available: { label: '可用', tone: 'success' },
  saved: { label: '已保存', tone: 'neutral' },
  missing_path: { label: '路径不存在', tone: 'warning' },
  not_configured: { label: '未配置', tone: 'warning' },
  error: { label: '错误', tone: 'danger' },
};

const CATEGORY_LABELS: Record<string, string> = {
  capture: '捕获', convert: '转换', ai: 'AI', automation: '自动化',
  desktop: '桌面', dev: '开发', knowledge: '知识', other: '其他',
};

const SAFETY_LABELS: Record<string, { label: string; tone: 'success' | 'warning' | 'danger' }> = {
  safe: { label: '安全', tone: 'success' },
  needs_review: { label: '需确认', tone: 'warning' },
  dangerous: { label: '高风险', tone: 'danger' },
};

const CATEGORIES: { value: ToolProjectCategory; label: string }[] = [
  { value: 'capture', label: '捕获' }, { value: 'convert', label: '转换' },
  { value: 'ai', label: 'AI' }, { value: 'automation', label: '自动化' },
  { value: 'desktop', label: '桌面' }, { value: 'dev', label: '开发' },
  { value: 'knowledge', label: '知识' }, { value: 'other', label: '其他' },
];

const SAFETY_LEVELS: { value: LocalScriptSafetyLevel; label: string }[] = [
  { value: 'safe', label: '安全' }, { value: 'needs_review', label: '需确认' }, { value: 'dangerous', label: '高风险' },
];

const FEATURED_SEARCH_TOOL_PATH = '/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main';
const FEATURED_SEARCH_TOOL_REPO = 'https://github.com/ZToolsCenter/ZTools';

// ─── Helpers ────────────────────────────────────────────────────────────────

const navigate = (view: string) => {
  window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view } }));
};

const inputCls = 'w-full rounded-[8px] border border-[color:var(--border-light)] bg-white/70 px-3 py-2 text-[13px] outline-none focus:border-[color:var(--pm-brand)] transition-colors';
const labelCls = 'text-[12px] font-medium mb-1 block';
const selectCls = 'w-full rounded-[8px] border border-[color:var(--border-light)] bg-white/70 px-3 py-2 text-[13px] outline-none';

// ─── 调度任务相关辅助 ─────────────────────────────────────────────────────

interface ScheduledTask {
  id: string;
  type: 'auto_distill' | 'auto_export' | 'cleanup';
  name: string;
  cronExpr: string;
  config: Record<string, unknown>;
  enabled: boolean;
  lastRunAt: number | null;
  nextRunAt: number | null;
  nextRunAtEstimated: boolean;
  lastResult: {
    success: boolean;
    startedAt: number;
    finishedAt: number;
    itemsProcessed: number;
    error?: string;
    summary?: string;
  } | null;
  createdAt: number;
}

function cronToReadable(cron: string): string {
  const map: Record<string, string> = {
    '0 */2 * * *': '每2小时',
    '0 0 * * *': '每天午夜',
    '0 8 * * *': '每天早上8点',
    '0 20 * * *': '每天晚上8点',
    '0 0 * * 0': '每周日午夜',
    '0 0 1 * *': '每月1号',
  };
  return map[cron] || cron;
}

function taskTypeLabel(type: string): string {
  const map: Record<string, string> = {
    auto_distill: '自动整理',
    auto_export: '自动导出',
    cleanup: '自动清理',
  };
  return map[type] || type;
}

function taskTypeBadgeTone(type: string): 'info' | 'success' | 'warning' {
  const map: Record<string, 'info' | 'success' | 'warning'> = {
    auto_distill: 'info',
    auto_export: 'success',
    cleanup: 'warning',
  };
  return map[type] || 'info';
}

function relativeTime(ts: number | null): string {
  if (ts === null) return '—';
  const diff = Date.now() - ts;
  const absDiff = Math.abs(diff);
  const future = diff < 0;
  const minutes = Math.floor(absDiff / 60000);
  const hours = Math.floor(absDiff / 3600000);
  const days = Math.floor(absDiff / 86400000);
  let text: string;
  if (minutes < 1) text = '刚刚';
  else if (minutes < 60) text = `${minutes}分钟`;
  else if (hours < 24) text = `${hours}小时`;
  else text = `${days}天`;
  return future ? `${text}后` : `${text}前`;
}

// ─── 自动工具：AcMind 可调用的处理能力 ───────────────────────────────

export function ToolBenchPage(): JSX.Element {
  const [activeTab, setActiveTab] = useState<ToolBenchTab>(() => {
    const tab = new URLSearchParams(window.location.search).get('tab');
    return isToolBenchTab(tab) ? tab : 'overview';
  });

  useEffect(() => {
    const syncTabFromUrl = () => {
      const tab = new URLSearchParams(window.location.search).get('tab');
      setActiveTab(isToolBenchTab(tab) ? tab : 'overview');
    };

    window.addEventListener('popstate', syncTabFromUrl);
    return () => window.removeEventListener('popstate', syncTabFromUrl);
  }, []);

  return (
    <PageShell>
      <ScrollContainer>
        <PageHeader
          title="自动工具"
          description="AcMind 可调用的处理能力 — 文件转换、OCR、语音转文字、自动化等"
        />

        <div className="flex items-center gap-1 px-6 pt-4">
          {TABS.map((tab) => (
            <button
              key={tab.key}
              type="button"
              className={`flex items-center gap-1.5 rounded-[8px] px-3 py-1.5 text-[13px] font-medium transition-colors ${
                activeTab === tab.key
                  ? 'bg-[color:var(--pm-brand)] text-white'
                  : 'text-[color:var(--text-muted)] hover:bg-[color:var(--pm-bg-subtle)]'
              }`}
              onClick={() => setActiveTab(tab.key)}
            >
              <AcMindIcon name={tab.icon as any} size={14} />
              {tab.label}
            </button>
          ))}
        </div>

        <div className="px-6 py-4">
          {activeTab === 'overview' && <OverviewTab />}
          {activeTab === 'file-converter' && <ToolDetailTab tool={BUILTIN_TOOLS.find(t => t.id === 'file-converter')!} />}
          {activeTab === 'ocr' && <ToolDetailTab tool={BUILTIN_TOOLS.find(t => t.id === 'ocr')!} />}
          {activeTab === 'audio-transcription' && <ToolDetailTab tool={BUILTIN_TOOLS.find(t => t.id === 'audio-transcription')!} />}
          {activeTab === 'webpage-parser' && <ToolDetailTab tool={BUILTIN_TOOLS.find(t => t.id === 'webpage-parser')!} />}
          {activeTab === 'clipboard' && <ClipboardTab />}
          {activeTab === 'screenshot' && <ScreenshotTab />}
          {activeTab === 'folder-watch' && <FolderWatchTab />}
          {activeTab === 'automation' && <AutomationTab />}
          {activeTab === 'local-models' && <LocalModelsTab />}
          {activeTab === 'runtime-status' && <RuntimeStatusTab />}
        </div>
      </ScrollContainer>
    </PageShell>
  );
}

function isToolBenchTab(tab: string | null): tab is ToolBenchTab {
  return tab === 'overview' || tab === 'file-converter' || tab === 'ocr' || tab === 'audio-transcription' || tab === 'webpage-parser' || tab === 'clipboard' || tab === 'screenshot' || tab === 'folder-watch' || tab === 'automation' || tab === 'local-models' || tab === 'runtime-status';
}

// ── 常用工具 ──

// ── 工具总览 ──

function OverviewTab(): JSX.Element {
  return (
    <Section title="工具总览" description="AcMind 所有可调用的处理能力。" compact>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
        {BUILTIN_TOOLS.map((tool) => (
          <ToolCardComponent key={tool.id} tool={tool} />
        ))}
      </div>
    </Section>
  );
}

// ── 工具详情页（通用） ──

function ToolDetailTab({ tool }: { tool: ToolCard }): JSX.Element {
  return (
    <Section title={tool.name} description={tool.description} compact>
      <Card variant="base" className="p-4">
        <div className="flex items-center gap-3">
          <AcMindIcon name={tool.icon as any} size={24} style={{ color: 'var(--pm-brand)' }} />
          <div>
            <div className="text-[14px] font-medium">{tool.name}</div>
            <div className="text-[12px]" style={{ color: 'var(--pm-text-secondary)' }}>{tool.description}</div>
          </div>
        </div>
        <div className="mt-3 flex items-center gap-2">
          <span className={`inline-flex items-center rounded-[6px] px-2 py-0.5 text-[11px] font-medium ${
            tool.status === 'ready'
              ? 'bg-green-50 text-green-700'
              : tool.status === 'coming_soon'
                ? 'bg-amber-50 text-amber-700'
                : 'bg-gray-50 text-gray-600'
          }`}>
            {tool.status === 'ready' ? '可用' : tool.status === 'coming_soon' ? '即将支持' : '未知'}
          </span>
          {tool.tags?.map((tag) => (
            <span key={tag} className="inline-flex items-center rounded-[6px] bg-[color:var(--pm-bg-subtle)] px-2 py-0.5 text-[11px]" style={{ color: 'var(--pm-text-secondary)' }}>
              {tag}
            </span>
          ))}
        </div>
      </Card>
    </Section>
  );
}

// ── 剪贴板监听 ──

function ClipboardTab(): JSX.Element {
  return (
    <Section title="剪贴板监听" description="监听系统剪贴板变化，自动捕获内容。" compact>
      <Card variant="base" className="p-4">
        <div className="flex items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
            <AcMindIcon name="filled-clipboard" size={20} style={{ color: 'var(--pm-brand)' }} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>剪贴板自动监听</p>
              <StatusBadge tone="success" label="后台运行中" />
            </div>
            <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
              AcMind 后台会自动监听系统剪贴板变化，捕获复制的内容（文本、图片、文件等）并送入工作台处理。
            </p>
            <p className="mt-2 text-[12px]" style={{ color: 'var(--text-muted)' }}>
              你无需手动开启或关闭，剪贴板监听随 AcMind 启动自动运行。复制任何内容后，可在剪贴板页面查看历史记录。
            </p>
          </div>
        </div>
        <div className="mt-4 flex gap-2">
          <Button
            variant="primary"
            size="sm"
            leadingIcon={<AcMindIcon name="filled-clipboard" size={14} />}
            onClick={() => navigate('clipboard')}
          >
            查看剪贴板历史
          </Button>
        </div>
      </Card>
    </Section>
  );
}

// ── 截图捕获 ──

function ScreenshotTab(): JSX.Element {
  const { addToast } = useToast();
  const [capturing, setCapturing] = useState(false);

  const handleScreenshot = async () => {
    try {
      setCapturing(true);
      await window.acmind.capture?.takeScreenshot();
      addToast('截图已捕获', 'success');
    } catch (err) {
      addToast(`截图失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setCapturing(false);
    }
  };

  return (
    <Section title="截图捕获" description="快速截图并处理。" compact>
      <Card variant="base" className="p-4">
        <div className="flex items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
            <AcMindIcon name="capture" size={20} style={{ color: 'var(--pm-brand)' }} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>截图捕获</p>
              <StatusBadge tone="success" label="可用" />
            </div>
            <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
              截取屏幕内容后，AcMind 会自动进行 OCR 识别或送入工作台进行 AI 分析。支持全屏截图和区域选择。
            </p>
            <p className="mt-2 text-[12px]" style={{ color: 'var(--text-muted)' }}>
              截图结果会自动保存到暂存池，你可以在截图页面查看和管理所有截图记录。
            </p>
          </div>
        </div>
        <div className="mt-4 flex gap-2">
          <Button
            variant="primary"
            size="sm"
            leadingIcon={<AcMindIcon name="capture" size={14} />}
            disabled={capturing}
            onClick={() => void handleScreenshot()}
          >
            {capturing ? '截图中...' : '立即截图'}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            leadingIcon={<AcMindIcon name="filled-search" size={14} />}
            onClick={() => navigate('capture')}
          >
            查看截图历史
          </Button>
        </div>
      </Card>
    </Section>
  );
}

// ── 文件夹监听 ──

function FolderWatchTab(): JSX.Element {
  const { addToast } = useToast();
  const [watchPath, setWatchPath] = useState('');
  const [watching, setWatching] = useState(false);
  const [loading, setLoading] = useState(true);
  const [currentState, setCurrentState] = useState<{ status: string; watchPath: string | null; error: string | null; importedCount: number; pendingCount: number } | null>(null);

  const loadWatchState = useCallback(async () => {
    try {
      const state = await window.acmind.voice?.getWatchState();
      setCurrentState(state ?? { status: 'idle', watchPath: null, error: null, importedCount: 0, pendingCount: 0 });
      if (state?.watchPath) {
        setWatchPath(state.watchPath);
      }
    } catch {
      setCurrentState({ status: 'idle', watchPath: null, error: null, importedCount: 0, pendingCount: 0 });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadWatchState(); }, [loadWatchState]);

  const handleStart = async () => {
    if (!watchPath.trim()) { addToast('请输入文件夹路径', 'warning'); return; }
    try {
      setWatching(true);
      await window.acmind.voice?.startWatch(watchPath.trim());
      addToast(`已开始监听: ${watchPath.trim()}`, 'success');
      await loadWatchState();
    } catch (err) {
      addToast(`启动失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setWatching(false);
    }
  };

  const handleStop = async () => {
    try {
      setWatching(true);
      await window.acmind.voice?.stopWatch();
      addToast('已停止监听', 'info');
      await loadWatchState();
    } catch (err) {
      addToast(`停止失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setWatching(false);
    }
  };

  const isCurrentlyWatching = currentState?.status === 'watching';

  return (
    <Section title="文件夹监听" description="监听指定文件夹的文件变化。" compact>
      <Card variant="base" className="p-4">
        <div className="flex items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
            <AcMindIcon name="sb-inbox" size={20} style={{ color: 'var(--pm-brand)' }} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>文件夹监听</p>
              {loading ? (
                <StatusBadge tone="neutral" label="检测中..." />
              ) : isCurrentlyWatching ? (
                <StatusBadge tone="success" label="监听中" />
              ) : (
                <StatusBadge tone="neutral" label="未监听" />
              )}
            </div>
            <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
              自动发现指定文件夹中的新增文件，并送入工作台处理流程。适用于持续监控下载目录、截图目录等场景。
            </p>
          </div>
        </div>

        {isCurrentlyWatching && currentState?.watchPath && (
          <div className="mt-3 rounded-[8px] bg-green-50 px-3 py-2 text-[12px] text-green-700">
            当前监听路径: <span className="font-mono">{currentState.watchPath}</span>
          </div>
        )}

        <div className="mt-3 flex gap-2">
          <input
            className={inputCls}
            style={{ flex: 1 }}
            value={watchPath}
            onChange={e => setWatchPath(e.target.value)}
            placeholder="输入文件夹路径，例如 /Users/you/Downloads"
            disabled={isCurrentlyWatching}
          />
          {!isCurrentlyWatching ? (
            <Button
              variant="primary"
              size="sm"
              disabled={watching || !watchPath.trim()}
              onClick={() => void handleStart()}
            >
              {watching ? '启动中...' : '启动监听'}
            </Button>
          ) : (
            <Button
              variant="danger"
              size="sm"
              disabled={watching}
              onClick={() => void handleStop()}
            >
              {watching ? '停止中...' : '停止监听'}
            </Button>
          )}
        </div>
      </Card>
    </Section>
  );
}

// ── 自动化任务 ──

function AutomationTab(): JSX.Element {
  const { addToast } = useToast();
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [runningId, setRunningId] = useState<string | null>(null);

  const loadTasks = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await window.acmind.scheduler.getTasks();
      setTasks(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadTasks(); }, [loadTasks]);

  const handleToggle = async (id: string) => {
    try {
      await window.acmind.scheduler.toggleTask(id, !tasks.find(t => t.id === id)?.enabled);
      addToast('状态已更新', 'info');
      await loadTasks();
    } catch (err) {
      addToast(`切换失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    }
  };

  const handleRunNow = async (id: string) => {
    try {
      setRunningId(id);
      await window.acmind.scheduler.runNow(id);
      addToast('任务已触发执行', 'success');
      await loadTasks();
    } catch (err) {
      addToast(`执行失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setRunningId(null);
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await window.acmind.scheduler.deleteTask(id);
      setTasks(prev => prev.filter(t => t.id !== id));
      setConfirmDeleteId(null);
      addToast('任务已删除', 'info');
    } catch (err) {
      addToast(`删除失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    }
  };

  const enabledCount = tasks.filter(t => t.enabled).length;
  const successCount = tasks.filter(t => t.lastResult?.success).length;
  const failCount = tasks.filter(t => t.lastResult && !t.lastResult.success).length;

  return (
    <Section title="自动化任务" description="配置和管理工作流自动化。" compact>
      {/* 统计概览 */}
      {!loading && tasks.length > 0 && (
        <div className="mb-4 grid grid-cols-4 gap-3">
          <Card variant="base" className="p-3 text-center">
            <p className="text-[20px] font-semibold" style={{ color: 'var(--text-title)' }}>{tasks.length}</p>
            <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>总任务</p>
          </Card>
          <Card variant="base" className="p-3 text-center">
            <p className="text-[20px] font-semibold" style={{ color: 'var(--pm-status-success, #22c55e)' }}>{enabledCount}</p>
            <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>已启用</p>
          </Card>
          <Card variant="base" className="p-3 text-center">
            <p className="text-[20px] font-semibold" style={{ color: 'var(--pm-status-success, #22c55e)' }}>{successCount}</p>
            <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>上次成功</p>
          </Card>
          <Card variant="base" className="p-3 text-center">
            <p className="text-[20px] font-semibold" style={{ color: 'var(--pm-status-danger, #ef4444)' }}>{failCount}</p>
            <p className="text-[11px]" style={{ color: 'var(--text-muted)' }}>上次失败</p>
          </Card>
        </div>
      )}

      {loading && <p className="text-[13px]" style={{ color: 'var(--text-muted)' }}>加载中...</p>}
      {error && <p className="text-[13px]" style={{ color: 'var(--pm-status-danger, #ef4444)' }}>加载失败: {error}</p>}

      {!loading && !error && tasks.length === 0 && (
        <EmptyState
          icon={<AcMindIcon name="sb-ai-process" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="暂无自动化任务"
          description="自动化任务可让 AcMind 按计划自动执行整理、导出、清理等操作。"
        />
      )}

      {!loading && !error && tasks.length > 0 && (
        <div className="flex flex-col gap-3">
          {tasks.map((task) => (
            <Card key={task.id} variant="base" className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{task.name}</p>
                    <StatusBadge tone={taskTypeBadgeTone(task.type)} label={taskTypeLabel(task.type)} />
                    <StatusBadge tone={task.enabled ? 'success' : 'neutral'} label={task.enabled ? '已启用' : '已关闭'} />
                  </div>

                  <div className="mt-2 grid grid-cols-2 gap-x-4 gap-y-1">
                    <div className="flex items-center justify-between text-[12px]">
                      <span style={{ color: 'var(--text-muted)' }}>执行频率</span>
                      <span style={{ color: 'var(--text-title)' }}>{cronToReadable(task.cronExpr)}</span>
                    </div>
                    <div className="flex items-center justify-between text-[12px]">
                      <span style={{ color: 'var(--text-muted)' }}>上次运行</span>
                      <span style={{ color: 'var(--text-title)' }}>{task.lastRunAt ? relativeTime(task.lastRunAt) : '从未运行'}</span>
                    </div>
                    <div className="flex items-center justify-between text-[12px]">
                      <span style={{ color: 'var(--text-muted)' }}>下次运行</span>
                      <span style={{ color: 'var(--text-title)' }}>
                        {task.nextRunAt ? `${relativeTime(task.nextRunAt)}${task.nextRunAtEstimated ? ' (预估)' : ''}` : '—'}
                      </span>
                    </div>
                    <div className="flex items-center justify-between text-[12px]">
                      <span style={{ color: 'var(--text-muted)' }}>上次结果</span>
                      {task.lastResult ? (
                        <StatusBadge tone={task.lastResult.success ? 'success' : 'danger'} label={task.lastResult.success ? '成功' : '失败'} />
                      ) : (
                        <span style={{ color: 'var(--text-muted)' }}>—</span>
                      )}
                    </div>
                  </div>

                  {task.lastResult?.summary && (
                    <p className="mt-1 text-[11px]" style={{ color: 'var(--text-muted)' }}>{task.lastResult.summary}</p>
                  )}
                  {task.lastResult?.error && (
                    <p className="mt-1 text-[11px]" style={{ color: 'var(--pm-status-danger, #ef4444)' }}>{task.lastResult.error}</p>
                  )}
                </div>

                <div className="flex shrink-0 flex-col gap-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => void handleToggle(task.id)}
                  >
                    {task.enabled ? '禁用' : '启用'}
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    disabled={runningId === task.id}
                    onClick={() => void handleRunNow(task.id)}
                  >
                    {runningId === task.id ? '执行中...' : '立即执行'}
                  </Button>
                  {confirmDeleteId === task.id ? (
                    <div className="flex gap-1">
                      <Button variant="danger" size="sm" onClick={() => void handleDelete(task.id)}>确认</Button>
                      <Button variant="ghost" size="sm" onClick={() => setConfirmDeleteId(null)}>取消</Button>
                    </div>
                  ) : (
                    <Button variant="ghost" size="sm" onClick={() => setConfirmDeleteId(task.id)}>删除</Button>
                  )}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </Section>
  );
}

// ── 本地模型 ──

interface WhisperModel {
  size: string;
  displayName: string;
  cached: boolean;
  cachePath?: string;
  cacheSize?: number;
}

interface WhisperStatus {
  available: boolean;
  initialized: boolean;
  currentModel?: string;
  loading: boolean;
  error?: string;
}

function LocalModelsTab(): JSX.Element {
  const { addToast } = useToast();
  const [status, setStatus] = useState<WhisperStatus | null>(null);
  const [models, setModels] = useState<WhisperModel[]>([]);
  const [loading, setLoading] = useState(true);
  const [downloading, setDownloading] = useState<string | null>(null);
  const [downloadProgress, setDownloadProgress] = useState(0);
  const [initializing, setInitializing] = useState(false);
  const [repairing, setRepairing] = useState(false);

  const loadData = useCallback(async () => {
    try {
      const [statusResult, modelsResult] = await Promise.all([
        window.acmind.whisper?.getStatus(),
        window.acmind.whisper?.getModels(),
      ]);
      setStatus(statusResult ?? null);
      setModels(modelsResult ?? []);
    } catch {
      // Whisper API may not be available
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);

  const handleDownload = async (size: string) => {
    try {
      setDownloading(size);
      setDownloadProgress(0);
      await window.acmind.whisper?.downloadModel(size, (progress: number) => {
        setDownloadProgress(progress);
      });
      addToast(`模型 ${size} 下载完成`, 'success');
      await loadData();
    } catch (err) {
      addToast(`下载失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setDownloading(null);
      setDownloadProgress(0);
    }
  };

  const handleDelete = async (size: string) => {
    try {
      await window.acmind.whisper?.deleteModel(size);
      addToast(`模型 ${size} 已删除`, 'info');
      await loadData();
    } catch (err) {
      addToast(`删除失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    }
  };

  const handleInitialize = async (size: string) => {
    try {
      setInitializing(true);
      await window.acmind.whisper?.initialize(size);
      addToast(`模型 ${size} 初始化完成`, 'success');
      await loadData();
    } catch (err) {
      addToast(`初始化失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setInitializing(false);
    }
  };

  const handleRepair = async () => {
    try {
      setRepairing(true);
      await window.acmind.whisper?.repair((progress: number) => {
        setDownloadProgress(progress);
      });
      addToast('引擎修复完成', 'success');
      await loadData();
    } catch (err) {
      addToast(`修复失败: ${err instanceof Error ? err.message : String(err)}`, 'error');
    } finally {
      setRepairing(false);
      setDownloadProgress(0);
    }
  };

  const formatSize = (bytes?: number): string => {
    if (!bytes) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  };

  return (
    <Section title="本地模型" description="管理和配置本地 AI 模型。" compact>
      {/* 引擎状态 */}
      <Card variant="base" className="mb-4 p-4">
        <div className="flex items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
            <AcMindIcon name="ai-workspace" size={20} style={{ color: 'var(--pm-brand)' }} />
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>Whisper 语音引擎</p>
              {loading ? (
                <StatusBadge tone="neutral" label="检测中..." />
              ) : status?.available ? (
                status.initialized ? (
                  <StatusBadge tone="success" label="已就绪" />
                ) : (
                  <StatusBadge tone="warning" label="未初始化" />
                )
              ) : (
                <StatusBadge tone="danger" label="不可用" />
              )}
            </div>
            <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
              {status?.available
                ? status.initialized
                  ? `Whisper 引擎已就绪，当前模型: ${status.currentModel || '未知'}`
                  : 'Whisper 引擎可用但未初始化，请下载模型后初始化。'
                : 'Whisper 语音引擎当前不可用，请检查安装状态。'}
            </p>
            {status?.error && (
              <p className="mt-1 text-[11px]" style={{ color: 'var(--pm-status-danger, #ef4444)' }}>
                错误: {status.error}
              </p>
            )}
          </div>
          {status?.available && !status.initialized && (
            <Button
              variant="secondary"
              size="sm"
              disabled={repairing}
              onClick={() => void handleRepair()}
            >
              {repairing ? `修复中 ${downloadProgress}%...` : '修复引擎'}
            </Button>
          )}
        </div>
      </Card>

      {/* 模型列表 */}
      {loading && <p className="text-[13px]" style={{ color: 'var(--text-muted)' }}>加载中...</p>}

      {!loading && models.length === 0 && (
        <EmptyState
          icon={<AcMindIcon name="ai-workspace" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="未检测到可用模型"
          description="Whisper 语音模型未安装或引擎不可用。"
        />
      )}

      {!loading && models.length > 0 && (
        <div className="flex flex-col gap-3">
          {models.map((model) => (
            <Card key={model.size} variant="base" className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{model.displayName || model.size}</p>
                    <StatusBadge tone={model.cached ? 'success' : 'neutral'} label={model.cached ? '已缓存' : '未下载'} />
                    {status?.currentModel === model.size && status?.initialized && (
                      <StatusBadge tone="info" label="当前使用" />
                    )}
                  </div>
                  <div className="mt-2 grid grid-cols-2 gap-x-4 gap-y-1 text-[12px]">
                    <div className="flex items-center justify-between">
                      <span style={{ color: 'var(--text-muted)' }}>模型规格</span>
                      <span style={{ color: 'var(--text-title)' }}>{model.size}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span style={{ color: 'var(--text-muted)' }}>缓存大小</span>
                      <span style={{ color: 'var(--text-title)' }}>{formatSize(model.cacheSize)}</span>
                    </div>
                  </div>
                  {downloading === model.size && (
                    <div className="mt-2">
                      <div className="h-1.5 w-full rounded-full bg-[color:var(--pm-bg-subtle)]">
                        <div
                          className="h-1.5 rounded-full bg-[color:var(--pm-brand)] transition-all"
                          style={{ width: `${downloadProgress}%` }}
                        />
                      </div>
                      <p className="mt-1 text-[11px]" style={{ color: 'var(--text-muted)' }}>下载进度: {downloadProgress}%</p>
                    </div>
                  )}
                </div>

                <div className="flex shrink-0 flex-col gap-1">
                  {!model.cached && (
                    <Button
                      variant="primary"
                      size="sm"
                      disabled={downloading !== null}
                      onClick={() => void handleDownload(model.size)}
                    >
                      {downloading === model.size ? '下载中...' : '下载'}
                    </Button>
                  )}
                  {model.cached && status?.currentModel !== model.size && (
                    <Button
                      variant="secondary"
                      size="sm"
                      disabled={initializing}
                      onClick={() => void handleInitialize(model.size)}
                    >
                      {initializing ? '初始化中...' : '初始化'}
                    </Button>
                  )}
                  {model.cached && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => void handleDelete(model.size)}
                    >
                      删除
                    </Button>
                  )}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </Section>
  );
}

// ── 运行状态 ──

function RuntimeStatusTab(): JSX.Element {
  const [whisperStatus, setWhisperStatus] = useState<WhisperStatus | null>(null);
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [watchState, setWatchState] = useState<{ status: string; watchPath: string | null; error: string | null; importedCount: number; pendingCount: number } | null>(null);
  const [loading, setLoading] = useState(true);

  const loadAllStatus = useCallback(async () => {
    try {
      const [ws, ts, fw] = await Promise.all([
        window.acmind.whisper?.getStatus().catch(() => null),
        window.acmind.scheduler.getTasks().catch(() => [] as ScheduledTask[]),
        window.acmind.voice?.getWatchState().catch(() => null),
      ]);
      setWhisperStatus(ws);
      setTasks(ts);
      setWatchState(fw);
    } catch {
      // Individual errors handled above
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadAllStatus(); }, [loadAllStatus]);

  const enabledTaskCount = tasks.filter(t => t.enabled).length;
  const lastSuccessTask = tasks.find(t => t.lastResult?.success);
  const lastFailedTask = tasks.find(t => t.lastResult && !t.lastResult.success);

  return (
    <Section title="运行状态" description="查看所有工具的运行状态和健康信息。" compact>
      {loading && <p className="text-[13px]" style={{ color: 'var(--text-muted)' }}>正在检测各工具状态...</p>}

      {!loading && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
          {/* Whisper 引擎状态 */}
          <Card variant="base" className="p-4">
            <div className="flex items-start gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
                <AcMindIcon name="ai-workspace" size={20} style={{ color: 'var(--pm-brand)' }} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>Whisper 语音引擎</p>
                  {whisperStatus?.available ? (
                    whisperStatus.initialized ? (
                      <StatusBadge tone="success" label="已就绪" />
                    ) : (
                      <StatusBadge tone="warning" label="未初始化" />
                    )
                  ) : (
                    <StatusBadge tone="danger" label="不可用" />
                  )}
                </div>
                <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                  {whisperStatus?.available
                    ? whisperStatus.initialized
                      ? `引擎运行正常，当前模型: ${whisperStatus.currentModel || '未知'}`
                      : '引擎可用但尚未初始化模型'
                    : '语音引擎未安装或加载失败'}
                </p>
                {whisperStatus?.error && (
                  <p className="mt-1 text-[11px]" style={{ color: 'var(--pm-status-danger, #ef4444)' }}>
                    {whisperStatus.error}
                  </p>
                )}
              </div>
            </div>
          </Card>

          {/* 调度任务统计 */}
          <Card variant="base" className="p-4">
            <div className="flex items-start gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
                <AcMindIcon name="sb-ai-process" size={20} style={{ color: 'var(--pm-brand)' }} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>调度任务</p>
                  <StatusBadge tone={tasks.length > 0 ? 'success' : 'neutral'} label={tasks.length > 0 ? '运行中' : '无任务'} />
                </div>
                <div className="mt-2 grid grid-cols-3 gap-2 text-[12px]">
                  <div className="text-center">
                    <p className="text-[16px] font-semibold" style={{ color: 'var(--text-title)' }}>{tasks.length}</p>
                    <p style={{ color: 'var(--text-muted)' }}>总任务</p>
                  </div>
                  <div className="text-center">
                    <p className="text-[16px] font-semibold" style={{ color: 'var(--pm-status-success, #22c55e)' }}>{enabledTaskCount}</p>
                    <p style={{ color: 'var(--text-muted)' }}>已启用</p>
                  </div>
                  <div className="text-center">
                    <p className="text-[16px] font-semibold" style={{ color: 'var(--text-title)' }}>
                      {lastSuccessTask ? '通过' : '—'}
                    </p>
                    <p style={{ color: 'var(--text-muted)' }}>最近结果</p>
                  </div>
                </div>
                {lastFailedTask && (
                  <p className="mt-1 text-[11px]" style={{ color: 'var(--pm-status-danger, #ef4444)' }}>
                    最近失败: {lastFailedTask.name} — {lastFailedTask.lastResult?.error || '未知错误'}
                  </p>
                )}
              </div>
            </div>
          </Card>

          {/* 剪贴板监听状态 */}
          <Card variant="base" className="p-4">
            <div className="flex items-start gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
                <AcMindIcon name="filled-clipboard" size={20} style={{ color: 'var(--pm-brand)' }} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>剪贴板监听</p>
                  <StatusBadge tone="success" label="后台运行中" />
                </div>
                <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                  剪贴板监听随 AcMind 启动自动运行，无需手动配置。复制的内容会自动送入工作台处理。
                </p>
                <div className="mt-2">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => navigate('clipboard')}
                  >
                    查看剪贴板历史
                  </Button>
                </div>
              </div>
            </div>
          </Card>

          {/* 文件夹监听状态 */}
          <Card variant="base" className="p-4">
            <div className="flex items-start gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
                <AcMindIcon name="sb-inbox" size={20} style={{ color: 'var(--pm-brand)' }} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>文件夹监听</p>
                  {watchState?.status === 'watching' ? (
                    <StatusBadge tone="success" label="监听中" />
                  ) : (
                    <StatusBadge tone="neutral" label="未监听" />
                  )}
                </div>
                <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                  {watchState?.status === 'watching'
                    ? `正在监听: ${watchState.watchPath}`
                    : '当前未启动文件夹监听，可在"文件夹监听"Tab 中配置。'}
                </p>
              </div>
            </div>
          </Card>
        </div>
      )}
    </Section>
  );
}

// ── GitHub 项目（真实持久化） ──

function GithubTab(): JSX.Element {
  const { addToast } = useToast();
  const [projects, setProjects] = useState<GithubToolProject[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  // Scan & import state
  const [showScanModal, setShowScanModal] = useState(false);
  const [scanDir, setScanDir] = useState('');
  const [scanResults, setScanResults] = useState<any[]>([]);
  const [selectedRepos, setSelectedRepos] = useState<Set<string>>(new Set());
  const [scanning, setScanning] = useState(false);
  const [importing, setImporting] = useState(false);

  // Form state
  const [formName, setFormName] = useState('');
  const [formDesc, setFormDesc] = useState('');
  const [formRepoUrl, setFormRepoUrl] = useState('');
  const [formLocalPath, setFormLocalPath] = useState('');
  const [formLaunchCmd, setFormLaunchCmd] = useState('');
  const [formDocsPath, setFormDocsPath] = useState('');
  const [formCategory, setFormCategory] = useState<ToolProjectCategory>('other');
  const [formTags, setFormTags] = useState('');
  const [saving, setSaving] = useState(false);

  const loadProjects = useCallback(async () => {
    try {
      const res = await window.acmind.toolBench.listGithubProjects();
      if (res.success) setProjects(res.projects);
    } catch { /* noop */ }
    setLoading(false);
  }, []);

  useEffect(() => { loadProjects(); }, [loadProjects]);

  const featuredSearchTool = projects.find((project) =>
    project.localPath === FEATURED_SEARCH_TOOL_PATH
      || project.repoUrl === FEATURED_SEARCH_TOOL_REPO
      || project.name === 'ZTools',
  );

  const resetForm = () => {
    setFormName(''); setFormDesc(''); setFormRepoUrl(''); setFormLocalPath('');
    setFormLaunchCmd(''); setFormDocsPath(''); setFormCategory('other'); setFormTags('');
    setEditId(null); setShowForm(false);
  };

  const openEdit = (p: GithubToolProject) => {
    setEditId(p.id);
    setFormName(p.name); setFormDesc(p.description);
    setFormRepoUrl(p.repoUrl || ''); setFormLocalPath(p.localPath || '');
    setFormLaunchCmd(p.launchCommand || ''); setFormDocsPath(p.docsPath || '');
    setFormCategory(p.category); setFormTags(p.tags.join(', '));
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!formName.trim()) { addToast('请输入项目名称', 'error'); return; }
    if (formRepoUrl && !formRepoUrl.startsWith('http')) { addToast('GitHub 链接格式无效', 'error'); return; }
    setSaving(true);
    try {
      const tags = formTags.split(',').map(t => t.trim()).filter(Boolean);
      if (editId) {
        const res = await window.acmind.toolBench.updateGithubProject(editId, {
          name: formName.trim(), description: formDesc.trim(),
          repoUrl: formRepoUrl || undefined, localPath: formLocalPath || undefined,
          launchCommand: formLaunchCmd || undefined, docsPath: formDocsPath || undefined,
          category: formCategory, tags,
        });
        if (res.success) { addToast('更新成功', 'success'); resetForm(); loadProjects(); }
        else addToast('更新失败', 'error');
      } else {
        const res = await window.acmind.toolBench.createGithubProject({
          name: formName.trim(), description: formDesc.trim(),
          repoUrl: formRepoUrl || undefined, localPath: formLocalPath || undefined,
          launchCommand: formLaunchCmd || undefined, docsPath: formDocsPath || undefined,
          category: formCategory, tags, status: 'saved',
        });
        if (res.success) { addToast('保存成功', 'success'); resetForm(); loadProjects(); }
        else addToast('保存失败', 'error');
      }
    } catch { addToast('操作失败', 'error'); }
    setSaving(false);
  };

  const handleDelete = async (id: string) => {
    const res = await window.acmind.toolBench.deleteGithubProject(id);
    if (res.success) { addToast('已删除', 'success'); setConfirmDeleteId(null); loadProjects(); }
    else addToast('删除失败', 'error');
  };

  const handleOpenUrl = async (url: string) => {
    const res = await window.acmind.toolBench.openUrl(url);
    if (!res.success) addToast(res.error || '打开失败', 'error');
  };

  const handleOpenPath = async (dirPath: string) => {
    const res = await window.acmind.toolBench.openPath(dirPath);
    if (!res.success) addToast(res.error || '打开失败', 'error');
  };

  const handleCopyCommand = async (command: string) => {
    const res = await window.acmind.toolBench.copyCommand(command);
    if (res.success) addToast('已复制命令', 'success');
    else addToast('复制失败', 'error');
  };

  const handleOpenZToolsPage = () => {
    window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'auto-tools', tab: 'ztools' } }));
  };

  const handlePickDirectory = async () => {
    const res = await window.acmind.toolBench.pickDirectory();
    if (res.success && res.path) setScanDir(res.path);
  };

  const handleScan = async () => {
    if (!scanDir.trim()) { addToast('请输入目录路径', 'error'); return; }
    setScanning(true);
    try {
      const res = await window.acmind.toolBench.scanLocalDir(scanDir.trim());
      if (res.success && res.repos) {
        setScanResults(res.repos);
        setSelectedRepos(new Set(res.repos.filter(r => !r.alreadyImported).map(r => r.localPath)));
      } else {
        addToast(res.error || '扫描失败', 'error');
      }
    } catch { addToast('扫描失败', 'error'); }
    setScanning(false);
  };

  const handleBatchImport = async () => {
    const toImport = scanResults.filter(r => selectedRepos.has(r.localPath) && !r.alreadyImported);
    if (toImport.length === 0) { addToast('没有可导入的项目', 'warning'); return; }
    setImporting(true);
    try {
      const res = await window.acmind.toolBench.batchImportProjects(toImport);
      if (res.success) {
        addToast(`成功导入 ${res.imported} 个项目${res.skipped ? `，跳过 ${res.skipped} 个` : ''}`, 'success');
        setShowScanModal(false);
        setScanResults([]);
        setSelectedRepos(new Set());
        loadProjects();
      } else {
        addToast('导入失败', 'error');
      }
    } catch { addToast('导入失败', 'error'); }
    setImporting(false);
  };

  const toggleRepo = (localPath: string) => {
    setSelectedRepos(prev => {
      const next = new Set(prev);
      if (next.has(localPath)) next.delete(localPath);
      else next.add(localPath);
      return next;
    });
  };

  if (loading) {
    return <Section title="开源项目" compact><p className="text-[13px]" style={{ color: 'var(--text-muted)' }}>加载中…</p></Section>;
  }

  return (
    <Section
      title="开源项目"
      description="保存你在网上看到的项目，记录它的用途、路径和启动方式。"
      compact
      action={
        <div className="flex gap-2">
          <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="search" size={14} />} onClick={() => setShowScanModal(true)}>
            扫描导入
          </Button>
          <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="launcher" size={14} />} onClick={() => { resetForm(); setShowForm(true); }}>
            添加项目
          </Button>
        </div>
      }
    >
      {featuredSearchTool ? (
        <Card variant="elevated" className="mb-4 p-4">
          <div className="flex items-start justify-between gap-4">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <p className="text-[15px] font-semibold" style={{ color: 'var(--text-title)' }}>
                  {featuredSearchTool.name}
                </p>
                <StatusBadge tone="success" label="搜索工具" />
                <span className="rounded-full px-2 py-0.5 text-[11px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">
                  推荐接入
                </span>
              </div>
              <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                {featuredSearchTool.description}
              </p>
              {featuredSearchTool.tags.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-1">
                  {featuredSearchTool.tags.map((tag) => (
                    <span key={tag} className="rounded-full px-2 py-0.5 text-[10px] bg-[color:var(--pm-bg-subtle)] text-[color:var(--text-muted)]">
                      {tag}
                    </span>
                  ))}
                </div>
              )}
              {featuredSearchTool.localPath && (
                <p className="mt-2 truncate text-[11px]" style={{ color: 'var(--text-muted)' }}>
                  📁 {featuredSearchTool.localPath}
                </p>
              )}
              {featuredSearchTool.launchCommand && (
                <p className="mt-0.5 truncate font-mono text-[11px]" style={{ color: 'var(--text-muted)' }}>
                  ⚡ {featuredSearchTool.launchCommand}
                </p>
              )}
            </div>
            <div className="flex shrink-0 flex-col gap-1">
              {featuredSearchTool.repoUrl && (
                <Button
                  variant="ghost"
                  size="sm"
                  leadingIcon={<AcMindIcon name="act-link" size={12} />}
                  onClick={() => void handleOpenUrl(featuredSearchTool.repoUrl!)}
                >
                  GitHub
                </Button>
              )}
              {featuredSearchTool.localPath && (
                <Button
                  variant="ghost"
                  size="sm"
                  leadingIcon={<AcMindIcon name="filled-file-import" size={12} />}
                  onClick={() => void handleOpenPath(featuredSearchTool.localPath!)}
                >
                  目录
                </Button>
              )}
              {featuredSearchTool.launchCommand && (
                <Button
                  variant="ghost"
                  size="sm"
                  leadingIcon={<AcMindIcon name="copy" size={12} />}
                  onClick={() => void handleCopyCommand(featuredSearchTool.launchCommand!)}
                >
                  复制命令
                </Button>
              )}
              <Button
                variant="secondary"
                size="sm"
                leadingIcon={<AcMindIcon name="line-search" size={12} />}
                onClick={handleOpenZToolsPage}
              >
                介绍页
              </Button>
            </div>
          </div>
        </Card>
      ) : null}

      {showForm && (
        <Card variant="base" className="mb-4 p-4">
          <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{editId ? '编辑项目' : '添加 GitHub 项目'}</p>
          <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>手动添加你常用的开源项目，记录启动方式和用途。</p>
          <div className="mt-3 grid grid-cols-2 gap-3">
            <div><label className={labelCls}>项目名称 *</label><input className={inputCls} value={formName} onChange={e => setFormName(e.target.value)} placeholder="MarkItDown" /></div>
            <div><label className={labelCls}>分类</label><select className={selectCls} value={formCategory} onChange={e => setFormCategory(e.target.value as ToolProjectCategory)}>{CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}</select></div>
            <div className="col-span-2"><label className={labelCls}>一句话用途</label><input className={inputCls} value={formDesc} onChange={e => setFormDesc(e.target.value)} placeholder="微软开源的文件转 Markdown 工具" /></div>
            <div><label className={labelCls}>GitHub 链接</label><input className={inputCls} value={formRepoUrl} onChange={e => setFormRepoUrl(e.target.value)} placeholder="https://github.com/..." /></div>
            <div><label className={labelCls}>本地路径</label><input className={inputCls} value={formLocalPath} onChange={e => setFormLocalPath(e.target.value)} placeholder="/Users/you/projects/..." /></div>
            <div><label className={labelCls}>启动命令</label><input className={inputCls} value={formLaunchCmd} onChange={e => setFormLaunchCmd(e.target.value)} placeholder="pip install markitdown && markitdown" /></div>
            <div><label className={labelCls}>文档路径</label><input className={inputCls} value={formDocsPath} onChange={e => setFormDocsPath(e.target.value)} placeholder="/Users/you/projects/.../README.md" /></div>
            <div className="col-span-2"><label className={labelCls}>标签（逗号分隔）</label><input className={inputCls} value={formTags} onChange={e => setFormTags(e.target.value)} placeholder="Markdown, 转换, PDF" /></div>
          </div>
          <div className="mt-3 flex gap-2">
            <Button variant="primary" size="sm" disabled={saving} onClick={() => void handleSave()}>{saving ? '保存中…' : '保存'}</Button>
            <Button variant="ghost" size="sm" onClick={resetForm}>取消</Button>
          </div>
        </Card>
      )}

      {/* ── 扫描导入弹窗 ── */}
      {showScanModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
          <Card variant="base" className="w-full max-w-lg p-5">
            <div className="flex items-center justify-between">
              <p className="text-[15px] font-semibold" style={{ color: 'var(--text-title)' }}>扫描本地目录</p>
              <Button variant="ghost" size="sm" onClick={() => { setShowScanModal(false); setScanResults([]); setSelectedRepos(new Set()); }}>✕</Button>
            </div>
            <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>选择一个包含 Git 仓库的目录，自动识别并批量导入。</p>

            <div className="mt-3 flex gap-2">
              <input className={inputCls} style={{ flex: 1 }} value={scanDir} onChange={e => setScanDir(e.target.value)} placeholder="/Users/you/Desktop/GitHub" onKeyDown={e => { if (e.key === 'Enter') void handleScan(); }} />
              <Button variant="secondary" size="sm" onClick={() => void handlePickDirectory()}>选择目录</Button>
              <Button variant="primary" size="sm" disabled={scanning} onClick={() => void handleScan()}>{scanning ? '扫描中…' : '扫描'}</Button>
            </div>

            {scanResults.length > 0 && (
              <div className="mt-4">
                <div className="flex items-center justify-between mb-2">
                  <p className="text-[12px]" style={{ color: 'var(--text-muted)' }}>
                    发现 {scanResults.length} 个 Git 仓库，{scanResults.filter(r => !r.alreadyImported).length} 个尚未导入
                  </p>
                  <button type="button" className="text-[12px] font-medium" style={{ color: 'var(--pm-brand)' }} onClick={() => {
                    const newRepos = scanResults.filter(r => !r.alreadyImported);
                    setSelectedRepos(new Set(newRepos.map(r => r.localPath)));
                  }}>
                    全选未导入
                  </button>
                </div>
                <div className="max-h-[300px] overflow-auto flex flex-col gap-1.5">
                  {scanResults.map((repo) => (
                    <label key={repo.localPath} className={`flex items-start gap-2.5 rounded-[8px] px-3 py-2 cursor-pointer transition-colors ${repo.alreadyImported ? 'opacity-50' : 'hover:bg-[color:var(--pm-bg-subtle)]'}`}>
                      <input
                        type="checkbox"
                        className="mt-0.5"
                        checked={selectedRepos.has(repo.localPath)}
                        disabled={repo.alreadyImported}
                        onChange={() => toggleRepo(repo.localPath)}
                      />
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <p className="text-[13px] font-medium truncate" style={{ color: 'var(--text-title)' }}>{repo.name}</p>
                          {repo.alreadyImported && <span className="rounded-full px-1.5 py-0.5 text-[10px] bg-[color:var(--pm-bg-subtle)] text-[color:var(--text-muted)]">已导入</span>}
                        </div>
                        <p className="text-[11px] truncate" style={{ color: 'var(--text-muted)' }}>{repo.localPath}</p>
                        {repo.description && <p className="mt-0.5 text-[11px] line-clamp-1" style={{ color: 'var(--text-muted)' }}>{repo.description}</p>}
                      </div>
                    </label>
                  ))}
                </div>
                <div className="mt-3 flex justify-end gap-2">
                  <Button variant="ghost" size="sm" onClick={() => { setShowScanModal(false); setScanResults([]); setSelectedRepos(new Set()); }}>取消</Button>
                  <Button variant="primary" size="sm" disabled={importing || selectedRepos.size === 0} onClick={() => void handleBatchImport()}>
                    {importing ? '导入中…' : `导入选中 (${scanResults.filter(r => selectedRepos.has(r.localPath) && !r.alreadyImported).length})`}
                  </Button>
                </div>
              </div>
            )}
          </Card>
        </div>
      )}

      {projects.length === 0 ? (
        <EmptyState
          icon={<AcMindIcon name="filled-cloud" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="还没有收纳开源项目"
          description="把你在 GitHub 上看到的项目保存到这里，记录用途、路径和启动命令，之后就能快速找回和使用。"
        />
      ) : (
        <div className="flex flex-col gap-3">
          {projects.filter((project) => project.id !== featuredSearchTool?.id).map((project) => (
            <Card key={project.id} variant="base" className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{project.name}</p>
                    <StatusBadge tone={PROJECT_STATUS_LABELS[project.status]?.tone || 'neutral'} label={PROJECT_STATUS_LABELS[project.status]?.label || project.status} />
                    <span className="rounded-full px-2 py-0.5 text-[11px] bg-[color:var(--pm-bg-subtle)] text-[color:var(--text-muted)]">{CATEGORY_LABELS[project.category] || project.category}</span>
                  </div>
                  <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>{project.description || '暂无描述'}</p>
                  {project.tags.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1">
                      {project.tags.map((tag) => (
                        <span key={tag} className="rounded-full px-2 py-0.5 text-[10px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">{tag}</span>
                      ))}
                    </div>
                  )}
                  {project.localPath && (
                    <p className="mt-1 text-[11px] truncate" style={{ color: 'var(--text-muted)' }}>📁 {project.localPath}</p>
                  )}
                  {project.launchCommand && (
                    <p className="mt-0.5 text-[11px] truncate font-mono" style={{ color: 'var(--text-muted)' }}>⚡ {project.launchCommand}</p>
                  )}
                </div>
                <div className="flex shrink-0 gap-1">
                  {project.repoUrl && (
                    <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="act-link" size={12} />} onClick={() => void handleOpenUrl(project.repoUrl!)}>GitHub</Button>
                  )}
                  {project.localPath && (
                    <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="filled-file-import" size={12} />} onClick={() => void handleOpenPath(project.localPath!)}>目录</Button>
                  )}
                  {project.launchCommand && (
                    <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="copy" size={12} />} onClick={() => void handleCopyCommand(project.launchCommand!)}>复制</Button>
                  )}
                  <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="act-edit" size={12} />} onClick={() => openEdit(project)}>编辑</Button>
                  {confirmDeleteId === project.id ? (
                    <div className="flex gap-1">
                      <Button variant="danger" size="sm" onClick={() => void handleDelete(project.id)}>确认</Button>
                      <Button variant="ghost" size="sm" onClick={() => setConfirmDeleteId(null)}>取消</Button>
                    </div>
                  ) : (
                    <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="act-delete" size={12} />} onClick={() => setConfirmDeleteId(project.id)}>删除</Button>
                  )}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </Section>
  );
}

// ── 本地脚本（真实持久化） ──

function ScriptsTab(): JSX.Element {
  const { addToast } = useToast();
  const [scripts, setScripts] = useState<LocalScriptTool[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  const [formName, setFormName] = useState('');
  const [formCommand, setFormCommand] = useState('');
  const [formWorkDir, setFormWorkDir] = useState('');
  const [formDesc, setFormDesc] = useState('');
  const [formTags, setFormTags] = useState('');
  const [formSafety, setFormSafety] = useState<LocalScriptSafetyLevel>('safe');
  const [saving, setSaving] = useState(false);

  const loadScripts = useCallback(async () => {
    try {
      const res = await window.acmind.toolBench.listScripts();
      if (res.success) setScripts(res.scripts);
    } catch { /* noop */ }
    setLoading(false);
  }, []);

  useEffect(() => { loadScripts(); }, [loadScripts]);

  const resetForm = () => {
    setFormName(''); setFormCommand(''); setFormWorkDir('');
    setFormDesc(''); setFormTags(''); setFormSafety('safe');
    setEditId(null); setShowForm(false);
  };

  const openEdit = (s: LocalScriptTool) => {
    setEditId(s.id);
    setFormName(s.name); setFormCommand(s.command);
    setFormWorkDir(s.workingDirectory || ''); setFormDesc(s.description);
    setFormTags(s.tags.join(', ')); setFormSafety(s.safetyLevel);
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!formName.trim()) { addToast('请输入脚本名称', 'error'); return; }
    if (!formCommand.trim()) { addToast('请输入命令', 'error'); return; }
    setSaving(true);
    try {
      const tags = formTags.split(',').map(t => t.trim()).filter(Boolean);
      if (editId) {
        const res = await window.acmind.toolBench.updateScript(editId, {
          name: formName.trim(), command: formCommand.trim(),
          workingDirectory: formWorkDir || undefined, description: formDesc.trim(),
          tags, safetyLevel: formSafety,
        });
        if (res.success) { addToast('更新成功', 'success'); resetForm(); loadScripts(); }
        else addToast('更新失败', 'error');
      } else {
        const res = await window.acmind.toolBench.createScript({
          name: formName.trim(), command: formCommand.trim(),
          workingDirectory: formWorkDir || undefined, description: formDesc.trim(),
          tags, safetyLevel: formSafety,
        });
        if (res.success) { addToast('保存成功', 'success'); resetForm(); loadScripts(); }
        else addToast('保存失败', 'error');
      }
    } catch { addToast('操作失败', 'error'); }
    setSaving(false);
  };

  const handleDelete = async (id: string) => {
    const res = await window.acmind.toolBench.deleteScript(id);
    if (res.success) { addToast('已删除', 'success'); setConfirmDeleteId(null); loadScripts(); }
    else addToast('删除失败', 'error');
  };

  const handleCopyCommand = async (command: string) => {
    const res = await window.acmind.toolBench.copyCommand(command);
    if (res.success) addToast('已复制命令', 'success');
    else addToast('复制失败', 'error');
  };

  const handleOpenPath = async (dirPath: string) => {
    const res = await window.acmind.toolBench.openPath(dirPath);
    if (!res.success) addToast(res.error || '打开失败', 'error');
  };

  if (loading) {
    return <Section title="本地脚本" compact><p className="text-[13px]" style={{ color: 'var(--text-muted)' }}>加载中…</p></Section>;
  }

  return (
    <Section
      title="本地脚本"
      description="保存常用命令和脚本。当前默认只复制命令，不直接执行。"
      compact
      action={
        <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="launcher" size={14} />} onClick={() => { resetForm(); setShowForm(true); }}>
          添加脚本
        </Button>
      }
    >
      {showForm && (
        <Card variant="base" className="mb-4 p-4">
          <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{editId ? '编辑脚本' : '添加本地脚本'}</p>
          <div className="mt-3 grid grid-cols-2 gap-3">
            <div><label className={labelCls}>脚本名称 *</label><input className={inputCls} value={formName} onChange={e => setFormName(e.target.value)} placeholder="build-docs" /></div>
            <div><label className={labelCls}>安全等级</label><select className={selectCls} value={formSafety} onChange={e => setFormSafety(e.target.value as LocalScriptSafetyLevel)}>{SAFETY_LEVELS.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}</select></div>
            <div className="col-span-2"><label className={labelCls}>命令 *</label><input className={inputCls} value={formCommand} onChange={e => setFormCommand(e.target.value)} placeholder="python scripts/build.py --output ./dist" /></div>
            <div><label className={labelCls}>工作目录</label><input className={inputCls} value={formWorkDir} onChange={e => setFormWorkDir(e.target.value)} placeholder="/Users/you/projects/myapp" /></div>
            <div><label className={labelCls}>标签（逗号分隔）</label><input className={inputCls} value={formTags} onChange={e => setFormTags(e.target.value)} placeholder="构建, 文档, Python" /></div>
            <div className="col-span-2"><label className={labelCls}>说明</label><input className={inputCls} value={formDesc} onChange={e => setFormDesc(e.target.value)} placeholder="构建项目文档并输出到 dist 目录" /></div>
          </div>
          <div className="mt-3 flex gap-2">
            <Button variant="primary" size="sm" disabled={saving} onClick={() => void handleSave()}>{saving ? '保存中…' : '保存'}</Button>
            <Button variant="ghost" size="sm" onClick={resetForm}>取消</Button>
          </div>
        </Card>
      )}

      {scripts.length === 0 ? (
        <EmptyState
          icon={<AcMindIcon name="line-edit" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
          title="还没有本地脚本"
          description="把常用命令和脚本记录到这里，先复制使用，之后再逐步升级为可执行工具。"
        />
      ) : (
        <div className="flex flex-col gap-3">
          {scripts.map((script) => (
            <Card key={script.id} variant="base" className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{script.name}</p>
                    <StatusBadge tone={SAFETY_LABELS[script.safetyLevel]?.tone || 'neutral'} label={SAFETY_LABELS[script.safetyLevel]?.label || script.safetyLevel} />
                  </div>
                  <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>{script.description || '暂无说明'}</p>
                  <code className="mt-2 block rounded-[6px] bg-[color:var(--pm-bg-subtle)] px-2 py-1 text-[11px]">{script.command}</code>
                  {script.workingDirectory && (
                    <p className="mt-1 text-[11px] truncate" style={{ color: 'var(--text-muted)' }}>📁 {script.workingDirectory}</p>
                  )}
                  {script.tags.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1">
                      {script.tags.map((tag) => (
                        <span key={tag} className="rounded-full px-2 py-0.5 text-[10px] bg-[color:var(--pm-bg-subtle)] text-[color:var(--text-muted)]">{tag}</span>
                      ))}
                    </div>
                  )}
                </div>
                <div className="flex shrink-0 flex-col gap-1">
                  <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="copy" size={12} />} onClick={() => void handleCopyCommand(script.command)}>复制命令</Button>
                  {script.workingDirectory && (
                    <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="filled-file-import" size={12} />} onClick={() => void handleOpenPath(script.workingDirectory!)}>打开目录</Button>
                  )}
                  <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="act-edit" size={12} />} onClick={() => openEdit(script)}>编辑</Button>
                  {confirmDeleteId === script.id ? (
                    <div className="flex gap-1">
                      <Button variant="danger" size="sm" onClick={() => void handleDelete(script.id)}>确认</Button>
                      <Button variant="ghost" size="sm" onClick={() => setConfirmDeleteId(null)}>取消</Button>
                    </div>
                  ) : (
                    <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="act-delete" size={12} />} onClick={() => setConfirmDeleteId(script.id)}>删除</Button>
                  )}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </Section>
  );
}

// ── 工具流程 ──

function WorkflowsTab(): JSX.Element {
  return (
    <Section title="工具流程" description="把多个工具组合成稳定流程，后续可一键运行。" compact>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
        {WORKFLOW_TEMPLATES.map((wf) => (
          <Card key={wf.id} variant="interactive" className="p-4">
            <div className="flex items-start gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
                <AcMindIcon name={wf.icon as any} size={20} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{wf.name}</p>
                <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>{wf.description}</p>
                <div className="mt-2 flex flex-wrap gap-1">
                  {wf.steps.map((step, i) => (
                    <span key={i} className="text-[11px]" style={{ color: 'var(--text-muted)' }}>{step}</span>
                  ))}
                </div>
                <div className="mt-2">
                  <StatusBadge tone="neutral" label="查看流程" />
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </Section>
  );
}

// ── 工具卡片组件 ──

function ToolCardComponent({ tool }: { tool: ToolCard }): JSX.Element {
  const statusConf = STATUS_LABELS[tool.status];
  const isClickable = tool.status === 'ready' && tool.targetView;
  const isAgentCallable = AGENT_CALLABLE_TOOLS.includes(tool.id);

  const handleClick = () => {
    if (isClickable) navigate(tool.targetView!);
  };

  return (
    <Card variant={isClickable ? 'interactive' : 'base'} className="p-4" onClick={handleClick} style={!isClickable ? { opacity: 0.7 } : undefined}>
      <div className="flex items-start gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
          <AcMindIcon name={tool.icon as any} size={20} />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>{tool.name}</p>
              {isAgentCallable && (
                <span className="flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[10px] bg-accent-soft text-accent">
                  <AcMindIcon name="sb-ai-process" size={10} />
                  Agent
                </span>
              )}
            </div>
            <StatusBadge tone={statusConf.tone} label={statusConf.label} />
          </div>
          <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>{tool.description}</p>
          <div className="mt-2 flex items-center justify-between">
            <div className="flex gap-1">
              {tool.tags.map((tag) => (
                <span key={tag} className="rounded-full px-2 py-0.5 text-[10px] bg-[color:var(--pm-bg-subtle)] text-[color:var(--text-muted)]">{tag}</span>
              ))}
            </div>
            <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="arrow-right" size={12} />}>
              {tool.primaryActionLabel}
            </Button>
          </div>
        </div>
      </div>
    </Card>
  );
}
