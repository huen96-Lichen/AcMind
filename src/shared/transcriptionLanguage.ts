const LANGUAGE_ALIASES: Record<string, string> = {
  chinese: 'zh',
  mandarin: 'zh',
  'simplified chinese': 'zh',
  'traditional chinese': 'zh',
  cantonese: 'yue',
  english: 'en',
  japanese: 'ja',
  korean: 'ko',
  spanish: 'es',
  french: 'fr',
  german: 'de',
  italian: 'it',
  portuguese: 'pt',
  russian: 'ru',
  arabic: 'ar',
};

/**
 * Normalize a transcription language for Whisper-compatible engines.
 *
 * - Converts locale tags like `zh-CN` and `en-US` to base language codes.
 * - Maps common language names to the codes accepted by whisper-ctranslate2.
 * - Treats `auto` / empty values as "let the engine auto-detect".
 */
export function normalizeTranscriptionLanguage(language?: string | null, fallback?: string): string | undefined {
  const trimmed = language?.trim();
  if (!trimmed) {
    return fallback;
  }

  const lower = trimmed.toLowerCase();
  if (lower === 'auto') {
    return undefined;
  }

  const alias = LANGUAGE_ALIASES[lower];
  if (alias) {
    return alias;
  }

  if (/-|_/.test(trimmed)) {
    const base = lower.split(/[-_]/)[0];
    if (base && base !== 'auto') {
      return base;
    }
  }

  return fallback ?? trimmed;
}
