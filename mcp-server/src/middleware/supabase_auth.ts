import type { NextFunction, Request, Response } from "express";

import { fail } from "../lib/api/envelope.js";
import { ErrorCodes, httpStatusForCode } from "../lib/api/codes.js";
import type { SupabaseAuthClient } from "../lib/supabase_auth_client.js";

export interface SupabaseAuthenticatedRequest extends Request {
  user?: { id: string; email: string | null };
}

export function createSupabaseAuthMiddleware(authClient: SupabaseAuthClient) {
  return async (req: SupabaseAuthenticatedRequest, res: Response, next: NextFunction) => {
    const header = req.header("authorization");
    if (!header?.startsWith("Bearer ")) {
      res.status(httpStatusForCode(ErrorCodes.UNAUTHORIZED)).json(fail(ErrorCodes.UNAUTHORIZED, "Authorization header required"));
      return;
    }
    try {
      const user = await authClient.getUser(header.slice(7).trim());
      if (!user) {
        res.status(httpStatusForCode(ErrorCodes.SESSION_EXPIRED)).json(fail(ErrorCodes.SESSION_EXPIRED, "Session expired — please log in again"));
        return;
      }
      req.user = user;
      next();
    } catch {
      res.status(502).json(fail(ErrorCodes.ERPNEXT_UNAVAILABLE, "Supabase Auth is unavailable"));
    }
  };
}
