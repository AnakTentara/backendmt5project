/**
 * Domain constants mirrored from the MQL5 backend.
 *
 * SOURCE OF TRUTH: these values are duplicated from `Types.mqh`, `Config.mqh`,
 * `TRADING_PLAN.md`, and `FINANCIAL_REVIEW.md`. They are copied rather than
 * fetched because the backend exposes no `/api/constants` endpoint yet.
 *
 * Each block cites its origin. If the EA changes, update here and nowhere
 * else — no component should hardcode a threshold.
 */

/** Instrument specification. Source: pyScript.py output, TRADING_PLAN.md §2. */
export const SYMBOL = {
  name: 'VOL_80',
  description: 'Volatility 80 Index',
  /** Integer pricing: `info.digits == 0`. */
  digits: 0,
  point: 1.0,
  contractSize: 1.0,
  /** USD per point per lot. */
  tickValue: 1.0,
  volumeMin: 0.01,
  volumeMax: 100.0,
  volumeStep: 0.01,
} as const;

/**
 * Spread thresholds, in points.
 * Source: `enum SPREAD_STATE` (Types.mqh) and TRADING_PLAN.md §10.4.
 *
 * VOL_80 averages ~72pts, so the spread is the dominant cost: a round trip
 * must clear ~144pts before the trade is profitable. This is why the gauge is
 * a headline element rather than a footnote.
 */
export const SPREAD = {
  baseline: 72.0,
  minTargetPoints: 100.0,
  /** Upper bound of each state, in points. */
  thresholds: {
    normal: 60,
    elevated: 80,
    wide: 100,
    veryWide: 150,
  },
} as const;

/** Ordered spread states. Index matches the MQL5 enum value. */
export const SPREAD_STATES = [
  'NORMAL',
  'ELEVATED',
  'WIDE',
  'VERY_WIDE',
  'CRITICAL',
] as const;

export type SpreadStateName = (typeof SPREAD_STATES)[number];

/** Human-readable action for each spread state. Source: TRADING_PLAN.md §10.4. */
export const SPREAD_STATE_GUIDANCE: Record<SpreadStateName, string> = {
  NORMAL: 'Trade freely',
  ELEVATED: 'Reduce lot size 25%',
  WIDE: 'Skip new trades',
  VERY_WIDE: 'Close existing, no new entries',
  CRITICAL: 'Emergency close all',
};

/**
 * Margin thresholds, in percent.
 * Source: Config.mqh `Inp_MarginAlertLevel` / `Inp_MarginCloseLevel`.
 *
 * CAVEAT: the docs are internally inconsistent — TRADING_PLAN.md §7.3 warns
 * below 500%, alerts at 200%, and force-closes at 300%, which means the
 * "close" level sits ABOVE the "alert" level. That ordering is almost
 * certainly a backend bug. The UI renders the configured numbers as-is and
 * does not silently reorder them; `hasInvertedThresholds` surfaces the
 * contradiction instead of hiding it.
 */
export const MARGIN = {
  warnLevel: 500.0,
  alertLevel: 200.0,
  closeLevel: 300.0,
  safetyPct: 50.0,
} as const;

export const hasInvertedMarginThresholds =
  MARGIN.closeLevel > MARGIN.alertLevel;

/** Risk limits. Source: Config.mqh, TRADING_PLAN.md §5.1. */
export const RISK = {
  maxRiskPercent: 3.0,
  maxTotalExposure: 5.0,
  maxPositionsPerDirection: 2,
  maxCounterTrendPositions: 1,
  /** Counter-trend entries are sized at half the normal calculation. */
  counterTrendSizeMultiplier: 0.5,
} as const;

/**
 * Position cap. Source: `MAX_LOTS_PER_TICKET` (Types.mqh),
 * `Inp_CapAlertBalance` (Config.mqh), FINANCIAL_REVIEW.md §7.
 *
 * At $12,250 balance with 1:2000 leverage, position size reaches the 100-lot
 * per-ticket ceiling. Past that point growth turns from exponential to linear,
 * which is the single most consequential fact about this strategy. The
 * dashboard surfaces it prominently.
 */
export const POSITION_CAP = {
  maxLotsPerTicket: 100.0,
  minLotsPerTicket: 0.01,
  maxSplitTickets: 20,
  alertBalance: 12_250,
} as const;

/** Capital growth phases. Source: FINANCIAL_REVIEW.md §7. */
export interface CapitalPhase {
  readonly id: 1 | 2 | 3 | 4;
  readonly label: string;
  readonly from: number;
  readonly to: number;
  readonly estimatedTrades: number;
  readonly estimatedMinutes: number;
  readonly note: string;
}

export const CAPITAL_PHASES: readonly CapitalPhase[] = [
  {
    id: 1,
    label: 'Phase 1 · Exponential',
    from: 10,
    to: 12_250,
    estimatedTrades: 48,
    estimatedMinutes: 48,
    note: 'Compounding freely below the lot cap.',
  },
  {
    id: 2,
    label: 'Phase 2 · Cap reached',
    from: 12_250,
    to: 500_000,
    estimatedTrades: 80,
    estimatedMinutes: 80,
    note: 'Lot size capped at 100; multi-ticket splitting engages.',
  },
  {
    id: 3,
    label: 'Phase 3 · Linear',
    from: 500_000,
    to: 5_000_000,
    estimatedTrades: 60,
    estimatedMinutes: 60,
    note: 'Fixed ~$7,800 net per trade.',
  },
  {
    id: 4,
    label: 'Phase 4 · Grind',
    from: 5_000_000,
    to: 40_000_000,
    estimatedTrades: 450,
    estimatedMinutes: 450,
    note: 'Longest phase by far; ~5,126 trades from the cap onward.',
  },
] as const;

/**
 * Backtest acceptance thresholds. Source: TRADING_PLAN.md §18.
 * Used to colour KPI cards against their target rather than in the abstract.
 */
export const KPI_TARGETS = {
  profitFactor: 1.5,
  maxDrawdownPct: 15,
  winRate: 0.45,
  expectancyR: 0.5,
} as const;

/**
 * Brute Mode config bounds. Source: Dashboard_API.md `/api/config/set`.
 *
 * IMPORTANT: Flask validates all five keys, but `ParseConfigChange()` in
 * `HTTPReceiver.mqh` only actually reads `max_orders`. The other four are
 * accepted and silently discarded by MT5. `appliedByBackend` records that, so
 * the config form can warn instead of implying a change took effect.
 */
export interface ConfigFieldSpec {
  readonly key: string;
  readonly label: string;
  readonly min: number;
  readonly max: number;
  readonly step: number;
  readonly unit: string;
  readonly appliedByBackend: boolean;
  readonly help: string;
}

export const BRUTE_CONFIG_FIELDS: readonly ConfigFieldSpec[] = [
  {
    key: 'max_orders_per_min',
    label: 'Max orders / minute',
    min: 1,
    max: 100,
    step: 1,
    unit: 'orders',
    appliedByBackend: true,
    help: 'Rate limit for momentum order spam.',
  },
  {
    key: 'ultra_tight_sl',
    label: 'Ultra-tight SL',
    min: 0,
    max: 0.1,
    step: 0.01,
    unit: 'pts',
    appliedByBackend: false,
    help: 'Stop distance for brute entries. Not yet parsed by MT5.',
  },
  {
    key: 'reentry_delay',
    label: 'Re-entry delay',
    min: 1,
    max: 10,
    step: 1,
    unit: 'sec',
    appliedByBackend: false,
    help: 'Pause after an SL hit before re-entering. Not yet parsed by MT5.',
  },
  {
    key: 'reentry_max',
    label: 'Max re-entries',
    min: 1,
    max: 20,
    step: 1,
    unit: 'times',
    appliedByBackend: false,
    help: 'Re-entry ceiling per sequence. Not yet parsed by MT5.',
  },
  {
    key: 'fixed_lots',
    label: 'Fixed lots',
    min: 0,
    max: 100,
    step: 0.01,
    unit: 'lots',
    appliedByBackend: false,
    help: '0 uses risk-based sizing. Not yet parsed by MT5.',
  },
] as const;

/** Timeframe weights for the confluence score. Source: TRADING_PLAN.md §3. */
export const TIMEFRAME_WEIGHTS = [
  { timeframe: 'H4', weight: 0.3 },
  { timeframe: 'H1', weight: 0.25 },
  { timeframe: 'M30', weight: 0.2 },
  { timeframe: 'M15', weight: 0.15 },
  { timeframe: 'M5', weight: 0.1 },
] as const;

export type TimeframeName = (typeof TIMEFRAME_WEIGHTS)[number]['timeframe'];
