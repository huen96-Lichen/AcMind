import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { Sidebar } from './Sidebar';
import { TopBar } from './TopBar';
import { RightInspector } from './RightInspector';
import { PersonalSpacePanel } from './PersonalSpacePanel';
import { ScrollContainer } from '../shared/ScrollContainer';
import { ToastProvider } from '../shared/ToastViewport';
import { useShellSnapshot } from '../../hooks/useShellSnapshot';
import { useLayoutMode } from '../../hooks/useLayoutMode';
import { SelectedItemContext } from '../../context/SelectedItemContext';
import type { CaptureItem } from '../../../shared/types';

interface AppShellProps {
  activeView: string;
  onNavigate: (view: string, options?: { tab?: string; id?: string }) => void;
  children: ReactNode;
}

export function AppShell({ activeView, onNavigate, children }: AppShellProps): JSX.Element {
  const snapshot = useShellSnapshot();
  const mode = useLayoutMode();
  const [selectedItem, setSelectedItem] = useState<CaptureItem | null>(null);
  const [showPersonalSpace, setShowPersonalSpace] = useState(false);
  const [sidebarForcedOpen, setSidebarForcedOpen] = useState(false);

  // Reset selectedItem when navigating away from capture-inbox
  const handleNavigate = useCallback((view: string, options?: { tab?: string; id?: string }) => {
    if (view !== 'capture-inbox') {
      setSelectedItem(null);
    }
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

  // Sidebar visibility: hidden in compact and small modes
  const sidebarVisible = sidebarForcedOpen || mode === 'large' || mode === 'medium';

  // RightInspector: only in large mode, but NOT on settings page
  const inspectorVisible = mode === 'large' && activeView !== 'settings';

  // Responsive grid: 4 breakpoints
  // large + inspector (>=1280):   240px minmax(0,1fr) 380px
  // large without inspector:      240px minmax(0,1fr)  (full width for main content)
  // medium (960-1279):            240px minmax(0,1fr)
  // compact (720-959):            1fr (sidebar collapsed, top entry only)
  // small (<720):                 1fr (single column)
  const layoutClasses = mode === 'large'
    ? inspectorVisible
      ? 'grid-cols-[var(--pm-sidebar-width)_minmax(0,1fr)_var(--pm-detail-width)]'
      : 'grid-cols-[var(--pm-sidebar-width)_minmax(0,1fr)]'
    : mode === 'medium'
      ? 'grid-cols-[var(--pm-sidebar-width)_minmax(0,1fr)]'
      : 'grid-cols-1';

  return (
    <ToastProvider>
      <SelectedItemContext.Provider value={{ selectedItem, setSelectedItem }}>
        <div className="flex h-full w-full flex-col overflow-hidden acmind-app-shell">
          <TopBar
            snapshot={snapshot}
            onRefresh={snapshot.refresh}
            onNavigate={handleNavigate}
            layoutMode={mode}
            activeView={activeView}
          />

          <div className={`grid flex-1 min-h-0 ${layoutClasses}`}>
            {/* Sidebar — visible in large/medium, hidden in compact/small */}
            <div className={sidebarVisible ? 'min-h-0' : 'hidden'}>
              <Sidebar activeView={activeView} onNavigate={handleNavigate} snapshot={snapshot} />
            </div>

            {/* Main content area */}
            <ScrollContainer className="acmind-window-page min-h-0 overflow-y-auto">
              {children}
            </ScrollContainer>

            {/* Right Inspector — only in large mode (380px via grid) */}
            {inspectorVisible && (
              <div className="min-h-0 flex">
                <RightInspector activeView={activeView} snapshot={snapshot} onNavigate={handleNavigate} />
              </div>
            )}
          </div>
        </div>

        {/* Personal Space Panel */}
        <PersonalSpacePanel
          visible={showPersonalSpace}
          onClose={() => setShowPersonalSpace(false)}
        />
      </SelectedItemContext.Provider>
    </ToastProvider>
  );
}
