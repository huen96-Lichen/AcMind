import type { AppSettings } from '../shared/types';

export function normalizeAppScopeValue(value: string | null | undefined): string {
  return (value ?? '').trim().toLowerCase();
}

export function isAppWithinScope(settings: Pick<AppSettings, 'scopeMode' | 'scopedApps'>, appName: string | null | undefined): boolean {
  const mode = (settings.scopeMode as string);
  if (mode === 'global' || mode === 'all') {
    return true;
  }

  const normalized = normalizeAppScopeValue(appName);
  const scopedApps = new Set(settings.scopedApps.map((item) => normalizeAppScopeValue(item)).filter(Boolean));
  if (!normalized) {
    return mode !== 'whitelist';
  }

  if (mode === 'blacklist') {
    return !scopedApps.has(normalized);
  }

  return scopedApps.has(normalized);
}
