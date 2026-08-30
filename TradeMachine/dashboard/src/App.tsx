import { QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { createQueryClient } from '@/api/queryClient';
import { AppShell } from '@/layout/AppShell';
import { BruteModePage } from '@/pages/BruteModePage';
import { OverviewPage } from '@/pages/OverviewPage';
import { RiskPage } from '@/pages/RiskPage';
import { SettingsPage } from '@/pages/SettingsPage';
import { TradesPage } from '@/pages/TradesPage';

/**
 * Root component.
 *
 * The QueryClient is created inside `useState` rather than at module scope so
 * it is never shared across React roots and survives Fast Refresh without
 * discarding the cache mid-session.
 */
export function App() {
  const [queryClient] = useState(createQueryClient);

  return (
    <QueryClientProvider client={queryClient}>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<OverviewPage />} />
          <Route path="brute" element={<BruteModePage />} />
          <Route path="trades" element={<TradesPage />} />
          <Route path="risk" element={<RiskPage />} />
          <Route path="settings" element={<SettingsPage />} />
          {/* Unknown paths fall back to the overview rather than a dead end. */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </QueryClientProvider>
  );
}
