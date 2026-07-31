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

/**
 * AUTH MODE — deliberately SEPARATE from the data mode.
 *
 * - `demo` → the role explorer / persona switcher exist; a preview identity may
 *            be minted client-side with no backend token.
 * - `live` → the ONLY way in is phone → OTP → real bearer token. Every
 *            preview-identity code path is hard-disabled (see AuthContext).
 *
 * Split because a future dedicated demo deployment (`demo.nikshaos.in`) wants
 * demo AUTH on top of a LIVE demo-school backend — `VITE_DATA_MODE=live` +
 * `VITE_AUTH_MODE=demo`. Production sets neither and therefore gets live auth.
 *
 * FAIL-CLOSED: demo auth requires the exact literal `demo`. An unset, empty,
 * misspelt, differently-cased or unknown `VITE_AUTH_MODE` resolves to live auth
 * (when unset it falls back to the data mode), so no typo can open the demo
 * surface on a production host.
 *
 * Written deliberately as a direct comparison against `import.meta.env.*` and
 * NOT normalised (no trim/lowercase): Vite substitutes those reads with string
 * literals at build time, so the whole expression constant-folds and the
 * bundler ELIMINATES every `if (AUTH_IS_DEMO)` branch from a production build.
 * The demo UI is therefore absent from the shipped bytes, not merely hidden.
 * Any normalisation here would defeat that folding.
 */
export type AuthMode = 'demo' | 'live';

const rawAuthMode = import.meta.env.VITE_AUTH_MODE as string | undefined;
const rawDataMode = import.meta.env.VITE_DATA_MODE as string | undefined;

/** Mirrors `IS_DEMO` but in a foldable form (dataMode defaults to `demo`). */
const dataModeIsDemo = rawDataMode === undefined || rawDataMode === '' || rawDataMode === 'demo';

/** True only in a demo build. Guards every preview/role-explorer code path. */
export const IS_DEMO_AUTH: boolean =
  rawAuthMode === 'demo' || ((rawAuthMode === undefined || rawAuthMode === '') && dataModeIsDemo);

export const AUTH_MODE: AuthMode = IS_DEMO_AUTH ? 'demo' : 'live';
