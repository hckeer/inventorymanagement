import { reconcileScannedVsExpected } from "../lib/diff.js";
import {
  getSession,
  SessionNotFoundError,
  updateSession,
} from "../lib/sessions.js";
import type { SessionEndResult } from "../lib/types.js";

export interface EndSessionInput {
  session_id: string;
}

export async function endSession(
  input: EndSessionInput,
): Promise<SessionEndResult> {
  const session = getSession(input.session_id);
  if (!session) {
    throw new SessionNotFoundError(input.session_id);
  }

  const result = reconcileScannedVsExpected(
    session.expected_audited,
    session.scanned,
  );

  updateSession(input.session_id, {
    ended_at: new Date().toISOString(),
    end_result: result,
  });

  return result;
}
