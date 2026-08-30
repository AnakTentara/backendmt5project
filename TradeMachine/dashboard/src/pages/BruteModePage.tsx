import { BruteModePanel } from '@/features/brute-mode/BruteModePanel';
import { ConfigForm } from '@/features/config/ConfigForm';
import { Panel } from '@/components/Panel';
import { TradesTable } from '@/features/trades/TradesTable';

/**
 * Brute Mode page — engine control plus the parameters that shape its behaviour.
 */
export function BruteModePage() {
  return (
    <div className="space-y-4">
      <Panel title="About Brute Mode" tone="warning">
        <div className="space-y-2 text-body text-content-secondary">
          <p>
            Brute Mode spams orders on strong momentum candles with an ultra-tight
            stop (0.00–0.10 pts), re-entering after each stop-out until price moves
            away. SL+ locks at the midpoint once reached, and take-profit sits just
            inside the nearest supply or demand zone.
          </p>
          <p>
            It is rate-limited by <span className="font-mono">Inp_Brute_MaxOrdersPerMin</span>{' '}
            and uses a separate magic number offset, so its positions are
            distinguishable from regular strategy trades.
          </p>
        </div>
      </Panel>

      <div className="grid gap-4 xl:grid-cols-2">
        <BruteModePanel />
        <ConfigForm />
      </div>

      <TradesTable limit={50} />
    </div>
  );
}
