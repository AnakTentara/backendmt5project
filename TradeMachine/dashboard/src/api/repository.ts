import type {
  BruteStatus,
  CommandAck,
  ConfigUpdate,
  HealthStatus,
  SessionMetrics,
  SymbolInfo,
  TradeList,
} from './contracts';

/**
 * Repository interface — the seam between UI and transport.
 *
 * WHY AN INTERFACE
 * ----------------
 * 1. The mock and HTTP implementations are interchangeable, so the toggle in
 *    `.env` swaps one for the other with no component changes and no mock code
 *    reachable in a production bundle beyond a single import.
 * 2. It is the exact shape of the Dart abstract class on the Flutter side.
 *    Porting means reimplementing these seven methods against `package:http`;
 *    no call sites move.
 * 3. No component ever touches `fetch`, a URL, or a schema. Endpoint knowledge
 *    stops at this boundary.
 *
 * Every method rejects with `ApiError` on failure. Implementations must not
 * swallow errors or return partial results — TanStack Query owns retry policy.
 */
export interface TradeMachineRepository {
  /** GET /api/health */
  getHealth(signal?: AbortSignal): Promise<HealthStatus>;

  /** GET /api/brute/status */
  getBruteStatus(signal?: AbortSignal): Promise<BruteStatus>;

  /**
   * POST /api/brute/on | /api/brute/off
   *
   * The ack only confirms the command file was written; MT5 polls it once per
   * second. Callers must reconcile against a later `getBruteStatus` rather
   * than treating the ack as applied state.
   */
  setBruteMode(active: boolean): Promise<CommandAck>;

  /**
   * POST /api/emergency/stop
   *
   * DESTRUCTIVE. Closes ALL positions, including regular non-Brute trades.
   * Callers must gate this behind explicit confirmation.
   */
  emergencyStop(): Promise<CommandAck>;

  /** POST /api/config/set */
  updateConfig(update: ConfigUpdate): Promise<CommandAck>;

  /** GET /api/trades/list */
  getTrades(limit: number, signal?: AbortSignal): Promise<TradeList>;

  /** GET /api/metrics/session */
  getSessionMetrics(signal?: AbortSignal): Promise<SessionMetrics>;

  /** GET /api/symbol/info */
  getSymbolInfo(signal?: AbortSignal): Promise<SymbolInfo>;
}
