import { config } from "dotenv";
config({ path: "mcp-server/.env.supabase" });

async function test() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;

  console.log("URL:", url);
  console.log("Key:", key?.substring(0, 20) + "...");

  // 1. Login (simulating Flutter)
  // We need a valid username/password to test. Since I don't have one, I can't do this easily.
  // Wait, I can try to hit the user endpoint directly with a bad token to see the EXACT 403 error.
  
  const badTokenResponse = await fetch(`${url}/auth/v1/user`, {
    headers: {
      apikey: key!,
      Authorization: `Bearer test.test.test`
    }
  });
  console.log("Bad token status:", badTokenResponse.status);
  console.log("Bad token body:", await badTokenResponse.text());
}
test();
