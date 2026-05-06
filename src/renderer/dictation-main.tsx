// ─── Dictation Capsule Window Entry Point ──────────────────────
// Dedicated entry for the dictation capsule BrowserWindow.
// Renders DictationCapsule directly WITHOUT App.tsx routing
// and WITHOUT importing global styles.css.
//
// Loaded by: dictation.html

import { createRoot } from 'react-dom/client';
import { DictationCapsule } from './pages/dictation/DictationCapsule';

const rootEl = document.getElementById('root');
if (rootEl) {
  createRoot(rootEl).render(<DictationCapsule />);
}
