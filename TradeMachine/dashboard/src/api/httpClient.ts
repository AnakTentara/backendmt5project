// `z` is used only in type positions here (`z.ZodTypeAny`, `z.infer`); schemas
// themselves are supplied by callers.
import type { z } from 'zod';
import { env } from '@/config/env';

/**
 * Minimal typed HTTP client.
 *
 * Deliberately not axios: the surface needed here is small, and `fetch` plus
 * `AbortController` maps cleanly onto Dart's `http` package, keeping the
 * Flutter port structurally identical.
 *
 * Every response is parsed through a Zod schema. There is no `any` escape
 * hatch and no unvalidated `.json()` call anywhere in the app.
 */

/** Discriminated error type so callers can branch without string matching. */
export type ApiErrorKind =
  | 'network'      // bridge unreachable — WebBridge.py likely not running
  | 'timeout'      // exceeded requestTimeoutMs
  | 'http'         // non-2xx response
  | 'validation'   // 2xx but the body did not match the contract
  | 'aborted';     // cancelled by the caller

export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  readonly status: number | null;
  readonly endpoint: string;
  /** Zod issues, present only when `kind === 'validation'`. */
  readonly issues: readonly string[];

  constructor(params: {
    kind: ApiErrorKind;
    message: string;
    endpoint: string;
    status?: number | null;
    issues?: readonly string[];
  }) {
    super(params.message);
    this.name = 'ApiError';
    this.kind = params.kind;
    this.status = params.status ?? null;
    this.endpoint = params.endpoint;
    this.issues = params.issues ?? [];
  }

  /** Operator-facing copy. Distinguishes "bridge down" from "contract drift". */
  get userMessage(): string {
    switch (this.kind) {
      case 'network':
        return 'Cannot reach the WebBridge. Confirm WebBridge.py is running.';
      case 'timeout':
        return 'The bridge did not respond in time.';
      case 'http':
        return `The bridge returned an error (HTTP ${this.status ?? '?'}).`;
      case 'validation':
        return 'The bridge returned data in an unexpected format. The backend contract may have changed.';
      case 'aborted':
        return 'Request cancelled.';
    }
  }

  /** True when retrying could plausibly succeed. Validation errors cannot. */
  get isRetryable(): boolean {
    return this.kind === 'network' || this.kind === 'timeout';
  }
}

/**
 * Generic is the schema's OUTPUT type, not the schema type itself.
 *
 * Parameterising on `TSchema extends z.ZodTypeAny` and returning
 * `z.infer<TSchema>` looks natural but resolves to `any` while the generic is
 * unresolved, which silently disables type checking on every call site.
 * `ZodType<TOutput>` keeps the output concrete and inference intact.
 */
interface RequestOptions<TOutput> {
  readonly path: string;
  readonly schema: z.ZodType<TOutput, z.ZodTypeDef, unknown>;
  readonly method?: 'GET' | 'POST';
  readonly body?: unknown;
  readonly signal?: AbortSignal;
  readonly query?: Readonly<Record<string, string | number>>;
}

function buildUrl(
  path: string,
  query?: Readonly<Record<string, string | number>>,
): string {
  const url = new URL(`${env.apiBaseUrl}${path}`);
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, String(value));
    }
  }
  return url.toString();
}

/**
 * Performs a request and validates the response against `schema`.
 * Returns the schema's OUTPUT type, i.e. already transformed to camelCase.
 */
export async function request<TOutput>(
  options: RequestOptions<TOutput>,
): Promise<TOutput> {
  const { path, schema, method = 'GET', body, signal, query } = options;
  const url = buildUrl(path, query);

  // Compose caller cancellation with our own timeout so either can abort.
  const timeoutController = new AbortController();
  const timeoutId = window.setTimeout(
    () => timeoutController.abort(),
    env.requestTimeoutMs,
  );

  const onCallerAbort = () => timeoutController.abort();
  signal?.addEventListener('abort', onCallerAbort);

  let response: Response;

  try {
    // Keys are spread conditionally rather than set to `undefined`:
    // `exactOptionalPropertyTypes` treats an explicit undefined as a distinct
    // value from an absent key, and `RequestInit` accepts neither for `body`.
    response = await fetch(url, {
      method,
      signal: timeoutController.signal,
      ...(body === undefined
        ? {}
        : {
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
          }),
    });
  } catch (cause) {
    if (signal?.aborted) {
      throw new ApiError({ kind: 'aborted', message: 'Cancelled', endpoint: path });
    }
    if (timeoutController.signal.aborted) {
      throw new ApiError({
        kind: 'timeout',
        message: `Timed out after ${env.requestTimeoutMs}ms`,
        endpoint: path,
      });
    }
    throw new ApiError({
      kind: 'network',
      message: cause instanceof Error ? cause.message : 'Network failure',
      endpoint: path,
    });
  } finally {
    window.clearTimeout(timeoutId);
    signal?.removeEventListener('abort', onCallerAbort);
  }

  if (!response.ok) {
    // Flask's error handlers return `{"error": "..."}`; surface it when present.
    let detail = response.statusText;
    try {
      const payload: unknown = await response.json();
      if (
        typeof payload === 'object' &&
        payload !== null &&
        'error' in payload &&
        typeof (payload as { error: unknown }).error === 'string'
      ) {
        detail = (payload as { error: string }).error;
      }
    } catch {
      // Body was not JSON. The status code alone is the signal.
    }

    throw new ApiError({
      kind: 'http',
      message: detail,
      endpoint: path,
      status: response.status,
    });
  }

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    throw new ApiError({
      kind: 'validation',
      message: 'Response body was not valid JSON',
      endpoint: path,
      status: response.status,
    });
  }

  const parsed = schema.safeParse(payload);

  if (!parsed.success) {
    const issues = parsed.error.issues.map(
      (issue) => `${issue.path.join('.') || '(root)'}: ${issue.message}`,
    );

    // Contract drift is a development-time bug, so log the full payload once
    // rather than making someone reconstruct it from a stack trace.
    if (env.isDev) {
      console.error(
        `[ApiError] Contract mismatch on ${path}`,
        { issues, payload },
      );
    }

    throw new ApiError({
      kind: 'validation',
      message: `Response did not match contract for ${path}`,
      endpoint: path,
      status: response.status,
      issues,
    });
  }

  // Concrete `TOutput`, so no assertion is needed here.
  return parsed.data;
}
