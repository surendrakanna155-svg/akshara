import type { Config } from 'tailwindcss';

/**
 * Akshara Web — Tailwind config.
 *
 * Colors map to CSS variables defined in `src/index.css` (`:root` = light,
 * `.dark` = obsidian dark), ported 1:1 from the Flutter M15 design system
 * (`lib/theme/color_tokens.dart`). Utilities like `bg-surface`,
 * `text-on-surface`, `border-outline-variant` mirror the Material 3 token names
 * the Flutter app uses, so a screen reads the same in either codebase.
 */
const withOpacity = (variable: string) => `rgb(var(${variable}) / <alpha-value>)`;

export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: withOpacity('--ak-primary'),
        'on-primary': withOpacity('--ak-on-primary'),
        'primary-container': withOpacity('--ak-primary-container'),
        'on-primary-container': withOpacity('--ak-on-primary-container'),
        secondary: withOpacity('--ak-secondary'),
        'on-secondary': withOpacity('--ak-on-secondary'),
        'secondary-container': withOpacity('--ak-secondary-container'),
        'on-secondary-container': withOpacity('--ak-on-secondary-container'),
        tertiary: withOpacity('--ak-tertiary'),
        'on-tertiary': withOpacity('--ak-on-tertiary'),
        'tertiary-container': withOpacity('--ak-tertiary-container'),
        'on-tertiary-container': withOpacity('--ak-on-tertiary-container'),
        surface: withOpacity('--ak-surface'),
        'surface-low': withOpacity('--ak-surface-low'),
        'surface-container': withOpacity('--ak-surface-container'),
        'surface-high': withOpacity('--ak-surface-high'),
        'surface-highest': withOpacity('--ak-surface-highest'),
        'on-surface': withOpacity('--ak-on-surface'),
        'on-surface-variant': withOpacity('--ak-on-surface-variant'),
        outline: withOpacity('--ak-outline'),
        'outline-variant': withOpacity('--ak-outline-variant'),
        error: withOpacity('--ak-error'),
        'error-container': withOpacity('--ak-error-container'),
        success: withOpacity('--ak-success'),
        'success-container': withOpacity('--ak-success-container'),
        warning: withOpacity('--ak-warning'),
        'warning-container': withOpacity('--ak-warning-container'),
        indigo: withOpacity('--ak-indigo'),
        'indigo-container': withOpacity('--ak-indigo-container'),
        'inverse-surface': withOpacity('--ak-inverse-surface'),
        'on-inverse-surface': withOpacity('--ak-on-inverse-surface'),
        chart1: withOpacity('--ak-chart1'),
        chart2: withOpacity('--ak-chart2'),
        chart3: withOpacity('--ak-chart3'),
        chart4: withOpacity('--ak-chart4'),
        'chart-grid': withOpacity('--ak-chart-grid'),
      },
      fontFamily: {
        sans: ['Roboto', 'system-ui', 'sans-serif'],
        mono: ['"Roboto Mono"', 'ui-monospace', 'monospace'],
      },
      borderRadius: {
        // M15 radius tokens (lib/theme/radius.dart)
        xs: '6px',
        sm: '8px',
        md: '12px',
        lg: '16px',
        xl: '20px',
        '2xl': '24px',
        full: '999px',
      },
      spacing: {
        // M15 8pt scale (lib/theme/spacing.dart) — s1..s16
        s0: '0px',
        s1: '4px',
        s2: '8px',
        s3: '12px',
        s4: '16px',
        s5: '20px',
        s6: '24px',
        s7: '28px',
        s8: '32px',
        s10: '40px',
        s12: '48px',
        s16: '64px',
        'rail-expanded': '260px',
        'rail-collapsed': '72px',
      },
      maxWidth: {
        content: '1136px',
        frame: '1440px',
        reading: '640px',
        compact: '480px',
      },
      boxShadow: {
        // M15 soft layered elevation (lib/theme/elevation.dart + shadows.dart)
        'ak-1': '0 1px 2px 0 rgb(var(--ak-shadow) / 0.06)',
        'ak-2': '0 1px 3px 0 rgb(var(--ak-shadow) / 0.08), 0 1px 2px -1px rgb(var(--ak-shadow) / 0.06)',
        'ak-3': '0 4px 8px -2px rgb(var(--ak-shadow) / 0.10), 0 2px 4px -2px rgb(var(--ak-shadow) / 0.06)',
        'ak-4': '0 8px 16px -4px rgb(var(--ak-shadow) / 0.12), 0 4px 6px -4px rgb(var(--ak-shadow) / 0.08)',
        'ak-5': '0 12px 24px -6px rgb(var(--ak-shadow) / 0.16), 0 6px 8px -6px rgb(var(--ak-shadow) / 0.10)',
      },
      transitionTimingFunction: {
        // M15 motion (lib/theme/motion.dart)
        enter: 'cubic-bezier(0.215, 0.61, 0.355, 1)',
        exit: 'cubic-bezier(0.55, 0.055, 0.675, 0.19)',
      },
      transitionDuration: {
        instant: '80ms',
        fast: '120ms',
        standard: '180ms',
        slow: '240ms',
      },
    },
  },
  plugins: [],
} satisfies Config;
