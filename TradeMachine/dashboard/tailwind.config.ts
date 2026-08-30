import type { Config } from 'tailwindcss';
import { tokens } from './src/design/tokens';

/**
 * Tailwind is configured entirely FROM the token module — no hex literals are
 * written here. This keeps the web theme and the generated Flutter theme
 * provably in sync: both read the same object.
 */

const px = (n: number): string => `${n}px`;

/** `{ 4: 16 }` -> `{ '4': '16px' }` for Tailwind's spacing scale. */
const spacingScale = Object.fromEntries(
  Object.entries(tokens.spacing).map(([key, value]) => [key, px(value)]),
);

/** `{ md: 8 }` -> `{ md: '8px' }`. */
const radiusScale = Object.fromEntries(
  Object.entries(tokens.radius).map(([key, value]) => [key, px(value)]),
);

/** `{ body: [14, 21] }` -> `{ body: ['14px', { lineHeight: '21px' }] }`. */
const fontSizeScale = Object.fromEntries(
  Object.entries(tokens.typography.scale).map(([key, [size, lineHeight]]) => [
    key,
    [px(size), { lineHeight: px(lineHeight) }],
  ]),
);

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        surface: tokens.surface,
        content: tokens.text,
        market: tokens.market,
        accent: tokens.accent,
        status: tokens.status,
        chart: tokens.chart,
      },
      spacing: spacingScale,
      borderRadius: radiusScale,
      fontSize: fontSizeScale,
      fontFamily: {
        sans: [tokens.typography.fontFamily.sans],
        mono: [tokens.typography.fontFamily.mono],
      },
      fontWeight: tokens.typography.weight,
      boxShadow: {
        sm: tokens.elevation.sm,
        md: tokens.elevation.md,
        lg: tokens.elevation.lg,
      },
      transitionDuration: {
        instant: `${tokens.motion.duration.instant}ms`,
        fast: `${tokens.motion.duration.fast}ms`,
        normal: `${tokens.motion.duration.normal}ms`,
      },
      transitionTimingFunction: {
        standard: tokens.motion.easing.standard,
        decelerate: tokens.motion.easing.decelerate,
      },
      maxWidth: {
        content: px(tokens.layout.contentMaxWidth),
      },
      keyframes: {
        'pulse-ring': {
          '0%': { opacity: '0.9', transform: 'scale(0.9)' },
          '70%': { opacity: '0', transform: 'scale(1.7)' },
          '100%': { opacity: '0', transform: 'scale(1.7)' },
        },
        'value-flash': {
          '0%': { backgroundColor: 'transparent' },
          '25%': { backgroundColor: 'currentColor' },
          '100%': { backgroundColor: 'transparent' },
        },
      },
      animation: {
        'pulse-ring': 'pulse-ring 1.8s cubic-bezier(0, 0, 0.2, 1) infinite',
        'value-flash': 'value-flash 500ms ease-out',
      },
    },
  },
  plugins: [],
} satisfies Config;
