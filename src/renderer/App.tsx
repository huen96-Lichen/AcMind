import { useCallback, useEffect, useState } from 'react';
import { AppShell } from './components/layout/AppShell';
import { EmptyState } from './components/shared/EmptyState';
import { ErrorBoundary } from './components/shared/ErrorBoundary';
import { ToastProvider } from './components/shared/ToastViewport';
import { AcMindIcon } from './design-system/icons';
import { CapturePage } from './pages/capture/CapturePage';
import { CaptureInboxPage } from './pages/capture-inbox/CaptureInboxPage';
import { CapsulePage } from './pages/capsule/CapsulePage';
import { DistillPage } from './pages/distill/DistillPage';
import { ExportPage } from './pages/export/ExportPage';
import { ImportPage } from './pages/import/ImportPage';
import { SettingsPage } from './pages/settings/SettingsPage';
import { EditPage } from './pages/edit/EditPage';
import { OnboardingPage } from './pages/onboarding/OnboardingPage';
import { SearchPage } from './pages/search';
import { ErrorReviewPage } from './pages/errors/ErrorReviewPage';
import { ProcessingHistoryPage } from './pages/history/ProcessingHistoryPage';
import { WorkbenchPage } from './pages/workbench/WorkbenchPage';
import { AIPage } from './pages/ai/AIPage';
import { StagingPoolPage } from './pages/staging-pool/StagingPoolPage';
import { ToolBenchPage } from './pages/tool-bench/ToolBenchPage';
import { ClipboardPage } from './pages/clipboard/ClipboardPage';
import { ShelfPage } from './pages/shelf/ShelfPage';
import { FileConverterPage } from './pages/file-converter/FileConverterPage';
import { KnowledgeCardsPage } from './pages/knowledge-cards/KnowledgeCardsPage';
import { VoiceDictionaryPage } from './pages/voice/VoiceDictionaryPage';
import { ReviewPage } from './pages/review/ReviewPage';
import { TaskQueuePage } from './pages/task-queue/TaskQueuePage';
import { AutomationPage } from './pages/automation/AutomationPage';
import { ProjectsPage } from './pages/projects/ProjectsPage';
import { DatasetsPage } from './pages/datasets/DatasetsPage';
import { AgentChatPage } from './pages/agent-chat/AgentChatPage';
import { AgentTasksPage } from './pages/agent-tasks/AgentTasksPage';
import { SchedulePage } from './pages/schedule/SchedulePage';
import { LoadingState } from './design-system/components';

// 一级导航：Agent / 日程表 / 工作台 / 自动工具 / 设置
// 保留旧页面用于内部跳转

type ViewName = 
  // 一级导航
  | 'agent'           // Agent 首页（默认）
  | 'schedule'        // 日程表
  | 'workbench'       // 工作台（Obsidian 入库和知识沉淀）
  | 'auto-tools'      // 自动工具
  | 'settings'        // 设置
  // 保留的旧页面（用于内部跳转）
  | 'staging-pool' | 'distill' | 'export' | 'import' | 'capture' | 'onboarding' 
  | 'capture-inbox' | 'capsule' | 'edit' | 'search' | 'errors' | 'history' 
  | 'ai' | 'clipboard' | 'shelf' | 'file-converter' | 'knowledge-cards' 
  | 'voice-dictionary' | 'review' | 'task-queue' | 'automation' 
  | 'projects' | 'datasets' | 'agent-chat' | 'agent-tasks';

const VIEW_LABELS: Record<ViewName, string> = {
  // 一级导航
  agent: 'Agent',
  schedule: '日程表',
  workbench: '工作台',
  'auto-tools': '自动工具',
  settings: '设置',
  // 保留的旧页面
  'staging-pool': '暂存池',
  distill: '整理',
  export: '入库',
  import: '资料库',
  capture: '快速捕获',
  onboarding: '初始引导',
  'capture-inbox': '整理',
  capsule: '灵感入口',
  edit: '整理详情',
  search: '搜索',
  errors: '错误回看',
  history: '处理历史',
  ai: 'AI',
  clipboard: '剪贴板',
  shelf: 'Shelf',
  'file-converter': '文件转换',
  'knowledge-cards': '知识库',
  'voice-dictionary': '语音设置',
  review: '确认',
  'task-queue': '任务队列',
  automation: '自动化',
  projects: '项目',
  datasets: '数据集',
  'agent-chat': 'Agent 对话',
  'agent-tasks': '定时任务',
};

// Agent-first: 默认首页改为 Agent
const DEFAULT_VIEW: ViewName = 'agent';

export function App(): JSX.Element {
  const [activeView, setActiveView] = useState<ViewName>(DEFAULT_VIEW);
  const [onboardingDone, setOnboardingDone] = useState<boolean | null>(null);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const viewParam = params.get('view');
    if (viewParam && isValidView(viewParam)) {
      setActiveView(viewParam);
    }
  }, []);

  useEffect(() => {
    async function loadOnboardingState(): Promise<void> {
      try {
        if (!window.acmind) {
          setOnboardingDone(true);
          return;
        }
        const settings = await window.acmind.settings.get();
        setOnboardingDone(settings.hasCompletedOnboarding);
      } catch {
        setOnboardingDone(true);
      }
    }

    void loadOnboardingState();
  }, []);

  useEffect(() => {
    const handlePopState = () => {
      const params = new URLSearchParams(window.location.search);
      const viewParam = params.get('view');
      setActiveView(viewParam && isValidView(viewParam) ? viewParam : DEFAULT_VIEW);
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  const navigateToView = useCallback((view: string, options?: { tab?: string; id?: string }) => {
    if (!isValidView(view)) {
      return;
    }

    setActiveView(view);
    const url = new URL(window.location.href);
    url.searchParams.set('view', view);
    if (options?.tab) {
      url.searchParams.set('tab', options.tab);
    } else {
      url.searchParams.delete('tab');
    }
    if (options?.id) {
      url.searchParams.set('id', options.id);
    } else {
      url.searchParams.delete('id');
    }
    window.history.replaceState({}, '', url.toString());
  }, []);

  useEffect(() => {
    const handleNavigateEvent = (event: Event) => {
      const detail = (event as CustomEvent<string | { view: string; tab?: string; id?: string; itemId?: string }>).detail;
      if (typeof detail === 'string') {
        navigateToView(detail);
        return;
      }
      if (detail && typeof detail === 'object' && typeof detail.view === 'string') {
        navigateToView(detail.view, { tab: detail.tab, id: detail.id ?? detail.itemId });
      }
    };

    window.addEventListener('acmind:navigate', handleNavigateEvent as EventListener);
    return () => window.removeEventListener('acmind:navigate', handleNavigateEvent as EventListener);
  }, [navigateToView]);

  if (onboardingDone === null) {
    return (
      <div className="flex h-screen items-center justify-center bg-[color:var(--pm-bg-canvas)] p-5">
        <LoadingState
          title="正在启动 AcMind"
          description="正在读取本地设置、工作区和导航状态。"
        />
      </div>
    );
  }

  if (activeView === 'onboarding' || !onboardingDone) {
    return (
      <OnboardingPage
        onComplete={() => {
          setOnboardingDone(true);
          navigateToView('agent');
        }}
      />
    );
  }

  if (activeView === 'capture') {
    return (
      <ToastProvider>
        <CapturePage />
      </ToastProvider>
    );
  }

  // Independent windows: no AppShell wrapper
  if (activeView === 'capsule') {
    return <CapsulePage />;
  }

  return (
    <AppShell activeView={activeView} onNavigate={navigateToView}>
      <ErrorBoundary key={activeView}>
        {renderPage(activeView)}
      </ErrorBoundary>
    </AppShell>
  );
}

function renderPage(activeView: ViewName): JSX.Element {
  switch (activeView) {
    // 一级导航页面
    case 'agent':
      return <AgentChatPage />;
    case 'schedule':
      return <SchedulePage />;
    case 'workbench':
      return <WorkbenchPage />;
    case 'auto-tools':
      return <ToolBenchPage />;
    case 'settings':
      return <SettingsPage />;
    // 保留的旧页面（用于工作台内部跳转）
    case 'staging-pool':
      return <StagingPoolPage />;
    case 'capture-inbox':
      return <CaptureInboxPage />;
    case 'distill':
      return <DistillPage />;
    case 'export':
      return <ExportPage />;
    case 'import':
      return <ImportPage />;
    case 'edit':
      return <EditPage itemId={new URLSearchParams(window.location.search).get('id') || undefined} />;
    case 'search':
      return <SearchPage />;
    case 'errors':
      return <ErrorReviewPage />;
    case 'history':
      return <ProcessingHistoryPage />;
    case 'ai':
      return <AIPage />;
    case 'clipboard':
      return <ClipboardPage />;
    case 'shelf':
      return <ShelfPage />;
    case 'file-converter':
      return <FileConverterPage />;
    case 'knowledge-cards':
      return <KnowledgeCardsPage />;
    case 'voice-dictionary':
      return <VoiceDictionaryPage />;
    case 'review':
      return <ReviewPage />;
    case 'task-queue':
      return <TaskQueuePage />;
    case 'automation':
      return <AutomationPage />;
    case 'projects':
      return <ProjectsPage />;
    case 'datasets':
      return <DatasetsPage />;
    case 'agent-chat':
      return <AgentChatPage />;
    case 'agent-tasks':
      return <AgentTasksPage />;
    default:
      return (
        <div className="flex h-full items-center justify-center p-8">
          <EmptyState
            icon={<AcMindIcon name="help" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title={`${VIEW_LABELS[activeView as ViewName] ?? '未知页面'} - 页面不可用`}
            description={'当前路由没有对应页面，请返回主工作区。'}
          />
        </div>
      );
  }
}

function isValidView(view: string): view is ViewName {
  return view in VIEW_LABELS;
}
