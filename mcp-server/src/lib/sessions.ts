import type { ScanSession } from "./types.js";

const sessions = new Map<string, ScanSession>();

export function createSession(session: ScanSession): ScanSession {
  sessions.set(session.id, session);
  return session;
}

export function getSession(sessionId: string): ScanSession | undefined {
  return sessions.get(sessionId);
}

export function updateSession(
  sessionId: string,
  patch: Partial<ScanSession>,
): ScanSession {
  const existing = sessions.get(sessionId);
  if (!existing) {
    throw new SessionNotFoundError(sessionId);
  }
  const updated = { ...existing, ...patch };
  sessions.set(sessionId, updated);
  return updated;
}

export function deleteSession(sessionId: string): void {
  sessions.delete(sessionId);
}

export class SessionNotFoundError extends Error {
  constructor(sessionId: string) {
    super(`Session not found: ${sessionId}`);
    this.name = "SessionNotFoundError";
  }
}

export function clearSessionsForTests(): void {
  sessions.clear();
}
