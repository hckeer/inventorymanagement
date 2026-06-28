import { ErpnextError } from "../erpnext_client.js";

export interface ErpnextLoginResult {
  sid: string;
  userId: string;
  email: string;
  fullName: string;
  roles: string[];
}

export async function loginToErpnext(
  baseUrl: string,
  username: string,
  password: string,
): Promise<ErpnextLoginResult> {
  const url = `${baseUrl}/api/method/login`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ usr: username, pwd: password }),
  });

  const text = await response.text();
  let payload: { message?: string; exc?: string } | null = null;
  if (text) {
    try {
      payload = JSON.parse(text) as { message?: string; exc?: string };
    } catch {
      payload = null;
    }
  }

  if (!response.ok) {
    throw new ErpnextError(
      payload?.message || "Invalid ERPNext credentials",
      response.status,
      payload,
    );
  }

  const sid = parseSidFromSetCookie(response.headers.get("set-cookie"));
  if (!sid) {
    throw new ErpnextError("ERPNext login did not return a session id", 502);
  }

  const profile = await fetchErpnextProfile(baseUrl, sid);
  return {
    sid,
    userId: profile.name,
    email: profile.email,
    fullName: profile.full_name,
    roles: profile.roles,
  };
}

export async function logoutFromErpnext(
  baseUrl: string,
  sid: string,
): Promise<void> {
  await fetch(`${baseUrl}/api/method/logout`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      Cookie: `sid=${sid}`,
    },
  });
}

export async function fetchErpnextProfile(
  baseUrl: string,
  sid: string,
): Promise<{ name: string; email: string; full_name: string; roles: string[] }> {
  const response = await fetch(
    `${baseUrl}/api/method/frappe.auth.get_logged_user`,
    {
      headers: {
        Accept: "application/json",
        Cookie: `sid=${sid}`,
      },
    },
  );
  if (!response.ok) {
    throw new ErpnextError("Failed to load ERPNext user profile", response.status);
  }

  const userIdPayload = (await response.json()) as { message: string };
  const userId = userIdPayload.message;

  const userResponse = await fetch(
    `${baseUrl}/api/resource/User/${encodeURIComponent(userId)}?fields=${encodeURIComponent(JSON.stringify(["name", "email", "full_name"]))}`,
    {
      headers: {
        Accept: "application/json",
        Cookie: `sid=${sid}`,
      },
    },
  );
  if (!userResponse.ok) {
    throw new ErpnextError("Failed to load ERPNext user document", userResponse.status);
  }

  const userDoc = (await userResponse.json()) as {
    data: { name: string; email: string; full_name: string };
  };

  const rolesResponse = await fetch(
    `${baseUrl}/api/method/frappe.core.doctype.user.user.get_roles`,
    {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        Cookie: `sid=${sid}`,
      },
      body: JSON.stringify({ uid: userId }),
    },
  );

  let roles: string[] = [];
  if (rolesResponse.ok) {
    const rolesPayload = (await rolesResponse.json()) as { message?: string[] };
    roles = rolesPayload.message ?? [];
  }

  return {
    name: userDoc.data.name,
    email: userDoc.data.email,
    full_name: userDoc.data.full_name,
    roles,
  };
}

function parseSidFromSetCookie(setCookie: string | null): string | null {
  if (!setCookie) {
    return null;
  }
  const match = /(?:^|,\s*)sid=([^;]+)/i.exec(setCookie);
  return match?.[1] ?? null;
}
