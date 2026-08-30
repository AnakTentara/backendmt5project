import {
  bruteStatusResponseSchema,
  commandAckSchema,
  healthResponseSchema,
  sessionMetricsResponseSchema,
  symbolInfoResponseSchema,
  tradeListResponseSchema,
  type BruteStatus,
  type CommandAck,
  type ConfigUpdate,
  type HealthStatus,
  type SessionMetrics,
  type SymbolInfo,
  type TradeList,
} from './contracts';
import { request } from './httpClient';
import type { TradeMachineRepository } from './repository';

/**
 * Live implementation backed by the Flask WebBridge.
 *
 * Endpoint paths appear here and nowhere else in the codebase.
 */

/** Centralised path registry. Keeps route strings out of method bodies. */
const ENDPOINTS = {
  health: '/api/health',
  bruteStatus: '/api/brute/status',
  bruteOn: '/api/brute/on',
  bruteOff: '/api/brute/off',
  emergencyStop: '/api/emergency/stop',
  configSet: '/api/config/set',
  tradesList: '/api/trades/list',
  sessionMetrics: '/api/metrics/session',
  symbolInfo: '/api/symbol/info',
} as const;

export class HttpTradeMachineRepository implements TradeMachineRepository {
  getHealth(signal?: AbortSignal): Promise<HealthStatus> {
    return request({
      path: ENDPOINTS.health,
      schema: healthResponseSchema,
      ...(signal ? { signal } : {}),
    });
  }

  getBruteStatus(signal?: AbortSignal): Promise<BruteStatus> {
    return request({
      path: ENDPOINTS.bruteStatus,
      schema: bruteStatusResponseSchema,
      ...(signal ? { signal } : {}),
    });
  }

  setBruteMode(active: boolean): Promise<CommandAck> {
    return request({
      path: active ? ENDPOINTS.bruteOn : ENDPOINTS.bruteOff,
      method: 'POST',
      schema: commandAckSchema,
      // Flask reads no body here, but sending `{}` keeps the Content-Type
      // header consistent across POSTs.
      body: {},
    });
  }

  emergencyStop(): Promise<CommandAck> {
    return request({
      path: ENDPOINTS.emergencyStop,
      method: 'POST',
      schema: commandAckSchema,
      body: {},
    });
  }

  updateConfig(update: ConfigUpdate): Promise<CommandAck> {
    return request({
      path: ENDPOINTS.configSet,
      method: 'POST',
      schema: commandAckSchema,
      // Sent as-is in snake_case: the request body IS the wire contract.
      body: update,
    });
  }

  getTrades(limit: number, signal?: AbortSignal): Promise<TradeList> {
    return request({
      path: ENDPOINTS.tradesList,
      schema: tradeListResponseSchema,
      query: { limit },
      ...(signal ? { signal } : {}),
    });
  }

  getSessionMetrics(signal?: AbortSignal): Promise<SessionMetrics> {
    return request({
      path: ENDPOINTS.sessionMetrics,
      schema: sessionMetricsResponseSchema,
      ...(signal ? { signal } : {}),
    });
  }

  getSymbolInfo(signal?: AbortSignal): Promise<SymbolInfo> {
    return request({
      path: ENDPOINTS.symbolInfo,
      schema: symbolInfoResponseSchema,
      ...(signal ? { signal } : {}),
    });
  }
}
