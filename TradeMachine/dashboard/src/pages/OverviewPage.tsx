import { BruteModePanel } from '@/features/brute-mode/BruteModePanel';
import { SessionMetricsPanel } from '@/features/metrics/SessionMetricsPanel';
import { SpreadPanel } from '@/features/spread/SpreadPanel';
import { TradesTable } from '@/features/trades/TradesTable';

/**
 * Overview — the default landing page.
 *
 * Ordered by decision urgency rather than by data volume: session P&L first,
 * then the two things that gate whether trading should continue at all (spread
 * cost and engine state), then history. Someone glancing at this screen for two
 * seconds should learn whether anything is wrong.
 */
export function OverviewPage() {
  return (
    <div className="space-y-4">
      <SessionMetricsPanel />

      <div className="grid gap-4 xl:grid-cols-2">
        <SpreadPanel />
        <BruteModePanel />
      </div>

      <TradesTable limit={15} />
    </div>
  );
}
