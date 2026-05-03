// ─── Pinned Image Window Entry Point ─────────────────────────────
// This is the dedicated entry for the pinned image BrowserWindow.
// It renders PinnedImageView directly WITHOUT going through App.tsx routing.
//
// Loaded by: pinned-image.html

import { createRoot } from 'react-dom/client';
import { PinnedImageView } from './pages/pinned-image/PinnedImageView';

const rootEl = document.getElementById('root');
if (rootEl) {
  createRoot(rootEl).render(<PinnedImageView />);
}
