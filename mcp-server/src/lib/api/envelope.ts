export interface ApiErrorBody {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

export interface ApiEnvelope<T> {
  ok: boolean;
  data: T | null;
  error: ApiErrorBody | null;
}

export function ok<T>(data: T): ApiEnvelope<T> {
  return { ok: true, data, error: null };
}

export function fail(
  code: string,
  message: string,
  details?: Record<string, unknown>,
): ApiEnvelope<null> {
  return {
    ok: false,
    data: null,
    error: { code, message, details },
  };
}
