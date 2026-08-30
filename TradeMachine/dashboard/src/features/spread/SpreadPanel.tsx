import { Panel } from '@/components/Panel';
import { QueryBoundary } from '@/components/QueryBoundary';
import { StateGauge } from '@/components/StateGauge';
import { Metric } from '@/components/Metric';
import { useSymbolInfo } from '@/hooks/useTradeMachine';
import { SPREAD_STATES, SYMBOL } from '@/domain/constants';
import { assessSpread, breakEvenPoints } from '@/domain/selectors';
import { formatCurrency, formatPoints, formatPrice } from '@/domain/formatters';

/**
 * Spread panel.
 *
 * Given prominence because on VOL_80 the spread is the strategy's primary
 * obstacle, not a detail. At the ~72pt baseline, every round trip pays ~144pts
 * before it can profit — which is why FINANCIAL_REVIEW.md rates the "worst
 * case" 80pt-move scenario as effectively impossible. The break-even figure is
 * shown explicitly so that cost is never implicit.
 */
export function SpreadPanel() {
  const symbol = useSymbolInfo();

  return (
    <Panel title="Spread & cost" subtitle={`${SYMBOL.name} · ${SYMBOL.description}`}>
      <QueryBoundary
        data={symbol.data}
        isPending={symbol.isPending}
        error={symbol.error}
        skeletonHeight={200}
      >
        {(data) => {
          const assessment = assessSpread(data.spreadPoints);
          const breakEven = breakEvenPoints(data.spreadPoints);

          return (
            <div className="space-y-4">
              <StateGauge
                label="Spread state"
                states={SPREAD_STATES}
                activeIndex={assessment.stateIndex}
                value={formatPoints(assessment.points)}
                guidance={assessment.guidance}
              />

              <div className="grid grid-cols-2 gap-4 border-t border-surface-border pt-4">
                <Metric
                  label="Break-even move"
                  value={formatPoints(breakEven)}
                  tone="warning"
                  size="sm"
                  hint="round trip pays spread twice"
                  suspect={data.isPlaceholder}
                />
                <Metric
                  label="Cost per lot"
                  value={formatCurrency(assessment.roundTripCostPerLot)}
                  size="sm"
                  hint="entry + exit"
                  suspect={data.isPlaceholder}
                />
                <Metric
                  label="Support"
                  value={formatPrice(data.support)}
                  tone="bull"
                  size="sm"
                  suspect={data.isPlaceholder}
                />
                <Metric
                  label="Resistance"
                  value={formatPrice(data.resistance)}
                  tone="bear"
                  size="sm"
                  suspect={data.isPlaceholder}
                />
              </div>
            </div>
          );
        }}
      </QueryBoundary>
    </Panel>
  );
}
