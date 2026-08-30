import { Metric } from '@/components/Metric';
import { Panel } from '@/components/Panel';
import { CapitalPhasePanel } from '@/features/risk/CapitalPhasePanel';
import { SpreadPanel } from '@/features/spread/SpreadPanel';
import {
  MARGIN,
  POSITION_CAP,
  RISK,
  hasInvertedMarginThresholds,
} from '@/domain/constants';
import { formatCurrency, formatInteger, formatPercent } from '@/domain/formatters';

/**
 * Risk page — the configured guardrails, shown as read-only reference.
 *
 * These values come from Config.mqh and cannot be changed over the API, so the
 * page states them rather than pretending they are editable.
 */
export function RiskPage() {
  return (
    <div className="space-y-4">
      <CapitalPhasePanel />

      <div className="grid gap-4 xl:grid-cols-2">
        <Panel title="Risk limits" subtitle="From Config.mqh · read-only">
          <div className="grid grid-cols-2 gap-4">
            <Metric
              label="Max risk / trade"
              value={formatPercent(RISK.maxRiskPercent / 100, 1)}
              size="sm"
              hint="spread-adjusted"
            />
            <Metric
              label="Max total exposure"
              value={formatPercent(RISK.maxTotalExposure / 100, 1)}
              size="sm"
              hint="all open positions"
            />
            <Metric
              label="Max per direction"
              value={formatInteger(RISK.maxPositionsPerDirection)}
              size="sm"
              hint="concurrent positions"
            />
            <Metric
              label="Counter-trend cap"
              value={formatInteger(RISK.maxCounterTrendPositions)}
              size="sm"
              hint={`sized at ${formatPercent(RISK.counterTrendSizeMultiplier, 0)} of normal`}
            />
          </div>
        </Panel>

        <Panel
          title="Margin thresholds"
          subtitle="From Config.mqh · read-only"
          tone={hasInvertedMarginThresholds ? 'warning' : 'default'}
        >
          <div className="space-y-4">
            <div className="grid grid-cols-3 gap-4">
              <Metric
                label="Warn"
                value={formatPercent(MARGIN.warnLevel / 100, 0)}
                tone="muted"
                size="sm"
              />
              <Metric
                label="Alert"
                value={formatPercent(MARGIN.alertLevel / 100, 0)}
                tone="warning"
                size="sm"
              />
              <Metric
                label="Force close"
                value={formatPercent(MARGIN.closeLevel / 100, 0)}
                tone="critical"
                size="sm"
              />
            </div>

            {/*
              Surfaces a genuine inconsistency rather than quietly reordering it:
              TRADING_PLAN.md sets the force-close level ABOVE the alert level,
              which would trigger closure before any warning is ever shown.
            */}
            {hasInvertedMarginThresholds && (
              <div className="rounded-md border border-status-warning/40 bg-status-warningSoft/40 px-3 py-2.5">
                <p className="text-caption text-content-secondary">
                  <strong className="text-status-warning">
                    Thresholds appear inverted.
                  </strong>{' '}
                  Force-close ({MARGIN.closeLevel}%) sits above alert (
                  {MARGIN.alertLevel}%), so positions would close before any
                  warning fires. This looks like a backend configuration bug and
                  is shown as configured rather than silently corrected.
                </p>
              </div>
            )}

            <Metric
              label="Margin utilisation cap"
              value={formatPercent(MARGIN.safetyPct / 100, 0)}
              size="sm"
              hint="max share of free margin per position"
            />
          </div>
        </Panel>
      </div>

      <div className="grid gap-4 xl:grid-cols-2">
        <SpreadPanel />

        <Panel title="Position cap" subtitle="Multi-ticket splitting">
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <Metric
                label="Max lots / ticket"
                value={formatInteger(POSITION_CAP.maxLotsPerTicket)}
                size="sm"
                hint="broker ceiling"
              />
              <Metric
                label="Max split tickets"
                value={formatInteger(POSITION_CAP.maxSplitTickets)}
                size="sm"
                hint="hard limit"
              />
              <Metric
                label="Cap engages at"
                value={formatCurrency(POSITION_CAP.alertBalance)}
                tone="warning"
                size="sm"
                hint="at 1:2000 leverage"
              />
              <Metric
                label="Max total lots"
                value={formatInteger(
                  POSITION_CAP.maxLotsPerTicket * POSITION_CAP.maxSplitTickets,
                )}
                size="sm"
                hint="across all tickets"
              />
            </div>

            <p className="text-caption text-content-muted">
              Above {formatInteger(POSITION_CAP.maxLotsPerTicket)} lots an order
              splits across tickets with a 1.0 pt offset between them to avoid
              slippage clustering. All tickets share one SL+, TP2, and trailing
              distance.
            </p>
          </div>
        </Panel>
      </div>
    </div>
  );
}
