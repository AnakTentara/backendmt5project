import { clsx } from 'clsx';
import type { ReactNode } from 'react';

/**
 * Panel — the base container for every dashboard section.
 *
 * Deliberately minimal: a surface, a border, an optional header. Layout is the
 * caller's responsibility, which keeps this composable rather than growing a
 * prop for every arrangement a page happens to need.
 */

interface PanelProps {
  readonly children: ReactNode;
  /** Omit for a bare surface with no header row. */
  readonly title?: string;
  readonly subtitle?: string;
  /** Rendered at the header's trailing edge (toggles, filters, counts). */
  readonly action?: ReactNode;
  readonly className?: string;
  /** Removes body padding, for tables and charts that bleed to the edge. */
  readonly flush?: boolean;
  /** Raises the border to signal an alert state. */
  readonly tone?: 'default' | 'warning' | 'critical';
}

const toneBorder = {
  default: 'border-surface-border',
  warning: 'border-status-warning/40',
  critical: 'border-status-critical/50',
} as const;

export function Panel({
  children,
  title,
  subtitle,
  action,
  className,
  flush = false,
  tone = 'default',
}: PanelProps) {
  const hasHeader = title !== undefined || action !== undefined;

  return (
    <section
      className={clsx(
        'rounded-lg border bg-surface-raised shadow-sm',
        toneBorder[tone],
        className,
      )}
    >
      {hasHeader && (
        <header className="flex items-start justify-between gap-4 border-b border-surface-border px-4 py-3">
          <div className="min-w-0">
            {title !== undefined && (
              <h2 className="truncate text-label font-semibold uppercase tracking-wide text-content-secondary">
                {title}
              </h2>
            )}
            {subtitle !== undefined && (
              <p className="mt-0.5 truncate text-caption text-content-muted">
                {subtitle}
              </p>
            )}
          </div>
          {action !== undefined && <div className="shrink-0">{action}</div>}
        </header>
      )}

      <div className={flush ? undefined : 'p-4'}>{children}</div>
    </section>
  );
}
