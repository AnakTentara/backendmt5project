import { env } from '@/config/env';
import { HttpTradeMachineRepository } from './httpRepository';
import { MockTradeMachineRepository } from './mockRepository';
import type { TradeMachineRepository } from './repository';

/**
 * Repository provider — the single decision point between mock and live data.
 *
 * Constructed once at module load. The choice is fixed for the session because
 * swapping transports mid-flight would leave TanStack Query holding cache
 * entries from two different sources.
 *
 * On the Flutter side this is where `get_it` / `Provider` registration goes;
 * the rest of the app depends on the interface, never on either concrete class.
 */
function createRepository(): TradeMachineRepository {
  if (env.useMockApi) {
    // Loud on purpose. Mock data that goes unnoticed is how a "working"
    // dashboard ends up showing fabricated P&L.
    console.warn(
      '[TradeMachine] Running against the MOCK repository. ' +
        'All figures are simulated. Set VITE_USE_MOCK_API=false for live data.',
    );
    return new MockTradeMachineRepository();
  }

  return new HttpTradeMachineRepository();
}

export const repository: TradeMachineRepository = createRepository();

/** True when the active repository serves simulated data. */
export const isUsingMockData = env.useMockApi;
