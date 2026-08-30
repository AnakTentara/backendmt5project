/**
 * Query key registry.
 *
 * Centralised so invalidation is never a guess. A typo in an inline key array
 * produces a silent cache miss rather than a compile error, which is exactly
 * the sort of bug that wastes an afternoon.
 *
 * `as const` on every tuple keeps the keys literal-typed, so TanStack Query can
 * infer data types through `queryKey` correctly.
 */
export const queryKeys = {
  /** Root namespace, for wholesale invalidation. */
  all: ['trademachine'] as const,

  health: () => [...queryKeys.all, 'health'] as const,

  brute: {
    all: () => [...queryKeys.all, 'brute'] as const,
    status: () => [...queryKeys.brute.all(), 'status'] as const,
  },

  metrics: {
    all: () => [...queryKeys.all, 'metrics'] as const,
    session: () => [...queryKeys.metrics.all(), 'session'] as const,
  },

  symbol: {
    all: () => [...queryKeys.all, 'symbol'] as const,
    info: () => [...queryKeys.symbol.all(), 'info'] as const,
  },

  trades: {
    all: () => [...queryKeys.all, 'trades'] as const,
    list: (limit: number) => [...queryKeys.trades.all(), 'list', limit] as const,
  },
} as const;
