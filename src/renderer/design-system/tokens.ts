export type ThemeMode = 'light' | 'dark';

export interface ThemeColorTokens {
  appBg: string;
  pageBg: string;
  sidebarBg: string;
  toolbarBg: string;
  surface: string;
  surfaceMuted: string;
  elevated: string;
  overlay: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  textMuted: string;
  textDisabled: string;
  textInverse: string;
  accent: string;
  accentHover: string;
  accentSoft: string;
  borderSubtle: string;
  borderStrong: string;
  shadowNeutral: string;
  shadowFloating: string;
  success: string;
  successSoft: string;
  warning: string;
  warningSoft: string;
  info: string;
  infoSoft: string;
  danger: string;
  dangerSoft: string;
  mock: string;
  mockSoft: string;
}

export interface DesignSystemTokens {
  color: Record<ThemeMode, ThemeColorTokens> & {
    semantic: {
      neutral: ThemeColorTokens['textSecondary'];
      info: ThemeColorTokens['info'];
      success: ThemeColorTokens['success'];
      warning: ThemeColorTokens['warning'];
      danger: ThemeColorTokens['danger'];
      processing: ThemeColorTokens['info'];
      mock: ThemeColorTokens['mock'];
    };
    aiTier: {
      local: string;
      cloudStandard: string;
      cloudAdvanced: string;
      mock: string;
    };
  };
  radius: {
    button: number;
    input: number;
    card: number;
    floating: number;
    badge: number;
  };
  space: {
    page: number;
    card: number;
    xs: number;
    sm: number;
    md: number;
    lg: number;
    xl: number;
    '2xl': number;
  };
  shadow: {
    card: string;
    cardHover: string;
    elevated: string;
    floating: string;
  };
  typography: {
    fontFamilySans: string;
    fontFamilyMono: string;
    fontFamilySerif: string;
    fontFamilyCjk: string;
    largeTitle: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    title1: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    title2: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    title3: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    headline: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    body: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    callout: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    subhead: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    footnote: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    caption1: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    caption2: { size: number; lineHeight: number; weight: number; letterSpacing: string };
    /** @deprecated Use largeTitle instead */
    pageTitle: { size: number; lineHeight: number; weight: number };
    /** @deprecated Use caption instead */
    caption: { size: number; lineHeight: number; weight: number };
    /** @deprecated Use footnote instead */
    micro: { size: number; lineHeight: number; weight: number };
  };
  motion: {
    duration: {
      instant: number;
      fast: number;
      normal: number;
      slow: number;
      /** @deprecated Use normal instead */
      base: number;
    };
    easing: {
      standard: string;
      spring: string;
      decelerate: string;
      accelerate: string;
    };
  };
}

export const LIGHT_THEME_TOKENS: ThemeColorTokens = {
  appBg: '#f6f7f8',
  pageBg: '#fbfbfc',
  sidebarBg: 'rgba(246, 247, 248, 0.88)',
  toolbarBg: 'rgba(251, 251, 252, 0.88)',
  surface: '#ffffff',
  surfaceMuted: '#f5f6f7',
  elevated: '#ffffff',
  overlay: 'rgba(17, 24, 39, 0.32)',
  textPrimary: '#1d1d1f',
  textSecondary: '#4b4b53',
  textTertiary: '#6e6e73',
  textMuted: '#a1a1a6',
  textDisabled: '#c1c1c7',
  textInverse: '#ffffff',
  accent: '#ff6b2b',
  accentHover: '#e55a1b',
  accentSoft: '#fff2ec',
  borderSubtle: 'rgba(17, 24, 39, 0.08)',
  borderStrong: 'rgba(17, 24, 39, 0.14)',
  shadowNeutral: '0 10px 28px rgba(17, 24, 39, 0.06)',
  shadowFloating: '0 18px 42px rgba(17, 24, 39, 0.12)',
  success: '#15803d',
  successSoft: '#dcfce7',
  warning: '#92400e',
  warningSoft: '#fef3c7',
  info: '#1d4ed8',
  infoSoft: '#dbeafe',
  danger: '#dc2626',
  dangerSoft: '#fee2e2',
  mock: '#52525b',
  mockSoft: '#f4f4f5',
};

export const DARK_THEME_TOKENS: ThemeColorTokens = {
  appBg: '#1e1e1e',
  pageBg: '#262626',
  sidebarBg: 'rgba(44, 44, 46, 0.78)',
  toolbarBg: 'rgba(28, 28, 30, 0.82)',
  surface: '#2c2c2e',
  surfaceMuted: '#262628',
  elevated: '#323234',
  overlay: 'rgba(0, 0, 0, 0.45)',
  textPrimary: '#f5f5f7',
  textSecondary: '#d1d1d6',
  textTertiary: '#a1a1a6',
  textMuted: '#6e6e73',
  textDisabled: '#52525b',
  textInverse: '#1d1d1f',
  accent: '#ff8f5e',
  accentHover: '#ffa87a',
  accentSoft: '#3d2a1e',
  borderSubtle: 'rgba(255, 255, 255, 0.08)',
  borderStrong: 'rgba(255, 255, 255, 0.14)',
  shadowNeutral: '0 10px 28px rgba(0, 0, 0, 0.28)',
  shadowFloating: '0 18px 42px rgba(0, 0, 0, 0.38)',
  success: '#4ade80',
  successSoft: '#052e16',
  warning: '#fbbf24',
  warningSoft: '#422006',
  info: '#60a5fa',
  infoSoft: '#172554',
  danger: '#f87171',
  dangerSoft: '#450a0a',
  mock: '#a1a1aa',
  mockSoft: '#27272a',
};

export const DESIGN_TOKENS: DesignSystemTokens = {
  color: {
    light: LIGHT_THEME_TOKENS,
    dark: DARK_THEME_TOKENS,
    semantic: {
      neutral: LIGHT_THEME_TOKENS.textSecondary,
      info: LIGHT_THEME_TOKENS.info,
      success: LIGHT_THEME_TOKENS.success,
      warning: LIGHT_THEME_TOKENS.warning,
      danger: LIGHT_THEME_TOKENS.danger,
      processing: LIGHT_THEME_TOKENS.info,
      mock: LIGHT_THEME_TOKENS.mock,
    },
    aiTier: {
      local: '#16a34a',
      cloudStandard: '#2563eb',
      cloudAdvanced: '#7c3aed',
      mock: '#71717a',
    },
  },
  radius: {
    button: 6,
    input: 6,
    card: 10,
    floating: 12,
    badge: 999,
  },
  space: {
    page: 20,
    card: 16,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    '2xl': 24,
  },
  shadow: {
    card: LIGHT_THEME_TOKENS.shadowNeutral,
    cardHover: '0 12px 32px rgba(17, 24, 39, 0.08)',
    elevated: '0 16px 38px rgba(17, 24, 39, 0.12)',
    floating: LIGHT_THEME_TOKENS.shadowFloating,
  },
  typography: {
    fontFamilySans:
      '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", "Helvetica Neue", sans-serif',
    fontFamilyMono:
      '"SF Mono", ui-monospace, "Cascadia Code", "Menlo", monospace',
    fontFamilySerif:
      '"New York", "Songti SC", serif',
    fontFamilyCjk:
      '"PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif',
    largeTitle: { size: 26, lineHeight: 32, weight: 700, letterSpacing: '-0.02em' },
    title1:     { size: 22, lineHeight: 28, weight: 700, letterSpacing: '-0.02em' },
    title2:     { size: 17, lineHeight: 22, weight: 600, letterSpacing: '-0.01em' },
    title3:     { size: 15, lineHeight: 20, weight: 600, letterSpacing: '0' },
    headline:   { size: 13, lineHeight: 18, weight: 600, letterSpacing: '0' },
    body:       { size: 13, lineHeight: 18, weight: 400, letterSpacing: '0' },
    callout:    { size: 12, lineHeight: 16, weight: 400, letterSpacing: '0.01em' },
    subhead:    { size: 12, lineHeight: 16, weight: 400, letterSpacing: '0.01em' },
    footnote:   { size: 11, lineHeight: 14, weight: 400, letterSpacing: '0.01em' },
    caption1:   { size: 10, lineHeight: 13, weight: 500, letterSpacing: '0.02em' },
    caption2:   { size: 10, lineHeight: 13, weight: 400, letterSpacing: '0.02em' },
    // Deprecated aliases (kept for backward compatibility)
    pageTitle:  { size: 26, lineHeight: 32, weight: 700 },
    caption:    { size: 12, lineHeight: 16, weight: 400 },
    micro:      { size: 11, lineHeight: 14, weight: 500 },
  },
  motion: {
    duration: {
      instant: 50,
      fast: 100,
      normal: 200,
      slow: 300,
      base: 200, // deprecated alias
    },
    easing: {
      standard: 'cubic-bezier(0.25, 0.1, 0.25, 1.0)',
      spring: 'cubic-bezier(0.34, 1.56, 0.64, 1.0)',
      decelerate: 'cubic-bezier(0, 0, 0.2, 1)',
      accelerate: 'cubic-bezier(0.4, 0, 1, 1)',
    },
  },
};

