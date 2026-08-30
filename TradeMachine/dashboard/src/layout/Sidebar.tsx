import { clsx } from 'clsx';
import { NavLink } from 'react-router-dom';
import { SYMBOL } from '@/domain/constants';

/**
 * Sidebar navigation.
 *
 * Route set is intentionally small. A dashboard that hides the spread reading
 * three clicks deep is a dashboard nobody checks, so the overview carries
 * everything time-critical and the other routes hold detail.
 */

interface NavItem {
  readonly to: string;
  readonly label: string;
  readonly icon: string;
  readonly description: string;
}

const NAV_ITEMS: readonly NavItem[] = [
  { to: '/', label: 'Overview', icon: '◧', description: 'Live state and KPIs' },
  { to: '/brute', label: 'Brute Mode', icon: '⚡', description: 'Momentum scalping engine' },
  { to: '/trades', label: 'Trades', icon: '≡', description: 'Execution history' },
  { to: '/risk', label: 'Risk', icon: '◈', description: 'Exposure and capital phase' },
  { to: '/settings', label: 'Settings', icon: '⚙', description: 'Runtime configuration' },
];

export function Sidebar() {
  return (
    <nav
      className="flex h-full w-[240px] shrink-0 flex-col border-r border-surface-border bg-surface-raised"
      aria-label="Main navigation"
    >
      <div className="flex h-[56px] items-center gap-2.5 border-b border-surface-border px-4">
        <div className="flex h-7 w-7 items-center justify-center rounded-md bg-accent-base text-content-inverse">
          <span className="text-body font-bold" aria-hidden="true">
            T
          </span>
        </div>
        <div className="min-w-0">
          <p className="truncate text-body font-semibold text-content-primary">
            TradeMachine
          </p>
          <p className="truncate font-mono text-caption text-content-muted">
            {SYMBOL.name}
          </p>
        </div>
      </div>

      <ul className="flex-1 space-y-0.5 overflow-y-auto p-2 scrollbar-slim">
        {NAV_ITEMS.map((item) => (
          <li key={item.to}>
            <NavLink
              to={item.to}
              // `end` restricts the root route to exact matches; without it the
              // Overview link stays active on every child route.
              end={item.to === '/'}
              className={({ isActive }) =>
                clsx(
                  'flex items-center gap-3 rounded-md px-3 py-2',
                  'transition-colors duration-fast ease-standard',
                  isActive
                    ? 'bg-surface-active text-content-primary'
                    : 'text-content-secondary hover:bg-surface-hover hover:text-content-primary',
                )
              }
            >
              <span className="w-4 shrink-0 text-center text-body" aria-hidden="true">
                {item.icon}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-body font-medium">
                  {item.label}
                </span>
                <span className="block truncate text-caption text-content-muted">
                  {item.description}
                </span>
              </span>
            </NavLink>
          </li>
        ))}
      </ul>

      <div className="border-t border-surface-border px-4 py-3">
        <p className="text-caption text-content-muted">
          Local bridge only. No authentication is configured on the backend.
        </p>
      </div>
    </nav>
  );
}
