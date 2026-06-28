export const ErrorCodes = {
  SESSION_EXPIRED: "SESSION_EXPIRED",
  FORBIDDEN: "FORBIDDEN",
  NOT_FOUND: "NOT_FOUND",
  SERIAL_ALREADY_RENTED: "SERIAL_ALREADY_RENTED",
  INSUFFICIENT_QTY: "INSUFFICIENT_QTY",
  VALIDATION_ERROR: "VALIDATION_ERROR",
  ERPNEXT_UNAVAILABLE: "ERPNEXT_UNAVAILABLE",
  UNAUTHORIZED: "UNAUTHORIZED",
} as const;

export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

export function httpStatusForCode(code: ErrorCode): number {
  switch (code) {
    case ErrorCodes.SESSION_EXPIRED:
    case ErrorCodes.UNAUTHORIZED:
      return 401;
    case ErrorCodes.FORBIDDEN:
      return 403;
    case ErrorCodes.NOT_FOUND:
      return 404;
    case ErrorCodes.SERIAL_ALREADY_RENTED:
    case ErrorCodes.INSUFFICIENT_QTY:
      return 409;
    case ErrorCodes.VALIDATION_ERROR:
      return 422;
    case ErrorCodes.ERPNEXT_UNAVAILABLE:
      return 502;
    default:
      return 500;
  }
}

export function mapErpnextError(status: number, message: string, detail?: unknown): ErrorCode {
  const detailText = extractDetailText(detail);
  const combined = `${message}\n${detailText}`.toLowerCase();

  if (status === 401 || status === 403) {
    return ErrorCodes.SESSION_EXPIRED;
  }
  if (status === 404) {
    return ErrorCodes.NOT_FOUND;
  }
  if (
    combined.includes("serial already rented") ||
    (combined.includes("serial") && combined.includes("active rental"))
  ) {
    return ErrorCodes.SERIAL_ALREADY_RENTED;
  }
  if (
    combined.includes("insufficient qty") ||
    combined.includes("insufficient stock")
  ) {
    return ErrorCodes.INSUFFICIENT_QTY;
  }
  if (status >= 500) {
    return ErrorCodes.ERPNEXT_UNAVAILABLE;
  }
  return ErrorCodes.VALIDATION_ERROR;
}

function extractDetailText(detail: unknown): string {
  if (typeof detail !== "object" || detail === null) {
    return "";
  }
  const record = detail as Record<string, unknown>;
  const parts: string[] = [];
  if (typeof record.message === "string") {
    parts.push(record.message);
  }
  if (typeof record.exc === "string") {
    parts.push(record.exc);
  }
  if (typeof record._server_messages === "string") {
    parts.push(record._server_messages);
  }
  return parts.join("\n");
}
