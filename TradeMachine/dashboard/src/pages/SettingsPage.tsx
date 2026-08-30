import { Badge } from '@/components/Badge';
import { Metric } from '@/components/Metric';
import { Panel } from '@/components/Panel';
import { QueryBoundary } from '@/components/QueryBoundary';
import { ConfigForm } from '@/features/config/ConfigForm';
import { useHealth } from '@/hooks/useTradeMachine';
import { isUsingMockData } from '@/api/provideRepository';
import { env } from '@/config/env';
import { formatRelativeTime } from '@/domain/formatters';

/**
 * Settings page — runtime config plus bridge diagnostics.
 *
 * The diagnostics panel exists because the most common failure here is not a
 * bug in the dashboard, it is WebBridge.py not running or MT5 not attached.
 * Showing the resolved base URL and the relay file paths turns "nothing works"
 * into an actionable answer.
 */
export function SettingsPage() {
  const health = useHealth();

  return (
    <div className="space-y-4">
      <ConfigForm />

      <div className="grid gap-4 xl:grid-cols-2">
        <Panel
          title="Bridge diagnostics"
          subtitle="GET /api/health"
          action={
            isUsingMockData ? (
              <Badge tone="warning">MOCK</Badge>
            ) : (
              <Badge tone={health.error === null ? 'success' : 'critical'} dot>
                {health.error === null ? 'REACHABLE' : 'UNREACHABLE'}
              </Badge>
            )
          }
        >
          <QueryBoundary
            data={health.data}
            isPending={health.isPending}
            error={health.error}
            skeletonHeight={140}
          >
            {(data) => (
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <Metric label="Service" value={data.service} size="sm" />
                  <Metric
                    label="Last response"
                    value={formatRelativeTime(data.timestamp)}
                    size="sm"
                  />
                </div>

                <div className="space-y-2 border-t border-surface-border pt-4">
                  <FilePathRow label="Command file" path={data.commandFile} />
                  <FilePathRow label="Response file" path={data.responseFile} />
                </div>

                {!data.bridgeFilesReady && (
                  <div className="rounded-md border border-status-warning/40 bg-status-warningSoft/40 px-3 py-2.5">
                    <p className="text-caption text-content-secondary">
                      One or both relay files are missing. The bridge writes
                      commands to disk for MT5 to poll, so commands will not reach
                      the EA until both exist.
                    </p>
                  </div>
                )}
              </div>
            )}
          </QueryBoundary>
        </Panel>

        <Panel title="Client configuration" subtitle="Resolved at startup">
          <div className="space-y-3">
            <ConfigRow label="API base URL" value={env.apiBaseUrl} />
            <ConfigRow
              label="Data source"
              value={isUsingMockData ? 'Mock (simulated)' : 'Live bridge'}
            />
            <ConfigRow label="Poll interval" value={`${env.pollIntervalMs} ms`} />
            <ConfigRow label="Request timeout" value={`${env.requestTimeoutMs} ms`} />

            <div className="rounded-md border border-surface-border bg-surface-overlay px-3 py-2.5">
              <p className="text-caption text-content-muted">
                Config.mqh declares <span className="font-mono">Inp_HTTP_Port = 8080</span>,
                but WebBridge.py listens on 5000. This dashboard targets the Flask
                bridge, so 5000 is correct.
              </p>
            </div>

            <div className="rounded-md border border-status-critical/40 bg-status-criticalSoft/30 px-3 py-2.5">
              <p className="text-caption text-content-secondary">
                <strong className="text-status-critical">No authentication.</strong>{' '}
                The bridge runs with fully open CORS and no token check. Anything
                able to reach port 5000 can trigger an emergency stop. Keep it
                bound to loopback, and add auth before exposing it to a network.
              </p>
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}

function ConfigRow({
  label,
  value,
}: {
  readonly label: string;
  readonly value: string;
}) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <span className="shrink-0 text-label text-content-muted">{label}</span>
      <span className="truncate font-mono text-label text-content-primary">
        {value}
      </span>
    </div>
  );
}

function FilePathRow({
  label,
  path,
}: {
  readonly label: string;
  readonly path: string;
}) {
  const isMissing = path === 'N/A';

  return (
    <div className="min-w-0">
      <div className="flex items-center gap-2">
        <span className="text-label text-content-muted">{label}</span>
        {isMissing && (
          <Badge tone="warning" size="sm">
            MISSING
          </Badge>
        )}
      </div>
      <p
        className={`mt-0.5 truncate font-mono text-caption ${
          isMissing ? 'text-content-disabled' : 'text-content-secondary'
        }`}
        title={path}
      >
        {path}
      </p>
    </div>
  );
}
