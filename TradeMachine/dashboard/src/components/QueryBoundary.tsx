import { clsx } from 'clsx';
import type { ReactNode } from 'react';
import { Badge } from './Badge';

/**
 * QueryBoundary — uniform handling of loading, error, and empty states.
 *
 * Every panel that reads server state wraps its body in this, so failure looks
 * the same everywhere and no panel silently renders zeros when a fetch failed.
 * That last point matters: a spread gauge showing "0 pts" because the bridge is
 * down looks like an excellent spread.
 */

interface QueryBoundaryProps<T> {
  readonly data: T | undefined;
  readonly isPending: boolean;
  readonly error: Error | null;
  readonly children: (data: T) => ReactNode;
  /** Skeleton height while loading. Prevents layout jump on first paint. */
  readonly skeletonHeight?: number;
  /** Treats successfully-loaded data as empty (e.g. a zero-length list). */
  readonly isEmpty?: (data: T) => boolean;
  readonly emptyMessage?: string;
}

export function QueryBoundary<T>({
  data,
  isPending,
  error,
  children,
  skeletonHeight = 72,
  isEmpty,
  emptyMessage = 'No data yet',
}: QueryBoundaryProps<T>) {
  if (error !== null) {
    return <ErrorState error={error} />;
  }

  // `isPending` alone is the right check: during a background refetch the
  // previous data stays available, so the panel keeps rendering instead of
  // flashing a skeleton once per second.
  if (isPending || data === undefined) {
    return <Skeleton height={skeletonHeight} />;
  }

  if (isEmpty?.(data) === true) {
    return (
      <div
        className="flex items-center justify-center py-6 text-body text-content-muted"
        style={{ minHeight: skeletonHeight }}
      >
        {emptyMessage}
      </div>
    );
  }

  return <>{children(data)}</>;
}

function Skeleton({ height }: { readonly height: number }) {
  return (
    <div
      className="animate-pulse rounded-md bg-surface-overlay"
      style={{ height }}
      role="status"
      aria-label="Loading"
    />
  );
}

/**
 * Distinguishes a contract-validation failure from an unreachable bridge. The
 * two need completely different responses — one is a backend code change, the
 * other is a process that is not running — so collapsing them into "something
 * went wrong" would waste the operator's time.
 */
function ErrorState({ error }: { readonly error: Error }) {
  const isApiError = 'kind' in error && 'userMessage' in error;
  const kind = isApiError ? (error as { kind: string }).kind : 'unknown';
  const message = isApiError
    ? (error as { userMessage: string }).userMessage
    : error.message;
  const issues = isApiError ? (error as { issues?: readonly string[] }).issues : undefined;

  const isContractDrift = kind === 'validation';

  return (
    <div
      className={clsx(
        'rounded-md border px-3 py-3',
        isContractDrift
          ? 'border-status-warning/40 bg-status-warningSoft/50'
          : 'border-status-danger/40 bg-status-dangerSoft/50',
      )}
      role="alert"
    >
      <div className="flex items-start gap-2">
        <Badge tone={isContractDrift ? 'warning' : 'danger'}>
          {isContractDrift ? 'CONTRACT' : 'OFFLINE'}
        </Badge>
        <div className="min-w-0 flex-1">
          <p className="text-label text-content-secondary">{message}</p>
          {issues !== undefined && issues.length > 0 && (
            <ul className="mt-1.5 space-y-0.5 font-mono text-caption text-content-muted">
              {issues.slice(0, 4).map((issue) => (
                <li key={issue} className="truncate">
                  {issue}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
