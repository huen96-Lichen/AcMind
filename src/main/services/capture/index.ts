// AcMind Capture Adapters — Barrel Export
// V2.1 Phase 7.1: Unified entry point for all capture adapters.

export { captureRegistry } from './captureRegistry';
export type { CaptureInput } from './captureRegistry';

export { manualTextAdapter } from './manualTextAdapter';
export type { ManualTextInput } from './manualTextAdapter';

export { clipboardTextAdapter } from './clipboardTextAdapter';
export type { ClipboardTextInput } from './clipboardTextAdapter';

export { screenshotAdapter } from './screenshotAdapter';
export type { ScreenshotInput } from './screenshotAdapter';

export { webpageAdapter } from './webpageAdapter';
export type { WebpageInput } from './webpageAdapter';

export { fileAdapter } from './fileAdapter';
export type { FileInput } from './fileAdapter';

export { imageAdapter } from './imageAdapter';
export type { ImageInput } from './imageAdapter';

export { audioAdapter } from './audioAdapter';
export type { AudioInput } from './audioAdapter';

export { videoAdapter } from './videoAdapter';
export type { VideoInput } from './videoAdapter';
