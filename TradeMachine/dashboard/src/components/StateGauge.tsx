import { clsx } from 'clsx';

/**
 * StateGauge — segmented indicator for a discrete state machine.
 *
 * Built for `SPREAD_STATE` (5 levels) and reused for any ordered enum. A
 * segmented bar is used rather than a continuous meter because the backend
 * states ARE discrete: 79pts and 61pts both mean "reduce lot size 25%", and a
 * smooth gradient would imply a precision the rules do not have.
 */

interface StateGaugeProps {
  /** Ordered labels, lowest severity first. */
  readonly states: readonly string[];
  /** Index into `states`. Values outside the range are clamped. */
  readonly activeIndex: number;
  /** Reading shown above the bar, already formatted. */
  readonly value: string;
  /** Action text for the active state. */
  readonly guidance: string;
  readonly label: string;
  readonly className?: string;
}

/**
 * Severity ramp. Index maps to a token colour; the final entry is reused when
 * a caller supplies more states than the ramp covers.
 */
const severityFill = [
  'bg-status-success',
  'bg-status-warning',
  'bg-status-danger',
  'bg-status-danger',
  'bg-status-critical',
] as const;

const severityText = [
  'text-status-success',
  'text-status-warning',
  'text-status-danger',
  'text-status-danger',
  'text-status-critical',
] as const;

function rampAt<T>(ramp: readonly T[], index: number, fallback: T): T {
  return ramp[Math.min(index, ramp.length - 1)] ?? fallback;
}

export function StateGauge({
  states,
  activeIndex,
  value,
  guidance,
  label,
  className,
}: StateGaugeProps) {
  const clampedIndex = Math.min(Math.max(activeIndex, 0), states.length - 1);
  const activeState = states[clampedIndex] ?? '—';
  const activeTextClass = rampAt(severityText, clampedIndex, 'text-status-critical');

  return (
    <div className={clsx('min-w-0', className)}>
      <div className="flex items-baseline justify-between gap-2">
        <span className="text-label font-medium uppercase tracking-wide text-content-muted">
          {label}
        </span>
        <span className={clsx('tabular font-mono text-bodyLg font-semibold', activeTextClass)}>
          {value}
        </span>
      </div>

      {/*
        Segments are decorative; the state and guidance below carry the meaning
        for assistive technology, so the bar itself is hidden from the a11y tree
        and the semantics are exposed via role="status".
      */}
      <div className="mt-2 flex gap-1" aria-hidden="true">
        {states.map((state, index) => {
          const isReached = index <= clampedIndex;
          return (
            <div
              key={state}
              className={clsx(
                'h-1.5 flex-1 rounded-full transition-colors duration-fast ease-standard',
                isReached
                  ? rampAt(severityFill, index, 'bg-status-critical')
                  : 'bg-surface-active',
              )}
            />
          );
        })}
      </div>

      <div className="mt-2 flex items-center justify-between gap-2" role="status">
        <span className={clsx('text-caption font-semibold', activeTextClass)}>
          {activeState.replace(/_/g, ' ')}
        </span>
        <span className="truncate text-caption text-content-muted">{guidance}</span>
      </div>
    </div>
  );
}
