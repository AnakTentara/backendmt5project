import { Metric } from '@/components/Metric';
import { Panel } from '@/components/Panel';
import { QueryBoundary } from '@/components/QueryBoundary';
import { useSessionMetrics } from '@/hooks/useTradeMachine';
import { KPI_TARGETS } from '@/domain/constants';
import {
  formatCurrency,
  formatInteger,
  formatPercent,
  formatRatio,
} from '@/domain/formatters';

/**
 * Session KPI cards.
 *
 * Each figure is coloured against its acceptance threshold from
 * TRADING_PLAN.md §18 rather than against zero. A 44% win rate is not "bad
 * because it is under half" — it is below the documented 45% floor, and that is
 * the comparison that matters. Showing the target inline saves the reader from
 * holding four thresholds in their head.
 */
export function SessionMetricsPanel() {
  const metrics = useSessionMetrics();

  return (
    <Panel title="Session metrics" subtitle="Against TRADING_PLAN.md targets">
      <QueryBoundary
        data={metrics.data}
        isPending={metrics.isPending}
        error={metrics.error}
        skeletonHeight={160}
      >
        {(data) => (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
              <Metric
                label="Net P&L"
                value={formatCurrency(data.netProfit, { signed: true })}
                tone={data.netProfit > 0 ? 'bull' : data.netProfit < 0 ? 'bear' : 'muted'}
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Win rate"
                value={formatPercent(data.winRate)}
                tone={data.winRate >= KPI_TARGETS.winRate ? 'bull' : 'bear'}
                hint={`target ≥ ${formatPercent(KPI_TARGETS.winRate, 0)}`}
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Profit factor"
                value={formatRatio(data.profitFactor)}
                tone={
                  data.profitFactor === null
                    ? 'muted'
                    : data.profitFactor >= KPI_TARGETS.profitFactor
                      ? 'bull'
                      : 'bear'
                }
                hint={`target ≥ ${KPI_TARGETS.profitFactor.toFixed(1)}`}
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Max drawdown"
                value={formatCurrency(data.maxDrawdown)}
                tone={data.maxDrawdown > 0 ? 'warning' : 'muted'}
                hint={`target < ${KPI_TARGETS.maxDrawdownPct}% of equity`}
                suspect={data.isPlaceholder}
              />
            </div>

            <div className="grid grid-cols-2 gap-4 border-t border-surface-border pt-4 lg:grid-cols-4">
              <Metric
                label="Closed trades"
                value={formatInteger(data.totalTrades)}
                size="sm"
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Winners"
                value={formatInteger(data.winningTrades)}
                tone="bull"
                size="sm"
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Losers"
                value={formatInteger(data.losingTrades)}
                tone="bear"
                size="sm"
                suspect={data.isPlaceholder}
              />
              <Metric
                label="Sharpe"
                value={formatRatio(data.sharpeRatio)}
                size="sm"
                suspect={data.isPlaceholder}
              />
            </div>

            {data.isPlaceholder && (
              <p className="text-caption text-content-muted">
                The backend reports these metrics as not yet integrated with MT5.
                Figures above are placeholders.
              </p>
            )}
          </div>
        )}
      </QueryBoundary>
    </Panel>
  );
}
