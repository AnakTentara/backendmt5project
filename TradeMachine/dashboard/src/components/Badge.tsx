import { clsx } from 'clsx';
import type { ReactNode } from 'react';
import type { SemanticTone } from '@/design/tokens';

/**
 * Badge — compact status label.
 *
 * Every tone pairs a colour with a text label. Colour is never the sole carrier
 * of meaning: the palette is already colour-blind-safe, but a badge reading
 * "CRITICAL" stays legible in a greyscale screenshot or a printed log too.
 */

interface BadgeProps {
  readonly children: ReactNode;
  readonly tone?: SemanticTone;
  readonly size?: 'sm' | 'md';
  /** Adds a leading dot, optionally animated for live states. */
  readonly dot?: boolean;
  readonly pulse?: boolean;
  readonly className?: string;
}

const toneClasses: Record<SemanticTone, string> = {
  neutral: 'bg-status-neutralSoft text-content-secondary ring-status-neutral/25',
  info: 'bg-status-infoSoft text-status-info ring-status-info/30',
  success: 'bg-status-successSoft text-status-success ring-status-success/30',
  warning: 'bg-status-warningSoft text-status-warning ring-status-warning/30',
  danger: 'bg-status-dangerSoft text-status-danger ring-status-danger/30',
  critical: 'bg-status-criticalSoft text-status-critical ring-status-critical/40',
};

const dotClasses: Record<SemanticTone, string> = {
  neutral: 'bg-status-neutral',
  info: 'bg-status-info',
  success: 'bg-status-success',
  warning: 'bg-status-warning',
  danger: 'bg-status-danger',
  critical: 'bg-status-critical',
};

export function Badge({
  children,
  tone = 'neutral',
  size = 'sm',
  dot = false,
  pulse = false,
  className,
}: BadgeProps) {
  return (
    <span
      className={clsx(
        'inline-flex items-center gap-1.5 rounded-full font-medium ring-1 ring-inset',
        size === 'sm' ? 'px-2 py-0.5 text-caption' : 'px-2.5 py-1 text-label',
        toneClasses[tone],
        className,
      )}
    >
      {dot && (
        <span className="relative flex h-1.5 w-1.5 shrink-0">
          {pulse && (
            <span
              className={clsx(
                'absolute inline-flex h-full w-full animate-pulse-ring rounded-full',
                dotClasses[tone],
              )}
            />
          )}
          <span
            className={clsx(
              'relative inline-flex h-1.5 w-1.5 rounded-full',
              dotClasses[tone],
            )}
          />
        </span>
      )}
      {children}
    </span>
  );
}
