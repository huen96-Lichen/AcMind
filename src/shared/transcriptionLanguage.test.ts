import { describe, expect, it } from 'vitest';
import { normalizeTranscriptionLanguage } from './transcriptionLanguage';

describe('normalizeTranscriptionLanguage', () => {
  it('normalizes locale tags to base codes', () => {
    expect(normalizeTranscriptionLanguage('zh-CN')).toBe('zh');
    expect(normalizeTranscriptionLanguage('en-US')).toBe('en');
    expect(normalizeTranscriptionLanguage('yue-HK')).toBe('yue');
  });

  it('maps common language names to whisper-compatible codes', () => {
    expect(normalizeTranscriptionLanguage('Chinese')).toBe('zh');
    expect(normalizeTranscriptionLanguage('Mandarin')).toBe('zh');
    expect(normalizeTranscriptionLanguage('Cantonese')).toBe('yue');
  });

  it('keeps plain language names when they are not locale tags or aliases', () => {
    expect(normalizeTranscriptionLanguage('Norwegian')).toBe('Norwegian');
  });

  it('lets auto-detection pass through as undefined', () => {
    expect(normalizeTranscriptionLanguage('auto')).toBeUndefined();
    expect(normalizeTranscriptionLanguage('')).toBeUndefined();
    expect(normalizeTranscriptionLanguage('   ')).toBeUndefined();
  });

  it('falls back when input is missing', () => {
    expect(normalizeTranscriptionLanguage(undefined, 'zh')).toBe('zh');
  });
});
