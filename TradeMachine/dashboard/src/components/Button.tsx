import { clsx } from 'clsx';
import { forwardRef } from 'react';
import type { ButtonHTMLAttributes, ReactNode } from 'react';

/**
 * Button — the only interactive trigger primitive.
 *
 * `variant="critical"` exists specifically for emergency stop. It is visually
 * distinct from `danger` because the action is categorically different: danger
 * is reversible (turn Brute Mode off), critical is not (close every position at
 * market). Making them look alike would invite a misclick with real money
 * behind it.
 */

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'critical';

interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className'> {
  readonly children: ReactNode;
  readonly variant?: ButtonVariant;
  readonly size?: 'sm' | 'md' | 'lg';
  /** Shows a spinner and blocks interaction. */
  readonly loading?: boolean;
  readonly fullWidth?: boolean;
  readonly icon?: ReactNode;
  readonly className?: string;
}

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    'bg-accent-base text-content-inverse hover:bg-accent-hover active:bg-accent-pressed',
  secondary:
    'bg-surface-overlay text-content-primary ring-1 ring-inset ring-surface-borderStrong hover:bg-surface-hover',
  ghost: 'bg-transparent text-content-secondary hover:bg-surface-hover hover:text-content-primary',
  danger:
    'bg-status-dangerSoft text-status-danger ring-1 ring-inset ring-status-danger/40 hover:bg-status-danger hover:text-content-inverse',
  critical:
    'bg-status-critical text-content-inverse hover:brightness-110 active:brightness-95 ring-1 ring-inset ring-status-critical',
};

const sizeClasses = {
  sm: 'h-8 px-3 text-label',
  md: 'h-10 px-4 text-body',
  lg: 'h-12 px-6 text-bodyLg',
} as const;

/**
 * Ref is forwarded so callers can manage focus. The emergency-stop dialog
 * relies on this to focus Cancel rather than Confirm on open.
 */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    children,
    variant = 'secondary',
    size = 'md',
    loading = false,
    fullWidth = false,
    icon,
    className,
    disabled,
    type = 'button',
    ...rest
  },
  ref,
) {
  const isDisabled = disabled === true || loading;

  return (
    <button
      ref={ref}
      type={type}
      disabled={isDisabled}
      // Communicates the busy state to screen readers, which cannot see the spinner.
      aria-busy={loading}
      className={clsx(
        'inline-flex items-center justify-center gap-2 rounded-md font-medium',
        'transition-colors duration-fast ease-standard',
        'disabled:cursor-not-allowed disabled:opacity-45',
        sizeClasses[size],
        variantClasses[variant],
        fullWidth && 'w-full',
        className,
      )}
      {...rest}
    >
      {loading ? (
        <Spinner />
      ) : (
        icon !== undefined && <span aria-hidden="true">{icon}</span>
      )}
      {children}
    </button>
  );
});

function Spinner() {
  return (
    <svg
      className="h-4 w-4 animate-spin"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="3"
      />
      <path
        className="opacity-90"
        fill="currentColor"
        d="M12 2a10 10 0 0 1 10 10h-3a7 7 0 0 0-7-7V2z"
      />
    </svg>
  );
}
