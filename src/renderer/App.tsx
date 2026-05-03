import { useCallback, useEffect, useState } from 'react';
import { AppShell } from './components/layout/AppShell';
import { EmptyState } from './components/shared/EmptyState';
import { ErrorBoundary } from './components/shared/ErrorBoundary';
import { PinStackIcon } from './design-system/icons';
import { CapturePage } from './pages/capture/CapturePage';
import { CaptureInboxPage } from './pages/capture-inbox/CaptureInboxPage';
import { CapsulePage } from './pages/capsule/CapsulePage';
import { DashboardPage } from './pages/dashboard/DashboardPage';
import { DistillPage } from './pages/distill/DistillPage';
import { ExportPage } from './pages/export/ExportPage';
import { ImportPage } from './pages/import/ImportPage';
import { SettingsPage } from './pages/settings/SettingsPage';
import { EditPage } from './pages/edit/EditPage';
import { OnboardingPage } from './pages/onboarding/OnboardingPage';
import { SearchPage } from './pages/search';
import { ErrorReviewPage } from './pages/errors/ErrorReviewPage';
import { ProcessingHistoryPage } from './pages/history/ProcessingHistoryPage';
import { DailyKnowledgeFlowPage } from './pages/daily-flow/DailyKnowledgeFlowPage';
import { AIPage } from './pages/ai/AIPage';
import { QuickDeskPage } from './pages/quick-desk/QuickDeskPage';
import { ClipboardPage } from './pages/clipboard/ClipboardPage';
import { ShelfPage } from './pages/shelf/ShelfPage';
import { FileConverterPage } from './pages/file-converter/FileConverterPage';
import { KnowledgeCardsPage } from './pages/knowledge-cards/KnowledgeCardsPage';
import { VoiceDictionaryPage } from './pages/voice/VoiceDictionaryPage';
import { UtilitiesPage } from './pages/utilities/UtilitiesPage';
import { ReviewPage } from './pages/review/ReviewPage';
import { TaskQueuePage } from './pages/task-queue/TaskQueuePage';
import { AutomationPage } from './pages/automation/AutomationPage';
import { ProjectsPage } from './pages/projects/ProjectsPage';
import { DatasetsPage } from './pages/datasets/DatasetsPage';
import { LoadingState } from './design-system/components';

type ViewName = 'quick-desk' | 'daily-flow' | 'dashboard' | 'distill' | 'export' | 'import' | 'settings' | 'capture' | 'onboarding' | 'capture-inbox' | 'capsule' | 'edit' | 'search' | 'errors' | 'history' | 'ai' | 'clipboard' | 'shelf' | 'file-converter' | 'knowledge-cards' | 'voice-dictionary' | 'utilities' | 'review' | 'task-queue' | 'automation' | 'projects' | 'datasets';

const VIEW_LABELS: Record<ViewName, string> = {
  'quick-desk': 'Quick Desk',
  'daily-flow': '首页',
  'capture-inbox': '收集',
  dashboard: '首页',
  distill: '整理',
  export: '入库',
  import: '资料库',
  settings: '设置',
  capture: '快速捕获',
  onboarding: '初始引导',
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
  'utilities': '工具箱',
  review: '确认',
  'task-queue': '任务队列',
  automation: '自动化',
  projects: '项目',
  datasets: '数据集',
};

const DEFAULT_VIEW: ViewName = 'quick-desk';

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
          navigateToView('quick-desk');
        }}
      />
    );
  }

  if (activeView === 'capture') {
    return <CapturePage />;
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
    case 'quick-desk':
      return <QuickDeskPage />;
    case 'daily-flow':
      return <DailyKnowledgeFlowPage />;
    case 'capture-inbox':
      return <CaptureInboxPage />;
    case 'dashboard':
      // Batch 4 Phase 7: Dashboard 今日工作台
      return <DashboardPage />;
    case 'distill':
      return <DistillPage />;
    case 'export':
      return <ExportPage />;
    case 'import':
      return <ImportPage />;
    case 'settings':
      return <SettingsPage />;
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
    case 'utilities':
      return <UtilitiesPage />;
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
    default:
      return (
        <div className="flex h-full items-center justify-center p-8">
          <EmptyState
            icon={<PinStackIcon name="help" size={32} style={{ color: 'var(--pm-text-tertiary)' }} />}
            title={`${VIEW_LABELS[activeView]} - 页面不可用`}
            description={'当前路由没有对应页面，请返回主工作区。'}
          />
        </div>
      );
  }
}

function isValidView(view: string): view is ViewName {
  return view in VIEW_LABELS;
}
