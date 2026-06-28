import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";

export interface JwtPayload {
  sub: string;
  sid: string;
  email: string;
  roles: string[];
  iat: number;
  exp: number;
}

function base64UrlEncode(input: string | Buffer): string {
  return Buffer.from(input)
    .toString("base64url");
}

function base64UrlDecode(input: string): string {
  return Buffer.from(input, "base64url").toString("utf8");
}

function sign(input: string, secret: string): string {
  return createHmac("sha256", secret).update(input).digest("base64url");
}

export function createAccessToken(
  payload: Omit<JwtPayload, "iat" | "exp">,
  secret: string,
  ttlSeconds: number,
): string {
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const body: JwtPayload = {
    ...payload,
    iat: now,
    exp: now + ttlSeconds,
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(body));
  const signature = sign(`${header}.${encodedPayload}`, secret);
  return `${header}.${encodedPayload}.${signature}`;
}

export function verifyAccessToken(token: string, secret: string): JwtPayload {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid token format");
  }
  const [header, payload, signature] = parts;
  const expected = sign(`${header}.${payload}`, secret);
  const a = Buffer.from(signature);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    throw new Error("Invalid token signature");
  }
  const decoded = JSON.parse(base64UrlDecode(payload)) as JwtPayload;
  const now = Math.floor(Date.now() / 1000);
  if (decoded.exp <= now) {
    throw new Error("Token expired");
  }
  return decoded;
}

export function newSessionId(): string {
  return randomUUID();
}
