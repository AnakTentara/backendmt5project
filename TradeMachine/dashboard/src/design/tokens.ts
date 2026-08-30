/**
 * Design tokens — single source of truth for the visual language.
 *
 * WHY THIS FILE EXISTS AS DATA, NOT CSS
 * -------------------------------------
 * Tailwind consumes these values via `tailwind.config.ts`, and
 * `scripts/export-dart-theme.ts` reads the very same object to generate a
 * Flutter `ThemeData`. Colours therefore live in exactly one place. If a token
 * is only ever written as a CSS class or a hex literal inside a component, it
 * cannot be ported, so treat inline hex values in components as a bug.
 *
 * RULES
 * - Every colour is a plain 6-digit hex string. No `rgb()`, no `hsl()`, no
 *   `oklch()`, no CSS variables, no alpha shorthand. Dart's `Color` constructor
 *   takes `0xAARRGGBB`, and the exporter does a mechanical string transform.
 * - Spacing and radii are unitless numbers in logical pixels. Tailwind appends
 *   `px`; Flutter uses them as doubles directly.
 * - Never import this file for its side effects. It is pure data.
 */

/** Semantic intent shared by badges, gauges, and status text. */
export type SemanticTone =
  | 'neutral'
  | 'info'
  | 'success'
  | 'warning'
  | 'danger'
  | 'critical';

/**
 * Surface ramp, darkest to lightest.
 *
 * A trading desk runs for hours, so the palette is a low-luminance neutral
 * rather than pure black. Pure `#000000` against bright P&L text produces
 * halation and measurably faster eye fatigue.
 */
export const surface = {
  /** App background, behind all panels. */
  base: '#0A0E17',
  /** Default panel/card background. */
  raised: '#111725',
  /** Nested panel, table header, input background. */
  overlay: '#182032',
  /** Hover state for interactive rows. */
  hover: '#1E283C',
  /** Pressed state and active nav item. */
  active: '#25314A',
  /** Hairline borders between regions. */
  border: '#232D42',
  /** Stronger border for focused inputs. */
  borderStrong: '#33405C',
} as const;

/** Foreground ramp. Contrast ratios are stated against `surface.raised`. */
export const text = {
  /** Headings and primary numerals. ~14.8:1 */
  primary: '#E8EDF7',
  /** Body copy and labels. ~8.2:1 */
  secondary: '#A7B2C7',
  /** Axis ticks, captions, metadata. ~4.7:1 — the WCAG AA floor for 14px. */
  muted: '#7A879E',
  /** Disabled only. Fails AA by design; never use for meaningful content. */
  disabled: '#4E5A70',
  /** Text on a saturated accent fill. */
  inverse: '#08111F',
} as const;

/**
 * Market direction colours.
 *
 * Deliberately teal/amber rather than the conventional green/red. Roughly 1 in
 * 12 men has a red-green colour vision deficiency, and profit/loss is the most
 * consequential signal on the screen. Teal versus amber stays separable under
 * deuteranopia and protanopia. Direction is additionally encoded by an arrow
 * glyph and a sign prefix, so colour is never the sole carrier of meaning.
 */
export const market = {
  /** Price up, profit, buy. */
  bull: '#00C9A7',
  bullSoft: '#0B3E39',
  bullBorder: '#12695F',

  /** Price down, loss, sell. */
  bear: '#FF7A45',
  bearSoft: '#40211A',
  bearBorder: '#8A3F27',

  /** No direction / flat. */
  flat: '#7A879E',
  flatSoft: '#1E283C',
} as const;

/** Accent used for primary actions, focus rings, and active chart series. */
export const accent = {
  base: '#3D8BFF',
  hover: '#5A9DFF',
  pressed: '#2E72D9',
  soft: '#12233D',
  border: '#2B5FA8',
} as const;

/**
 * Status colours for the state machines exposed by the backend.
 *
 * `SPREAD_STATE` in Types.mqh has five levels and `TP_STATE` has six, so the
 * ramp runs all the way to `critical` — a distinct step beyond `danger`,
 * reserved for conditions that trigger automatic position closure.
 */
export const status = {
  neutral: '#7A879E',
  neutralSoft: '#1E283C',

  info: '#3D8BFF',
  infoSoft: '#12233D',

  success: '#00C9A7',
  successSoft: '#0B3E39',

  warning: '#F5B93B',
  warningSoft: '#3D2F0F',

  danger: '#FF7A45',
  dangerSoft: '#40211A',

  /** Emergency stop, spread > 150pts, margin breach. */
  critical: '#FF4D6D',
  criticalSoft: '#45141F',
} as const;

/** Categorical series colours for multi-timeframe overlays. Order matters. */
export const chartSeries = [
  '#3D8BFF',
  '#00C9A7',
  '#F5B93B',
  '#B07CFF',
  '#FF7A45',
  '#4ECDC4',
] as const;

/** Chart chrome kept separate from panel borders so grids can be dialled back. */
export const chart = {
  grid: '#1A2334',
  axis: '#7A879E',
  crosshair: '#5A9DFF',
  /** Background must match `surface.raised`; charts sit inside panels. */
  background: '#111725',
} as const;

/**
 * Spacing scale in logical pixels, on a 4px grid.
 *
 * Numeric keys are intentional: `spacing[4]` reads identically to Flutter's
 * `EdgeInsets.all(AppSpacing.s4)` after export.
 */
export const spacing = {
  0: 0,
  1: 4,
  2: 8,
  3: 12,
  4: 16,
  5: 20,
  6: 24,
  8: 32,
  10: 40,
  12: 48,
  16: 64,
} as const;

export const radius = {
  none: 0,
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  full: 9999,
} as const;

/**
 * Typography.
 *
 * `mono` is mandatory for every price, lot size, and P&L figure. Tabular
 * digits keep columns from shifting as values tick, which matters when a
 * number updates once per second.
 */
export const typography = {
  fontFamily: {
    sans: "'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif",
    mono: "'JetBrains Mono', 'Cascadia Mono', 'Consolas', ui-monospace, monospace",
  },
  /** [fontSize, lineHeight] in logical pixels. */
  scale: {
    caption: [11, 16],
    label: [12, 18],
    body: [14, 21],
    bodyLg: [16, 24],
    metric: [22, 28],
    metricLg: [30, 36],
    display: [40, 48],
  },
  weight: {
    regular: 400,
    medium: 500,
    semibold: 600,
    bold: 700,
  },
} as const;

/**
 * Elevation.
 *
 * Flutter has no direct CSS box-shadow equivalent, so the exporter maps these
 * to `BoxShadow` with a matching blur radius and offset.
 */
export const elevation = {
  none: 'none',
  sm: '0 1px 2px 0 rgba(0, 0, 0, 0.40)',
  md: '0 4px 12px -2px rgba(0, 0, 0, 0.50)',
  lg: '0 12px 32px -8px rgba(0, 0, 0, 0.60)',
} as const;

/**
 * Motion.
 *
 * Kept short. A dashboard that animates every one-second poll feels unstable,
 * so transitions apply to user-initiated state changes, not data refreshes.
 */
export const motion = {
  duration: {
    instant: 80,
    fast: 140,
    normal: 220,
  },
  easing: {
    standard: 'cubic-bezier(0.2, 0, 0.2, 1)',
    decelerate: 'cubic-bezier(0, 0, 0.2, 1)',
  },
} as const;

/** Layout constants referenced by the app shell. */
export const layout = {
  sidebarWidth: 240,
  sidebarCollapsedWidth: 64,
  topbarHeight: 56,
  contentMaxWidth: 1680,
} as const;

/** Aggregate export consumed by Tailwind and the Dart exporter. */
export const tokens = {
  surface,
  text,
  market,
  accent,
  status,
  chartSeries,
  chart,
  spacing,
  radius,
  typography,
  elevation,
  motion,
  layout,
} as const;

export type Tokens = typeof tokens;
