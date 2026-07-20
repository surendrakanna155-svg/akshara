/**
 * M15 non-color tokens for use in TS (charts, layout math, motion).
 * Colors live as CSS variables (src/index.css) + Tailwind utilities.
 * Mirrors lib/theme/{spacing,radius,motion,breakpoints}.dart.
 */

export const breakpoints = {
  mobileMax: 767,
  tabletMax: 1199,
  tabletMin: 768,
  desktopMin: 1200,
  desktopContentMaxWidth: 1136,
  desktopFrameWidth: 1440,
} as const;

export const motion = {
  instant: 0.08,
  fast: 0.12,
  standard: 0.18,
  slow: 0.24,
  enter: [0.215, 0.61, 0.355, 1] as [number, number, number, number],
  exit: [0.55, 0.055, 0.675, 0.19] as [number, number, number, number],
} as const;

export const railWidth = { expanded: 260, collapsed: 72 } as const;

/** Reads a themed chart color from the live CSS variables (respects light/dark). */
export function cssVarColor(name: string): string {
  if (typeof window === 'undefined') return '#1A56DB';
  const raw = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return raw ? `rgb(${raw})` : '#1A56DB';
}

export function chartPalette(): string[] {
  return [
    cssVarColor('--ak-chart1'),
    cssVarColor('--ak-chart2'),
    cssVarColor('--ak-chart3'),
    cssVarColor('--ak-chart4'),
  ];
}
