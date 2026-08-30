import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { repository } from '@/api/provideRepository';
import { queryKeys } from '@/api/queryKeys';
import { env } from '@/config/env';
import type { ConfigUpdate } from '@/api/contracts';

/**
 * Data hooks.
 *
 * These are the ONLY place components obtain server state. A component never
 * imports `repository` directly, which keeps transport concerns out of the view
 * layer and makes the Flutter port a matter of swapping these hooks for
 * Riverpod providers / Blocs over the same repository interface.
 *
 * All read hooks poll at `env.pollIntervalMs` (1s by default), matching the MT5
 * command-file poll rate. Polling faster gains nothing.
 */

/** Bridge liveness. Drives the connection indicator. */
export function useHealth() {
  return useQuery({
    queryKey: queryKeys.health(),
    queryFn: ({ signal }) => repository.getHealth(signal),
    refetchInterval: env.pollIntervalMs,
    // Health is the connection canary, so keep polling even when the tab is
    // backgrounded; an operator returning to the tab should see a genuine
    // stale-state warning rather than a frozen "connected" badge.
    refetchIntervalInBackground: true,
  });
}

/** Live Brute Mode engine state. */
export function useBruteStatus() {
  return useQuery({
    queryKey: queryKeys.brute.status(),
    queryFn: ({ signal }) => repository.getBruteStatus(signal),
    refetchInterval: env.pollIntervalMs,
  });
}

/** Session KPIs. */
export function useSessionMetrics() {
  return useQuery({
    queryKey: queryKeys.metrics.session(),
    queryFn: ({ signal }) => repository.getSessionMetrics(signal),
    // Aggregates move slowly relative to price; a 3s cadence is ample and eases
    // load on a single-threaded Flask dev server.
    refetchInterval: env.pollIntervalMs * 3,
  });
}

/** Price, spread, trend, and nearest S/R. */
export function useSymbolInfo() {
  return useQuery({
    queryKey: queryKeys.symbol.info(),
    queryFn: ({ signal }) => repository.getSymbolInfo(signal),
    refetchInterval: env.pollIntervalMs,
  });
}

/** Recent trades. `limit` participates in the cache key. */
export function useTrades(limit = 50) {
  return useQuery({
    queryKey: queryKeys.trades.list(limit),
    queryFn: ({ signal }) => repository.getTrades(limit, signal),
    refetchInterval: env.pollIntervalMs * 2,
  });
}

/**
 * Brute Mode toggle.
 *
 * NO OPTIMISTIC UPDATE, deliberately. The ack confirms only that Flask wrote the
 * command file; MT5 reads it on its own 1-second cycle and may reject it.
 * Flipping the switch immediately would assert a state the engine has not
 * reached. Instead `isPending` drives a "queued" affordance and the next status
 * poll reveals the real state.
 */
export function useSetBruteMode() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (active: boolean) => repository.setBruteMode(active),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: queryKeys.brute.all() });
    },
  });
}

/**
 * Emergency stop.
 *
 * DESTRUCTIVE: closes ALL positions, including regular non-Brute trades. The
 * confirmation gate lives in the UI component; this hook assumes the caller has
 * already obtained explicit consent.
 */
export function useEmergencyStop() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => repository.emergencyStop(),
    onSuccess: () => {
      // Everything on screen is now suspect: positions, P&L, engine state.
      void queryClient.invalidateQueries({ queryKey: queryKeys.all });
    },
  });
}

/** Runtime config update. */
export function useUpdateConfig() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (update: ConfigUpdate) => repository.updateConfig(update),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: queryKeys.brute.all() });
    },
  });
}
