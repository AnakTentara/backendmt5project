/// <reference types="vite/client" />

/**
 * Typed environment variables.
 *
 * Every value arrives from Vite as a string; parsing and validation happens
 * once in `src/config/env.ts`. Declaring them here prevents typos from
 * silently producing `undefined` at runtime.
 */
interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string;
  readonly VITE_USE_MOCK_API?: string;
  readonly VITE_POLL_INTERVAL_MS?: string;
  readonly VITE_REQUEST_TIMEOUT_MS?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
