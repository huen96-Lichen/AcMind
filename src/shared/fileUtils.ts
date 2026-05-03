import type { AssetFileKind } from './types';

/**
 * Extension → AssetFileKind mapping.
 * Exported for testing and extension.
 */
export const EXT_TO_KIND_MAP: Record<string, AssetFileKind> = {
  '.png': 'image', '.jpg': 'image', '.jpeg': 'image', '.gif': 'image',
  '.webp': 'image', '.svg': 'image', '.bmp': 'image', '.ico': 'image',
  '.mp3': 'audio', '.wav': 'audio', '.flac': 'audio', '.ogg': 'audio',
  '.aac': 'audio', '.m4a': 'audio',
  '.mp4': 'video', '.mov': 'video', '.avi': 'video', '.mkv': 'video',
  '.webm': 'video',
  '.pdf': 'pdf',
  '.docx': 'docx', '.doc': 'docx',
  '.html': 'html', '.htm': 'html',
  '.md': 'markdown', '.markdown': 'markdown',
};

/**
 * Infer AssetFileKind from a file extension (lowercase, with leading dot).
 * Falls back to 'other' for unknown extensions.
 */
export function inferFileKind(ext: string): AssetFileKind {
  return EXT_TO_KIND_MAP[ext] ?? 'other';
}
