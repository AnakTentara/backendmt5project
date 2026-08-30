import { z } from 'zod';

/**
 * Runtime environment configuration.
 *
 * Vite hands every `VITE_*` value over as a string, so this module is the one
 * place where those strings are coerced and validated. Parsing once at startup
 * means a typo in `.env` fails loudly here instead of producing `NaN` inside a
 * polling interval an hour later.
 */

const envSchema = z.object({
  /**
   * WebBridge base URL.
   *
   * Defaults to port 5000 to match `WebBridge.py`. Note that `Config.mqh`
   * declares `Inp_HTTP_Port = 8080` for the MT5 side; that port is not what
   * this dashboard talks to.
   */
  apiBaseUrl: z
    .string()
    .url('VITE_API_BASE_URL must be a valid URL')
    // A trailing slash would produce `//api/health` once joined with a path.
    .transform((value) => value.replace(/\/+$/, '')),

  /**
   * When true, all repository calls resolve from the in-memory fixture set
   * instead of hitting HTTP. Four backend endpoints are still stubs, so this
   * keeps UI work unblocked without shipping placeholder data to production.
   */
  useMockApi: z.boolean(),

  /**
   * Polling cadence. Floored at 500ms: `HTTPReceiver.mqh` polls its command
   * file once per second, so a faster interval only adds load without
   * surfacing fresher data.
   */
  pollIntervalMs: z.number().int().min(500).max(60_000),

  requestTimeoutMs: z.number().int().min(1_000).max(60_000),

  /** True when running `vite dev`. Drives devtools and verbose logging. */
  isDev: z.boolean(),
});

export type Env = z.infer<typeof envSchema>;

/** Parses `"true"`/`"1"` as true; anything else (including undefined) is false. */
function parseBoolean(raw: string | undefined, fallback: boolean): boolean {
  if (raw === undefined || raw.trim() === '') return fallback;
  const normalised = raw.trim().toLowerCase();
  return normalised === 'true' || normalised === '1' || normalised === 'yes';
}

function parseInteger(raw: string | undefined, fallback: number): number {
  if (raw === undefined || raw.trim() === '') return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function loadEnv(): Env {
  const candidate = {
    apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:5000',
    useMockApi: parseBoolean(import.meta.env.VITE_USE_MOCK_API, true),
    pollIntervalMs: parseInteger(import.meta.env.VITE_POLL_INTERVAL_MS, 1_000),
    requestTimeoutMs: parseInteger(import.meta.env.VITE_REQUEST_TIMEOUT_MS, 8_000),
    isDev: import.meta.env.DEV,
  };

  const result = envSchema.safeParse(candidate);

  if (!result.success) {
    // Fail fast and loudly. A misconfigured dashboard that silently points at
    // the wrong port is worse than one that refuses to boot.
    const detail = result.error.issues
      .map((issue) => `  - ${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('\n');
    throw new Error(
      `Invalid environment configuration:\n${detail}\n\n` +
        'Check your .env file against .env.example.',
    );
  }

  return result.data;
}

export const env: Env = loadEnv();
