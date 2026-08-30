import { clsx } from 'clsx';
import type { ReactNode } from 'react';

/**
 * Metric — a single labelled figure.
 *
 * The workhorse of the dashboard. Two rules are enforced here rather than left
 * to each caller:
 *
 * 1. Values always render in the mono font with tabular numerals, so a figure
 *    updating once per second does not shift the column width beside it.
 * 2. `null` renders an em dash, never "0". On a trading screen those mean very
 *    different things: no data versus genuinely zero.
 */

export type MetricTone = 'default' | 'bull' | 'bear' | 'warning' | 'critical' | 'muted';

interface MetricProps {
  readonly label: string;
  /** Pre-formatted string. Pass null for "no data". */
  readonly value: string | null;
  readonly tone?: MetricTone;
  readonly size?: 'sm' | 'md' | 'lg';
  /**
   * Secondary context: target, comparison, or unit note.
   *
   * Optional props that callers pass conditionally are declared as
   * `?: T | undefined` rather than `?: T`. Under `exactOptionalPropertyTypes`
   * those are distinct, and the former is what a ternary yielding `undefined`
   * actually produces.
   */
  readonly hint?: string | undefined;
  /** Leading glyph, typically a direction arrow. */
  readonly icon?: ReactNode | undefined;
  readonly className?: string | undefined;
  /** Marks the figure as simulated or stale. */
  readonly suspect?: boolean;
}

const toneClasses: Record<MetricTone, string> = {
  default: 'text-content-primary',
  bull: 'text-market-bull',
  bear: 'text-market-bear',
  warning: 'text-status-warning',
  critical: 'text-status-critical',
  muted: 'text-content-muted',
};

const sizeClasses = {
  sm: 'text-body',
  md: 'text-metric',
  lg: 'text-metricLg',
} as const;

export function Metric({
  label,
  value,
  tone = 'default',
  size = 'md',
  hint,
  icon,
  className,
  suspect = false,
}: MetricProps) {
  return (
    <div className={clsx('min-w-0', className)}>
      <div className="flex items-center gap-1.5">
        <span className="truncate text-label font-medium uppercase tracking-wide text-content-muted">
          {label}
        </span>
        {suspect && (
          <span
            className="text-caption text-content-disabled"
            title="Simulated or unverified data"
            aria-label="Simulated or unverified data"
          >
            ~
          </span>
        )}
      </div>

      <div
        className={clsx(
          'tabular mt-1 flex items-baseline gap-1.5 font-mono font-semibold',
          sizeClasses[size],
          value === null ? toneClasses.muted : toneClasses[tone],
        )}
      >
        {icon !== undefined && <span aria-hidden="true">{icon}</span>}
        <span className="truncate">{value ?? '—'}</span>
      </div>

      {hint !== undefined && (
        <p className="mt-0.5 truncate text-caption text-content-muted">{hint}</p>
      )}
    </div>
  );
}
