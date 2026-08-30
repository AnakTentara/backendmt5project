import { clsx } from 'clsx';
import { Badge } from '@/components/Badge';
import { Button } from '@/components/Button';
import { Metric } from '@/components/Metric';
import { Panel } from '@/components/Panel';
import { QueryBoundary } from '@/components/QueryBoundary';
import { useBruteStatus, useSetBruteMode } from '@/hooks/useTradeMachine';
import { formatCurrency, formatInteger, formatPrice } from '@/domain/formatters';
import type { BruteStatus } from '@/api/contracts';

/**
 * Brute Mode control panel.
 *
 * Brute Mode spams orders on momentum candles with an ultra-tight stop and
 * re-enters after each SL hit. It is the most aggressive path in the system, so
 * the panel foregrounds the rate limit and session P&L rather than burying them.
 *
 * The toggle is NOT optimistic. `success` from the bridge only means the command
 * file was written; MT5 reads it on its own 1-second cycle and may reject it.
 * Flipping the switch instantly would assert a state the engine has not reached,
 * which on a live account is a lie worth avoiding. Instead the control shows a
 * "queued" state until a status poll confirms.
 */
export function BruteModePanel() {
  const status = useBruteStatus();
  const setBruteMode = useSetBruteMode();

  return (
    <Panel
      title="Brute Mode"
      subtitle="Aggressive momentum scalping"
      tone={status.data?.isActive === true ? 'warning' : 'default'}
      action={
        status.data && (
          <Badge
            tone={status.data.isActive ? 'warning' : 'neutral'}
            dot
            pulse={status.data.isActive}
          >
            {status.data.isActive ? 'ENGAGED' : 'IDLE'}
          </Badge>
        )
      }
    >
      <QueryBoundary
        data={status.data}
        isPending={status.isPending}
        error={status.error}
        skeletonHeight={220}
      >
        {(data) => (
          <div className="space-y-4">
            <MomentumIndicator status={data} />

            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <Metric
                label="Session P&L"
                value={formatCurrency(data.sessionPnl, { signed: true })}
                tone={data.sessionPnl > 0 ? 'bull' : data.sessionPnl < 0 ? 'bear' : 'muted'}
                size="sm"
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Total orders"
                value={formatInteger(data.totalOrders)}
                size="sm"
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Re-entries"
                value={formatInteger(data.reentryCount)}
                size="sm"
                hint={data.slHitPendingReentry ? 'SL hit — pending' : undefined}
                tone={data.slHitPendingReentry ? 'warning' : 'default'}
                suspect={data.isPlaceholder}
              />
              <Metric
                label="SL+ lock"
                value={data.slPlusLocked ? formatPrice(data.lockedSlPlus) : 'Unlocked'}
                tone={data.slPlusLocked ? 'bull' : 'muted'}
                size="sm"
                suspect={data.isPlaceholder}
              />
            </div>

            <RateLimitBar status={data} />

            <div className="flex items-center gap-2 border-t border-surface-border pt-4">
              <Button
                variant={data.isActive ? 'danger' : 'primary'}
                onClick={() => setBruteMode.mutate(!data.isActive)}
                loading={setBruteMode.isPending}
                fullWidth
              >
                {data.isActive ? 'Deactivate Brute Mode' : 'Activate Brute Mode'}
              </Button>
            </div>

            {setBruteMode.isPending && (
              <p className="text-caption text-content-muted">
                Command queued. MT5 polls once per second, so the engine state
                below updates on the next cycle.
              </p>
            )}

            {setBruteMode.error && (
              <p className="text-caption text-status-danger" role="alert">
                {setBruteMode.error.message}
              </p>
            )}
          </div>
        )}
      </QueryBoundary>
    </Panel>
  );
}

/**
 * Momentum direction. The two backend flags are mutually exclusive, so a state
 * where both are set indicates a backend bug and is surfaced rather than hidden.
 */
function MomentumIndicator({ status }: { readonly status: BruteStatus }) {
  const { momentumBullish, momentumBearish } = status;

  if (momentumBullish && momentumBearish) {
    return (
      <div className="rounded-md border border-status-warning/40 bg-status-warningSoft/40 px-3 py-2">
        <p className="text-label text-status-warning">
          Conflicting momentum flags reported. These are mutually exclusive in
          BruteMode.mqh — treat this reading as unreliable.
        </p>
      </div>
    );
  }

  const direction = momentumBullish ? 'bullish' : momentumBearish ? 'bearish' : 'none';

  const config = {
    bullish: { label: 'Bullish momentum', glyph: '▲', className: 'text-market-bull bg-market-bullSoft border-market-bullBorder' },
    bearish: { label: 'Bearish momentum', glyph: '▼', className: 'text-market-bear bg-market-bearSoft border-market-bearBorder' },
    none: { label: 'No momentum detected', glyph: '■', className: 'text-content-muted bg-surface-overlay border-surface-border' },
  }[direction];

  return (
    <div
      className={clsx(
        'flex items-center gap-2.5 rounded-md border px-3 py-2.5',
        config.className,
      )}
    >
      <span className="text-bodyLg" aria-hidden="true">
        {config.glyph}
      </span>
      <span className="text-body font-medium">{config.label}</span>
    </div>
  );
}

/**
 * Rate limit usage.
 *
 * `Inp_Brute_MaxOrdersPerMin` caps order flow per minute. Sitting at the cap
 * means signals are being dropped, which is worth seeing before it shows up as
 * missed entries in the trade log.
 */
function RateLimitBar({ status }: { readonly status: BruteStatus }) {
  const { ordersThisMinute, maxOrdersPerMinute, rateLimitUsage } = status;
  const isSaturated = rateLimitUsage >= 1;
  const isNearLimit = rateLimitUsage >= 0.8;

  return (
    <div>
      <div className="flex items-baseline justify-between gap-2">
        <span className="text-label font-medium uppercase tracking-wide text-content-muted">
          Order rate
        </span>
        <span
          className={clsx(
            'tabular font-mono text-body font-semibold',
            isSaturated
              ? 'text-status-danger'
              : isNearLimit
                ? 'text-status-warning'
                : 'text-content-primary',
          )}
        >
          {formatInteger(ordersThisMinute)} / {formatInteger(maxOrdersPerMinute)}
        </span>
      </div>

      <div
        className="mt-2 h-1.5 overflow-hidden rounded-full bg-surface-active"
        role="progressbar"
        aria-valuenow={ordersThisMinute}
        aria-valuemin={0}
        aria-valuemax={maxOrdersPerMinute}
        aria-label="Orders this minute against rate limit"
      >
        <div
          className={clsx(
            'h-full rounded-full transition-[width] duration-normal ease-decelerate',
            isSaturated
              ? 'bg-status-danger'
              : isNearLimit
                ? 'bg-status-warning'
                : 'bg-accent-base',
          )}
          style={{ width: `${rateLimitUsage * 100}%` }}
        />
      </div>

      {isSaturated && (
        <p className="mt-1.5 text-caption text-status-danger">
          Rate limit reached. Further momentum signals are being dropped this minute.
        </p>
      )}
    </div>
  );
}
