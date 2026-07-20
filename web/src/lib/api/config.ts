/**
 * API configuration. Mirrors lib/core/network/api_config.dart +
 * lib/core/config/environment.dart.
 *
 * DATA MODE (owner-locked): the web platform NEVER fabricates business data.
 * - `live`  → pages hit the real Supabase edge function.
 * - `demo`  → the backend is not wired yet, so pages render loading/empty/error/
 *             "awaiting backend" states instead of any mock data. (Default.)
 * Set `VITE_DATA_MODE=live` + `VITE_API_BASE_URL` to connect the real backend.
 * A single shared Demo School dataset is provided later as a separate phase.
 */
export type DataMode = 'demo' | 'live';

const env = import.meta.env;

export const API_CONFIG = {
  baseUrl: (env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '') || 'http://localhost:8080/v1',
  dataMode: ((env.VITE_DATA_MODE as string | undefined) || 'demo') as DataMode,
  headers: {
    apiVersion: 'X-Api-Version',
    tenantId: 'X-Tenant-Id',
    schoolId: 'X-School-Id',
    userId: 'X-User-Id',
    correlationId: 'X-Correlation-Id',
  },
  apiVersion: '1',
  connectTimeoutMs: 15000,
  receiveTimeoutMs: 30000,
} as const;

export const IS_DEMO = API_CONFIG.dataMode === 'demo';
