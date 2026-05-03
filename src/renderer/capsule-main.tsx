// ─── Capsule Window Entry Point ─────────────────────────────────
// This is the dedicated entry for the capsule BrowserWindow.
// It renders CapsulePage directly WITHOUT going through App.tsx routing,
// and WITHOUT importing global styles.css.
//
// Loaded by: capsule.html

import { createRoot } from 'react-dom/client';
import { CapsulePage } from './pages/capsule/CapsulePage';

const rootEl = document.getElementById('root');
if (rootEl) {
  createRoot(rootEl).render(<CapsulePage />);
}
