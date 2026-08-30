import { isUsingMockData } from '@/api/provideRepository';
import { Badge } from '@/components/Badge';
import { useHealth, useSymbolInfo } from '@/hooks/useTradeMachine';
import { assessSpread, trendDirection, trendDisplayName } from '@/domain/selectors';
import { formatPoints, formatPrice, formatRelativeTime } from '@/domain/formatters';
import { EmergencyStopButton } from '@/features/emergency/EmergencyStopButton';

/**
 * Topbar — always-visible live state.
 *
 * Holds the three things that must never require navigation to see: whether the
 * bridge is connected, what the spread is, and the emergency stop. Everything
 * else can live on a page.
 */
export function Topbar() {
  const health = useHealth();
  const symbol = useSymbolInfo();

  return (
    <header className="flex h-[56px] shrink-0 items-center justify-between gap-4 border-b border-surface-border bg-surface-raised px-4">
      <div className="flex min-w-0 items-center gap-4">
        <ConnectionIndicator
          isPending={health.isPending}
          hasError={health.error !== null}
          timestamp={health.data?.timestamp}
        />

        {symbol.data && (
          <>
            <Divider />
            <PriceReadout
              price={symbol.data.price}
              trend={symbol.data.trend}
            />
            <Divider />
            <SpreadReadout points={symbol.data.spreadPoints} />
          </>
        )}
      </div>

      <div className="flex shrink-0 items-center gap-3">
        {isUsingMockData && (
          <Badge tone="warning" dot>
            SIMULATED DATA
          </Badge>
        )}
        <EmergencyStopButton />
      </div>
    </header>
  );
}

function Divider() {
  return <span className="h-6 w-px shrink-0 bg-surface-border" aria-hidden="true" />;
}

function ConnectionIndicator({
  isPending,
  hasError,
  timestamp,
}: {
  readonly isPending: boolean;
  readonly hasError: boolean;
  readonly timestamp: string | undefined;
}) {
  if (isUsingMockData) {
    return (
      <Badge tone="info" dot>
        MOCK BRIDGE
      </Badge>
    );
  }

  if (isPending) {
    return <Badge tone="neutral" dot pulse>CONNECTING</Badge>;
  }

  if (hasError) {
    return <Badge tone="critical" dot>BRIDGE OFFLINE</Badge>;
  }

  return (
    <div className="flex items-center gap-2">
      <Badge tone="success" dot pulse>
        LIVE
      </Badge>
      {timestamp !== undefined && (
        <span className="tabular font-mono text-caption text-content-muted">
          {formatRelativeTime(timestamp)}
        </span>
      )}
    </div>
  );
}

function PriceReadout({
  price,
  trend,
}: {
  readonly price: number;
  readonly trend: Parameters<typeof trendDisplayName>[0];
}) {
  const direction = trendDirection(trend);

  const toneClass =
    direction === 'bullish'
      ? 'text-market-bull'
      : direction === 'bearish'
        ? 'text-market-bear'
        : 'text-content-secondary';

  // Direction is carried by an arrow glyph as well as colour, so the readout
  // survives greyscale and colour vision deficiency.
  const arrow = direction === 'bullish' ? '▲' : direction === 'bearish' ? '▼' : '■';

  return (
    <div className="flex min-w-0 items-center gap-2">
      <span className="tabular font-mono text-bodyLg font-semibold text-content-primary">
        {formatPrice(price)}
      </span>
      <span className={`flex items-center gap-1 text-caption font-medium ${toneClass}`}>
        <span aria-hidden="true">{arrow}</span>
        <span className="truncate">{trendDisplayName(trend)}</span>
      </span>
    </div>
  );
}

/**
 * Spread is given permanent screen real estate because it is the dominant cost
 * on VOL_80: at ~72pts, a round trip must clear ~144pts before it profits.
 */
function SpreadReadout({ points }: { readonly points: number }) {
  const assessment = assessSpread(points);

  const toneClass =
    assessment.stateIndex === 0
      ? 'text-status-success'
      : assessment.stateIndex === 1
        ? 'text-status-warning'
        : assessment.stateIndex >= 4
          ? 'text-status-critical'
          : 'text-status-danger';

  return (
    <div className="flex min-w-0 items-center gap-2">
      <span className="text-caption uppercase tracking-wide text-content-muted">
        Spread
      </span>
      <span className={`tabular font-mono text-body font-semibold ${toneClass}`}>
        {formatPoints(assessment.points)}
      </span>
      <span className="hidden truncate text-caption text-content-muted lg:inline">
        {assessment.guidance}
      </span>
    </div>
  );
}
