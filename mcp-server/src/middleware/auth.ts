import type { NextFunction, Request, Response } from "express";

import { fail } from "../lib/api/envelope.js";
import { ErrorCodes, httpStatusForCode } from "../lib/api/codes.js";
import { verifyAccessToken } from "../lib/auth/jwt.js";
import type { SessionStore } from "../lib/auth/session_store.js";
import { ErpnextSessionClient } from "../lib/erpnext_session_client.js";

export interface AuthenticatedRequest extends Request {
  sessionId?: string;
  erpnext?: ErpnextSessionClient;
  user?: {
    id: string;
    email: string;
    fullName: string;
    roles: string[];
  };
}

export function createAuthMiddleware(
  sessionStore: SessionStore,
  jwtSecret: string,
  erpnextUrl: string,
) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    const header = req.header("authorization");
    if (!header?.startsWith("Bearer ")) {
      res
        .status(httpStatusForCode(ErrorCodes.UNAUTHORIZED))
        .json(fail(ErrorCodes.UNAUTHORIZED, "Authorization header required"));
      return;
    }

    const token = header.slice("Bearer ".length).trim();
    try {
      const payload = verifyAccessToken(token, jwtSecret);
      const session = sessionStore.get(payload.sub);
      if (!session || session.sid !== payload.sid) {
        res
          .status(httpStatusForCode(ErrorCodes.SESSION_EXPIRED))
          .json(fail(ErrorCodes.SESSION_EXPIRED, "Session expired — please log in again"));
        return;
      }

      sessionStore.touch(session.id);
      req.sessionId = session.id;
      req.user = {
        id: session.userId,
        email: session.email,
        fullName: session.fullName,
        roles: session.roles,
      };
      req.erpnext = new ErpnextSessionClient(erpnextUrl, session.sid);
      next();
    } catch {
      res
        .status(httpStatusForCode(ErrorCodes.SESSION_EXPIRED))
        .json(fail(ErrorCodes.SESSION_EXPIRED, "Session expired — please log in again"));
    }
  };
}
