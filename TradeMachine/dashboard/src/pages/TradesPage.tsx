import { SessionMetricsPanel } from '@/features/metrics/SessionMetricsPanel';
import { TradesTable } from '@/features/trades/TradesTable';

/** Trades page — full history with session context above it. */
export function TradesPage() {
  return (
    <div className="space-y-4">
      <SessionMetricsPanel />
      <TradesTable limit={200} />
    </div>
  );
}
