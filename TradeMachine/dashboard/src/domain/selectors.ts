import type { SpreadAssessment, TrendLabel } from '@/api/contracts';
import {
  CAPITAL_PHASES,
  POSITION_CAP,
  SPREAD,
  SPREAD_STATE_GUIDANCE,
  SPREAD_STATES,
  SYMBOL,
  type CapitalPhase,
} from './constants';

/**
 * Domain selectors — pure business logic derived from raw backend values.
 *
 * Kept out of components so the rules are testable in isolation and portable
 * to Dart verbatim. Nothing here touches React or the DOM.
 */

/**
 * Classifies a spread reading into its `SPREAD_STATE` band.
 * Source: TRADING_PLAN.md §10.4.
 *
 * Boundaries are exclusive-upper: exactly 60pts is NORMAL, 60.1 is ELEVATED.
 */
export function assessSpread(points: number): SpreadAssessment {
  const { thresholds } = SPREAD;

  let stateIndex: number;
  if (points <= thresholds.normal) stateIndex = 0;
  else if (points <= thresholds.elevated) stateIndex = 1;
  else if (points <= thresholds.wide) stateIndex = 2;
  else if (points <= thresholds.veryWide) stateIndex = 3;
  else stateIndex = 4;

  const state = SPREAD_STATES[stateIndex] ?? 'CRITICAL';

  return {
    points,
    state,
    stateIndex,
    guidance: SPREAD_STATE_GUIDANCE[state],
    // A round trip pays the spread twice: once entering, once exiting.
    roundTripCostPerLot: points * 2 * SYMBOL.tickValue,
  };
}

/**
 * Minimum favourable move needed to break even, in points.
 *
 * This is the number that decides whether the strategy is viable at all. At the
 * ~72pt baseline spread, price must travel ~144pts just to reach zero.
 */
export function breakEvenPoints(spreadPoints: number): number {
  return spreadPoints * 2;
}

/**
 * Maximum lots affordable at a given balance and leverage.
 * Formula: `(Lots × ContractSize × Price) / Leverage = Margin`.
 * Source: FINANCIAL_REVIEW.md §6.
 */
export function maxLotsForBalance(
  balance: number,
  price: number,
  leverage: number,
  marginUtilisation = 1.0,
): number {
  if (price <= 0 || leverage <= 0) return 0;

  const affordable =
    (balance * marginUtilisation * leverage) / (price * SYMBOL.contractSize);

  // Round down to the broker's volume step; never round up into a rejection.
  const stepped =
    Math.floor(affordable / SYMBOL.volumeStep) * SYMBOL.volumeStep;

  return Math.max(0, Math.min(stepped, POSITION_CAP.maxLotsPerTicket));
}

/**
 * Ticket count needed for a requested lot size.
 *
 * Above 100 lots per ticket the order must be split, up to
 * `MAX_SPLIT_TICKETS` (20). Beyond that the request cannot be filled at all —
 * a hard ceiling the dashboard should show rather than silently truncate.
 */
export function ticketsRequired(totalLots: number): {
  ticketCount: number;
  lotsPerTicket: number;
  exceedsMaxSplit: boolean;
} {
  if (totalLots <= POSITION_CAP.maxLotsPerTicket) {
    return { ticketCount: 1, lotsPerTicket: totalLots, exceedsMaxSplit: false };
  }

  const ticketCount = Math.ceil(totalLots / POSITION_CAP.maxLotsPerTicket);

  return {
    ticketCount,
    lotsPerTicket: totalLots / ticketCount,
    exceedsMaxSplit: ticketCount > POSITION_CAP.maxSplitTickets,
  };
}

/** Resolves the capital phase containing `balance`. */
export function currentCapitalPhase(balance: number): CapitalPhase {
  const match = CAPITAL_PHASES.find(
    (phase) => balance >= phase.from && balance < phase.to,
  );

  if (match) return match;

  // Below the first phase floor, or at/past the final target.
  const first = CAPITAL_PHASES[0];
  const last = CAPITAL_PHASES[CAPITAL_PHASES.length - 1];

  if (first === undefined || last === undefined) {
    throw new Error('CAPITAL_PHASES must not be empty');
  }

  return balance < first.from ? first : last;
}

/**
 * Progress through the current phase, 0..1.
 *
 * Uses a logarithmic scale because phase ranges span four orders of magnitude
 * ($10 → $40M). Linear progress would sit pinned near zero for the entire
 * first phase and convey nothing.
 */
export function capitalPhaseProgress(balance: number, phase: CapitalPhase): number {
  if (balance <= phase.from) return 0;
  if (balance >= phase.to) return 1;

  const logFrom = Math.log(Math.max(phase.from, 1));
  const logTo = Math.log(phase.to);
  const logBalance = Math.log(Math.max(balance, 1));

  const span = logTo - logFrom;
  if (span <= 0) return 0;

  return Math.min(1, Math.max(0, (logBalance - logFrom) / span));
}

/** True once the 100-lot ceiling starts constraining position size. */
export function isPositionCapReached(balance: number): boolean {
  return balance >= POSITION_CAP.alertBalance;
}

/** Direction of a trend label, for colour and icon selection. */
export type TrendDirection = 'bullish' | 'bearish' | 'neutral';

export function trendDirection(trend: TrendLabel): TrendDirection {
  if (trend.startsWith('BULLISH')) return 'bullish';
  if (trend.startsWith('BEARISH')) return 'bearish';
  return 'neutral';
}

/** Trend conviction, 0..1. Drives opacity/emphasis, not colour. */
export function trendStrength(trend: TrendLabel): number {
  if (trend.endsWith('_STRONG')) return 1;
  if (trend.endsWith('_WEAK')) return 0.4;
  if (trend === 'NEUTRAL') return 0;
  return 0.7;
}

/** Human-readable trend label. */
export function trendDisplayName(trend: TrendLabel): string {
  return trend
    .split('_')
    .map((part) => part.charAt(0) + part.slice(1).toLowerCase())
    .join(' ');
}

/**
 * Expectancy in R multiples.
 * `E = (WinRate × AvgWin/AvgLoss) - (1 - WinRate)`
 * Source: TRADING_PLAN.md §18 (target > 0.5R).
 */
export function expectancyR(
  winRate: number,
  averageWin: number,
  averageLoss: number,
): number | null {
  if (averageLoss <= 0) return null;
  const payoff = averageWin / averageLoss;
  return winRate * payoff - (1 - winRate);
}
