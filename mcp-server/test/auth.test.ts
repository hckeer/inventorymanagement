import { describe, expect, it } from "vitest";

import { createAccessToken, verifyAccessToken } from "../src/lib/auth/jwt.js";
import { SessionStore } from "../src/lib/auth/session_store.js";

describe("jwt", () => {
  it("round-trips access token payload", () => {
    const token = createAccessToken(
      {
        sub: "session-1",
        sid: "sid-abc",
        email: "admin@example.com",
        roles: ["System Manager"],
      },
      "test-secret",
      3600,
    );
    const payload = verifyAccessToken(token, "test-secret");
    expect(payload.sub).toBe("session-1");
    expect(payload.sid).toBe("sid-abc");
    expect(payload.email).toBe("admin@example.com");
  });
});

describe("SessionStore", () => {
  it("creates and retrieves sessions", () => {
    const store = new SessionStore(60_000);
    const session = store.create({
      sid: "sid",
      userId: "Administrator",
      email: "admin@example.com",
      fullName: "Administrator",
      roles: ["System Manager"],
    });
    expect(store.get(session.id)?.userId).toBe("Administrator");
    store.delete(session.id);
    expect(store.get(session.id)).toBeNull();
  });
});
