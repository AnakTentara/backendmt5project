import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

/**
 * App shell.
 *
 * Sidebar and topbar are fixed; only the outlet scrolls. This keeps the
 * connection indicator, live price, spread reading, and emergency stop on
 * screen at all times regardless of how long the page below gets.
 */
export function AppShell() {
  return (
    <div className="flex h-screen overflow-hidden bg-surface-base">
      <Sidebar />

      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar />

        <main className="flex-1 overflow-y-auto scrollbar-slim">
          <div className="mx-auto max-w-content p-4">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
