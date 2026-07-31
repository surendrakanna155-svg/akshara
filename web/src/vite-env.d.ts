/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string;
  readonly VITE_DATA_MODE?: 'demo' | 'live';
  /**
   * Auth mode. Defaults to VITE_DATA_MODE. Set to `demo` for a dedicated demo
   * deployment that wants the role explorer on top of a live backend. Anything
   * other than the literal `demo` resolves to live auth (fail-closed).
   */
  readonly VITE_AUTH_MODE?: 'demo' | 'live';
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
