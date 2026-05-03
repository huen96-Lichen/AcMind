import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: 'media',
  content: ['./src/renderer/**/*.{html,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        acmind: {
          app: 'var(--pm-bg-app)',
          window: 'var(--pm-bg-window)',
          sidebar: 'var(--pm-bg-sidebar)',
          surface: 'var(--pm-bg-surface)',
          surfaceSoft: 'var(--pm-bg-surface-soft)',
          subtle: 'var(--pm-bg-subtle)',
          hover: 'var(--pm-bg-hover)',
          selected: 'var(--pm-bg-selected)',
          overlay: 'var(--pm-bg-overlay)',
          primaryText: 'var(--pm-text-main)',
          secondaryText: 'var(--pm-text-secondary)',
          tertiaryText: 'var(--pm-text-tertiary)',
          disabledText: 'var(--pm-text-disabled)',
          inverseText: 'var(--pm-text-inverse)',
          brandText: 'var(--pm-text-brand)',
          border: 'var(--pm-border)',
          borderSoft: 'var(--pm-border-soft)',
          borderStrong: 'var(--pm-border-strong)',
          borderBrand: 'var(--pm-border-brand)',
          divider: 'var(--pm-divider)',
          brand: 'var(--pm-brand)',
          brandHover: 'var(--pm-brand-hover)',
          brandActive: 'var(--pm-brand-active)',
          brandSoft: 'var(--pm-brand-soft)',
          brandSubtle: 'var(--pm-brand-subtle)',
          brandBorder: 'var(--pm-brand-border)',
          success: 'var(--pm-success)',
          successText: 'var(--pm-success-text)',
          successBg: 'var(--pm-success-bg)',
          successBorder: 'var(--pm-success-border)',
          info: 'var(--pm-info)',
          infoText: 'var(--pm-info-text)',
          infoBg: 'var(--pm-info-bg)',
          infoBorder: 'var(--pm-info-border)',
          warning: 'var(--pm-warning)',
          warningText: 'var(--pm-warning-text)',
          warningBg: 'var(--pm-warning-bg)',
          warningBorder: 'var(--pm-warning-border)',
          danger: 'var(--pm-danger)',
          dangerText: 'var(--pm-danger-text)',
          dangerBg: 'var(--pm-danger-bg)',
          dangerBorder: 'var(--pm-danger-border)',
          purple: 'var(--pm-purple)',
          purpleText: 'var(--pm-purple-text)',
          purpleBg: 'var(--pm-purple-bg)',
          purpleBorder: 'var(--pm-purple-border)',
          iconDefault: 'var(--pm-icon-default)',
          iconMuted: 'var(--pm-icon-muted)',
          iconActive: 'var(--pm-icon-active)',
        }
      },
      borderRadius: {
        xs: '4px',
        sm: '6px',
        DEFAULT: '8px',
        md: '8px',
        lg: '10px',
        xl: '12px',
        '2xl': '16px',
        full: '999px'
      },
      fontSize: {
        xs: ['10px', { lineHeight: '13px', letterSpacing: '0.02em' }],
        sm: ['11px', { lineHeight: '14px', letterSpacing: '0.01em' }],
        base: ['13px', { lineHeight: '18px' }],
        lg: ['15px', { lineHeight: '20px' }],
        xl: ['17px', { lineHeight: '22px', letterSpacing: '-0.01em' }],
        '2xl': ['22px', { lineHeight: '28px', letterSpacing: '-0.02em' }],
        '3xl': ['26px', { lineHeight: '32px', letterSpacing: '-0.02em' }]
      },
      boxShadow: {
        glass: '0 18px 34px rgba(0, 0, 0, 0.16)',
        acmindXs: '0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04)',
        acmindSm: '0 4px 12px rgba(0, 0, 0, 0.08), 0 2px 4px rgba(0, 0, 0, 0.04)',
        acmindMd: '0 12px 40px rgba(0, 0, 0, 0.12), 0 4px 12px rgba(0, 0, 0, 0.06)',
        acmindLg: '0 24px 64px rgba(0, 0, 0, 0.16), 0 8px 20px rgba(0, 0, 0, 0.08)'
      },
      backdropBlur: {
        xs: '2px'
      }
    }
  },
  plugins: []
};

export default config;
