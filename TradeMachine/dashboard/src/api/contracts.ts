import { z } from 'zod';
// Type-only: `SPREAD_STATES` is referenced solely via `typeof` below, so the
// runtime import would be elided anyway.
import type { SPREAD_STATES } from '@/domain/constants';

/**
 * ============================================================================
 * API CONTRACTS — SINGLE SOURCE OF TRUTH
 * ============================================================================
 *
 * Every byte crossing the network boundary is validated here. Nothing else in
 * the app is permitted to `fetch` or to hand-roll a response type.
 *
 * WHY VALIDATION IS NOT OPTIONAL HERE
 * -----------------------------------
 * The backend contract is demonstrably unstable. Documented divergences between
 * `Dashboard_API.md`, `WebBridge.py`, `HTTPReceiver.mqh`, and `Types.mqh`:
 *
 *   1. `Types.mqh` defines the config command as `"set_config"`, while both
 *      `HTTPReceiver.mqh` and `WebBridge.py` use `"config_set"`.
 *   2. `/api/symbol/info` is documented as returning `volume_tick`, but
 *      `WebBridge.py` returns `volume`.
 *   3. `net_profit` appears in the docs for `/api/metrics/session` but is
 *      absent from the implementation.
 *   4. Four endpoints return an extra `"error": "Requires MT5 integration"`
 *      key alongside otherwise-valid placeholder data.
 *
 * Without a validating boundary these differences become `undefined` deep
 * inside a chart component. With one, they surface as a single explicit error
 * naming the offending field.
 *
 * FLUTTER PORTING GUIDE
 * ---------------------
 * Each schema below maps 1:1 to a Dart model. Conventions chosen to make that
 * translation mechanical:
 *
 *   - `snake_case` wire fields are renamed to `camelCase` exactly once, in the
 *     `.transform()` attached to each schema. Dart's `fromJson` does the same,
 *     so both clients agree on domain field names.
 *   - Tolerant fields use `.catch()` / `.default()` rather than `.optional()`
 *     where a sensible zero value exists. This avoids null-handling branches in
 *     Dart, where null safety makes optionals costlier to thread through.
 *   - Enums are `z.enum` over string literal unions, which become Dart `enum`s
 *     with an explicit `fromWire` factory.
 *   - No `z.date()`. Timestamps stay ISO-8601 strings and are parsed by the
 *     presentation layer, matching `DateTime.parse` in Dart.
 */

// ---------------------------------------------------------------------------
// Shared primitives
// ---------------------------------------------------------------------------

/**
 * A number that may arrive as a JSON string.
 *
 * MQL5 string building via `DoubleToString` occasionally quotes numerics, and
 * the file-bridge round trip is hand-rolled rather than using a real JSON
 * serialiser. Coercing defensively costs nothing and prevents a class of crash.
 */
const numeric = z.union([z.number(), z.string()]).pipe(z.coerce.number());

/** Numeric that falls back to 0 rather than failing the whole payload. */
const numericOr = (fallback: number) => numeric.catch(fallback);

/** ISO-8601 timestamp. Kept as a string for Dart parity. */
const isoTimestamp = z.string().min(1);

/**
 * The stub marker present on not-yet-integrated endpoints.
 * Its presence means the data is placeholder, not real MT5 state.
 */
const stubMarker = z.string().optional();

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

export const healthResponseSchema = z
  .object({
    status: z.string(),
    service: z.string().default('TradeMachine WebBridge'),
    timestamp: isoTimestamp,
    cmd_file: z.string().default('N/A'),
    resp_file: z.string().default('N/A'),
  })
  .transform((raw) => ({
    status: raw.status,
    service: raw.service,
    timestamp: raw.timestamp,
    commandFile: raw.cmd_file,
    responseFile: raw.resp_file,
    /** The bridge only reports healthy when both relay files are present. */
    bridgeFilesReady: raw.cmd_file !== 'N/A' && raw.resp_file !== 'N/A',
  }));

export type HealthStatus = z.infer<typeof healthResponseSchema>;

// ---------------------------------------------------------------------------
// Brute Mode status
// ---------------------------------------------------------------------------

/**
 * Source: `BruteMode_GetStatusJSON()` in BruteMode.mqh.
 *
 * Currently served as a hardcoded stub by `WebBridge.py`, which never reads
 * `TradeMachine_RESP.txt`. Field names follow the real MQL5 producer so this
 * schema keeps working once the bridge is wired up.
 */
export const bruteStatusResponseSchema = z
  .object({
    active: z.boolean().catch(false),
    momentum_bullish: z.boolean().catch(false),
    momentum_bearish: z.boolean().catch(false),
    orders_this_min: numericOr(0),
    max_orders_min: numericOr(20),
    total_orders: numericOr(0),
    reentry_count: numericOr(0),
    sl_plus_locked: z.boolean().catch(false),
    locked_sl_plus: numericOr(0),
    sl_hit_pending: z.boolean().catch(false),
    session_pnl: numericOr(0),
    ultra_tight_sl: numericOr(0.05),
    reentry_delay: numericOr(2),
    error: stubMarker,
  })
  .transform((raw) => ({
    isActive: raw.active,
    momentumBullish: raw.momentum_bullish,
    momentumBearish: raw.momentum_bearish,
    ordersThisMinute: raw.orders_this_min,
    maxOrdersPerMinute: raw.max_orders_min,
    totalOrders: raw.total_orders,
    reentryCount: raw.reentry_count,
    slPlusLocked: raw.sl_plus_locked,
    lockedSlPlus: raw.locked_sl_plus,
    slHitPendingReentry: raw.sl_hit_pending,
    sessionPnl: raw.session_pnl,
    ultraTightSl: raw.ultra_tight_sl,
    reentryDelaySec: raw.reentry_delay,
    isPlaceholder: raw.error !== undefined,
    /** Derived: how close the engine is to its own rate limit, 0..1. */
    rateLimitUsage:
      raw.max_orders_min > 0
        ? Math.min(raw.orders_this_min / raw.max_orders_min, 1)
        : 0,
  }));

export type BruteStatus = z.infer<typeof bruteStatusResponseSchema>;

// ---------------------------------------------------------------------------
// Command acknowledgements
// ---------------------------------------------------------------------------

/**
 * Response for POST /api/brute/on, /api/brute/off, /api/config/set.
 *
 * `success` only confirms the command file was written. MT5 polls that file
 * once per second, so a successful ack does NOT mean the EA has acted yet. The
 * UI must reconcile against a subsequent status poll rather than trusting this.
 */
export const commandAckSchema = z
  .object({
    success: z.boolean(),
    action: z.string().optional(),
    message: z.string().optional(),
    priority: z.string().optional(),
    updated: z.record(z.unknown()).optional(),
    error: z.string().optional(),
  })
  .transform((raw) => ({
    accepted: raw.success,
    action: raw.action ?? 'unknown',
    message: raw.message ?? null,
    isCritical: raw.priority === 'critical',
    updated: raw.updated ?? null,
    errorDetail: raw.error ?? null,
  }));

export type CommandAck = z.infer<typeof commandAckSchema>;

// ---------------------------------------------------------------------------
// Session metrics
// ---------------------------------------------------------------------------

/**
 * Source: `/api/metrics/session`.
 *
 * `net_profit` is documented but not implemented, so it is derived from
 * profit/loss when absent. Loss values arrive with inconsistent sign
 * conventions across the docs, hence the `Math.abs` normalisation.
 */
export const sessionMetricsResponseSchema = z
  .object({
    total_trades: numericOr(0),
    winning_trades: numericOr(0),
    losing_trades: numericOr(0),
    win_rate: numericOr(0),
    total_profit: numericOr(0),
    total_loss: numericOr(0),
    net_profit: numeric.optional(),
    max_drawdown: numericOr(0),
    sharpe_ratio: numericOr(0),
    error: stubMarker,
  })
  .transform((raw) => {
    const grossProfit = Math.abs(raw.total_profit);
    const grossLoss = Math.abs(raw.total_loss);

    return {
      totalTrades: raw.total_trades,
      winningTrades: raw.winning_trades,
      losingTrades: raw.losing_trades,
      /**
       * Normalised to 0..1. The docs show a decimal (0.627) but a naive
       * backend change to percent (62.7) would otherwise render as 6270%.
       */
      winRate: raw.win_rate > 1 ? raw.win_rate / 100 : raw.win_rate,
      grossProfit,
      grossLoss,
      netProfit: raw.net_profit ?? grossProfit - grossLoss,
      maxDrawdown: Math.abs(raw.max_drawdown),
      sharpeRatio: raw.sharpe_ratio,
      /** Derived: gross profit / gross loss. Null when there are no losses. */
      profitFactor: grossLoss > 0 ? grossProfit / grossLoss : null,
      isPlaceholder: raw.error !== undefined,
    };
  });

export type SessionMetrics = z.infer<typeof sessionMetricsResponseSchema>;

// ---------------------------------------------------------------------------
// Symbol info
// ---------------------------------------------------------------------------

/** Trend labels emitted by the EA. Source: `enum TREND_STATE` (Types.mqh). */
export const trendLabelSchema = z
  .enum([
    'BULLISH_STRONG',
    'BULLISH',
    'BULLISH_WEAK',
    'NEUTRAL',
    'BEARISH_WEAK',
    'BEARISH',
    'BEARISH_STRONG',
  ])
  .catch('NEUTRAL');

export type TrendLabel = z.infer<typeof trendLabelSchema>;

/**
 * Source: `/api/symbol/info`.
 *
 * Accepts both `volume_tick` (documented) and `volume` (implemented) and
 * normalises to a single field — divergence #2 from the header comment.
 */
export const symbolInfoResponseSchema = z
  .object({
    symbol: z.string().default('VOL_80'),
    price: numericOr(0),
    spread: numericOr(0),
    volume_tick: numeric.optional(),
    volume: numeric.optional(),
    trend: trendLabelSchema.optional(),
    support: numericOr(0),
    resistance: numericOr(0),
    error: stubMarker,
  })
  .transform((raw) => ({
    symbol: raw.symbol,
    price: raw.price,
    spreadPoints: raw.spread,
    tickVolume: raw.volume_tick ?? raw.volume ?? 0,
    trend: raw.trend ?? 'NEUTRAL',
    support: raw.support,
    resistance: raw.resistance,
    isPlaceholder: raw.error !== undefined,
  }));

export type SymbolInfo = z.infer<typeof symbolInfoResponseSchema>;

// ---------------------------------------------------------------------------
// Trades
// ---------------------------------------------------------------------------

export const tradeSideSchema = z.enum(['BUY', 'SELL']).catch('BUY');

/** Source: `enum TP_STATE` (Types.mqh). Optional; older payloads omit it. */
export const tpStateSchema = z
  .enum([
    'DRAFT',
    'TP1_APPROACH',
    'TP1_HIT',
    'TP2_HIT',
    'TRAILING',
    'CLOSED',
  ])
  .catch('DRAFT');

export const tradeSchema = z
  .object({
    id: z.union([z.string(), z.number()]).transform(String),
    type: tradeSideSchema,
    entry: numericOr(0),
    /** Null while the position is still open. */
    exit: numeric.nullable().catch(null),
    lots: numericOr(0),
    profit: numericOr(0),
    time: isoTimestamp,
    tp_state: tpStateSchema.optional(),
    /** Present when the order was produced by Brute Mode. */
    is_brute: z.boolean().optional(),
  })
  .transform((raw) => ({
    id: raw.id,
    side: raw.type,
    entryPrice: raw.entry,
    exitPrice: raw.exit,
    lots: raw.lots,
    profit: raw.profit,
    openedAt: raw.time,
    tpState: raw.tp_state ?? 'DRAFT',
    /** `BRU_` prefix is the documented Brute Mode ticket convention. */
    isBrute: raw.is_brute ?? raw.id.startsWith('BRU_'),
    isOpen: raw.exit === null,
  }));

export type Trade = z.infer<typeof tradeSchema>;

export const tradeListResponseSchema = z
  .object({
    trades: z.array(tradeSchema).catch([]),
    total: numericOr(0),
    pending: numericOr(0),
    error: stubMarker,
  })
  .transform((raw) => ({
    trades: raw.trades,
    total: raw.total,
    pending: raw.pending,
    isPlaceholder: raw.error !== undefined,
  }));

export type TradeList = z.infer<typeof tradeListResponseSchema>;

// ---------------------------------------------------------------------------
// Config mutation
// ---------------------------------------------------------------------------

/**
 * Request body for POST /api/config/set.
 *
 * Flask rejects any key outside this set with
 * `{"success": false, "error": "Invalid keys: [...]"}`, so bounds are enforced
 * client-side to turn a server rejection into an inline form error.
 *
 * Keys stay `snake_case` here because this is a REQUEST body — the wire format
 * is the contract. Only responses get camelised.
 */
export const configUpdateSchema = z
  .object({
    max_orders_per_min: z.number().int().min(1).max(100).optional(),
    ultra_tight_sl: z.number().min(0).max(0.1).optional(),
    reentry_delay: z.number().int().min(1).max(10).optional(),
    reentry_max: z.number().int().min(1).max(20).optional(),
    fixed_lots: z.number().min(0).max(100).optional(),
  })
  .refine((value) => Object.keys(value).length > 0, {
    message: 'At least one configuration field must be provided',
  });

export type ConfigUpdate = z.infer<typeof configUpdateSchema>;

// ---------------------------------------------------------------------------
// Derived client-side view models
// ---------------------------------------------------------------------------

/**
 * Spread assessment. Computed on the client because the backend exposes the
 * raw point value but not the resulting state.
 */
export interface SpreadAssessment {
  readonly points: number;
  readonly state: (typeof SPREAD_STATES)[number];
  readonly stateIndex: number;
  readonly guidance: string;
  /** Round-trip cost in USD per lot. */
  readonly roundTripCostPerLot: number;
}

/** Connection state driving the topbar indicator. */
export type ConnectionState = 'connected' | 'degraded' | 'disconnected' | 'mock';
