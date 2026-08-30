import { clsx } from 'clsx';
import { useState } from 'react';
import { Badge } from '@/components/Badge';
import { Metric } from '@/components/Metric';
import { Panel } from '@/components/Panel';
import { CAPITAL_PHASES, POSITION_CAP, SYMBOL } from '@/domain/constants';
import {
  capitalPhaseProgress,
  currentCapitalPhase,
  isPositionCapReached,
  maxLotsForBalance,
  ticketsRequired,
} from '@/domain/selectors';
import {
  formatCompactCurrency,
  formatCurrency,
  formatInteger,
  formatLots,
} from '@/domain/formatters';

/**
 * Capital phase tracker.
 *
 * WHY THIS PANEL EXISTS
 * ---------------------
 * FINANCIAL_REVIEW.md §7 identifies $12,250 as the point where position size
 * hits the 100-lot per-ticket ceiling at 1:2000 leverage. Past it, growth stops
 * being exponential and becomes linear at roughly $7,800 per trade — turning the
 * remaining distance to $40M into ~5,126 trades (about 3.5 days) rather than
 * the hours the earlier phases suggest.
 *
 * That single discontinuity is the most important fact about this strategy's
 * timeline, so it gets a dedicated panel rather than a footnote.
 *
 * Balance is entered manually because no endpoint exposes account equity yet.
 */

/** Leverage options from FINANCIAL_REVIEW.md §6. Below 1:500 is non-viable. */
const LEVERAGE_OPTIONS = [500, 1000, 2000] as const;

export function CapitalPhasePanel() {
  const [balance, setBalance] = useState(10);
  const [leverage, setLeverage] = useState<number>(2000);

  const phase = currentCapitalPhase(balance);
  const progress = capitalPhaseProgress(balance, phase);
  const capReached = isPositionCapReached(balance);

  // Uses the live mid-price from pyScript.py; margin scales with price.
  const referencePrice = 244_973;
  const maxLots = maxLotsForBalance(balance, referencePrice, leverage);
  const split = ticketsRequired(maxLots);

  return (
    <Panel
      title="Capital phase"
      subtitle="Projection · balance entered manually"
      tone={capReached ? 'warning' : 'default'}
      action={
        <Badge tone={capReached ? 'warning' : 'info'}>
          {capReached ? 'LOT CAP ACTIVE' : 'COMPOUNDING'}
        </Badge>
      }
    >
      <div className="space-y-5">
        <div className="flex flex-wrap items-end gap-4">
          <label className="min-w-0 flex-1">
            <span className="block text-label font-medium uppercase tracking-wide text-content-muted">
              Account balance (USD)
            </span>
            <input
              type="number"
              min={1}
              step="any"
              value={balance}
              onChange={(event) => {
                const parsed = Number(event.target.value);
                setBalance(Number.isFinite(parsed) && parsed > 0 ? parsed : 1);
              }}
              className={clsx(
                'tabular mt-1.5 w-full rounded-md border border-surface-borderStrong',
                'bg-surface-overlay px-3 py-2 font-mono text-body text-content-primary',
                'focus:border-accent-base focus:outline-none',
              )}
            />
          </label>

          <fieldset className="min-w-0">
            <legend className="text-label font-medium uppercase tracking-wide text-content-muted">
              Leverage
            </legend>
            <div className="mt-1.5 flex gap-1">
              {LEVERAGE_OPTIONS.map((option) => (
                <button
                  key={option}
                  type="button"
                  onClick={() => setLeverage(option)}
                  aria-pressed={leverage === option}
                  className={clsx(
                    'rounded-md px-3 py-2 font-mono text-label transition-colors duration-fast',
                    leverage === option
                      ? 'bg-accent-base text-content-inverse'
                      : 'bg-surface-overlay text-content-secondary hover:bg-surface-hover',
                  )}
                >
                  1:{option}
                </button>
              ))}
            </div>
          </fieldset>
        </div>

        <PhaseTimeline currentPhaseId={phase.id} progress={progress} />

        <div className="grid grid-cols-2 gap-4 border-t border-surface-border pt-4 lg:grid-cols-4">
          <Metric
            label="Current phase"
            value={phase.label.split(' · ')[1] ?? phase.label}
            size="sm"
            hint={`to ${formatCompactCurrency(phase.to)}`}
          />
          <Metric
            label="Max lots"
            value={formatLots(maxLots)}
            tone={maxLots >= POSITION_CAP.maxLotsPerTicket ? 'warning' : 'default'}
            size="sm"
            hint={
              maxLots >= POSITION_CAP.maxLotsPerTicket
                ? 'per-ticket ceiling'
                : `at 1:${leverage}`
            }
          />
          <Metric
            label="Tickets needed"
            value={formatInteger(split.ticketCount)}
            tone={split.exceedsMaxSplit ? 'critical' : 'default'}
            size="sm"
            hint={split.exceedsMaxSplit ? `exceeds ${POSITION_CAP.maxSplitTickets} max` : undefined}
          />
          <Metric
            label="Est. trades left"
            value={formatInteger(phase.estimatedTrades)}
            size="sm"
            hint="this phase"
          />
        </div>

        {capReached ? (
          <div className="rounded-md border border-status-warning/40 bg-status-warningSoft/40 px-3 py-2.5">
            <p className="text-label text-content-secondary">
              <strong className="text-status-warning">Growth is now linear.</strong>{' '}
              Position size is capped at {POSITION_CAP.maxLotsPerTicket} lots per
              ticket, so each trade nets roughly a fixed{' '}
              {formatCurrency(7_800)} regardless of balance. Reaching{' '}
              {formatCompactCurrency(40_000_000)} from here takes on the order of
              5,000 more trades.
            </p>
          </div>
        ) : (
          <div className="rounded-md border border-surface-border bg-surface-overlay px-3 py-2.5">
            <p className="text-label text-content-secondary">
              Compounding freely. The 100-lot ceiling engages at{' '}
              <span className="tabular font-mono text-content-primary">
                {formatCurrency(POSITION_CAP.alertBalance)}
              </span>
              , after which growth turns linear.
            </p>
          </div>
        )}

        <p className="text-caption text-content-muted">
          Reference price {formatInteger(referencePrice)} ({SYMBOL.name}). Margin
          scales with price, so these figures shift as the index moves.
        </p>
      </div>
    </Panel>
  );
}

/**
 * Phase timeline.
 *
 * Segments are equal-width rather than proportional to their dollar range.
 * Proportional widths would make Phase 1 ($10–$12,250) an invisible sliver next
 * to Phase 4, when Phase 1 is where the account actually starts.
 */
function PhaseTimeline({
  currentPhaseId,
  progress,
}: {
  readonly currentPhaseId: number;
  readonly progress: number;
}) {
  return (
    <div>
      <div className="flex gap-1.5">
        {CAPITAL_PHASES.map((phase) => {
          const isPast = phase.id < currentPhaseId;
          const isCurrent = phase.id === currentPhaseId;

          return (
            <div key={phase.id} className="min-w-0 flex-1">
              <div
                className="h-1.5 overflow-hidden rounded-full bg-surface-active"
                role="progressbar"
                aria-valuenow={isCurrent ? Math.round(progress * 100) : isPast ? 100 : 0}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-label={phase.label}
              >
                <div
                  className={clsx(
                    'h-full rounded-full transition-[width] duration-normal ease-decelerate',
                    isPast || isCurrent ? 'bg-accent-base' : 'bg-transparent',
                  )}
                  style={{
                    width: isPast ? '100%' : isCurrent ? `${progress * 100}%` : '0%',
                  }}
                />
              </div>
              <p
                className={clsx(
                  'mt-1.5 truncate text-caption',
                  isCurrent ? 'font-semibold text-content-primary' : 'text-content-muted',
                )}
              >
                {formatCompactCurrency(phase.to)}
              </p>
            </div>
          );
        })}
      </div>
      <p className="mt-1 text-caption text-content-muted">
        Progress within a phase is logarithmic; ranges span four orders of magnitude.
      </p>
    </div>
  );
}
