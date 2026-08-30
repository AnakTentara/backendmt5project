import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './httpClient';

/**
 * TanStack Query configuration.
 *
 * Tuned for a 1-second polling dashboard, which differs from typical web app
 * defaults in three ways worth stating:
 *
 * 1. `retry` never retries validation errors. A contract mismatch will fail
 *    identically on every attempt, so retrying only delays the error and
 *    triples the log noise.
 * 2. `staleTime` is 0. Every value on screen is a live market figure; there is
 *    no such thing as an acceptably stale spread reading.
 * 3. `refetchOnWindowFocus` is off. Polling already runs continuously, so focus
 *    refetches would just add a redundant burst on every alt-tab.
 */
export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 0,
        // Keep the previous value on screen while a refetch is in flight, so
        // numbers do not blank out once per second.
        gcTime: 5 * 60_000,
        refetchOnWindowFocus: false,
        refetchOnReconnect: true,
        retry: (failureCount, error) => {
          if (error instanceof ApiError) {
            if (!error.isRetryable) return false;
            return failureCount < 2;
          }
          return failureCount < 2;
        },
        // Short, bounded backoff. The bridge is on loopback; if it is down,
        // long exponential waits just make recovery feel broken.
        retryDelay: (attemptIndex) => Math.min(500 * 2 ** attemptIndex, 4_000),
      },
      mutations: {
        // Commands are not idempotent. Sending `emergency_stop` twice because
        // of an automatic retry is unacceptable, so mutations never retry.
        retry: false,
      },
    },
  });
}
