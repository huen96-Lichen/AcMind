// ─── Widget Window Entry Point ─────────────────────────────────
// Dedicated entry for the dashboard widget BrowserWindow.
// Renders DashboardWidgetPage directly WITHOUT App.tsx routing
// and WITHOUT importing global styles.css.
//
// Loaded by: widget.html

import { createRoot } from 'react-dom/client';
import { DashboardWidgetPage } from './pages/dashboard-widget/DashboardWidgetPage';

const rootEl = document.getElementById('root');
if (rootEl) {
  createRoot(rootEl).render(<DashboardWidgetPage />);
}
