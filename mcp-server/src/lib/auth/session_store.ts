import type { JwtPayload } from "./jwt.js";
import { newSessionId } from "./jwt.js";

export interface StoredSession {
  id: string;
  sid: string;
  userId: string;
  email: string;
  fullName: string;
  roles: string[];
  expiresAt: number;
}

export class SessionStore {
  private readonly sessions = new Map<string, StoredSession>();

  constructor(private readonly ttlMs: number) {}

  create(input: Omit<StoredSession, "id" | "expiresAt">): StoredSession {
    const session: StoredSession = {
      ...input,
      id: newSessionId(),
      expiresAt: Date.now() + this.ttlMs,
    };
    this.sessions.set(session.id, session);
    return session;
  }

  get(sessionId: string): StoredSession | null {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return null;
    }
    if (session.expiresAt <= Date.now()) {
      this.sessions.delete(sessionId);
      return null;
    }
    return session;
  }

  delete(sessionId: string): void {
    this.sessions.delete(sessionId);
  }

  touch(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.expiresAt = Date.now() + this.ttlMs;
    }
  }

  toJwtPayload(session: StoredSession): Omit<JwtPayload, "iat" | "exp"> {
    return {
      sub: session.id,
      sid: session.sid,
      email: session.email,
      roles: session.roles,
    };
  }
}
