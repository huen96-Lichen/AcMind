import { useCallback, useEffect, useState, type ReactNode } from 'react';
import type { CSSProperties } from 'react';
import { Sidebar } from './Sidebar';
import { TopBar } from './TopBar';
import { PersonalSpacePanel } from './PersonalSpacePanel';
import { ScrollContainer } from '../shared/ScrollContainer';
import { ToastProvider } from '../shared/ToastViewport';
import { useShellSnapshot } from '../../hooks/useShellSnapshot';
import { useLayoutMode } from '../../hooks/useLayoutMode';

const STORAGE_APP_NAV_COLLAPSED_KEY = 'acmind:app-nav-collapsed';
const APP_NAV_EXPANDED_WIDTH = 216;
const APP_NAV_COLLAPSED_WIDTH = 72;

interface AppShellProps {
  activeView: string;
  onNavigate: (view: string, options?: { tab?: string; id?: string }) => void;
  children: ReactNode;
}

export function AppShell({ activeView, onNavigate, children }: AppShellProps): JSX.Element {
  const snapshot = useShellSnapshot();
  const mode = useLayoutMode();
  const [showPersonalSpace, setShowPersonalSpace] = useState(false);
  const [sidebarForcedOpen, setSidebarForcedOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState<boolean>(() => loadCollapsedState());

  const handleNavigate = useCallback((view: string, options?: { tab?: string; id?: string }) => {
    onNavigate(view, options);
  }, [onNavigate]);

  // Listen for personal space open event
  useEffect(() => {
    const handler = () => setShowPersonalSpace(true);
    window.addEventListener('acmind:open-personal-space', handler);
    return () => window.removeEventListener('acmind:open-personal-space', handler);
  }, []);

  useEffect(() => {
    const handler = () => setSidebarForcedOpen((current) => !current);
    window.addEventListener('acmind:toggle-sidebar', handler);
    return () => window.removeEventListener('acmind:toggle-sidebar', handler);
  }, []);

  useEffect(() => {
    persistCollapsedState(sidebarCollapsed);
  }, [sidebarCollapsed]);

  // Refresh shell snapshot when settings are updated (e.g. dashboard toggle)
  useEffect(() => {
    const handler = () => { snapshot.refresh(); };
    window.addEventListener('acmind:settings-updated', handler);
    return () => window.removeEventListener('acmind:settings-updated', handler);
  }, [snapshot]);

  // Sidebar stays visible on spacious layouts; on compact layouts it can be toggled open.
  const sidebarVisible = sidebarForcedOpen || mode === 'large' || mode === 'medium';
  const sidebarWidth = sidebarCollapsed ? APP_NAV_COLLAPSED_WIDTH : APP_NAV_EXPANDED_WIDTH;

  const layoutClasses = mode === 'small' || mode === 'compact'
    ? 'grid-cols-1'
    : 'grid-cols-[var(--pm-sidebar-width)_minmax(0,1fr)]';

  return (
    <ToastProvider>
      <div
        className="flex h-full w-full min-w-0 flex-col overflow-hidden acmind-app-shell"
        style={{ '--pm-sidebar-width': `${sidebarWidth}px` } as CSSProperties}
      >
        <TopBar
          snapshot={snapshot}
          onRefresh={snapshot.refresh}
          onNavigate={handleNavigate}
          layoutMode={mode}
          activeView={activeView}
        />

        <div className={`grid flex-1 min-h-0 min-w-0 ${layoutClasses}`}>
          {/* Sidebar — visible in large/medium, hidden in compact/small */}
          <div className={sidebarVisible ? 'min-h-0' : 'hidden'}>
            <Sidebar
              activeView={activeView}
              onNavigate={handleNavigate}
              snapshot={snapshot}
              collapsed={sidebarCollapsed}
              onToggleCollapsed={() => setSidebarCollapsed((current) => !current)}
            />
          </div>

          {/* Main content area */}
          {activeView === 'schedule' ? (
            <div className="acmind-window-page min-h-0 min-w-0 overflow-hidden">
              {children}
            </div>
          ) : (
            <ScrollContainer className="acmind-window-page min-h-0 min-w-0 overflow-y-auto">
              {children}
            </ScrollContainer>
          )}

        </div>
      </div>

      {/* Personal Space Panel */}
      <PersonalSpacePanel
        visible={showPersonalSpace}
        onClose={() => setShowPersonalSpace(false)}
      />
    </ToastProvider>
  );
}

function loadCollapsedState(): boolean {
  try {
    return window.localStorage.getItem(STORAGE_APP_NAV_COLLAPSED_KEY) === '1';
  } catch {
    return false;
  }
}

function persistCollapsedState(collapsed: boolean): void {
  try {
    window.localStorage.setItem(STORAGE_APP_NAV_COLLAPSED_KEY, collapsed ? '1' : '0');
  } catch {
    // noop
  }
}
