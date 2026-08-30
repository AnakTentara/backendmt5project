import {
  bruteStatusResponseSchema,
  commandAckSchema,
  healthResponseSchema,
  sessionMetricsResponseSchema,
  symbolInfoResponseSchema,
  tradeListResponseSchema,
  type BruteStatus,
  type CommandAck,
  type ConfigUpdate,
  type HealthStatus,
  type SessionMetrics,
  type SymbolInfo,
  type TradeList,
} from './contracts';
import type { TradeMachineRepository } from './repository';
import { SPREAD, SYMBOL } from '@/domain/constants';

/**
 * In-memory mock repository.
 *
 * PURPOSE
 * -------
 * Four backend endpoints (`/api/brute/status`, `/api/trades/list`,
 * `/api/metrics/session`, `/api/symbol/info`) currently return placeholder data,
 * three of them with `"error": "Requires MT5 integration"`. Building a dashboard
 * against all-zero responses makes it impossible to judge layout, colour
 * thresholds, or number formatting.
 *
 * DESIGN CONSTRAINTS
 * ------------------
 * 1. Output is fed through the SAME Zod schemas as the HTTP repository. If a
 *    contract changes, the mock breaks too — it cannot drift into fiction.
 * 2. Fixtures are emitted in wire format (snake_case) and parsed, rather than
 *    constructed as domain objects. This exercises the transform layer.
 * 3. Deterministic PRNG, so a suspicious render is reproducible.
 * 4. Latency is simulated (~120ms) so loading states are actually visible.
 *
 * This file is only imported by `provideRepository()` when
 * `VITE_USE_MOCK_API=true`, so it tree-shakes out of a production build.
 */

/** Mulberry32. Small, fast, and deterministic from a fixed seed. */
function createRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const delay = (ms: number): Promise<void> =>
  new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });

/** Simulated network latency. Loopback Flask is fast but not instant. */
const SIMULATED_LATENCY_MS = 120;

/**
 * Mutable simulation state.
 *
 * Held at module scope so toggling Brute Mode persists across polls and the
 * optimistic-then-reconciled UI flow behaves as it will in production.
 */
interface MockState {
  bruteActive: boolean;
  totalOrders: number;
  ordersThisMinute: number;
  maxOrdersPerMinute: number;
  reentryCount: number;
  sessionPnl: number;
  ultraTightSl: number;
  reentryDelay: number;
  price: number;
  tickCount: number;
  trades: MockTrade[];
  emergencyStopped: boolean;
}

interface MockTrade {
  id: string;
  type: 'BUY' | 'SELL';
  entry: number;
  exit: number | null;
  lots: number;
  profit: number;
  time: string;
  tp_state: 'DRAFT' | 'TP1_APPROACH' | 'TP1_HIT' | 'TP2_HIT' | 'TRAILING' | 'CLOSED';
  is_brute: boolean;
}

const random = createRandom(0x5eed_1234);

const state: MockState = {
  bruteActive: false,
  totalOrders: 0,
  ordersThisMinute: 0,
  maxOrdersPerMinute: 20,
  reentryCount: 0,
  sessionPnl: 0,
  ultraTightSl: 0.05,
  reentryDelay: 2,
  // Mid-price from the live pyScript.py reading.
  price: 244_973,
  tickCount: 0,
  trades: [],
  emergencyStopped: false,
};

/** Seeds a plausible trade history so tables and metrics render populated. */
function seedTrades(): void {
  const now = Date.now();
  let price = 244_500;
  let cumulative = 0;

  for (let index = 0; index < 24; index += 1) {
    const isBuy = random() > 0.45;
    // ~65% win rate, matching the TRADING_PLAN.md baseline assumption.
    const isWin = random() < 0.65;
    const grossMove = 80 + random() * 220;
    // Every round trip pays roughly 2x the ~72pt spread.
    const netPoints = isWin
      ? grossMove - SPREAD.baseline * 2
      : -(SPREAD.baseline * 2 * (0.4 + random() * 0.6));
    const lots = 0.08 + random() * 0.6;
    const profit = netPoints * lots * SYMBOL.tickValue;

    cumulative += profit;
    price += (isBuy ? 1 : -1) * grossMove * 0.3;

    state.trades.push({
      id: `BRU_${String(index + 1).padStart(3, '0')}`,
      type: isBuy ? 'BUY' : 'SELL',
      entry: Math.round(price),
      exit: Math.round(price + netPoints * (isBuy ? 1 : -1)),
      lots: Number(lots.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      // Roughly one trade per minute, newest last.
      time: new Date(now - (24 - index) * 61_000).toISOString(),
      tp_state: isWin ? 'TP2_HIT' : 'CLOSED',
      is_brute: true,
    });
  }

  // Two still-open positions to exercise the open-position styling.
  for (let index = 0; index < 2; index += 1) {
    const isBuy = random() > 0.5;
    const lots = 0.2 + random() * 0.4;
    state.trades.push({
      id: `TM_${String(index + 1).padStart(3, '0')}`,
      type: isBuy ? 'BUY' : 'SELL',
      entry: Math.round(price),
      exit: null,
      lots: Number(lots.toFixed(2)),
      profit: Number((random() * 240 - 80).toFixed(2)),
      time: new Date(now - (index + 1) * 45_000).toISOString(),
      tp_state: index === 0 ? 'TP1_HIT' : 'DRAFT',
      is_brute: false,
    });
  }

  state.sessionPnl = Number(cumulative.toFixed(2));
  state.totalOrders = state.trades.length;
  state.price = Math.round(price);
}

seedTrades();

/**
 * Advances the simulation one step. Called on every status poll so the UI
 * shows live movement rather than a frozen snapshot.
 */
function advanceSimulation(): void {
  state.tickCount += 1;

  // VOL_80 is a synthetic index: a random walk with occasional volatility
  // bursts is a reasonable approximation for UI purposes.
  const burst = random() < 0.08 ? 6 : 1;
  state.price += Math.round((random() - 0.5) * 90 * burst);

  if (state.bruteActive && !state.emergencyStopped) {
    // Order flow arrives in clusters, not uniformly.
    if (random() < 0.55) {
      const newOrders = 1 + Math.floor(random() * 3);
      state.ordersThisMinute = Math.min(
        state.ordersThisMinute + newOrders,
        state.maxOrdersPerMinute,
      );
      state.totalOrders += newOrders;
      state.sessionPnl += Number(((random() - 0.35) * 45).toFixed(2));
    }
    if (random() < 0.12) {
      state.reentryCount += 1;
    }
    // Rate-limit window resets roughly once a minute at a 1s poll.
    if (state.tickCount % 60 === 0) {
      state.ordersThisMinute = 0;
      state.reentryCount = 0;
    }
  } else {
    state.ordersThisMinute = 0;
  }
}

/** Current spread, oscillating within the documented 56-82pt band. */
function currentSpread(): number {
  const oscillation = Math.sin(state.tickCount / 9) * 11;
  return Math.round(SPREAD.baseline + oscillation + (random() - 0.5) * 6);
}

export class MockTradeMachineRepository implements TradeMachineRepository {
  async getHealth(): Promise<HealthStatus> {
    await delay(SIMULATED_LATENCY_MS);
    return healthResponseSchema.parse({
      status: 'ok',
      service: 'TradeMachine WebBridge (mock)',
      timestamp: new Date().toISOString(),
      cmd_file: 'C:\\...\\Data\\TradeMachine_CMD.txt',
      resp_file: 'C:\\...\\Data\\TradeMachine_RESP.txt',
    });
  }

  async getBruteStatus(): Promise<BruteStatus> {
    await delay(SIMULATED_LATENCY_MS);
    advanceSimulation();

    // Momentum flags are mutually exclusive in BruteMode.mqh.
    const momentumRoll = random();
    const bullish = state.bruteActive && momentumRoll > 0.62;
    const bearish = state.bruteActive && !bullish && momentumRoll < 0.28;

    return bruteStatusResponseSchema.parse({
      active: state.bruteActive,
      momentum_bullish: bullish,
      momentum_bearish: bearish,
      orders_this_min: state.ordersThisMinute,
      max_orders_min: state.maxOrdersPerMinute,
      total_orders: state.totalOrders,
      reentry_count: state.reentryCount,
      sl_plus_locked: state.bruteActive && random() > 0.7,
      locked_sl_plus: state.price - 40,
      sl_hit_pending: state.bruteActive && random() > 0.85,
      session_pnl: Number(state.sessionPnl.toFixed(2)),
      ultra_tight_sl: state.ultraTightSl,
      reentry_delay: state.reentryDelay,
    });
  }

  async setBruteMode(active: boolean): Promise<CommandAck> {
    await delay(SIMULATED_LATENCY_MS);
    state.bruteActive = active;
    if (active) {
      state.emergencyStopped = false;
    } else {
      state.ordersThisMinute = 0;
      state.reentryCount = 0;
    }

    return commandAckSchema.parse({
      success: true,
      action: active ? 'brute_on' : 'brute_off',
      message: active
        ? 'Brute Mode activation queued'
        : 'Brute Mode deactivation queued',
    });
  }

  async emergencyStop(): Promise<CommandAck> {
    await delay(SIMULATED_LATENCY_MS);
    state.emergencyStopped = true;
    state.bruteActive = false;
    state.ordersThisMinute = 0;
    state.reentryCount = 0;
    // Emergency stop closes every position, brute and regular alike.
    for (const trade of state.trades) {
      if (trade.exit === null) {
        trade.exit = state.price;
        trade.tp_state = 'CLOSED';
      }
    }

    return commandAckSchema.parse({
      success: true,
      action: 'emergency_stop',
      priority: 'critical',
      message: 'All positions queued for closure',
    });
  }

  async updateConfig(update: ConfigUpdate): Promise<CommandAck> {
    await delay(SIMULATED_LATENCY_MS);

    // Mirrors the real backend limitation: only `max_orders_per_min` reaches
    // MT5, because `ParseConfigChange()` in HTTPReceiver.mqh parses nothing else.
    if (update.max_orders_per_min !== undefined) {
      state.maxOrdersPerMinute = update.max_orders_per_min;
    }
    if (update.ultra_tight_sl !== undefined) {
      state.ultraTightSl = update.ultra_tight_sl;
    }
    if (update.reentry_delay !== undefined) {
      state.reentryDelay = update.reentry_delay;
    }

    return commandAckSchema.parse({
      success: true,
      action: 'config_set',
      updated: update as Record<string, unknown>,
    });
  }

  async getTrades(limit: number): Promise<TradeList> {
    await delay(SIMULATED_LATENCY_MS);
    // Newest first, matching how the table is read.
    const ordered = [...state.trades].reverse().slice(0, limit);

    return tradeListResponseSchema.parse({
      trades: ordered,
      total: state.trades.length,
      pending: state.trades.filter((trade) => trade.exit === null).length,
    });
  }

  async getSessionMetrics(): Promise<SessionMetrics> {
    await delay(SIMULATED_LATENCY_MS);

    const closed = state.trades.filter((trade) => trade.exit !== null);
    const winners = closed.filter((trade) => trade.profit > 0);
    const losers = closed.filter((trade) => trade.profit <= 0);
    const grossProfit = winners.reduce((sum, t) => sum + t.profit, 0);
    const grossLoss = Math.abs(losers.reduce((sum, t) => sum + t.profit, 0));

    // Peak-to-trough on the running equity curve.
    let peak = 0;
    let equity = 0;
    let maxDrawdown = 0;
    for (const trade of closed) {
      equity += trade.profit;
      peak = Math.max(peak, equity);
      maxDrawdown = Math.max(maxDrawdown, peak - equity);
    }

    return sessionMetricsResponseSchema.parse({
      total_trades: closed.length,
      winning_trades: winners.length,
      losing_trades: losers.length,
      win_rate: closed.length > 0 ? winners.length / closed.length : 0,
      total_profit: Number(grossProfit.toFixed(2)),
      total_loss: Number(grossLoss.toFixed(2)),
      max_drawdown: Number(maxDrawdown.toFixed(2)),
      sharpe_ratio: 1.42,
    });
  }

  async getSymbolInfo(): Promise<SymbolInfo> {
    await delay(SIMULATED_LATENCY_MS);
    const spread = currentSpread();

    return symbolInfoResponseSchema.parse({
      symbol: SYMBOL.name,
      price: state.price,
      spread,
      // Intentionally the implemented key (`volume`) rather than the documented
      // `volume_tick`, so the normalising transform stays exercised.
      volume: 1_200 + Math.round(random() * 800),
      trend: state.price > 244_900 ? 'BULLISH' : 'BEARISH_WEAK',
      support: state.price - 380,
      resistance: state.price + 420,
    });
  }
}
