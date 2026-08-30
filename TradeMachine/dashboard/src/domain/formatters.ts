import { SYMBOL } from './constants';

/**
 * Formatting utilities.
 *
 * All display formatting lives here rather than inline in components, for two
 * reasons: consistency (a price is formatted identically everywhere), and
 * portability (these map directly onto Dart's `intl` NumberFormat).
 *
 * Functions are pure and have no React dependency.
 */

/**
 * Locale is pinned rather than taken from the browser.
 *
 * A trading dashboard read by different people must not render 1.234,56 for
 * one and 1,234.56 for another — that ambiguity is a real risk when someone is
 * reading a lot size under time pressure.
 */
const LOCALE = 'en-US';

const priceFormatter = new Intl.NumberFormat(LOCALE, {
  minimumFractionDigits: SYMBOL.digits,
  maximumFractionDigits: SYMBOL.digits,
});

const lotFormatter = new Intl.NumberFormat(LOCALE, {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const currencyFormatter = new Intl.NumberFormat(LOCALE, {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const compactCurrencyFormatter = new Intl.NumberFormat(LOCALE, {
  style: 'currency',
  currency: 'USD',
  notation: 'compact',
  maximumFractionDigits: 1,
});

const integerFormatter = new Intl.NumberFormat(LOCALE, {
  maximumFractionDigits: 0,
});

/** VOL_80 trades at integer prices (`digits == 0`). */
export function formatPrice(value: number): string {
  if (!Number.isFinite(value)) return '—';
  return priceFormatter.format(value);
}

/** Lot sizes always show 2 decimals; `volumeStep` is 0.01. */
export function formatLots(value: number): string {
  if (!Number.isFinite(value)) return '—';
  return lotFormatter.format(value);
}

/** Currency with an explicit sign, since P&L polarity is the point. */
export function formatCurrency(value: number, options?: { signed?: boolean }): string {
  if (!Number.isFinite(value)) return '—';
  const formatted = currencyFormatter.format(Math.abs(value));
  if (options?.signed !== true) {
    return value < 0 ? `-${formatted}` : formatted;
  }
  if (value > 0) return `+${formatted}`;
  if (value < 0) return `-${formatted}`;
  return formatted;
}

/** Compact currency for axis labels and phase milestones ($12.3K, $40M). */
export function formatCompactCurrency(value: number): string {
  if (!Number.isFinite(value)) return '—';
  return compactCurrencyFormatter.format(value);
}

/** Accepts a 0..1 ratio. Callers must not pre-multiply by 100. */
export function formatPercent(ratio: number, fractionDigits = 1): string {
  if (!Number.isFinite(ratio)) return '—';
  return `${(ratio * 100).toFixed(fractionDigits)}%`;
}

/** Spread, order counts, tick volume. */
export function formatPoints(value: number): string {
  if (!Number.isFinite(value)) return '—';
  return `${integerFormatter.format(Math.round(value))} pts`;
}

export function formatInteger(value: number): string {
  if (!Number.isFinite(value)) return '—';
  return integerFormatter.format(value);
}

/**
 * Ratios such as profit factor and Sharpe.
 * Null renders as an em dash — "no losses yet" is not the same as "0.00".
 */
export function formatRatio(value: number | null, fractionDigits = 2): string {
  if (value === null || !Number.isFinite(value)) return '—';
  return value.toFixed(fractionDigits);
}

/** Clock time from an ISO timestamp. Dates are rarely useful intraday. */
export function formatTime(isoTimestamp: string): string {
  const date = new Date(isoTimestamp);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleTimeString(LOCALE, {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });
}

/** Relative age ("12s ago"), used for freshness indicators. */
export function formatRelativeTime(isoTimestamp: string, now = Date.now()): string {
  const date = new Date(isoTimestamp);
  if (Number.isNaN(date.getTime())) return '—';

  const seconds = Math.max(0, Math.floor((now - date.getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;

  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  return `${Math.floor(hours / 24)}d ago`;
}

/** Duration in ms to a compact "1h 23m" form. */
export function formatDuration(milliseconds: number): string {
  if (!Number.isFinite(milliseconds) || milliseconds < 0) return '—';

  const totalMinutes = Math.floor(milliseconds / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours === 0) return `${minutes}m`;
  return `${hours}h ${minutes}m`;
}
