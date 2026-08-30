import { clsx } from 'clsx';
import { Badge } from '@/components/Badge';
import { Panel } from '@/components/Panel';
import { QueryBoundary } from '@/components/QueryBoundary';
import { useTrades } from '@/hooks/useTradeMachine';
import { formatCurrency, formatLots, formatPrice, formatTime } from '@/domain/formatters';
import type { Trade } from '@/api/contracts';

/**
 * Trade history table.
 *
 * Numeric columns are right-aligned and monospaced so magnitudes line up
 * vertically — the fastest way to spot an outlier loss in a long list. Side and
 * TP state are shown as text, never as colour alone.
 */

interface TradesTableProps {
  readonly limit?: number;
}

export function TradesTable({ limit = 50 }: TradesTableProps) {
  const trades = useTrades(limit);

  return (
    <Panel
      title="Trades"
      subtitle={`Most recent ${limit}`}
      flush
      action={
        trades.data && (
          <div className="flex items-center gap-2">
            <Badge tone="neutral">{trades.data.total} total</Badge>
            {trades.data.pending > 0 && (
              <Badge tone="info" dot pulse>
                {trades.data.pending} open
              </Badge>
            )}
          </div>
        )
      }
    >
      <QueryBoundary
        data={trades.data}
        isPending={trades.isPending}
        error={trades.error}
        skeletonHeight={280}
        isEmpty={(data) => data.trades.length === 0}
        emptyMessage="No trades recorded this session"
      >
        {(data) => (
          <div className="overflow-x-auto scrollbar-slim">
            <table className="w-full border-collapse text-body">
              <thead>
                <tr className="border-b border-surface-border bg-surface-overlay">
                  <Th align="left">Ticket</Th>
                  <Th align="left">Side</Th>
                  <Th align="right">Entry</Th>
                  <Th align="right">Exit</Th>
                  <Th align="right">Lots</Th>
                  <Th align="right">P&L</Th>
                  <Th align="left">State</Th>
                  <Th align="right">Time</Th>
                </tr>
              </thead>
              <tbody>
                {data.trades.map((trade) => (
                  <TradeRow key={trade.id} trade={trade} />
                ))}
              </tbody>
            </table>

            {data.isPlaceholder && (
              <p className="border-t border-surface-border px-4 py-3 text-caption text-content-muted">
                The backend reports the trade list as not yet integrated with MT5.
              </p>
            )}
          </div>
        )}
      </QueryBoundary>
    </Panel>
  );
}

function Th({
  children,
  align,
}: {
  readonly children: React.ReactNode;
  readonly align: 'left' | 'right';
}) {
  return (
    <th
      scope="col"
      className={clsx(
        'px-4 py-2.5 text-label font-medium uppercase tracking-wide text-content-muted',
        align === 'right' ? 'text-right' : 'text-left',
      )}
    >
      {children}
    </th>
  );
}

function TradeRow({ trade }: { readonly trade: Trade }) {
  const isBuy = trade.side === 'BUY';
  const isProfit = trade.profit > 0;

  return (
    <tr
      className={clsx(
        'border-b border-surface-border/60 transition-colors duration-fast',
        'hover:bg-surface-hover',
        // Open positions get a left accent so they are findable at a glance in
        // a long history without relying on reading the State column.
        trade.isOpen && 'bg-accent-soft/30',
      )}
    >
      <td className="px-4 py-2.5">
        <div className="flex items-center gap-2">
          <span className="tabular font-mono text-label text-content-secondary">
            {trade.id}
          </span>
          {trade.isBrute && (
            <span
              className="text-caption text-status-warning"
              title="Opened by Brute Mode"
            >
              ⚡
            </span>
          )}
        </div>
      </td>

      <td className="px-4 py-2.5">
        <span
          className={clsx(
            'inline-flex items-center gap-1 text-label font-semibold',
            isBuy ? 'text-market-bull' : 'text-market-bear',
          )}
        >
          <span aria-hidden="true">{isBuy ? '▲' : '▼'}</span>
          {trade.side}
        </span>
      </td>

      <td className="tabular px-4 py-2.5 text-right font-mono text-content-primary">
        {formatPrice(trade.entryPrice)}
      </td>

      <td className="tabular px-4 py-2.5 text-right font-mono text-content-secondary">
        {trade.exitPrice === null ? '—' : formatPrice(trade.exitPrice)}
      </td>

      <td className="tabular px-4 py-2.5 text-right font-mono text-content-secondary">
        {formatLots(trade.lots)}
      </td>

      <td
        className={clsx(
          'tabular px-4 py-2.5 text-right font-mono font-semibold',
          isProfit ? 'text-market-bull' : 'text-market-bear',
        )}
      >
        {formatCurrency(trade.profit, { signed: true })}
      </td>

      <td className="px-4 py-2.5">
        <TpStateBadge state={trade.tpState} isOpen={trade.isOpen} />
      </td>

      <td className="tabular px-4 py-2.5 text-right font-mono text-caption text-content-muted">
        {formatTime(trade.openedAt)}
      </td>
    </tr>
  );
}

/**
 * TP Draft state. Source: `enum TP_STATE` (Types.mqh).
 *
 * Worth surfacing because this system holds TP/SL internally rather than on the
 * server, so the state machine is the only way to know whether a position has
 * had its stop moved to break-even (`TP1_HIT` sets SL+).
 */
function TpStateBadge({
  state,
  isOpen,
}: {
  readonly state: Trade['tpState'];
  readonly isOpen: boolean;
}) {
  const config = {
    DRAFT: { tone: 'neutral', label: 'Draft' },
    TP1_APPROACH: { tone: 'info', label: 'TP1 near' },
    TP1_HIT: { tone: 'success', label: 'SL+ set' },
    TP2_HIT: { tone: 'success', label: 'TP2 hit' },
    TRAILING: { tone: 'info', label: 'Trailing' },
    CLOSED: { tone: 'neutral', label: 'Closed' },
  } as const;

  const { tone, label } = config[state];

  return (
    <Badge tone={tone} dot={isOpen} pulse={isOpen}>
      {label}
    </Badge>
  );
}
