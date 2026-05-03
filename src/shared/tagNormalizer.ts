// AcMind Tag Normalizer
// Centralized tag cleaning, deduplication, and formatting.
// ALL tag output MUST go through this module before reaching frontmatter.
//
// Rules:
//   - Lowercase
//   - Spaces → hyphens
//   - Remove special characters (#, !, @, etc.)
//   - Remove leading/trailing hyphens
//   - Deduplicate (case-insensitive)
//   - Limit length (max 30 chars per tag)
//   - Limit count (3-7 tags per item)
//   - Always include 'acmind' default tag
//   - Optionally include 'inbox' default tag

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface TagNormalizerOptions {
  /** Maximum number of tags per item (default: 7) */
  maxTags?: number;
  /** Minimum number of tags per item (default: 3) */
  minTags?: number;
  /** Maximum length per tag in characters (default: 30) */
  maxTagLength?: number;
  /** Whether to always include 'acmind' tag (default: true) */
  includeAcMind?: boolean;
  /** Whether to include 'inbox' tag (default: false) */
  includeInbox?: boolean;
  /** Additional default tags to always include */
  extraDefaults?: string[];
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_MAX_TAGS = 7;
const DEFAULT_MIN_TAGS = 3;
const DEFAULT_MAX_TAG_LENGTH = 30;

// Characters to strip from tags
const STRIP_CHARS = /[#\-_!@#$%^&*()+=\[\]{}|\\:;"'<>,.?/~`\s]+/g;

// ---------------------------------------------------------------------------
// TagNormalizer
// ---------------------------------------------------------------------------

/**
 * Normalize a single tag string.
 * - Lowercase
 * - Strip special characters
 * - Spaces → hyphens
 * - Trim hyphens
 * - Limit length
 */
function normalizeSingleTag(tag: string, maxLength: number): string {
  if (!tag || typeof tag !== 'string') return '';

  let normalized = tag
    .trim()
    .toLowerCase()
    // Remove leading #
    .replace(/^#+/, '')
    // Replace spaces and special chars with hyphens
    .replace(STRIP_CHARS, '-')
    // Remove consecutive hyphens
    .replace(/-+/g, '-')
    // Remove leading/trailing hyphens
    .replace(/^-+/, '')
    .replace(/-+$/, '');

  // Limit length
  if (normalized.length > maxLength) {
    normalized = normalized.substring(0, maxLength).replace(/-+$/, '');
  }

  return normalized;
}

/**
 * Remove near-duplicate tags (case-insensitive, after normalization).
 * Also removes tags that are substrings of longer tags (e.g., "ai" if "ai-tools" exists).
 */
function deduplicateTags(tags: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  // Sort by length descending so longer tags take priority
  const sorted = [...tags].sort((a, b) => b.length - a.length);

  for (const tag of sorted) {
    const lower = tag.toLowerCase();
    if (seen.has(lower)) continue;

    // Skip if this tag is a substring of an already-seen longer tag
    let isSubstring = false;
    for (const existing of seen) {
      if (existing.includes(lower) && existing !== lower) {
        isSubstring = true;
        break;
      }
    }
    if (isSubstring) continue;

    seen.add(lower);
    result.push(tag);
  }

  // Restore original order (by first appearance in input)
  const orderMap = new Map(tags.map((t, i) => [t.toLowerCase(), i]));
  result.sort((a, b) => (orderMap.get(a.toLowerCase()) ?? 0) - (orderMap.get(b.toLowerCase()) ?? 0));

  return result;
}

/**
 * Normalize an array of tags.
 *
 * This is the main entry point — ALL tag arrays MUST pass through here
 * before being written to frontmatter or stored.
 *
 * @param rawTags - Raw tag array from AI output, extraction, or user input
 * @param options - Normalization options
 * @returns Cleaned, deduplicated, limited tag array
 */
export function normalizeTags(
  rawTags: string[] | undefined | null,
  options?: TagNormalizerOptions,
): string[] {
  const maxTags = options?.maxTags ?? DEFAULT_MAX_TAGS;
  const minTags = options?.minTags ?? DEFAULT_MIN_TAGS;
  const maxTagLength = options?.maxTagLength ?? DEFAULT_MAX_TAG_LENGTH;
  const includeAcMind = options?.includeAcMind !== false; // default true
  const includeInbox = options?.includeInbox ?? false;
  const extraDefaults = options?.extraDefaults ?? [];

  // 1. Normalize each tag
  const normalized = (rawTags ?? [])
    .map((t) => normalizeSingleTag(t, maxTagLength))
    .filter(Boolean);

  // 2. Deduplicate
  const deduped = deduplicateTags(normalized);

  // 3. Build result with defaults
  const result: string[] = [];

  // Add default tags first
  if (includeAcMind && !deduped.includes('acmind')) {
    result.push('acmind');
  }
  if (includeInbox && !deduped.includes('inbox')) {
    result.push('inbox');
  }
  for (const def of extraDefaults) {
    const clean = normalizeSingleTag(def, maxTagLength);
    if (clean && !result.includes(clean) && !deduped.includes(clean)) {
      result.push(clean);
    }
  }

  // Add user/AI tags (skip if already in defaults)
  for (const tag of deduped) {
    if (!result.includes(tag)) {
      result.push(tag);
    }
  }

  // 4. Limit count
  return result.slice(0, maxTags);
}

/**
 * Check if tags meet the minimum count requirement.
 * Returns the tags as-is if they do, or pads with defaults if needed.
 */
export function ensureMinTags(
  tags: string[],
  options?: TagNormalizerOptions,
): string[] {
  const minTags = options?.minTags ?? DEFAULT_MIN_TAGS;
  if (tags.length >= minTags) return tags;

  const defaults: string[] = [];
  if (!tags.includes('acmind')) defaults.push('acmind');
  if (!tags.includes('inbox') && (options?.includeInbox ?? false)) defaults.push('inbox');

  const padded = [...tags, ...defaults];
  return padded.slice(0, Math.max(minTags, padded.length));
}
