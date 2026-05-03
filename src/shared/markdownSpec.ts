// Phase 1: 不再硬编码开发者路径，使用空字符串作为默认值
// 用户需要在设置中配置实际的 Obsidian vault 路径
export const PINMIND_MARKDOWN_SPEC_DIR = '';

export const DEFAULT_OBSIDIAN_DOCUMENTS_ROOT = '';

export const DEFAULT_LOCAL_MODEL_ID = 'gemma4:e4b';

export const DEFAULT_DISTILLED_CATEGORY = '00_Inbox/PinMind';

export const DEFAULT_DISTILLED_TYPE = 'distilled-note';

export const DEFAULT_DISTILLED_LINKS = ['PinMind', '第二大脑', '本地蒸馏'];

export const DISTILLED_DOCUMENT_TYPES = [
  'index',
  'project-note',
  'decision',
  'task',
  'review',
  'bug-note',
  'learning-note',
  'diary',
  'meeting-note',
  'reference',
  'prompt',
  'template',
  'distilled-note',
  'dataset-note',
] as const;

export type DistilledDocumentType = (typeof DISTILLED_DOCUMENT_TYPES)[number];
